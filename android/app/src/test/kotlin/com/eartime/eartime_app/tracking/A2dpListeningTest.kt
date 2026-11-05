package com.eartime.eartime_app.tracking

import android.app.Application
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

/** Projection v6: A2DP stream + global music activity from the owning healthy collector = CONFIRMED listening. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class A2dpListeningTest {
    private val context = RuntimeEnvironment.getApplication()
    private val name = "a2dp-${UUID.randomUUID().toString().take(8)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private var journal = ObservationJournal(context, name)
    private val buds = "02:11:22:33:44:55"
    private val other = "00:11:22:33:44:55"
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @After fun cleanup() { run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name) }

    private fun time(at: Long) = ObservationTime(at, at, "boot", "epoch")
    private fun status(at: Long, phase: String, generation: Long = 1) = ObservationInput(UUID.randomUUID().toString(),
        "COLLECTOR_STATUS", CollectorHealth.SOURCE, "process", time(at), JournalJson.encode(mapOf("contractVersion" to 1,
            "generation" to generation, "continuityEpoch" to "continuity-$generation", "state" to phase,
            "leaseMs" to 15000, "deviceListenerRegistered" to true, "activityObservationReady" to true,
            "sampleSucceeded" to true)))
    private fun evidence(at: Long, music: Boolean, streaming: Set<String> = setOf(buds),
        connected: List<String> = listOf(buds), generation: Long = 1, state: String = "SAMPLED") =
        ObservationInput(UUID.randomUUID().toString(), "OUTPUT_EVIDENCE", CollectorHealth.SOURCE, "process", time(at),
            JournalJson.encode(mapOf("type" to "OUTPUT_EVIDENCE", "contractVersion" to 1, "generation" to generation,
                "continuityEpoch" to "continuity-$generation", "globalMusicActive" to music,
                "a2dpTransport" to mapOf("contractVersion" to 1, "apiSource" to "BluetoothA2dp.isA2dpPlaying",
                    "ownerId" to "00000000-0000-4000-8000-000000000001", "requestGeneration" to 1, "state" to state,
                    "devices" to connected.map { mapOf("endpointAddress" to it, "profile" to "A2DP",
                        "connectedReported" to true, "observedName" to "Nord Buds", "observedWallUtcMs" to at,
                        "observedElapsedMs" to at,
                        "streamState" to if (it in streaming) "STREAMING_REPORTED" else "NOT_STREAMING_OR_API_UNAVAILABLE") }))),
            "synthetic_a2dp_fixture_not_hardware")
    private fun snapshot(now: Long? = null) = journal.listeningSnapshot(0, 1_000_000, "UTC", now?.let(::time))
    private fun confirmed(now: Long? = null) = snapshot(now)["confirmedMs"] as Long

    /** STARTING + first sample mints the endpoint alias; HEALTHY makes later samples attributable. */
    private fun ready(at: Long = 1000) {
        journal.append(status(at, "STARTING"))
        journal.append(evidence(at + 10, music = false))
        journal.append(status(at + 20, "HEALTHY"))
    }

    @Test fun streamingWithMusicCountsUntilPauseIsObserved() = run {
        ready()
        journal.append(evidence(2000, music = true)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(7000, music = true)); journal.append(status(7010, "HEALTHY"))
        journal.append(evidence(9000, music = false)); journal.append(status(9010, "HEALTHY"))
        assertEquals(7000L, confirmed())
        val device = (snapshot()["perDevice"] as? List<*>)
        if (device != null) assertEquals(7000L, ((device.single() as Map<*, *>)["durationMs"] as Number).toLong())
    }

    @Test fun speakerPlaybackWithBudsConnectedDoesNotCount() = run {
        ready()
        // Music active but the A2DP stream to the buds is suspended: output is the phone speaker.
        journal.append(evidence(2000, music = true, streaming = emptySet())); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(8000, music = true, streaming = emptySet())); journal.append(status(8010, "HEALTHY"))
        assertEquals(0L, confirmed())
    }

    @Test fun streamWithoutMusicActivityDoesNotCount() = run {
        ready()
        journal.append(evidence(2000, music = false)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(8000, music = false)); journal.append(status(8010, "HEALTHY"))
        assertEquals(0L, confirmed())
    }

    @Test fun reroutedToBudsMidSongStartsAtFirstStreamingSample() = run {
        ready()
        journal.append(evidence(2000, music = true, streaming = emptySet())); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(4000, music = true)); journal.append(status(4010, "HEALTHY"))
        journal.append(evidence(10000, music = true)); journal.append(status(10010, "HEALTHY"))
        assertEquals(6000L, confirmed())
    }

    @Test fun disconnectEndsIntervalAtTheObservedSample() = run {
        ready()
        journal.append(evidence(2000, music = true)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(5000, music = true, connected = emptyList(), streaming = emptySet()))
        assertEquals(3000L, confirmed())
    }

    @Test fun evidenceFromRetiredOrUnhealthyOwnerNeverCounts() = run {
        ready()
        journal.append(evidence(2000, music = true, generation = 7)); journal.append(evidence(6000, music = true, generation = 7))
        assertEquals(0L, confirmed())
        journal.append(status(6100, "STOPPED"))
        journal.append(evidence(6200, music = true)); journal.append(evidence(9000, music = true))
        assertEquals(0L, confirmed())
    }

    @Test fun expiredLeaseClosesWithoutCountingTheGap() = run {
        ready()
        journal.append(evidence(2000, music = true)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(4000, music = true)); journal.append(status(4010, "HEALTHY"))
        // Lease from 4010 expires at 19010; a late sample cannot bridge the missing interval.
        journal.append(evidence(60000, music = true))
        assertEquals(2000L, confirmed())
    }

    @Test fun unknownProbeStateEndsAttributionAtLastEvidence() = run {
        ready()
        journal.append(evidence(2000, music = true)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(5000, music = true)); journal.append(status(5010, "HEALTHY"))
        journal.append(evidence(7000, music = true, state = "UNKNOWN"))
        assertEquals(3000L, confirmed())
    }

    @Test fun onlyTheStreamingEndpointIsAttributed() = run {
        journal.append(status(1000, "STARTING"))
        journal.append(evidence(1010, music = false, connected = listOf(buds, other)))
        journal.append(status(1020, "HEALTHY"))
        journal.append(evidence(2000, music = true, connected = listOf(buds, other), streaming = setOf(other)))
        journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(6000, music = true, connected = listOf(buds, other), streaming = setOf(other)))
        assertEquals(4000L, confirmed())
        val perDevice = snapshot()["perDevice"] as? List<*>
        if (perDevice != null) assertEquals(1, perDevice.size)
    }

    @Test fun liveDurationExtendsOnlyWithinTheLease() = run {
        ready()
        journal.append(evidence(2000, music = true)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(4000, music = true)); journal.append(status(4010, "HEALTHY"))
        assertEquals(2000L, confirmed())
        assertEquals(5000L, confirmed(7000))
        assertEquals(2000L + CollectorHealth.MAX_LEASE_MS, confirmed(100000))
    }

    @Test fun rebuildReplaysTheSameConfirmedTotals() = run {
        ready()
        journal.append(evidence(2000, music = true)); journal.append(status(2010, "HEALTHY"))
        journal.append(evidence(7000, music = true)); journal.append(status(7010, "HEALTHY"))
        journal.append(evidence(9000, music = false))
        val before = confirmed()
        journal.rebuildListeningProjection()
        assertEquals(before, confirmed()); assertEquals(7000L, before)
    }

    private fun tick(at: Long, music: Boolean) { journal.append(evidence(at, music)); journal.append(status(at + 10, "HEALTHY")) }

    @Test fun pauseBetweenConfirmedSpansIsReportedAsBreak() = run {
        ready()
        tick(2000, true); tick(10000, false)
        var at = 20000L
        while (at < 80000) { tick(at, false); at += 10000 }
        tick(80000, true); tick(90000, false)
        val snapshot = snapshot()
        assertEquals(18000L, snapshot["confirmedMs"])
        assertEquals(1, snapshot["breakCount"]); assertEquals(70000L, snapshot["longestBreakMs"])
        assertEquals(70000L, snapshot["averageBreakMs"]); assertEquals(70000L, snapshot["totalBreakMs"])
    }

    @Test fun shortPausesAndPausesAcrossLostCollectionAreNotBreaks() = run {
        ready()
        tick(2000, true); tick(10000, false); tick(30000, true); tick(40000, false)
        assertEquals(0, snapshot()["breakCount"])
        // Lease lost after 40010: the next span starts after an unknown gap, not an observed break.
        journal.append(evidence(200000, music = true))
        journal.append(status(200100, "STARTING", 2)); journal.append(evidence(200200, music = true, generation = 2))
        journal.append(status(200300, "HEALTHY", 2)); journal.append(evidence(205000, music = true, generation = 2))
        journal.append(status(205010, "HEALTHY", 2)); journal.append(evidence(210000, music = false, generation = 2))
        assertEquals(0, snapshot()["breakCount"])
    }
}
