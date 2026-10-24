package com.eartime.eartime_app.tracking

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import org.json.JSONObject

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class ListeningProjectionTest {
    private lateinit var context: Context
    private lateinit var journal: ObservationJournal
    private val name = "p-${UUID.randomUUID().toString().take(8)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private val deviceA = "00000000-0000-4000-8000-000000000001"
    private val deviceB = "00000000-0000-4000-8000-000000000002"
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @Before fun setup() { context = RuntimeEnvironment.getApplication(); journal = ObservationJournal(context, name) }
    @After fun cleanup() { run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name) }
    private fun raw(kind: String, wall: Long, elapsed: Long = wall, epoch: String = "epoch", boot: String? = "boot",
        payload: Map<String, Any?> = emptyMap(), confidence: AttributionConfidence = AttributionConfidence.UNKNOWN) =
        ObservationInput(UUID.randomUUID().toString(), kind, "fixture", "process", ObservationTime(wall, elapsed, boot, epoch),
            JournalJson.encode(payload), "fixture_observation", confidence)
    private fun route(wall: Long, playing: Boolean = true, route: String = "r1", device: String = deviceA,
        elapsed: Long = wall, epoch: String = "epoch", external: Boolean = true) = raw("ROUTE_PLAYBACK", wall, elapsed, epoch,
            payload = mapOf("routeId" to route, "physicalDeviceId" to device, "playing" to playing, "external" to external),
            confidence = AttributionConfidence.CONFIRMED)
    private fun snapshot(from: Long = 0, until: Long = 100000, now: ObservationTime? = null) =
        journal.listeningSnapshot(from, until, "UTC", now)
    private fun total() = snapshot()["confirmedMs"]
    @Suppress("UNCHECKED_CAST") private fun intervals() = snapshot()["intervals"] as List<Map<String, Any?>>

    @Test fun b02SyncRetainsDurableOpeningRatherThanFlutterTimestamp() = run {
        journal.append(raw("PLAYBACK_STARTED", 1000))
        journal.append(raw("SYNC_STATE", 5000, payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(raw("PLAYBACK_PAUSED", 9000))
        assertEquals(1000L, intervals().single()["startUtcMs"])
        assertEquals(8000L, snapshot()["unverifiedMs"])
        assertEquals(0L, total()) // A global flag is not evidence of external listening.
    }

    @Test fun crossLayerFixtureUsesTheActualNativeReducerAndFlutterWireContract() = run {
        val fixture = JSONObject(javaClass.classLoader!!.getResourceAsStream("listening_continuity.json")!!.bufferedReader().use { it.readText() })
        val events = fixture.getJSONArray("events")
        for (i in 0 until events.length()) {
            val event = events.getJSONObject(i)
            @Suppress("UNCHECKED_CAST") val payload = JournalJson.toValue(event.getJSONObject("payload")) as Map<String, Any?>
            journal.append(raw(event.getString("kind"), event.getLong("wall"), payload = payload))
        }
        val expected = fixture.getJSONObject("projection")
        val actual = snapshot()
        for (key in listOf("confirmedMs", "unverifiedMs", "sequence", "gapCount"))
            assertEquals(key, expected.getLong(key), actual[key])
        assertEquals(expected.getJSONArray("intervals").getJSONObject(0).getLong("startUtcMs"), intervals().single()["startUtcMs"])
    }

    @Test fun confirmedContinuitySurvivesFlutterSnapshotAndJournalReopen() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.close(); journal = ObservationJournal(context, name)
        journal.append(raw("SYNC_STATE", 5000, payload = mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(route(9000, false))
        assertEquals(8000L, total())
        assertEquals(1000L, intervals().single { it["attribution"] == "CONFIRMED" }["startUtcMs"])
    }

    @Test fun restartGapClosesAtLastEvidenceAndNeverBridgesToNewProcess() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(raw("COLLECTION_GAP", 8000, epoch = "new"))
        journal.append(route(10000, epoch = "new")); journal.append(route(12000, false, epoch = "new"))
        assertEquals(4000L, total())
        assertEquals("collection_gap", intervals().last()["closeReason"])
    }

    @Test fun preCommitCrashRollsBackProjectionAndSourceTogether() = run {
        val event = route(1000)
        assertThrows(IllegalStateException::class.java) { journal.append(event) { error("process death before commit") } }
        assertEquals(0L, snapshot()["sequence"])
        assertTrue(intervals().isEmpty())
        journal.append(event); journal.append(route(4000, false))
        assertEquals(3000L, total())
    }

    @Test fun duplicateDeliveryAndRebuildHaveExactlyEquivalentProjection() = run {
        val start = route(1000)
        journal.append(start); journal.append(start); journal.append(route(4000, false))
        val before = snapshot()
        journal.rebuildListeningProjection()
        assertEquals(before, snapshot())
        assertEquals(3000L, total())
    }

    @Test fun overlappingOutputsAreUnionedAndDisconnectIsRouteScoped() = run {
        journal.append(route(1000)); journal.append(route(2000, route = "r2", device = deviceB))
        journal.append(raw("ROUTE_DISCONNECTED", 4000, payload = mapOf("routeId" to "r1", "physicalDeviceId" to deviceA),
            confidence = AttributionConfidence.CONFIRMED))
        journal.append(route(7000, false, "r2", deviceB))
        assertEquals(6000L, total())
        assertEquals(8000L, intervals().sumOf { it["durationMs"] as Long })
    }

    @Test fun twoRoutesOfOnePhysicalDeviceRemainConnectedWhenOneDisconnects() = run {
        journal.append(route(1000)); journal.append(route(2000, route = "r2"))
        journal.append(raw("ROUTE_DISCONNECTED", 3000, payload = mapOf("routeId" to "r1", "physicalDeviceId" to deviceA),
            confidence = AttributionConfidence.CONFIRMED))
        val devices = snapshot()["devices"] as List<*>
        assertEquals(true, (devices.single() as Map<*, *>)["connected"])
    }

    @Test fun pauseResumeDoesNotCountPausedTime() = run {
        journal.append(route(1000)); journal.append(route(3000, false))
        journal.append(route(6000)); journal.append(route(9000, false))
        assertEquals(5000L, total()); assertEquals(2, intervals().size)
    }

    @Test fun lossOfRouteAttributionClosesAtLastVerifiedEvidence() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(route(9000).copy(confidence = AttributionConfidence.UNKNOWN))
        assertEquals(2000L, total()); assertEquals("attribution_lost", intervals().single()["closeReason"])
    }

    @Test fun speakerAndUnidentifiedOrUnconfirmedOutputsNeverBecomeListening() = run {
        journal.append(route(1000, external = false)); journal.append(route(2000, device = "mutable name"))
        journal.append(route(3000).copy(confidence = AttributionConfidence.UNKNOWN))
        journal.append(raw("PLAYBACK_STARTED", 4000)); journal.append(raw("PLAYBACK_PAUSED", 8000))
        assertEquals(0L, total()); assertEquals(4000L, snapshot()["unverifiedMs"])
    }

    @Test fun wallRollbackAndForwardJumpCannotFabricateDuration() = run {
        journal.append(route(10000, elapsed = 1000)); journal.append(route(12000, elapsed = 3000))
        journal.append(route(2000, elapsed = 4000)); journal.append(route(5000, false, elapsed = 7000))
        journal.append(route(100000, elapsed = 8000)); journal.append(route(200000, false, elapsed = 9000))
        assertEquals(5000L, journal.listeningSnapshot(0, 300000, "UTC")["confirmedMs"])
    }

    @Test fun bootOrElapsedRegressionAndUnknownBootCannotExtendOldInterval() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(route(5000, elapsed = 100))
        journal.append(route(7000, false, elapsed = 2100))
        assertEquals(4000L, total())
        journal.append(raw("PLAYBACK_STARTED", 10000, boot = null))
        journal.append(raw("PLAYBACK_PAUSED", 20000, boot = null))
        assertEquals(0L, snapshot()["unverifiedMs"])
    }

    @Test fun liveExtensionRequiresCurrentEpochBootAndStableClock() = run {
        journal.append(route(1000))
        assertEquals(4000L, snapshot(now = ObservationTime(5000, 5000, "boot", "epoch"))["confirmedMs"])
        assertEquals(0L, snapshot(now = ObservationTime(5000, 5000, "boot", "new"))["confirmedMs"])
        assertEquals(0L, snapshot(now = ObservationTime(50000, 5000, "boot", "epoch"))["confirmedMs"])
    }

    @Test fun physicalIdentityChangeSplitsRatherThanRenamesOldListening() = run {
        journal.append(route(1000)); journal.append(route(3000))
        journal.append(route(4000, device = deviceB)); journal.append(route(7000, false, device = deviceB))
        assertEquals(5000L, total())
        assertEquals(setOf(deviceA, deviceB), intervals().map { it["deviceId"] }.toSet())
    }

    @Test fun calendarMidnightAndDstDaysUseLocalCalendarNotFixed24Hours() = run {
        val midnight = 1710046800000L // 2024-03-10 00:00 America/New_York
        journal.append(route(midnight - 1000)); journal.append(route(midnight + 2000, false))
        val result = journal.listeningSnapshot(midnight - 1000, midnight + 86400000, "America/New_York")
        val days = result["days"] as List<*>
        assertEquals(3000L, result["confirmedMs"])
        val springDay = days.map { it as Map<*, *> }.single { it["startUtcMs"] == midnight }
        assertEquals(23L * 3600000, springDay["endUtcMs"] as Long - midnight)
        assertEquals(2000L, springDay["confirmedMs"])
    }

    @Test fun autumnRepeatedHourAndAllAggregateBucketsReconcile() = run {
        val start = java.time.Instant.parse("2024-11-03T04:30:00Z").toEpochMilli()
        journal.append(route(start)); journal.append(route(start + 4 * 3600000, false))
        val result = journal.listeningSnapshot(start, start + 4 * 3600000, "America/New_York")
        val hours = (result["hourly"] as List<*>).map { it as Map<*, *> }
        assertEquals(4L * 3600000, hours.sumOf { it["durationMs"] as Long })
        assertEquals(2L * 3600000, hours.single { it["hour"] == 1 }["durationMs"])
        assertEquals(4L * 3600000, result["longestMs"])
        assertEquals(4L * 3600000, result["averageMs"])
        assertEquals(1, result["listeningRuns"])
    }

    @Test fun leapYearLocalWindowMayIncludeAnAdditionalDstHourWithoutOverflow() = run {
        val start = java.time.Instant.parse("2023-11-05T04:00:00Z").toEpochMilli()
        val end = java.time.Instant.parse("2024-11-05T05:00:00Z").toEpochMilli()
        journal.append(route(start)); journal.append(route(end, false))
        val result = journal.listeningSnapshot(start, end, "America/New_York")
        assertEquals(366, (result["days"] as List<*>).size)
        assertEquals(end - start, result["confirmedMs"])
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(Long.MIN_VALUE, Long.MAX_VALUE, "UTC") }
        Unit
    }

    @Test fun displayNameEditsDoNotChangePhysicalIdentityOrJournalFacts() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        val before = journal.readAfter(0)
        ListeningPreferences(context).update(mapOf("deviceNames" to mapOf(deviceA to "My headset")))
        val device = (snapshot()["devices"] as List<*>).single() as Map<*, *>
        assertEquals("My headset", device["name"]); assertEquals(deviceA, device["id"])
        assertEquals(before, journal.readAfter(0)); assertEquals(4000L, total())
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals("My headset", ((snapshot()["devices"] as List<*>).single() as Map<*, *>)["name"])
    }

    @Test fun additiveV1MigrationPreservesObservationsAndReplaysInBoundedBatches() = run {
        repeat(140) { journal.append(raw("PLAYBACK_STARTED", it.toLong())) }
        val source = journal.stats()["sourceId"]
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE listening_projection"); it.execSQL("DROP TABLE listening_intervals")
            it.execSQL("DROP TABLE listening_devices"); it.version = 1
        }
        journal = ObservationJournal(context, name)
        assertEquals(source, snapshot()["sourceId"]); assertEquals(140L, snapshot()["sequence"])
        assertEquals(140L, journal.stats()["observationCount"])
        assertEquals(3, journal.stats()["schemaVersion"])
    }

    @Test fun v2MigrationRebuildsOnlyDisposableStateAndPreservesSourceAndCursors() = run {
        journal.append(route(1000)); journal.append(route(5000, false))
        val source = journal.stats()["sourceId"]
        journal.acknowledge("reader", 2)
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE listening_devices"); it.version = 2
        }
        journal = ObservationJournal(context, name)
        assertEquals(source, snapshot()["sourceId"]); assertEquals(4000L, total())
        assertEquals(2L, journal.cursor("reader")); assertEquals(2L, journal.stats()["observationCount"])
    }

    @Test fun sameMillisecondSourceOrderAndPaginationAreDeterministic() = run {
        journal.append(route(1000)); journal.append(route(1000, false)); journal.append(route(1000))
        assertEquals(2, intervals().size)
        val page = journal.listeningSnapshot(0, 100000, "UTC", offset = 1, limit = 1)
        assertEquals(false, page["hasMore"]); assertEquals(2, page["nextOffset"])
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100, "invalid") }
        Unit
    }

    @Test fun knownDevicePagesAreBoundedDisjointAndPreserveListeningTotals() = run {
        repeat(205) { index ->
            journal.append(raw("DEVICE_CONNECTED", 1000L + index * 2, payload = mapOf("device" to
                mapOf("id" to "endpoint-$index", "friendlyName" to "Fixture $index", "nativeType" to 8))))
            if (index < 204) journal.append(raw("DEVICE_DISCONNECTED", 1001L + index * 2,
                payload = mapOf("deviceId" to "endpoint-$index")))
        }
        fun page(offset: Int) = journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = offset)
        val first = page(0); val second = page(100); val third = page(200)
        val firstDevices = first["devices"] as List<*>
        val secondDevices = second["devices"] as List<*>
        val thirdDevices = third["devices"] as List<*>
        assertEquals(100, firstDevices.size); assertEquals(100, secondDevices.size); assertEquals(5, thirdDevices.size)
        assertEquals(205, (firstDevices + secondDevices + thirdDevices).map { (it as Map<*, *>)["id"] }.toSet().size)
        assertEquals("Fixture 204", (firstDevices.first() as Map<*, *>)["name"])
        assertEquals("Fixture 0", (thirdDevices.last() as Map<*, *>)["name"])
        assertEquals(205L, third["deviceCount"]); assertEquals(205L, third["nextDeviceOffset"])
        assertEquals(true, first["hasMoreDevices"]); assertEquals(false, third["hasMoreDevices"])
        for (result in listOf(first, second, third)) {
            assertEquals(0L, result["confirmedMs"]); assertEquals(0L, result["unverifiedMs"])
            assertEquals(0, result["intervalCount"])
        }
        journal.close(); journal = ObservationJournal(context, name)
        assertEquals(third, page(200))
    }

    @Test fun invalidDeviceOffsetsFailAndEmptyPagesCannotAdvancePastCount() = run {
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = -1) }
        assertThrows(IllegalArgumentException::class.java) { journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = Int.MAX_VALUE) }
        val page = journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = 100)
        assertEquals(100, page["deviceOffset"]); assertEquals(0L, page["nextDeviceOffset"])
        assertEquals(false, page["hasMoreDevices"]); assertTrue((page["devices"] as List<*>).isEmpty())
        assertEquals(0L, journal.stats()["observationCount"])
    }
}
