package com.eartime.eartime_app.tracking

import org.junit.Assert.*
import org.junit.Test

class AudioObserverOwnerTest {
    private var wall = 1000L
    private var elapsed = 1000L
    private var generation = 0L
    private val events = mutableListOf<Map<String, Any?>>()
    private val acknowledgments = mutableListOf<(Boolean) -> Unit>()
    private var autoAck = true
    private val backend = object : AudioObservationBackend {
        var registrations = 0
        var cleanups = 0
        var samples = 0
        var registerFailure: Exception? = null
        var sampleFailure: Exception? = null
        var cleanupFailure = false
        var stallSample = false
        var playing = true
        var route = "fixture-a2dp"
        override fun register(): AutoCloseable {
            registerFailure?.let { throw it }
            registrations++
            return AutoCloseable { cleanups++; if (cleanupFailure) error("synthetic cleanup failure") }
        }
        override fun sample(): Map<String, Any?> {
            sampleFailure?.let { throw it }
            samples++
            if (stallSample) { elapsed += 2000; wall += 2000 }
            return mapOf("globalMusicActive" to playing, "predictedMediaDevices" to listOf(route), "actualOutputKnown" to false)
        }
    }
    private fun owner() = AudioObserverOwner(backend, { AudioSampleTime(wall, elapsed) }, { ++generation },
        { event, captured, completion ->
            assertEquals(captured.wallUtcMs, event["timestamp"])
            events.add(event)
            if (event["state"] == "HEALTHY") {
                if (autoAck) completion(true) else acknowledgments.add(completion)
            } else completion(true)
        })
    private fun advance(ms: Long) { wall += ms; elapsed += ms }
    private fun states() = events.mapNotNull { it["state"] }

    @Test fun initializationAcknowledgesOnlySuccessfulRegisteredSamplesAndNeverClaimsOutput() {
        val owner = owner(); owner.start()
        assertEquals(listOf("STARTING", "HEALTHY"), states())
        assertEquals(1, backend.registrations); assertEquals(1, backend.samples)
        val evidence = events.single { it["type"] == "OUTPUT_EVIDENCE" }
        assertEquals("UNKNOWN", evidence["confidence"]); assertEquals(false, evidence["actualOutputKnown"])
        owner.close(); assertEquals(1, backend.cleanups); assertEquals("STOPPED", states().last())
    }
    @Test fun repeatedStartCloseAndFiveHundredReplacementsDoNotLeakRegistrations() {
        repeat(500) {
            val owner = owner(); owner.start(); owner.start(); owner.close(); owner.close(); owner.sample()
        }
        assertEquals(500, backend.registrations); assertEquals(500, backend.cleanups)
        assertEquals(500, backend.samples)
    }
    @Test fun callbacksAreBoundedAndAlwaysResampleCurrentStateRatherThanOldRoutePayloads() {
        val owner = owner(); owner.start()
        repeat(1000) { owner.sample() }; assertEquals(1, backend.samples)
        backend.route = "fixture-speaker"; backend.playing = false; advance(1000); owner.sample()
        val evidence = events.last { it["type"] == "OUTPUT_EVIDENCE" }
        assertEquals(listOf("fixture-speaker"), evidence["predictedMediaDevices"])
        assertEquals(false, evidence["globalMusicActive"]); assertEquals("UNKNOWN", evidence["confidence"])
        owner.close()
    }
    @Test fun commitRejectionReinitializesWithNewOwnerAndContinuityEpoch() {
        autoAck = false; val owner = owner(); owner.start()
        val oldEpoch = events.first()["continuityEpoch"]
        acknowledgments.removeAt(0)(false); advance(1000); owner.sample()
        assertEquals(1, backend.registrations)
        advance(9000); owner.sample()
        assertEquals(2, backend.registrations); assertEquals(1, backend.cleanups)
        assertNotEquals(oldEpoch, events.last()["continuityEpoch"])
        assertEquals(2L, events.last()["generation"]); owner.close()
    }
    @Test fun missingCommitAckExpiresAndOldAckCannotRenewReplacementOwner() {
        autoAck = false; val owner = owner(); owner.start()
        advance(10000); owner.sample(); assertEquals(1, backend.samples)
        val oldAck = acknowledgments.removeAt(0)
        advance(5000); owner.sample(); assertEquals(2, backend.samples)
        oldAck(false); acknowledgments.removeAt(0)(true)
        advance(1000); owner.sample(); assertEquals(2, backend.registrations)
        owner.close()
    }
    @Test fun failedInitializationAndPermissionDenialNeverAcknowledgeHealthAndCanRetry() {
        backend.registerFailure = SecurityException("synthetic denial")
        val owner = owner(); owner.start()
        assertEquals(listOf("STARTING", "PERMISSION_BLOCKED"), states())
        assertEquals(0, backend.samples)
        backend.registerFailure = null; advance(10000); owner.sample()
        assertEquals(0, backend.samples)
        advance(20000); owner.sample()
        assertEquals("HEALTHY", states().last()); assertEquals(2L, events.last()["generation"])
        owner.close()
    }
    @Test fun sampleFailureClosesListenersBeforeUnavailableStatusAndFreshRetry() {
        val owner = owner(); owner.start(); backend.sampleFailure = IllegalStateException("synthetic failure")
        advance(10000); owner.sample()
        assertEquals("TEMPORARILY_UNAVAILABLE", states().last()); assertEquals(1, backend.cleanups)
        backend.sampleFailure = null; advance(30000); owner.sample()
        assertEquals("HEALTHY", states().last()); assertEquals(2, backend.registrations); owner.close()
    }
    @Test fun clockJumpAndMonotonicRollbackInvalidateThenAcknowledgeNewEpochs() {
        val owner = owner(); owner.start()
        elapsed += 1000; wall += 100000; owner.sample()
        assertEquals(2, backend.registrations); assertTrue(states().contains("CONTINUITY_LOST"))
        elapsed -= 100; wall += 100; owner.sample(); assertEquals(3, backend.registrations); owner.close()
    }
    @Test fun cleanupFailureCannotSilentlyStartAnotherListenerOwner() {
        val owner = owner(); owner.start(); backend.cleanupFailure = true
        advance(15000); owner.sample()
        assertEquals(1, backend.registrations)
        advance(10000); owner.sample(); assertEquals(1, backend.registrations)
        assertEquals("UNKNOWN", states().last()); owner.close()
    }
    @Test fun overlongSampleDoesNotGetAHealthyLease() {
        backend.stallSample = true; val owner = owner(); owner.start()
        assertFalse(states().contains("HEALTHY")); assertEquals("TEMPORARILY_UNAVAILABLE", states().last())
        assertEquals(1, backend.cleanups); owner.close()
    }
}
