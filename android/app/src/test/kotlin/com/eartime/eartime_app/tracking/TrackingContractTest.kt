package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class TrackingContractTest {
    private val a = PhysicalDeviceId.create()
    private val b = PhysicalDeviceId.create()
    private fun route(id: String, deviceId: PhysicalDeviceId = a, external: Boolean = true) = OutputRoute(
        RouteId("epoch", id), AudioProfile.A2DP, null, deviceId, external,
    )

    @Test fun mutableNamesDoNotCreateIdentityOrMergeDevices() {
        val first = PhysicalAudioDevice(a, "Buds")
        val second = PhysicalAudioDevice(b, "Buds")
        assertNotEquals(first.id, second.id)
        assertEquals(first.id, first.copy(observedName = "Renamed").id)
        assertEquals("My earbuds", first.copy(userName = "My earbuds").displayName)
    }

    @Test fun exactEndpointNormalizationRejectsMaskedAndNameFallbacks() {
        assertNull(TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, "Buds_8"))
        assertNull(TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_LE, "02:00:00:00:00:00"))
        assertNull(TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_LE, "00:00:00:00:00:00"))
        assertEquals("AA:BB:CC:DD:EE:FF",
            TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, "aa:bb:cc:dd:ee:ff")?.address)
        assertNotEquals(
            TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_CLASSIC, "AA:BB:CC:DD:EE:FF"),
            TransportEndpoint.bluetooth(AudioTransport.BLUETOOTH_LE, "AA:BB:CC:DD:EE:FF"))
    }

    @Test fun unscopedGlobalPlaybackNeverStartsListening() {
        val state = DeviceRouteState()
        state.connect(route("1"))
        state.playback(RoutePlayback(null, true, AttributionConfidence.CONFIRMED))
        state.playback(RoutePlayback(route("1").id, true, AttributionConfidence.CANDIDATE))
        assertFalse(state.isListening(a))
    }

    @Test fun profileRemovalRetainsAnotherRouteAndOtherDevices() {
        val state = DeviceRouteState()
        val media = route("1")
        val sco = route("2").copy(profile = AudioProfile.SCO)
        val other = route("3", b)
        listOf(media, sco, other).forEach(state::connect)
        state.playback(RoutePlayback(media.id, true, AttributionConfidence.CONFIRMED))
        state.disconnect(sco.id)
        state.disconnect(other.id)
        assertTrue(state.isConnected(a))
        assertTrue(state.isListening(a))
        assertFalse(state.isConnected(b))
        state.gap()
        assertFalse(state.isListening(a))
    }

    @Test fun speakerAndUnknownIdentityCannotBeCounted() {
        val state = DeviceRouteState()
        val speaker = route("speaker", external = false)
        val unknown = route("unknown").copy(deviceId = null)
        listOf(speaker, unknown).forEach { state.connect(it)
            state.playback(RoutePlayback(it.id, true, AttributionConfidence.CONFIRMED)) }
        assertFalse(state.isListening(a))
    }

    @Test fun monotonicTimeCannotBridgeBootsEpochsOrClockRollback() {
        val start = ObservationTime(5000, 100, "boot-1", "collection-1")
        assertEquals(50L, start.elapsedUntil(start.copy(wallUtcMs = 100, elapsedMs = 150)))
        assertNull(start.elapsedUntil(start.copy(elapsedMs = 150, bootId = "boot-2")))
        assertNull(start.elapsedUntil(start.copy(elapsedMs = 150, collectionEpoch = "collection-2")))
        assertNull(start.elapsedUntil(start.copy(elapsedMs = 90)))
        assertNull(start.copy(bootId = null).elapsedUntil(start.copy(elapsedMs = 150)))
    }

    @Test fun everyRemovalPermutationPreservesUnrelatedDevicePlayback() {
        for (count in 1..50) {
            val state = DeviceRouteState()
            val active = route("active")
            state.connect(active)
            state.playback(RoutePlayback(active.id, true, AttributionConfidence.CONFIRMED))
            val unrelated = (1..count).map { route("other-$it", b) }
            unrelated.forEach(state::connect)
            unrelated.reversed().forEach { state.disconnect(it.id)
                assertTrue(state.isListening(a)) }
        }
    }
}
