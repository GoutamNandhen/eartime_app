package com.eartime.eartime_app.tracking

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class ObservationJournalTest {
    private lateinit var context: Context
    private lateinit var journal: ObservationJournal
    private val worker = Executors.newSingleThreadExecutor()
    private val name = "test-${UUID.randomUUID()}.sqlite"

    private fun <T> run(work: () -> T): T = try {
        worker.submit(Callable { work() }).get()
    } catch (error: ExecutionException) { throw error.cause ?: error }

    private fun input(timestamp: Long = 1000) = ObservationInput(
        UUID.randomUUID().toString(), "PLAYBACK_STARTED", "legacy_audio_service", "process-1",
        ObservationTime(timestamp, 100, "boot-1", "epoch-1"),
        JournalJson.encode(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to timestamp)),
    )

    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        journal = ObservationJournal(context, name) { 9000 }
    }

    @After fun cleanup() {
        run { journal.close() }
        worker.shutdownNow()
        context.deleteDatabase(name)
    }

    @Test fun sameMillisecondObservationsHaveDistinctPersistentIdsAndSequences() = run {
        val first = journal.append(input())
        val second = journal.append(input())
        assertEquals(1L, first.sequence)
        assertEquals(2L, second.sequence)
        assertNotEquals(first.input.id, second.input.id)
        assertEquals(first.sourceId, second.sourceId)
        assertEquals(2, journal.readAfter(0).size)
    }

    @Test fun duplicateIsIdempotentButConflictIsDurableAndVisible() = run {
        val observation = input()
        val committed = journal.append(observation)
        assertEquals(committed, journal.append(observation))
        assertThrows(ObservationConflict::class.java) {
            journal.append(observation.copy(payloadJson = "{\"changed\":true}"))
        }
        assertEquals(1L, journal.stats()["observationCount"])
        assertEquals(1L, journal.stats()["conflictCount"])
        assertEquals(observation, journal.readAfter(0).single().input)
    }

    @Test fun injectedCrashRollsBackRowAndSequenceTogether() = run {
        val observation = input()
        assertThrows(IllegalStateException::class.java) {
            journal.append(observation) { throw IllegalStateException("crash before commit") }
        }
        assertTrue(journal.readAfter(0).isEmpty())
        assertEquals(1L, journal.append(observation).sequence)
    }

    @Test fun reopenPreservesSourceIdentitySequenceAndPayload() = run {
        val first = journal.append(input())
        journal.close()
        journal = ObservationJournal(context, name)
        assertEquals(first, journal.readAfter(0).single())
        assertEquals(first.sourceId, journal.append(input(2000)).sourceId)
        assertEquals(2L, journal.stats()["lastSequence"])
    }

    @Test fun replayIsBoundedOrderedAndDoesNotConsumeDurableEvents() = run {
        repeat(150) { journal.append(input(it.toLong())) }
        val first = journal.readAfter(0, 64)
        val second = journal.readAfter(first.last().sequence, 64)
        val third = journal.readAfter(second.last().sequence, 64)
        assertEquals((1L..150L).toList(), (first + second + third).map { it.sequence })
        assertEquals(first, journal.readAfter(0, 64))
        assertThrows(IllegalArgumentException::class.java) { journal.readAfter(0, 129) }
        assertThrows(IllegalArgumentException::class.java) { journal.readAfter(-1) }
        Unit
    }

    @Test fun acknowledgementIsMonotonicBoundedAndDoesNotDeleteSourceData() = run {
        repeat(3) { journal.append(input()) }
        assertEquals(2L, journal.acknowledge("projection.v1", 2))
        assertEquals(2L, journal.acknowledge("projection.v1", 1))
        assertEquals(0L, journal.cursor("different.consumer"))
        assertThrows(IllegalArgumentException::class.java) { journal.acknowledge("projection.v1", 4) }
        journal.close()
        journal = ObservationJournal(context, name)
        assertEquals(2L, journal.cursor("projection.v1"))
        assertEquals(3, journal.readAfter(0).size)
    }

    @Test fun mainThreadAccessIsRejectedBeforeOpeningDatabase() {
        assertThrows(IllegalStateException::class.java) { journal.stats() }
        assertFalse(context.getDatabasePath(name).exists())
    }

    @Test fun mutablePayloadCannotChangeAfterSnapshot() {
        val device = mutableMapOf<String, Any?>("name" to "Before")
        val raw = mutableMapOf<String, Any?>("device" to device)
        val snapshot = JournalJson.snapshot(raw)
        device["name"] = "After"
        assertEquals("Before", (snapshot["device"] as Map<*, *>)["name"])
        assertThrows(IllegalArgumentException::class.java) {
            JournalJson.snapshot(mapOf("invalid" to Double.NaN))
        }
    }

    @Test fun canonicalJsonIgnoresMapInsertionOrder() {
        assertEquals(JournalJson.encode(mapOf("a" to 1, "b" to listOf(true, null))),
            JournalJson.encode(mapOf("b" to listOf(true, null), "a" to 1)))
    }

    @Test fun unsupportedDowngradeRetainsExistingDatabaseAndData() = run {
        context.getDatabasePath(name).parentFile?.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(context.getDatabasePath(name), null).use { database ->
            database.execSQL("CREATE TABLE future_data (value TEXT NOT NULL)")
            database.execSQL("INSERT INTO future_data VALUES ('preserve-me')")
            database.version = 4
        }
        assertThrows(SQLiteException::class.java) { journal.stats() }
        journal.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READONLY).use { reader ->
            reader.rawQuery("SELECT value FROM future_data", null).use {
                assertTrue(it.moveToFirst())
                assertEquals("preserve-me", it.getString(0))
            }
            assertEquals(4, reader.version)
        }
    }
}
