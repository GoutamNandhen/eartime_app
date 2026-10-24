package com.eartime.eartime_app.tracking

import android.app.Application
import android.database.sqlite.SQLiteDatabase
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
@Config(sdk = [28], manifest = Config.NONE, application = Application::class)
class ListeningHistoryLoadTest {
    private val context = RuntimeEnvironment.getApplication()
    private val name = "l-${UUID.randomUUID().toString().take(8)}.db"
    private val worker = Executors.newSingleThreadExecutor()
    private var journal = ObservationJournal(context, name)
    private val device = "00000000-0000-4000-8000-000000000001"
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @After fun cleanup() { run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name) }
    private fun input(kind: String, at: Long, payload: Map<String, Any?>) = ObservationInput(
        UUID.randomUUID().toString(), kind, "synthetic_history_fixture", "fixture-process",
        ObservationTime(at, at, "fixture-boot", "fixture-epoch"), JournalJson.encode(payload),
        "synthetic_fixture_not_hardware", if (kind == "ROUTE_PLAYBACK") AttributionConfidence.CONFIRMED else AttributionConfidence.UNKNOWN)

    @Test fun twelveHundredSessionsCancelAtTransactionBoundariesAndRecoverWithoutPartialTotals() = run {
        val started = System.nanoTime()
        repeat(1200) { index ->
            val start = 1000L + index * 2000
            for ((at, playing) in listOf(start to true, start + 1000 to false)) journal.append(input("ROUTE_PLAYBACK", at,
                mapOf("routeId" to "fixture-route", "physicalDeviceId" to device, "external" to true, "playing" to playing)))
        }
        val seeded = System.nanoTime()
        val before = journal.listeningSnapshot(0, 3000000, "UTC")
        assertEquals(1200000L, before["confirmedMs"]); assertEquals(1200, before["intervalCount"])
        assertEquals(1200, before["listeningRuns"]); assertEquals(1000L, before["longestMs"])
        assertEquals(1000L, before["averageMs"])
        assertEquals(1200000L, (before["days"] as List<*>).sumOf { ((it as Map<*, *>)["confirmedMs"] as Number).toLong() })
        val ids = mutableSetOf<String>()
        for (offset in 0 until 1200 step 100) {
            val page = journal.listeningSnapshot(0, 3000000, "UTC", offset = offset)
            assertEquals(before["confirmedMs"], page["confirmedMs"])
            for (row in page["intervals"] as List<*>) assertTrue(ids.add((row as Map<*, *>)["id"] as String))
        }
        assertEquals(1200, ids.size)
        journal.acknowledge("load_fixture", 2000)
        val source = journal.stats()["sourceId"]
        var checks = 0
        assertThrows(ProjectionReplayCancelled::class.java) { journal.rebuildListeningProjection { ++checks == 5 } }
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READONLY).use { reader ->
            reader.rawQuery("SELECT sequence FROM listening_projection WHERE singleton=1", null).use {
                assertTrue(it.moveToFirst()); assertEquals(384L, it.getLong(0))
            }
        }
        assertEquals(2400L, journal.stats()["observationCount"]); assertEquals(source, journal.stats()["sourceId"])
        assertEquals(2000L, journal.cursor("load_fixture"))
        journal.close(); journal = ObservationJournal(context, name)
        val recovered = journal.listeningSnapshot(0, 3000000, "UTC")
        assertEquals(before, recovered)
        assertThrows(ProjectionReplayCancelled::class.java) { journal.rebuildListeningProjection { true } }
        assertEquals(before, journal.listeningSnapshot(0, 3000000, "UTC"))
        println("SYNTHETIC_HISTORY sessions=1200 observations=2400 seedMs=${(seeded - started) / 1000000} totalMs=${(System.nanoTime() - started) / 1000000} dbBytes=${context.getDatabasePath(name).length()}")
    }

    @Test fun pagingWhileObservationsArriveNeverTruncatesTotalsAndCanRestartACompleteScan() = run {
        repeat(205) { index -> journal.append(input("DEVICE_CONNECTED", 1000L + index,
            mapOf("device" to mapOf("id" to "fixture-$index", "friendlyName" to "Synthetic $index")))) }
        val first = journal.listeningSnapshot(0, 100000, "UTC")
        val firstSequence = first["sequence"] as Long
        journal.append(input("DEVICE_CONNECTED", 5000, mapOf("device" to mapOf("id" to "new-fixture", "friendlyName" to "New synthetic"))))
        val second = journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = 100)
        assertTrue((second["sequence"] as Long) > firstSequence)
        assertEquals(206L, second["deviceCount"]); assertEquals(100, (second["devices"] as List<*>).size)
        assertEquals(first["confirmedMs"], second["confirmedMs"])
        // Live offset queries may reorder: restart from page zero after sequence changes.
        val ids = mutableSetOf<String>()
        for (offset in listOf(0, 100, 200)) for (row in journal.listeningSnapshot(0, 100000, "UTC", deviceOffset = offset)["devices"] as List<*>)
            assertTrue(ids.add((row as Map<*, *>)["id"] as String))
        assertEquals(206, ids.size)
    }

    @Test fun versionTwoCacheReplaysKnownOwnerStopAndFutureCachesAreNotDeleted() = run {
        fun status(at: Long, phase: String) = input("COLLECTOR_STATUS", at,
            mapOf("contractVersion" to 1, "generation" to 1, "continuityEpoch" to "fixture-owner", "state" to phase,
                "reason" to "observer_owner_stopped")).copy(collector = CollectorHealth.SOURCE)
        journal.append(status(500, "STARTING"))
        journal.append(input("PLAYBACK_STARTED", 1000, emptyMap()))
        journal.append(input("SYNC_STATE", 5000, mapOf("connectedDevices" to emptyList<Any>(), "isPlaying" to true)))
        journal.append(status(9000, "STOPPED"))
        journal.acknowledge("migration_fixture", 4)
        val observations = journal.readAfter(0)
        val source = journal.stats()["sourceId"]
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("UPDATE listening_projection SET version=2")
            it.execSQL("UPDATE listening_intervals SET open=1, duration_ms=8000, end_utc_ms=9000")
        }
        journal = ObservationJournal(context, name)
        val corrected = journal.listeningSnapshot(0, 100000, "UTC")
        assertEquals(4, corrected["projectionVersion"]); assertEquals(4000L, corrected["unverifiedMs"])
        assertEquals(false, ((corrected["intervals"] as List<*>).single() as Map<*, *>)["open"])
        assertEquals(observations, journal.readAfter(0)); assertEquals(source, journal.stats()["sourceId"])
        assertEquals(4L, journal.cursor("migration_fixture")); assertEquals(3, journal.stats()["schemaVersion"])
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("UPDATE listening_projection SET version=99")
        }
        journal = ObservationJournal(context, name)
        assertThrows(IllegalStateException::class.java) { journal.listeningSnapshot(0, 100000, "UTC") }
        assertThrows(IllegalStateException::class.java) { journal.rebuildListeningProjection() }
        assertEquals(observations, journal.readAfter(0)); assertEquals(4L, journal.cursor("migration_fixture"))
    }
}
