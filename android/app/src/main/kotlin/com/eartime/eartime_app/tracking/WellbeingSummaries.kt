package com.eartime.eartime_app.tracking

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import com.eartime.eartime_app.NavigationTarget
import com.eartime.eartime_app.R
import java.util.Calendar
import java.util.TimeZone

internal object WellbeingSummaries {
    const val ACTION = "com.eartime.app.RECORDED_SUMMARY"
    const val CHANNEL = "recorded_listening_summaries_v1"
    private fun id(kind: String) = if (kind == "daily") 4101 else 4102
    private fun state(context: Context) = context.getSharedPreferences("eartime_summary_delivery_v1", Context.MODE_PRIVATE)
    fun refresh(context: Context): Map<String, Any?> = try { reconcile(context) } catch (_: Exception) {
        state(context).edit().putString("lastResult", "SCHEDULING_UNAVAILABLE").commit()
        mapOf("version" to 1, "permissionGranted" to null, "schedulingAvailable" to false,
            "liveRemindersEligible" to false, "dailyUtcMs" to null, "weeklyUtcMs" to null, "delivery" to "SCHEDULING_UNAVAILABLE")
    }
    private fun intent(context: Context, kind: String) = Intent(context, WellbeingSummaryReceiver::class.java).setAction(ACTION).putExtra("kind", kind)
    private fun permission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    }
    fun reconcile(context: Context, now: Long = System.currentTimeMillis(), zone: String = TimeZone.getDefault().id): Map<String, Any?> {
        val config = ListeningPreferences(context).wellbeing()
        val receiver = ComponentName(context, WellbeingSummaryReceiver::class.java)
        val desired = if (config.daily || config.weekly) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        if (context.packageManager.getComponentEnabledSetting(receiver) != desired)
            context.packageManager.setComponentEnabledSetting(receiver, desired, PackageManager.DONT_KILL_APP)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if ((config.daily || config.weekly) && Build.VERSION.SDK_INT >= 26 && manager?.getNotificationChannel(CHANNEL) == null)
            manager?.createNotificationChannel(NotificationChannel(CHANNEL, "Recorded listening summaries", NotificationManager.IMPORTANCE_DEFAULT))
        val allowed = permission(context)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val next = mutableMapOf<String, Any?>()
        var failed = false
        for (kind in WellbeingSchedule.kinds) {
            val old = PendingIntent.getBroadcast(context, id(kind), intent(context, kind), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
            if (old != null) alarms?.cancel(old)
            val plan = if (allowed) WellbeingSchedule.next(kind, now, zone, config) else null
            try {
                if (plan != null) {
                    check(alarms != null)
                    val request = intent(context, kind).putExtra("due", plan.dueUtcMs).putExtra("from", plan.fromUtcMs)
                        .putExtra("until", plan.untilUtcMs).putExtra("zone", plan.zoneId).putExtra("key", plan.key)
                    val operation = PendingIntent.getBroadcast(context, id(kind), request, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    alarms.setWindow(AlarmManager.RTC_WAKEUP, plan.dueUtcMs, 3600000, operation)
                }
                next["${kind}UtcMs"] = plan?.dueUtcMs
            } catch (_: Exception) { failed = true; next["${kind}UtcMs"] = null }
        }
        return next + mapOf("version" to 1, "permissionGranted" to allowed, "schedulingAvailable" to !failed,
            "liveRemindersEligible" to false, "delivery" to state(context).getString("lastResult", "NOT_DELIVERED"))
    }
    fun parse(extras: PersistableBundle): SummaryPlan? = runCatching {
        SummaryPlan(extras.getString("kind") ?: "", extras.getLong("due"), extras.getLong("from"), extras.getLong("until"),
            extras.getString("zone") ?: "", extras.getString("key") ?: "")
    }.getOrNull()
    internal fun valid(plan: SummaryPlan, now: Long): Boolean {
        if (plan.kind !in WellbeingSchedule.kinds || !ListeningTimeZones.valid(plan.zoneId) || plan.key.length > 80 ||
            plan.untilUtcMs <= 0 || plan.untilUtcMs > now || plan.dueUtcMs > now || plan.dueUtcMs < plan.untilUtcMs ||
            now - plan.dueUtcMs !in 0..172800000L) return false
        val end = Calendar.getInstance(TimeZone.getTimeZone(plan.zoneId)).apply { timeInMillis = plan.untilUtcMs }
        if (end.get(Calendar.HOUR_OF_DAY) != 0 || end.get(Calendar.MINUTE) != 0 || end.get(Calendar.SECOND) != 0 || end.get(Calendar.MILLISECOND) != 0 ||
            plan.kind == "weekly" && end.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) return false
        val expectedKey = "${plan.kind}:${end.get(Calendar.YEAR)}:${end.get(Calendar.DAY_OF_YEAR)}"
        end.add(Calendar.DAY_OF_MONTH, if (plan.kind == "daily") -1 else -7)
        return expectedKey == plan.key && end.timeInMillis == plan.fromUtcMs
    }
    internal fun deliver(context: Context, store: ObservationJournal, plan: SummaryPlan, active: () -> Boolean,
        now: () -> Long = System::currentTimeMillis): String {
        fun result(value: String): String { state(context).edit().putString("lastResult", value).commit(); return value }
        var config = ListeningPreferences(context).wellbeing()
        if (!active() || !valid(plan, now())) return result("STALE_OR_CANCELLED")
        if (!WellbeingSchedule.enabled(plan.kind, config) || !permission(context)) return result("DISABLED_OR_PERMISSION_BLOCKED")
        if (WellbeingSchedule.quiet(now(), TimeZone.getDefault().id, config)) return result("QUIET_HOURS")
        val receipts = state(context)
        val localEnd = Calendar.getInstance(TimeZone.getTimeZone(plan.zoneId)).apply { timeInMillis = plan.untilUtcMs }
        val receiptDay = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear(); set(localEnd.get(Calendar.YEAR), localEnd.get(Calendar.MONTH), localEnd.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis / 86400000L
        if (receiptDay <= receipts.getLong("last_day_${plan.kind}", Long.MIN_VALUE)) return result("ALREADY_ATTEMPTED")
        val snapshot = try { store.listeningSnapshot(plan.fromUtcMs, plan.untilUtcMs, plan.zoneId) }
            catch (_: Exception) { return result("HISTORY_UNAVAILABLE") }
        config = ListeningPreferences(context).wellbeing()
        if (!active() || !valid(plan, now()) || !WellbeingSchedule.enabled(plan.kind, config) || !permission(context)) return result("STALE_OR_CANCELLED")
        if (WellbeingSchedule.quiet(now(), TimeZone.getDefault().id, config)) return result("QUIET_HOURS")
        val confirmed = (snapshot["confirmedMs"] as Number).toLong() / 60000
        val unverified = (snapshot["unverifiedMs"] as Number).toLong() / 60000
        val date = java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM).apply { timeZone = TimeZone.getTimeZone(plan.zoneId) }
        val period = if (plan.kind == "daily") date.format(java.util.Date(plan.fromUtcMs)) else
            "${date.format(java.util.Date(plan.fromUtcMs))} - ${date.format(java.util.Date(plan.untilUtcMs - 1))}"
        val text = "Recorded confirmed listening: ${confirmed / 60}h ${confirmed % 60}m. Unverified activity: ${unverified / 60}h ${unverified % 60}m. Unknown time is excluded; totals are lower bounds."
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.widget_headphones)
            .setContentTitle(if (plan.kind == "daily") "Daily recorded listening" else "Weekly recorded listening")
            .setSubText(period).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text)).setOnlyAlertOnce(true).setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, id(plan.kind), NavigationTarget.intent(context, "wellbeing"),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build()
        // At most one attempt per calendar period. Crash between receipt and notify can miss delivery, never duplicate an alert.
        if (!receipts.edit().putLong("last_day_${plan.kind}", receiptDay).putString("last_${plan.kind}", plan.key)
            .putString("lastResult", "ATTEMPTED").commit()) return "RECEIPT_WRITE_FAILED"
        if (!active() || !permission(context) || WellbeingSchedule.quiet(now(), TimeZone.getDefault().id, ListeningPreferences(context).wellbeing()))
            return result("CANCELLED_AFTER_RECEIPT")
        return try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(id(plan.kind)); manager.notify(id(plan.kind), notification)
            result("POSTED")
        } catch (_: Exception) { result("DELIVERY_UNAVAILABLE") }
    }
    fun failure(context: Context, reason: String) {
        state(context).edit().putString("lastResult", reason).commit()
    }
}

class WellbeingSummaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WellbeingSummaries.ACTION) {
            val kind = intent.getStringExtra("kind") ?: ""
            if (kind !in WellbeingSchedule.kinds) return
            val extras = PersistableBundle().apply {
                putString("requestId", java.util.UUID.randomUUID().toString())
                putString("kind", kind); putString("zone", intent.getStringExtra("zone")); putString("key", intent.getStringExtra("key"))
                putLong("due", intent.getLongExtra("due", 0)); putLong("from", intent.getLongExtra("from", 0)); putLong("until", intent.getLongExtra("until", 0))
            }
            val scheduled = runCatching { (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler)?.schedule(JobInfo.Builder(
                if (kind == "daily") 4101 else 4102, ComponentName(context, WellbeingSummaryJob::class.java)).setExtras(extras).setMinimumLatency(0).build()) }.getOrNull()
            if (scheduled != JobScheduler.RESULT_SUCCESS) NativeJournalRuntime.wellbeingFailure("JOB_SCHEDULING_FAILED")
        } else if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) return
        NativeJournalRuntime.refreshWellbeing({}, {})
    }
}

class WellbeingSummaryJob : JobService() {
    private val owners = SummaryJobOwners()
    override fun onStartJob(params: JobParameters): Boolean {
        val plan = WellbeingSummaries.parse(params.extras) ?: return false
        if (plan.kind !in WellbeingSchedule.kinds || params.jobId != if (plan.kind == "daily") 4101 else 4102) return false
        val token = params.extras.getString("requestId") ?: return false
        if (!EndpointIdentity.validId(token)) return false
        val owner = owners.start(params.jobId, token)
        fun finish() { Handler(Looper.getMainLooper()).post { if (owners.finish(owner)) jobFinished(params, false) } }
        NativeJournalRuntime.deliverWellbeing(plan, { owners.active(owner) }, { finish() }, { finish() })
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean {
        params.extras.getString("requestId")?.let { owners.stop(params.jobId, it) }
        return false
    }
}
