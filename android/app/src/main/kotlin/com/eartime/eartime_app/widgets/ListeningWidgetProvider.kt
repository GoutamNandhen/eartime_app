package com.eartime.eartime_app.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import com.eartime.eartime_app.NavigationTarget
import com.eartime.eartime_app.R
import com.eartime.eartime_app.tracking.NativeJournalRuntime
import java.util.Calendar

open class ListeningWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        ListeningWidgets.refresh(context) { pending?.finish() }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle) {
        onUpdate(context, manager, intArrayOf(id))
    }
}

class CurrentListeningWidgetProvider : ListeningWidgetProvider()
class DailyListeningWidgetProvider : ListeningWidgetProvider()

object ListeningWidgets {
    private val main = Handler(Looper.getMainLooper())
    private var scheduled = false

    fun observationCommitted(context: Context) {
        main.post {
            if (scheduled || providers.all { ids(context, it).isEmpty() }) return@post
            scheduled = true
            main.postDelayed({ scheduled = false; refresh(context) {} }, 1000)
        }
    }

    private val providers = listOf(ListeningWidgetProvider::class.java,
        CurrentListeningWidgetProvider::class.java, DailyListeningWidgetProvider::class.java)

    private fun ids(context: Context, provider: Class<out AppWidgetProvider>) = AppWidgetManager.getInstance(context)
        .getAppWidgetIds(ComponentName(context, provider))

    private fun update(context: Context, snapshot: Map<String, Any?>) {
        providers.forEach { provider ->
            val targets = ids(context, provider)
            if (targets.isNotEmpty()) AppWidgetManager.getInstance(context).updateAppWidget(targets,
                if (provider == ListeningWidgetProvider::class.java) render(context, snapshot)
                else renderSummary(context, snapshot, provider == CurrentListeningWidgetProvider::class.java))
        }
    }

    fun refresh(context: Context, completed: () -> Unit) {
        if (providers.all { ids(context, it).isEmpty() }) { completed(); return }
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val from = calendar.timeInMillis
        calendar.add(Calendar.DAY_OF_MONTH, 1)
        NativeJournalRuntime.readListening(from, calendar.timeInMillis, calendar.timeZone.id, 0, 1, { snapshot ->
            try { update(context, snapshot) }
            finally { completed() }
        }, {
            try {
                update(context, emptyMap())
            } finally { completed() }
        })
    }

    fun render(context: Context, snapshot: Map<String, Any?>): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.listening_widget)
        views.setTextViewText(R.id.widget_total, if (snapshot.isEmpty()) "--" else duration(snapshot["confirmedMs"]))
        views.setTextViewText(R.id.widget_status, if (snapshot["lastError"] != null) "Collection incomplete"
            else if (snapshot.isEmpty()) "History unavailable" else "Confirmed listening today")
        val intent = PendingIntent.getActivity(context, 0, NavigationTarget.intent(context, "devices"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_root, intent)
        val devices = (snapshot["devices"] as? List<*>)?.mapNotNull { it as? Map<*, *> }
            ?.sortedByDescending { it["connected"] == true } ?: emptyList()
        val visibleCount = if (context.resources.configuration.fontScale > 1.3f) 2 else 4
        views.setViewVisibility(R.id.widget_second_row, if (visibleCount == 2) android.view.View.GONE else android.view.View.VISIBLE)
        val names = intArrayOf(R.id.device_name_1, R.id.device_name_2, R.id.device_name_3, R.id.device_name_4)
        val states = intArrayOf(R.id.device_state_1, R.id.device_state_2, R.id.device_state_3, R.id.device_state_4)
        val batteries = intArrayOf(R.id.device_battery_1, R.id.device_battery_2, R.id.device_battery_3, R.id.device_battery_4)
        for (index in names.indices) {
            val device = devices.getOrNull(index)
            views.setTextViewText(names[index], device?.get("name") as? String ?: "No device")
            views.setTextViewText(states[index], when {
                device == null -> "Not observed"
                device["connectionState"] == "UNKNOWN" -> "Connection unknown"
                device["connected"] == true -> "Last observed connected"
                device["connectionState"] == "DISCONNECTED_REPORTED" -> "Disconnection reported"
                else -> "Connection unknown"
            })
            // No validated battery collector exists. Unknown is never rendered as zero or a stale percentage.
            views.setTextViewText(batteries[index], "Battery unknown")
        }
        val deviceCount = snapshot["deviceCount"] as? Long ?: devices.size.toLong()
        views.setTextViewText(R.id.widget_more, if (deviceCount > visibleCount) "+${deviceCount - visibleCount} records" else "EarTime")
        return views
    }

    private fun duration(value: Any?): String {
        val minutes = ((value as? Number)?.toLong() ?: 0).coerceAtLeast(0) / 60000
        return "${minutes / 60}h ${minutes % 60}m"
    }

    fun renderSummary(context: Context, snapshot: Map<String, Any?>, current: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.listening_summary_widget)
        val unavailable = snapshot.isEmpty()
        val intervals = (snapshot["intervals"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        val active = ((snapshot["openIntervalCount"] as? Number)?.toLong()
            ?: intervals.count { it["open"] == true }.toLong()) > 0
        val incomplete = snapshot["lastError"] != null || ((snapshot["failedCount"] as? Number)?.toLong() ?: 0) > 0
        views.setTextViewText(R.id.summary_title, if (current) "EarTime activity" else "EarTime today")
        views.setTextViewText(R.id.summary_total, when {
            unavailable -> "--"
            !current -> duration(snapshot["confirmedMs"])
            active -> "Playback last observed"
            else -> "No active playback observed"
        })
        views.setTextViewText(R.id.summary_status, when {
            unavailable -> "History unavailable"
            incomplete -> "Collection incomplete; unknown time excluded"
            current -> "Current output and continuity unverified"
            else -> "Confirmed listening\nUnverified activity: ${duration(snapshot["unverifiedMs"])}"
        })
        views.setOnClickPendingIntent(R.id.summary_root, PendingIntent.getActivity(context, if (current) 1 else 2,
            NavigationTarget.intent(context, if (current) "home" else "analytics"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        return views
    }
}
