package com.eartime.eartime_app.tracking

import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

/** Synthetic policy scenarios, not Android routing or hardware acceptance. */
@RunWith(Parameterized::class)
class OutputAttributionTest(private val scenario: String) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name = "{0}") fun scenarios() = listOf(
            "earbuds_media", "connected_speaker", "connected_silent", "disconnect", "speaker_after_disconnect",
            "two_connected", "route_switch", "a2dp_sco", "a2dp_disconnect_sco_remains", "le_audio",
            "usb_wired", "pause_resume", "unknown_output", "collector_restart", "flutter_reopen", "delayed_callback",
        ).map { arrayOf(it) }
    }
    @Test fun onlyCurrentOwnedPlayingMediaRouteCanBeConfirmed() {
        val time = ObservationTime(1000, 1000, "boot", "epoch")
        val id = PhysicalDeviceId("00000000-0000-4000-8000-000000000001")
        var route: OutputRoute? = OutputRoute(RouteId("epoch", "a2dp"), AudioProfile.A2DP, null, id, true)
        var evidence = OutputEvidence(OutputEvidenceKind.OWNED_PLAYER_ROUTING, time, 1,
            route!!.id, "synthetic-owned-player", true, true, id, true)
        var now = time.copy(wallUtcMs = 1100, elapsedMs = 1100)
        var generation = 1L
        val confirmed = scenario in listOf("earbuds_media", "le_audio", "usb_wired", "flutter_reopen")
        when (scenario) {
            "connected_speaker", "speaker_after_disconnect" -> evidence = evidence.copy(external = false)
            "connected_silent", "pause_resume" -> evidence = evidence.copy(playing = false)
            "disconnect", "a2dp_disconnect_sco_remains" -> route = null
            "two_connected" -> evidence = evidence.copy(kind = OutputEvidenceKind.CONNECTED_INVENTORY)
            "route_switch", "delayed_callback" -> route = route.copy(id = RouteId("epoch", "new-route"))
            "a2dp_sco" -> evidence = evidence.copy(kind = OutputEvidenceKind.COMMUNICATION_DEVICE)
            "unknown_output" -> evidence = evidence.copy(kind = OutputEvidenceKind.PREDICTED_MEDIA)
            "collector_restart" -> { generation = 2; now = now.copy(collectionEpoch = "new-epoch") }
            "le_audio" -> { route = route.copy(profile = AudioProfile.LE_HEADSET); evidence = evidence.copy(routeId = route.id) }
            "usb_wired" -> route = route.copy(profile = AudioProfile.USB)
        }
        assertEquals(if (confirmed) AttributionConfidence.CONFIRMED else AttributionConfidence.UNKNOWN,
            OutputAttribution.confidence(evidence, now, generation, route))
        assertEquals(AttributionConfidence.UNKNOWN, OutputAttribution.confidence(
            evidence.copy(kind = OutputEvidenceKind.GLOBAL_ACTIVITY), now, generation, route))
        assertEquals(AttributionConfidence.UNKNOWN, OutputAttribution.confidence(evidence,
            now.copy(elapsedMs = 5000), generation, route))
    }
}
