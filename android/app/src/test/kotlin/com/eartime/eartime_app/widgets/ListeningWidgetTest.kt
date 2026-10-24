package com.eartime.eartime_app.widgets

import android.app.Application
import android.widget.TextView
import com.eartime.eartime_app.R
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], application = Application::class)
class ListeningWidgetTest {
    @Test fun summaryVariantsUseSameCanonicalTotalsAndUnknownOutputDoesNotTick() {
        val context = RuntimeEnvironment.getApplication()
        val snapshot = mapOf("confirmedMs" to 3720000L, "unverifiedMs" to 600000L,
            "intervals" to listOf(mapOf("open" to true, "live" to false, "attribution" to "UNVERIFIED")))
        val daily = ListeningWidgets.renderSummary(context, snapshot, false).apply(context, null)
        val current = ListeningWidgets.renderSummary(context, snapshot, true).apply(context, null)
        assertEquals("1h 2m", daily.findViewById<TextView>(R.id.summary_total).text.toString())
        assertEquals("Playback last observed", current.findViewById<TextView>(R.id.summary_total).text.toString())
        assertTrue(current.findViewById<TextView>(R.id.summary_status).text.toString().contains("unverified"))
        assertEquals("--", ListeningWidgets.renderSummary(context, emptyMap(), false).apply(context, null)
            .findViewById<TextView>(R.id.summary_total).text.toString())
    }

    @Test fun nativeWidgetUsesProjectionTotalsAndNeverInventsBatteryPercentages() {
        val context = RuntimeEnvironment.getApplication()
        val snapshot = mapOf("confirmedMs" to 3720000L, "unverifiedMs" to 9999999L,
            "devices" to listOf(mapOf("name" to "Disconnected headset", "connected" to false, "connectionState" to "DISCONNECTED_REPORTED"),
                mapOf("name" to "A very long connected device name that must truncate", "connected" to true)))
        val view = ListeningWidgets.render(context, snapshot).apply(context, null)
        assertEquals("1h 2m", view.findViewById<TextView>(R.id.widget_total).text.toString())
        assertEquals("Last observed connected", view.findViewById<TextView>(R.id.device_state_1).text.toString())
        assertEquals("Disconnection reported", view.findViewById<TextView>(R.id.device_state_2).text.toString())
        assertEquals("Battery unknown", view.findViewById<TextView>(R.id.device_battery_1).text.toString())
        assertEquals(1, view.findViewById<TextView>(R.id.device_name_1).maxLines)
        assertNotNull(view.findViewById<TextView>(R.id.device_name_1).ellipsize)
    }

    @Test fun unavailableHistoryIsExplicitRatherThanAFalseZeroListeningClaim() {
        val context = RuntimeEnvironment.getApplication()
        val view = ListeningWidgets.render(context, emptyMap()).apply(context, null)
        assertEquals("History unavailable", view.findViewById<TextView>(R.id.widget_status).text.toString())
        assertEquals("Not observed", view.findViewById<TextView>(R.id.device_state_1).text.toString())
    }

    @Test fun largerFontsKeepTwoColumnsAndReduceVisibleRowsWithoutFakeTelemetry() {
        val context = RuntimeEnvironment.getApplication()
        val configuration = android.content.res.Configuration(context.resources.configuration).apply { fontScale = 2f }
        val scaled = context.createConfigurationContext(configuration)
        val snapshot = mapOf("confirmedMs" to 0L, "deviceCount" to 6L,
            "devices" to (1..6).map { mapOf("name" to "Headset $it", "connected" to (it == 1)) })
        val view = ListeningWidgets.render(scaled, snapshot).apply(scaled, null)
        assertEquals(android.view.View.GONE, view.findViewById<android.view.View>(R.id.widget_second_row).visibility)
        assertEquals("+4 records", view.findViewById<TextView>(R.id.widget_more).text.toString())
        assertEquals("Battery unknown", view.findViewById<TextView>(R.id.device_battery_2).text.toString())
    }

    @Test fun missingOrLostConnectionEvidenceNeverClaimsDisconnection() {
        val context = RuntimeEnvironment.getApplication()
        val snapshot = mapOf("confirmedMs" to 0L, "devices" to listOf(
            mapOf("name" to "Unknown endpoint", "connected" to false, "connectionState" to "UNKNOWN"),
            mapOf("name" to "Old record", "connected" to false)))
        val view = ListeningWidgets.render(context, snapshot).apply(context, null)
        assertEquals("Connection unknown", view.findViewById<TextView>(R.id.device_state_1).text.toString())
        assertEquals("Connection unknown", view.findViewById<TextView>(R.id.device_state_2).text.toString())
    }
}
