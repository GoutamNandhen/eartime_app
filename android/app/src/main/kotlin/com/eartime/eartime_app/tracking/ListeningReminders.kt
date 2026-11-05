package com.eartime.eartime_app.tracking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.eartime.eartime_app.NavigationTarget
import com.eartime.eartime_app.R
import java.util.TimeZone

/**
 * F2/F3 listening reminders. Settings are personal duration guidance, not a sound-exposure limit.
 * Only CONFIRMED listening (projection v6+) can start a reminder; unverified activity never does.
 */
internal data class ReminderPreferences(val enabled: Boolean = true, val continuousMinutes: Int = 60,
    val repeatMinutes: Int = 30, val breakMinutes: Int = 5) {
    init {
        require(continuousMinutes in 5..480 && repeatMinutes in 5..240 && breakMinutes in 1..60)
    }
    fun wire(): Map<String, Any?> = mapOf("version" to 1, "enabled" to enabled, "continuousMinutes" to continuousMinutes,
        "repeatMinutes" to repeatMinutes, "breakMinutes" to breakMinutes)
    companion object {
        private val keys = setOf("version", "enabled", "continuousMinutes", "repeatMinutes", "breakMinutes")
        fun decode(value: Any?): ReminderPreferences {
            if (value == null) return ReminderPreferences()
            require(value is Map<*, *> && value.keys == keys && value["version"] == 1 && value["enabled"] is Boolean)
            fun number(key: String): Int {
                val raw = value[key]; require(raw is Int || raw is Long)
                val n = (raw as Number).toLong(); require(n in 1..1440); return n.toInt()
            }
            return ReminderPreferences(value["enabled"] as Boolean, number("continuousMinutes"),
                number("repeatMinutes"), number("breakMinutes"))
        }
        fun stored(raw: String?): ReminderPreferences = if (raw == null) ReminderPreferences() else {
            require(raw.length <= 512)
            decode(JournalJson.toValue(org.json.JSONObject(raw)))
        }
    }
}

internal data class ReminderState(val runStartUtcMs: Long, val lastNotifiedUtcMs: Long, val count: Int)

internal enum class ReminderKind { CONTINUOUS, BREAK }
internal data class ReminderDecision(val kind: ReminderKind, val runStartUtcMs: Long, val listenedMs: Long, val state: ReminderState)

internal object ReminderPolicy {
    /** Evidence must reach within this much of now for the run to count as still going. */
    const val LIVE_SLACK_MS = CollectorHealth.MAX_LEASE_MS + 5000

    /**
     * The current continuous run: the newest confirmed span must still be live, and earlier spans join it
     * while the pause between them is shorter than the break length. Returns start to newest end.
     */
    fun currentRun(spans: List<Pair<Long, Long>>, now: Long, breakMs: Long): Pair<Long, Long>? {
        val merged = mutableListOf<Pair<Long, Long>>()
        spans.filter { it.second > it.first }.sortedBy { it.first }.forEach { span ->
            val last = merged.lastOrNull()
            if (last != null && span.first <= last.second) merged[merged.lastIndex] = last.first to maxOf(last.second, span.second)
            else merged.add(span)
        }
        val newest = merged.lastOrNull() ?: return null
        if (newest.second < now - LIVE_SLACK_MS || newest.first > now) return null
        var start = newest.first
        for (index in merged.lastIndex - 1 downTo 0) {
            if (start - merged[index].second < breakMs) start = merged[index].first else break
        }
        return start to newest.second
    }

    fun decide(preferences: ReminderPreferences, run: Pair<Long, Long>?, now: Long, state: ReminderState?, quiet: Boolean): ReminderDecision? {
        if (!preferences.enabled || run == null || quiet) return null
        val listened = run.second - run.first
        if (listened < preferences.continuousMinutes * 60000L) return null
        if (state == null || state.runStartUtcMs != run.first)
            return ReminderDecision(ReminderKind.CONTINUOUS, run.first, listened, ReminderState(run.first, now, 1))
        if (now - state.lastNotifiedUtcMs >= preferences.repeatMinutes * 60000L)
            return ReminderDecision(ReminderKind.BREAK, run.first, listened, ReminderState(run.first, now, state.count + 1))
        return null
    }
}

internal object ListeningReminders {
    const val CHANNEL = "listening_reminders_v1"
    private const val NOTIFICATION_ID = 4201
    private const val WINDOW_MS = 12 * 3600_000L
    private const val THROTTLE_MS = 30_000L
    @Volatile private var lastEvaluatedElapsed = Long.MIN_VALUE / 2

    private fun state(context: Context) = context.getSharedPreferences("eartime_listening_reminders_v1", Context.MODE_PRIVATE)

    /** Runs on the journal worker after an observer sample commits. Never throws into the collector path. */
    fun evaluate(context: Context, store: ObservationJournal, now: ObservationTime) {
        val elapsed = now.elapsedMs ?: return
        if (elapsed - lastEvaluatedElapsed < THROTTLE_MS) return
        lastEvaluatedElapsed = elapsed
        try {
            val preferences = ListeningPreferences(context).reminders()
            if (!preferences.enabled) return
            val snapshot = store.listeningSnapshot(now.wallUtcMs - WINDOW_MS, now.wallUtcMs + 1, TimeZone.getDefault().id, now)
            val spans = (snapshot["intervals"] as List<*>).mapNotNull { it as? Map<*, *> }
                .filter { it["attribution"] == "CONFIRMED" }
                .map { (it["clippedStartUtcMs"] as Number).toLong() to (it["clippedEndUtcMs"] as Number).toLong() }
            val run = ReminderPolicy.currentRun(spans, now.wallUtcMs, preferences.breakMinutes * 60000L)
            val stored = state(context)
            val previous = if (stored.contains("runStart")) ReminderState(stored.getLong("runStart", 0),
                stored.getLong("lastNotified", 0), stored.getInt("count", 0)) else null
            val quiet = WellbeingSchedule.quiet(now.wallUtcMs, TimeZone.getDefault().id, ListeningPreferences(context).wellbeing())
            val decision = ReminderPolicy.decide(preferences, run, now.wallUtcMs, previous, quiet) ?: return
            // Receipt first: a crash between receipt and notify can miss one reminder, never repeat it.
            if (!stored.edit().putLong("runStart", decision.state.runStartUtcMs).putLong("lastNotified", decision.state.lastNotifiedUtcMs)
                .putInt("count", decision.state.count).commit()) return
            post(context, decision)
        } catch (_: Exception) { /* Reminders are best effort and must never disturb collection. */ }
    }

    private fun post(context: Context, decision: ReminderDecision) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        if (Build.VERSION.SDK_INT >= 26) {
            if (manager.getNotificationChannel(CHANNEL) == null)
                manager.createNotificationChannel(NotificationChannel(CHANNEL, "Listening reminders", NotificationManager.IMPORTANCE_DEFAULT))
            if (manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return
        }
        val minutes = decision.listenedMs / 60000
        val duration = if (minutes >= 60) "${minutes / 60} h ${minutes % 60} min" else "$minutes min"
        val title = if (decision.kind == ReminderKind.CONTINUOUS) "Time for a listening break" else "Still listening"
        val text = "You have been listening for $duration without a break. Resting your ears for a few minutes helps."
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.widget_headphones).setContentTitle(title)
            .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text))
            .setVisibility(Notification.VISIBILITY_PRIVATE).setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, NOTIFICATION_ID, NavigationTarget.intent(context, "wellbeing"),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build()
        try { manager.notify(NOTIFICATION_ID, notification) } catch (_: Exception) {}
    }
}
