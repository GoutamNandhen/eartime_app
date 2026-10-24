package com.eartime.eartime_app.tracking

import android.app.Application
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class EndpointIdentityTest {
    private val context = RuntimeEnvironment.getApplication()
    private val name = "id-${UUID.randomUUID().toString().take(8)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private var journal = ObservationJournal(context, name)
    private val address = "02:11:22:33:44:55"
    private val second = "00:11:22:33:44:55"
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @After fun cleanup() {
        run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name)
    }
    private fun sample(at: Long = 1000, addresses: List<String> = listOf(address), epoch: String = "fixture-epoch",
        observedName: String = "Same model") = ObservationInput(UUID.randomUUID().toString(), "OUTPUT_EVIDENCE",
        CollectorHealth.SOURCE, "fixture-process", ObservationTime(at, at, "fixture-boot", epoch),
        JournalJson.encode(mapOf("a2dpTransport" to mapOf("contractVersion" to 1,
            "apiSource" to "BluetoothA2dp.isA2dpPlaying", "ownerId" to "00000000-0000-4000-8000-000000000001",
            "requestGeneration" to 1, "state" to "SAMPLED", "devices" to addresses.map {
                mapOf("endpointAddress" to it, "profile" to "A2DP", "connectedReported" to true,
                    "observedName" to observedName, "observedWallUtcMs" to at, "observedElapsedMs" to at,
                    "streamState" to "STREAMING_REPORTED") }))), "synthetic_identity_fixture_not_hardware")
    private fun snapshot() = journal.listeningSnapshot(0, 100000, "UTC")
    private fun devices() = (snapshot()["devices"] as List<*>).map { it as Map<*, *> }
    private fun alias(id: String) = (journal.deviceIdentity(id)["aliases"] as List<*>).single() as Map<*, *>
    private fun change(row: Map<*, *>, target: String?, at: Long = 9000, source: String = journal.stats()["sourceId"] as String) =
        journal.changeEndpointIdentity(source, row["id"] as String, row["revision"] as Long, target,
            ObservationTime(at, at, "fixture-boot", "fixture-epoch"), "fixture-process")

    @Test fun evidenceAndRandomAssociationCommitTogetherAndDuplicatesDoNotRemint() = run {
        val input = sample()
        val observed = journal.append(input)
        val rows = journal.readAfter(0)
        assertEquals(2, rows.size); assertEquals(observed, rows.first())
        assertEquals(EndpointIdentity.KIND, rows.last().input.kind)
        val device = devices().single(); val id = device["id"] as String
        assertTrue(EndpointIdentity.validId(id)); assertNotEquals(id, alias(id)["id"])
        assertEquals(false, device["identityVerified"]); assertEquals("ENDPOINT_ASSOCIATED", device["identityKind"])
        assertEquals(0L, snapshot()["confirmedMs"])
        journal.append(input)
        assertEquals(rows, journal.readAfter(0)); assertEquals(id, devices().single()["id"])
    }

    @Test fun failureBeforeCommitLeavesNeitherEvidenceNorIdentityCache() = run {
        assertThrows(IllegalStateException::class.java) { journal.append(sample()) { error("synthetic crash") } }
        assertTrue(journal.readAfter(0).isEmpty()); assertTrue(devices().isEmpty())
        journal.append(sample()); assertEquals(2L, journal.stats()["observationCount"])
        assertEquals(1, devices().size)
    }

    @Test fun reconnectRenameProcessAndCacheRebuildKeepSameEndpointIdAndDisplayOverride() = run {
        journal.append(sample())
        val id = devices().single()["id"] as String
        ListeningPreferences(context).update(mapOf("deviceNames" to mapOf(id to "My listening device")))
        val initial = alias(id)
        journal.close(); journal = ObservationJournal(context, name)
        journal.append(sample(4000, epoch = "new-epoch", observedName = "Renamed transport").copy(processGeneration = "new-process"))
        assertEquals(id, devices().single()["id"])
        assertEquals("My listening device", devices().single()["name"])
        journal.rebuildListeningProjection()
        assertEquals(initial, alias(id)); assertEquals("My listening device", devices().single()["name"])
    }

    @Test fun identicalNamesNeverMergeDifferentEndpointsAndCaseNormalizationIsIdempotent() = run {
        journal.append(sample(addresses = listOf(address, second)))
        val before = devices().map { it["id"] }.toSet()
        assertEquals(2, before.size)
        journal.append(sample(2000, listOf(address.lowercase(), second)))
        assertEquals(before, devices().map { it["id"] }.toSet())
        assertEquals(4L, journal.stats()["observationCount"])
    }

    @Test fun maskedDuplicateStaleAndUnsupportedEvidenceCannotMintIdentity() = run {
        assertTrue(EndpointIdentity.observations(sample(addresses = listOf("02:00:00:00:00:00"))).isEmpty())
        assertTrue(EndpointIdentity.observations(sample(addresses = listOf(address, address))).isEmpty())
        assertTrue(EndpointIdentity.observations(sample().copy(collector = "other_source")).isEmpty())
        assertTrue(EndpointIdentity.observations(sample().copy(payloadVersion = 2)).isEmpty())
        val original = sample()
        val payload = JSONObject(original.payloadJson)
        payload.getJSONObject("a2dpTransport").getJSONArray("devices").getJSONObject(0).put("observedElapsedMs", 1)
        assertTrue(EndpointIdentity.observations(original.copy(payloadJson = payload.toString(),
            time = original.time.copy(elapsedMs = 5000))).isEmpty())
        journal.append(sample().copy(time = original.time.copy(elapsedMs = null)))
        assertTrue(devices().isEmpty())
    }

    @Test fun unknownBootStillStoresEndpointWithoutInventingPlaybackOrDisconnection() = run {
        journal.append(sample().let { it.copy(time = it.time.copy(bootId = null)) })
        assertEquals("CONNECTED_REPORTED", devices().single()["connectionState"])
        journal.append(sample(2000, emptyList()))
        assertEquals("UNKNOWN", devices().single()["connectionState"])
        assertEquals(false, devices().single()["connected"])
        assertEquals(0L, snapshot()["confirmedMs"])
    }

    @Test fun explicitAssociationResetReplayAndOptimisticConflictAreReversible() = run {
        journal.append(sample(addresses = listOf(address, second)))
        val ids = devices().map { it["id"] as String }
        val original = alias(ids[0])
        assertEquals(false, change(original, ids[1])["unchanged"])
        val updated = alias(ids[0])
        assertEquals(ids[1], updated["deviceId"]); assertEquals("USER_CONFIRMED", updated["evidence"])
        assertThrows(IllegalArgumentException::class.java) { change(original, ids[1]) }
        assertThrows(IllegalArgumentException::class.java) { change(updated, null, source = UUID.randomUUID().toString()) }
        assertThrows(IllegalArgumentException::class.java) { change(updated, UUID.randomUUID().toString()) }
        assertEquals(true, change(updated, ids[1])["unchanged"])
        journal.rebuildListeningProjection(); assertEquals(updated, alias(ids[0]))
        change(updated, null)
        assertEquals(ids[0], alias(ids[0])["deviceId"])
        assertEquals("SAME_OBSERVED_ENDPOINT", alias(ids[0])["evidence"])
    }

    @Test fun identityChangeDoesNotRestartTheLegacyB02Opening() = run {
        journal.append(sample(addresses = listOf(address, second)))
        fun legacy(kind: String, at: Long, payload: String = "{}") = sample(at).copy(kind = kind, payloadJson = payload)
        journal.append(legacy("PLAYBACK_STARTED", 2000))
        journal.append(legacy("SYNC_STATE", 5000, "{\"connectedDevices\":[],\"isPlaying\":true}"))
        val ids = devices().map { it["id"] as String }
        change(alias(ids[0]), ids[1], 6000)
        journal.append(legacy("PLAYBACK_PAUSED", 7000))
        val interval = (snapshot()["intervals"] as List<*>).single() as Map<*, *>
        assertEquals(2000L, interval["startUtcMs"])
        assertEquals(5000L, snapshot()["unverifiedMs"])
    }

    @Test fun versionThreeCacheUpgradeRetainsRawIdentityProofAndConsumerCursor() = run {
        journal.append(sample()); val id = devices().single()["id"] as String
        val before = journal.readAfter(0); journal.acknowledge("identity-fixture", 2)
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("UPDATE listening_projection SET version=3")
            it.execSQL("DROP TABLE listening_endpoint_aliases")
        }
        journal = ObservationJournal(context, name)
        assertEquals(id, devices().single()["id"]); assertEquals(before, journal.readAfter(0))
        assertEquals(2L, journal.cursor("identity-fixture")); assertEquals(3, journal.stats()["schemaVersion"])
        assertEquals(4, snapshot()["projectionVersion"])
    }

    @Test fun archiveRoundTripRestoresTheExactEndpointIdsWithoutHardwarePromotion() = run {
        journal.append(sample()); val id = devices().single()["id"] as String
        val file = File.createTempFile("identity-archive-", ".fixture", context.cacheDir)
        val restoredName = "ir-${UUID.randomUUID().toString().take(8)}.db"
        val restored = ObservationJournal(context, restoredName)
        try {
            file.outputStream().use(journal::writeArchive)
            restored.restoreArchive(file, ObservationTime(20000, 20000, "boot", "restored-epoch"), "restored")
            val row = (restored.listeningSnapshot(0, 100000, "UTC")["devices"] as List<*>).single() as Map<*, *>
            assertEquals(id, row["id"]); assertEquals(false, row["identityVerified"])
            assertEquals("UNKNOWN", row["connectionState"])
            assertEquals(alias(id), (restored.deviceIdentity(id)["aliases"] as List<*>).single())
        } finally { restored.close(); context.deleteDatabase(restoredName); file.delete() }
    }

    @Test fun candidatePagingReturnsAllIdsAndAliasPagingHasIndependentCursor() = run {
        // Generated, deterministic synthetic endpoints; no hardware identifiers.
        val endpoints = (1..105).map { "02:11:22:33:%02X:%02X".format(it / 256, it % 256) }
        endpoints.chunked(16).forEachIndexed { index, batch -> journal.append(sample(1000L + index, batch)) }
        val id = devices().first()["id"] as String
        val first = journal.deviceIdentity(id)
        val last = journal.deviceIdentity(id, candidateOffset = 100)
        assertEquals(100, (first["candidates"] as List<*>).size)
        assertEquals(5, (last["candidates"] as List<*>).size)
        assertEquals(true, first["hasMoreCandidates"]); assertEquals(false, last["hasMoreCandidates"])
        assertEquals(first["aliases"], last["aliases"])
        val ids = ((first["candidates"] as List<*>) + (last["candidates"] as List<*>)).map { (it as Map<*, *>)["id"] }
        assertEquals(105, ids.distinct().size)
    }

    @Test fun reassociationClosesOnlyTheAffectedDeviceRouteAtItsLastEvidence() = run {
        journal.append(sample(addresses = listOf(address, second)))
        val ids = devices().map { it["id"] as String }
        fun route(id: String, at: Long) = sample(at).copy(kind = "ROUTE_PLAYBACK", collector = "synthetic_route_fixture",
            confidence = AttributionConfidence.CONFIRMED, payloadJson = JournalJson.encode(mapOf("routeId" to id,
                "physicalDeviceId" to id, "external" to true, "playing" to true)))
        for (id in ids) { journal.append(route(id, 2000)); journal.append(route(id, 4000)) }
        change(alias(ids[0]), ids[1], 9000)
        val intervals = (snapshot()["intervals"] as List<*>).map { it as Map<*, *> }
        val closed = intervals.single { it["deviceId"] == ids[0] }
        assertEquals(false, closed["open"]); assertEquals(4000L, closed["endUtcMs"])
        assertEquals("device_identity_changed", closed["closeReason"])
        assertEquals(true, intervals.single { it["deviceId"] == ids[1] }["open"])
    }
}
