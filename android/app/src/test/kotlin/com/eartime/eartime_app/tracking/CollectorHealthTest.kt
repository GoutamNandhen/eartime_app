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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class CollectorHealthTest {
    private val context = RuntimeEnvironment.getApplication()
    private val name = "h-${UUID.randomUUID().toString().take(8)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private var journal = ObservationJournal(context, name)
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @After fun cleanup() { run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name) }
    private fun time(at: Long) = ObservationTime(at, at, "boot", "process-epoch")
    private fun status(at: Long, phase: String, generation: Long = 1, epoch: String = "continuity-$generation",
        extra: Map<String, Any?> = emptyMap()) = ObservationInput(UUID.randomUUID().toString(), "COLLECTOR_STATUS",
        CollectorHealth.SOURCE, "process", time(at), JournalJson.encode(mapOf("contractVersion" to 1,
            "generation" to generation, "continuityEpoch" to epoch, "state" to phase,
            "leaseMs" to 5000, "deviceListenerRegistered" to true,
            "activityObservationReady" to true, "sampleSucceeded" to true) + extra))
    private fun health(at: Long = 2000): Map<*, *> = journal.listeningSnapshot(0, 100000, "UTC", healthTime = time(at))["collectorHealth"] as Map<*, *>
    private fun ready() { journal.append(status(1000, "STARTING")); journal.append(status(1500, "HEALTHY")) }

    @Test fun noAcknowledgmentOrProcessUptimeNeverProvesHealth() = run {
        assertEquals("UNKNOWN", health()["state"])
        journal.append(status(1000, "HEALTHY"))
        assertEquals("UNKNOWN", health()["state"])
        ready(); assertEquals("HEALTHY", health()["state"])
        assertEquals(false, health()["liveListeningEligible"])
        assertEquals(0L, journal.listeningSnapshot(0, 100000, "UTC")["confirmedMs"])
        journal.append(status(2100, "HEALTHY").copy(payloadVersion = 2))
        assertEquals("CONTINUITY_LOST", health(2200)["state"])
    }
    @Test fun expiryCannotBeRetroactivelyRenewedByDelayedHeartbeat() = run {
        ready(); assertEquals("HEALTHY", health(6499)["state"])
        assertEquals("TEMPORARILY_UNAVAILABLE", health(6500)["state"])
        journal.append(status(6500, "HEALTHY"))
        assertEquals("CONTINUITY_LOST", health(6500)["state"])
        journal.append(status(7000, "STARTING", 2)); journal.append(status(7100, "HEALTHY", 2))
        assertEquals("HEALTHY", health(7200)["state"])
    }
    @Test fun generationAndEpochFenceOldCallbacksAndCannotResumeStoppedOwner() = run {
        ready(); journal.append(status(2000, "STOPPED"))
        journal.append(status(2100, "HEALTHY")); assertEquals("CONTINUITY_LOST", health(2100)["state"])
        journal.append(status(2200, "STARTING", 2)); journal.append(status(2300, "HEALTHY", 2))
        journal.append(status(2400, "STOPPED", 1))
        journal.append(status(2500, "PERMISSION_BLOCKED", 2, "wrong-epoch"))
        assertEquals("HEALTHY", health(2500)["state"]); assertEquals(2L, (health(2500)["generation"] as Number).toLong())
    }
    @Test fun failedRegistrationAndOversizedLeasesCannotAcknowledgeHealth() = run {
        journal.append(status(1000, "STARTING"))
        journal.append(status(1500, "HEALTHY", extra = mapOf("deviceListenerRegistered" to false)))
        assertEquals("CONTINUITY_LOST", health()["state"])
        journal.append(status(2000, "STARTING", 2))
        journal.append(status(2100, "HEALTHY", 2, extra = mapOf("leaseMs" to 15001)))
        assertEquals("CONTINUITY_LOST", health(2200)["state"])
    }
    @Test fun clockRollbackBootChangeAndUnverifiedClockCannotGrantLease() = run {
        ready()
        assertEquals("UNKNOWN", journal.listeningSnapshot(0, 100000, "UTC")["collectorHealth"].let { (it as Map<*, *>)["state"] })
        val rollback = status(1600, "HEALTHY").copy(time = ObservationTime(1600, 1400, "boot", "process-epoch"))
        journal.append(rollback); assertEquals("CONTINUITY_LOST", health()["state"])
        journal.append(status(2200, "STARTING", 2)); journal.append(status(2300, "HEALTHY", 2))
        assertEquals("UNKNOWN", (journal.listeningSnapshot(0, 100000, "UTC", healthTime = time(2400).copy(bootId = "other"))["collectorHealth"] as Map<*, *>)["state"])
        journal.append(status(90000, "HEALTHY", 2).copy(time = time(2400).copy(wallUtcMs = 90000)))
        assertEquals("CONTINUITY_LOST", health(2400)["state"])
        journal.append(status(90010, "STARTING", 3).copy(time = time(2410).copy(wallUtcMs = 90010)))
        journal.append(status(90020, "HEALTHY", 3).copy(time = time(2420).copy(wallUtcMs = 90020)))
        assertEquals("HEALTHY", (journal.listeningSnapshot(0, 100000, "UTC", healthTime = time(2430).copy(wallUtcMs = 90030))["collectorHealth"] as Map<*, *>)["state"])
    }
    @Test fun journalReopenRebuildDuplicateAndRollbackRetainExactlyTheSameHealthEvidence() = run {
        ready(); val sample = status(2000, "HEALTHY")
        journal.append(sample); journal.append(sample)
        assertEquals(3L, journal.stats()["observationCount"])
        val before = health(2200)
        assertThrows(IllegalStateException::class.java) { journal.append(status(2100, "STOPPED")) { error("synthetic crash") } }
        assertEquals(before, health(2200))
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals(before, health(2200)); journal.rebuildListeningProjection(); assertEquals(before, health(2200))
    }
    @Test fun processGapRevokesHealthWithoutCreditingListening() = run {
        ready(); journal.append(status(3000, "STOPPED").copy(kind = "COLLECTION_GAP", collector = "journal_runtime"))
        assertEquals("CONTINUITY_LOST", health(3000)["state"])
        assertEquals(0L, journal.listeningSnapshot(0, 100000, "UTC")["confirmedMs"])
    }
    @Test fun allUnavailableStatesAreDurableAndLegacyCannotImpersonateObserver() = run {
        var generation = 1L
        for (phase in listOf("PERMISSION_BLOCKED", "TEMPORARILY_UNAVAILABLE", "SUSPENDED", "STOPPED", "UNKNOWN", "NOT_STARTED")) {
            val at = generation * 1000
            journal.append(status(at, "STARTING", generation)); journal.append(status(at + 100, phase, generation))
            assertEquals(phase, health(at + 100)["state"]); generation++
        }
        journal.append(status(9000, "STARTING", 99).copy(collector = "legacy_audio_service"))
        assertEquals("NOT_STARTED", health(9000)["state"])
    }

    @Test fun knownServiceOwnerStopClosesAtLastEvidenceAndLaterSyncCannotBridgeTheGap() = run {
        ready()
        journal.append(status(1000, "UNKNOWN").copy(kind = "PLAYBACK_STARTED", collector = "legacy_audio_service", payloadJson = "{}"))
        fun sync(at: Long) = status(at, "UNKNOWN").copy(kind = "SYNC_STATE", collector = "legacy_audio_service",
            payloadJson = JournalJson.encode(mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(sync(5000))
        journal.append(status(9000, "STOPPED", extra = mapOf("reason" to "observer_owner_stopped")))
        val stopped = journal.listeningSnapshot(0, 100000, "UTC")
        val old = (stopped["intervals"] as List<*>).single() as Map<*, *>
        assertEquals(false, old["open"]); assertEquals(5000L, old["endUtcMs"])
        assertEquals("service_owner_stopped", old["closeReason"])
        journal.append(sync(12000))
        journal.append(status(16000, "UNKNOWN").copy(kind = "PLAYBACK_PAUSED", collector = "legacy_audio_service", payloadJson = "{}"))
        assertEquals(8000L, journal.listeningSnapshot(0, 100000, "UTC")["unverifiedMs"])
        assertEquals(0L, journal.listeningSnapshot(0, 100000, "UTC")["confirmedMs"])
    }

    @Test fun retiredOwnerStopAndDuplicateStopCannotInvalidateNewOwnerOrInventMoreGaps() = run {
        ready()
        journal.append(status(2000, "STARTING", 2)); journal.append(status(2100, "HEALTHY", 2))
        journal.append(status(2200, "UNKNOWN").copy(kind = "PLAYBACK_STARTED", collector = "legacy_audio_service", payloadJson = "{}"))
        journal.append(status(2300, "STOPPED", 1, extra = mapOf("reason" to "observer_owner_stopped")))
        var snapshot = journal.listeningSnapshot(0, 100000, "UTC")
        assertEquals(true, ((snapshot["intervals"] as List<*>).single() as Map<*, *>)["open"])
        assertEquals(0L, snapshot["gapCount"])
        journal.append(status(2400, "STOPPED", 2, extra = mapOf("reason" to "observer_owner_stopped")))
        journal.append(status(2450, "HEALTHY", 2))
        journal.append(status(2500, "STOPPED", 2, extra = mapOf("reason" to "observer_owner_stopped")))
        snapshot = journal.listeningSnapshot(0, 100000, "UTC")
        assertEquals(false, ((snapshot["intervals"] as List<*>).single() as Map<*, *>)["open"])
        assertEquals(1L, snapshot["gapCount"])
    }
}
