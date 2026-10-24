package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.Semaphore

class A2dpStreamProbeTest {
    private class Device(override val address: String = "02:11:22:33:44:55",
        var isConnected: Boolean = true, var isStreaming: Boolean = false) : A2dpDeviceRead {
        var onQuery: () -> Unit = {}
        override fun connected() = isConnected
        override fun streaming(): Boolean { onQuery(); return isStreaming }
    }
    private class Profile(var entries: List<A2dpDeviceRead>) : A2dpProfileRead {
        var closes = 0
        var fail = false
        override fun devices(): List<A2dpDeviceRead> { if (fail) throw SecurityException("synthetic permission denial"); return entries }
        override fun close() { closes++ }
    }
    private class Connector : A2dpProfileConnector {
        lateinit var connect: (A2dpProfileRead) -> Unit
        lateinit var disconnect: () -> Unit
        var accepted = true
        var requests = 0
        var closes = 0
        var fail = false
        override fun request(connected: (A2dpProfileRead) -> Unit, disconnected: () -> Unit): Boolean {
            requests++; connect = connected; disconnect = disconnected
            if (fail) throw SecurityException("synthetic denial")
            return accepted
        }
        override fun close() { closes++ }
    }
    private class Fixture {
        val connector = Connector()
        var time = AudioSampleTime(1000, 1000)
        val budget = Semaphore(1)
        val jobs = mutableListOf<Runnable>()
        val probe = A2dpStreamProbe(connector, { time }, {}, budget, jobs::add)
        fun attach(profile: Profile) { probe.start(); connector.connect(profile) }
        fun cleanup() { while (jobs.isNotEmpty()) jobs.removeAt(0).run() }
    }
    private fun deviceRows(sample: Map<String, Any?>) = sample["devices"] as List<*>

    @Test fun positiveSampleIsDeviceScopedButDoesNotGrantConfirmedDurationOrLease() {
        val f = Fixture(); val profile = Profile(listOf(Device(isStreaming = true)))
        f.attach(profile)
        val sample = f.probe.sample()
        assertEquals("SAMPLED", sample["state"])
        assertEquals("UNKNOWN", sample["confidence"])
        assertEquals(false, sample["liveListeningEligible"])
        assertEquals("STREAMING_REPORTED", (deviceRows(sample).single() as Map<*, *>)["streamState"])
        f.probe.close(); f.cleanup(); assertEquals(1, profile.closes)
    }
    @Test fun falseAndEmptyReadingsAreAmbiguousRatherThanProvenPauseOrSpeaker() {
        val f = Fixture(); val profile = Profile(listOf(Device()))
        f.attach(profile)
        assertEquals("NOT_STREAMING_OR_API_UNAVAILABLE", (deviceRows(f.probe.sample()).single() as Map<*, *>)["streamState"])
        profile.entries = emptyList()
        assertEquals("empty_inventory_or_api_unavailable", f.probe.sample()["reason"])
        f.probe.close(); f.cleanup()
    }
    @Test fun speakerSwitchBeforeDelayedHintUsesFreshQueryNotHistoricalPlayingFlag() {
        val f = Fixture(); val device = Device(isStreaming = true); f.attach(Profile(listOf(device)))
        assertEquals("STREAMING_REPORTED", (deviceRows(f.probe.sample()).single() as Map<*, *>)["streamState"])
        device.isStreaming = false
        assertEquals("NOT_STREAMING_OR_API_UNAVAILABLE", (deviceRows(f.probe.sample()).single() as Map<*, *>)["streamState"])
        f.probe.close(); f.cleanup()
    }
    @Test fun twoEndpointsAreNeverMergedAndUnknownAddressCannotSupplyPositiveEvidence() {
        val f = Fixture()
        f.attach(Profile(listOf(Device(isStreaming = true), Device("02:11:22:33:44:66"), Device("02:00:00:00:00:00", isStreaming = true))))
        val rows = deviceRows(f.probe.sample()).map { it as Map<*, *> }
        assertEquals(3, rows.size)
        assertEquals("STREAMING_REPORTED", rows[0]["streamState"])
        assertEquals("NOT_STREAMING_OR_API_UNAVAILABLE", rows[1]["streamState"])
        assertEquals("NOT_STREAMING_OR_API_UNAVAILABLE", rows[2]["streamState"])
        assertNull(rows[2]["endpointAddress"])
        f.probe.close(); f.cleanup()
    }
    @Test fun disconnectedOrPermissionBlockedReadsNeverConfirmStreaming() {
        val f = Fixture(); val profile = Profile(listOf(Device(isConnected = false, isStreaming = true)))
        f.attach(profile)
        assertEquals("NOT_STREAMING_OR_API_UNAVAILABLE", (deviceRows(f.probe.sample()).single() as Map<*, *>)["streamState"])
        profile.fail = true
        assertEquals("permission_blocked", f.probe.sample()["reason"])
        f.probe.close(); f.cleanup()
    }
    @Test fun lateConnectionAfterCloseIsDisposedOffCallbackAndReleasesReservationOnlyAfterCleanup() {
        val f = Fixture(); val profile = Profile(emptyList())
        f.probe.start(); f.probe.close(); f.connector.connect(profile)
        assertEquals(0, profile.closes)
        assertEquals(0, f.budget.availablePermits())
        assertEquals("UNKNOWN", f.probe.sample()["state"])
        f.cleanup(); assertEquals(1, profile.closes); assertEquals(1, f.budget.availablePermits())
        f.connector.connect(profile); f.probe.close(); f.cleanup(); assertEquals(1, profile.closes)
    }
    @Test fun serviceDisconnectAndReconnectUseSameProxyWithoutInventingContinuity() {
        val f = Fixture(); val profile = Profile(listOf(Device(isStreaming = true)))
        f.attach(profile); f.connector.disconnect()
        assertEquals("profile_service_unavailable", f.probe.sample()["reason"])
        f.connector.connect(profile)
        assertEquals("SAMPLED", f.probe.sample()["state"])
        assertEquals(false, f.probe.sample()["liveListeningEligible"])
        f.probe.close(); f.cleanup(); assertEquals(1, profile.closes)
    }
    @Test fun refusedRequestBacksOffAndCanRetryWithoutLeakingBudget() {
        val f = Fixture(); f.connector.accepted = false
        repeat(1000) { f.probe.sample() }
        assertEquals(1, f.connector.requests)
        assertEquals(1, f.budget.availablePermits())
        f.time = AudioSampleTime(31000, 31000); f.connector.accepted = true
        f.probe.sample(); assertEquals(2, f.connector.requests)
        f.connector.connect(Profile(emptyList())); f.probe.close(); f.cleanup()
    }
    @Test fun lostOrBlockedPendingRequestsBoundResourcePressureRatherThanRetryIndefinitely() {
        val f = Fixture(); f.connector.fail = true
        repeat(1000) { f.probe.sample() }
        assertEquals(1, f.connector.requests)
        assertEquals(0, f.budget.availablePermits())
        val second = A2dpStreamProbe(Connector(), { f.time }, {}, f.budget, f.jobs::add)
        assertEquals("profile_capacity_unavailable", second.sample()["reason"])
        second.close(); f.probe.close()
    }
    @Test fun clockJumpSlowSampleAndExcessInventoryDiscardAllPositiveCandidates() {
        val f = Fixture(); val device = Device(isStreaming = true); val profile = Profile(listOf(device))
        f.attach(profile)
        device.onQuery = { f.time = AudioSampleTime(3000, 3000) }
        assertEquals("sample_clock_or_deadline_lost", f.probe.sample()["reason"])
        device.onQuery = { f.time = AudioSampleTime(100000, 3001) }
        assertEquals("sample_clock_or_deadline_lost", f.probe.sample()["reason"])
        device.onQuery = {}; profile.entries = List(17) { device }
        assertEquals("device_sample_bound_exceeded", f.probe.sample()["reason"])
        f.probe.close(); f.cleanup()
    }
    @Test fun ownerLossDuringQueryDiscardsCapturedPositiveRatherThanPublishingStaleRoute() {
        val f = Fixture(); val device = Device(isStreaming = true)
        f.attach(Profile(listOf(device)))
        device.onQuery = { f.connector.disconnect() }
        assertEquals("profile_owner_changed_during_sample", f.probe.sample()["reason"])
        f.probe.close(); f.cleanup()
    }
    @Test fun unexpectedProxyReplacementIsUnknownAndBothHandlesAreDisposedWithoutResurrection() {
        val f = Fixture(); val first = Profile(listOf(Device(isStreaming = true))); val second = Profile(emptyList())
        f.attach(first); f.connector.connect(second)
        assertEquals("UNKNOWN", f.probe.sample()["state"])
        f.cleanup(); f.probe.close(); f.cleanup()
        assertEquals(1, first.closes); assertEquals(1, second.closes)
        assertEquals(0, f.budget.availablePermits()) // Contract-violating source cannot renew its request budget.
    }
    @Test fun lateCallbackFromRefusedRequestCannotBecomeANewerOwnersPositiveSample() {
        val f = Fixture(); f.connector.accepted = false; f.probe.start()
        val old = f.connector.connect
        f.time = AudioSampleTime(31000, 31000); f.connector.accepted = true; f.probe.start()
        val first = Profile(listOf(Device(isStreaming = true))); val second = Profile(emptyList())
        old(first); f.connector.connect(second)
        assertEquals("UNKNOWN", f.probe.sample()["state"])
        f.cleanup(); f.probe.close(); f.cleanup()
        assertEquals(1, first.closes); assertEquals(1, second.closes)
    }
    @Test fun duplicateEndpointRowsAreNotSilentlyMergedIntoPositiveOutputEvidence() {
        val f = Fixture(); f.attach(Profile(listOf(Device(isStreaming = true), Device())))
        assertEquals("duplicate_endpoint_inventory", f.probe.sample()["reason"])
        assertTrue(deviceRows(f.probe.sample()).isEmpty())
        f.probe.close(); f.cleanup()
    }
}
