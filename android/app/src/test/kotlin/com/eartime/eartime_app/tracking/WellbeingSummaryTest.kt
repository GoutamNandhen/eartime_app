package com.eartime.eartime_app.tracking

import android.Manifest
import android.app.Application
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.job.JobScheduler
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class WellbeingSummaryTest {
    private val context = RuntimeEnvironment.getApplication()
    private val name = "wb-${UUID.randomUUID().toString().take(6)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private var journal = ObservationJournal(context, name)
    private val zone = TimeZone.getDefault()
    private val config = WellbeingPreferences(daily = true, weekly = true, quiet = false)
    private val notifications get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    private fun at(text: String, tz: String = "UTC") = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.ROOT).apply { timeZone = TimeZone.getTimeZone(tz) }.parse(text)!!.time
    private fun save(value: WellbeingPreferences = config) = ListeningPreferences(context).update(mapOf("wellbeingNotifications" to value.wire()))
    private fun plan(kind: String = "daily", text: String = "2026-10-24 08:00", prefs: WellbeingPreferences = config, tz: String = "UTC") =
        WellbeingSchedule.next(kind, at(text, tz), tz, prefs)!!
    private fun delivery(value: SummaryPlan, now: Long = value.dueUtcMs, active: () -> Boolean = { true }) =
        WellbeingSummaries.deliver(context, journal, value, active) { now }
    @Before fun setup() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
        context.getSharedPreferences("eartime_preferences_v1", 0).edit().clear().commit()
        context.getSharedPreferences("eartime_summary_delivery_v1", 0).edit().clear().commit()
        shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        shadowOf(notifications).setNotificationsEnabled(true)
    }
    @After fun cleanup() { run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name); TimeZone.setDefault(zone) }
    private fun playback(kind: String, time: Long, payload: Map<String, Any?> = emptyMap()) = ObservationInput(UUID.randomUUID().toString(), kind,
        "synthetic_summary_fixture", "fixture-process", ObservationTime(time, time, "fixture-boot", "fixture-epoch"), JournalJson.encode(payload),
        "synthetic_fixture_not_hardware", if (kind == "ROUTE_PLAYBACK") AttributionConfidence.CONFIRMED else AttributionConfidence.UNKNOWN)
    private fun seed(value: SummaryPlan) {
        val device = "00000000-0000-4000-8000-000000000001"
        fun route(minute: Int, playing: Boolean, id: String) = journal.append(playback("ROUTE_PLAYBACK", value.fromUtcMs + minute * 60000L,
            mapOf("routeId" to id, "physicalDeviceId" to device, "external" to true, "playing" to playing)))
        route(10, true, "a"); route(20, true, "b"); route(60, false, "a"); route(70, false, "b")
        journal.append(playback("PLAYBACK_STARTED", value.fromUtcMs + 80 * 60000L))
        journal.append(playback("PLAYBACK_PAUSED", value.fromUtcMs + 90 * 60000L))
    }

    @Test fun defaultsDoNotScheduleOrGrantLiveReminders() {
        val status = WellbeingSummaries.reconcile(context, at("2026-10-24 08:00"), "UTC")
        assertNull(status["dailyUtcMs"]); assertNull(status["weeklyUtcMs"])
        assertEquals(false, status["liveRemindersEligible"])
        assertTrue(shadowOf(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).scheduledAlarms.isEmpty())
    }
    @Test fun explicitPreferencesPersistAndInvalidUpdatesAreAtomic() {
        save(); assertEquals(config, ListeningPreferences(context).wellbeing())
        val before = ListeningPreferences(context).snapshot()
        assertThrows(IllegalArgumentException::class.java) { ListeningPreferences(context).update(mapOf("themeMode" to "dark",
            "wellbeingNotifications" to (config.wire() + ("quietEnd" to 1440)))) }
        assertEquals(before, ListeningPreferences(context).snapshot())
        assertThrows(IllegalArgumentException::class.java) { WellbeingPreferences.decode(config.wire() + ("daily" to "true")) }
        assertThrows(IllegalArgumentException::class.java) { WellbeingPreferences.decode(config.wire() + ("version" to 2)) }
    }
    @Test fun storedNotificationPreferencesRejectNestedDuplicateFractionalAndOversizedInputs() {
        assertThrows(IllegalArgumentException::class.java) { WellbeingPreferences.stored("{\"version\":1,\"version\":1}") }
        assertThrows(IllegalArgumentException::class.java) { WellbeingPreferences.stored("{\"version\":1.5}") }
        assertThrows(IllegalArgumentException::class.java) { WellbeingPreferences.stored("{\"version\":${"[".repeat(500)}0${"]".repeat(500)}}") }
        assertThrows(IllegalArgumentException::class.java) { WellbeingPreferences.stored(" ".repeat(2049)) }
        assertEquals(config, WellbeingPreferences.stored(JournalJson.encode(config.wire())))
    }
    @Test fun overnightAndDaytimeQuietHoursRespectBoundaryMinutesAndAllDay() {
        val overnight = config.copy(quiet = true)
        assertTrue(WellbeingSchedule.quiet(at("2026-10-24 22:00"), "UTC", overnight))
        assertTrue(WellbeingSchedule.quiet(at("2026-10-25 06:59"), "UTC", overnight))
        assertFalse(WellbeingSchedule.quiet(at("2026-10-25 07:00"), "UTC", overnight))
        val daytime = config.copy(quiet = true, quietStart = 600, quietEnd = 720)
        assertTrue(WellbeingSchedule.quiet(at("2026-10-24 11:00"), "UTC", daytime))
        assertNull(WellbeingSchedule.next("daily", at("2026-10-24 08:00"), "UTC", config.copy(quiet = true, quietStart = 0, quietEnd = 0)))
    }
    @Test fun refreshDoesNotSkipAQuietDeferredDailyOrWeeklySummary() {
        val prefs = config.copy(quiet = true, quietStart = 480, quietEnd = 720)
        val early = plan(text = "2026-10-26 07:00", prefs = prefs)
        val later = plan(text = "2026-10-26 10:00", prefs = prefs)
        assertEquals(early, later); assertEquals(at("2026-10-26 12:00"), later.dueUtcMs)
        assertEquals(at("2026-10-26 00:00"), later.untilUtcMs)
        assertEquals(plan("weekly", "2026-10-26 07:00", prefs), plan("weekly", "2026-10-26 10:00", prefs))
        val overnight = config.copy(quiet = true, quietStart = 1320, quietEnd = 480, deliveryMinute = 1380)
        val monday = plan("weekly", "2026-10-26 21:00", overnight)
        assertEquals(monday, plan("weekly", "2026-10-27 07:00", overnight))
    }
    @Test fun windowsUseCalendarDaysWeeksAndRealDstRatherThanFixedMilliseconds() {
        val spring = plan(text = "2026-03-09 08:00", tz = "America/New_York")
        val autumn = plan(text = "2026-11-02 08:00", tz = "America/New_York")
        assertEquals(23 * 3600000L, spring.untilUtcMs - spring.fromUtcMs)
        assertEquals(25 * 3600000L, autumn.untilUtcMs - autumn.fromUtcMs)
        val weekly = plan("weekly", "2026-03-09 08:00", tz = "America/New_York")
        assertEquals(167 * 3600000L, weekly.untilUtcMs - weekly.fromUtcMs)
        assertTrue(WellbeingSummaries.valid(spring, spring.dueUtcMs))
    }
    @Test fun fixedOffsetTimeZonesAreValidButUnknownZoneDoesNotFallBackToGmt() = run {
        val value = plan(tz = "GMT+05:30")
        assertTrue(WellbeingSummaries.valid(value, value.dueUtcMs))
        assertEquals(0L, journal.listeningSnapshot(value.fromUtcMs, value.untilUtcMs, value.zoneId)["confirmedMs"])
        assertThrows(IllegalArgumentException::class.java) { WellbeingSchedule.next("daily", value.dueUtcMs, "not-a-zone", config) }
        Unit
    }
    @Test fun alarmSchedulingIsOptInInexactAndDisabledSettingsCancelBoth() {
        save()
        val status = WellbeingSummaries.reconcile(context, at("2026-10-24 08:00"), "UTC")
        val alarms = shadowOf(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).scheduledAlarms
        assertEquals(2, alarms.size); assertNotNull(status["dailyUtcMs"]); assertNotNull(status["weeklyUtcMs"])
        val receiver = android.content.ComponentName(context, WellbeingSummaryReceiver::class.java)
        assertEquals(android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED, context.packageManager.getComponentEnabledSetting(receiver))
        save(WellbeingPreferences()); WellbeingSummaries.reconcile(context)
        assertTrue(shadowOf(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).scheduledAlarms.isEmpty())
        assertEquals(android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED, context.packageManager.getComponentEnabledSetting(receiver))
    }
    @Test fun androidPermissionOrBlockedChannelSuppressSchedulingAndPosting() = run {
        save(); shadowOf(notifications).setNotificationsEnabled(false)
        assertEquals(false, WellbeingSummaries.reconcile(context)["permissionGranted"])
        assertEquals("DISABLED_OR_PERMISSION_BLOCKED", delivery(plan()))
        shadowOf(notifications).setNotificationsEnabled(true)
        notifications.deleteNotificationChannel(WellbeingSummaries.CHANNEL)
        notifications.createNotificationChannel(NotificationChannel(WellbeingSummaries.CHANNEL, "Blocked", NotificationManager.IMPORTANCE_NONE))
        assertEquals(false, WellbeingSummaries.reconcile(context)["permissionGranted"])
        assertEquals(0, shadowOf(notifications).size())
    }
    @Test fun deliveredSummaryUsesCanonicalUnionExcludesUnknownAndIsRestartIdempotent() = run {
        save(); WellbeingSummaries.reconcile(context)
        val value = plan(); seed(value)
        assertEquals("POSTED", delivery(value))
        val notification = shadowOf(notifications).allNotifications.single()
        val text = notification.extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString()
        assertTrue(text.contains("1h 0m")); assertTrue(text.contains("0h 10m")); assertTrue(text.contains("lower bounds"))
        assertEquals(1, shadowOf(notifications).size())
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals("ALREADY_ATTEMPTED", delivery(value)); assertEquals(1, shadowOf(notifications).size())
    }
    @Test fun quietDelayAndOwnerCancellationNeverTurnIntoANotification() = run {
        save(config.copy(quiet = true, quietStart = 480, quietEnd = 720)); WellbeingSummaries.reconcile(context)
        val value = plan()
        assertEquals("QUIET_HOURS", delivery(value)); assertEquals(0, shadowOf(notifications).size())
        save(); assertEquals("STALE_OR_CANCELLED", delivery(value, active = { false }))
        assertEquals(0, shadowOf(notifications).size())
    }
    @Test fun receiptHighWaterPreventsDuplicateOlderAlertsAfterClockChanges() = run {
        save(); WellbeingSummaries.reconcile(context)
        val recent = plan(); assertEquals("POSTED", delivery(recent))
        val previous = plan(text = "2026-10-23 08:00")
        assertEquals("ALREADY_ATTEMPTED", delivery(previous)); assertEquals(1, shadowOf(notifications).size())
    }
    @Test fun cancellationAfterReceiptIsAtMostOnceNotFalseExactlyOnceDelivery() = run {
        save(); WellbeingSummaries.reconcile(context)
        val value = plan(); var checks = 0
        assertEquals("CANCELLED_AFTER_RECEIPT", delivery(value, active = { ++checks < 3 }))
        assertEquals("ALREADY_ATTEMPTED", delivery(value)); assertEquals(0, shadowOf(notifications).size())
    }
    @Test fun malformedFutureAndDelayedPlansNeverQueryOrNotify() = run {
        save(); WellbeingSummaries.reconcile(context); val value = plan()
        assertEquals("STALE_OR_CANCELLED", delivery(value.copy(zoneId = "invented")))
        assertEquals("STALE_OR_CANCELLED", delivery(value.copy(fromUtcMs = value.fromUtcMs - 1)))
        assertEquals("STALE_OR_CANCELLED", delivery(value, value.dueUtcMs - 1))
        assertEquals("STALE_OR_CANCELLED", delivery(value, value.dueUtcMs + 172800001))
        assertEquals(0, shadowOf(notifications).size())
    }
    @Test fun historyFailureIsExplicitAndDoesNotPostAnInventedZeroSummary() = run {
        save(); WellbeingSummaries.reconcile(context); val value = plan(); seed(value)
        val raw = journal.readAfter(0); journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use { it.execSQL("UPDATE listening_projection SET version=99") }
        journal = ObservationJournal(context, name)
        assertEquals("HISTORY_UNAVAILABLE", delivery(value)); assertEquals(raw, journal.readAfter(0))
        assertEquals(0, shadowOf(notifications).size())
    }
    @Test fun notificationPreferenceCorruptionDoesNotBlockCanonicalListeningReports() = run {
        context.getSharedPreferences("eartime_preferences_v1", 0).edit().putString("wellbeing_notifications_v1", "{\"version\":99}").commit()
        assertThrows(IllegalArgumentException::class.java) { ListeningPreferences(context).snapshot() }
        assertEquals(0L, journal.listeningSnapshot(0, 100000, "UTC")["confirmedMs"])
        assertEquals(false, WellbeingSummaries.refresh(context)["schedulingAvailable"])
    }
    @Test fun receiverEnqueuesABoundedJobAndIgnoresUnknownActions() {
        val value = plan()
        val receiver = WellbeingSummaryReceiver()
        receiver.onReceive(context, Intent(context, WellbeingSummaryReceiver::class.java).setAction(WellbeingSummaries.ACTION)
            .putExtra("kind", value.kind).putExtra("due", value.dueUtcMs).putExtra("from", value.fromUtcMs)
            .putExtra("until", value.untilUtcMs).putExtra("zone", value.zoneId).putExtra("key", value.key))
        val jobs = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        assertNotNull(jobs.getPendingJob(4101)); assertEquals(value.untilUtcMs, jobs.getPendingJob(4101)!!.extras.getLong("until"))
        assertTrue(EndpointIdentity.validId(jobs.getPendingJob(4101)!!.extras.getString("requestId") ?: ""))
        receiver.onReceive(context, Intent("untrusted_action")); assertEquals(1, jobs.allPendingJobs.size)
    }
}
