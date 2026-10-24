package com.eartime.eartime_app.tracking

import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.util.Calendar
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24], manifest = Config.NONE, application = Application::class)
class WellbeingLegacyNotificationTest {
    private val context = RuntimeEnvironment.getApplication()
    private val name = "old-${UUID.randomUUID().toString().take(6)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private val journal = ObservationJournal(context, name)
    private val originalZone = TimeZone.getDefault()
    @After fun cleanup() { worker.submit { journal.close() }.get(); worker.shutdownNow(); context.deleteDatabase(name); TimeZone.setDefault(originalZone) }
    @Test fun api24PostsCanonicalRecordedSummaryWithoutNotificationChannelApis() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
        val config = WellbeingPreferences(daily = true, quiet = false)
        ListeningPreferences(context).update(mapOf("wellbeingNotifications" to config.wire()))
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        shadowOf(manager).setNotificationsEnabled(true)
        val now = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { clear(); set(2026, 9, 24, 8, 0) }.timeInMillis
        val plan = WellbeingSchedule.next("daily", now, "UTC", config)!!
        val result = worker.submit<String> {
            for ((kind, time) in listOf("PLAYBACK_STARTED" to (plan.fromUtcMs + 1000), "PLAYBACK_PAUSED" to (plan.fromUtcMs + 61000))) {
                journal.append(ObservationInput(UUID.randomUUID().toString(), kind, "synthetic_summary_fixture", "fixture-process",
                    ObservationTime(time, time, "fixture-boot", "fixture-epoch"), "{}", "synthetic_fixture_not_hardware"))
            }
            WellbeingSummaries.reconcile(context, now, "UTC")
            WellbeingSummaries.deliver(context, journal, plan, { true }, { plan.dueUtcMs })
        }.get()
        assertEquals("POSTED", result)
        val notification = shadowOf(manager).allNotifications.single()
        assertTrue(notification.extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString().contains("0h 1m"))
        assertTrue(notification.extras.getCharSequence(Notification.EXTRA_SUB_TEXT).toString().contains("2026"))
        assertEquals(Notification.VISIBILITY_PRIVATE, notification.visibility)
    }
    @Test fun api24GlobalNotificationDenialDoesNotCreateAlarmsOrClaimPermission() {
        ListeningPreferences(context).update(mapOf("wellbeingNotifications" to WellbeingPreferences(daily = true).wire()))
        shadowOf(context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).setNotificationsEnabled(false)
        val status = WellbeingSummaries.reconcile(context)
        assertEquals(false, status["permissionGranted"]); assertNull(status["dailyUtcMs"])
    }
}
