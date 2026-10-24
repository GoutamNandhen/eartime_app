package com.eartime.eartime_app.tracking

import android.app.Application
import android.content.Context
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class JournalArchiveTest {
    private lateinit var context: Context
    private lateinit var a: ObservationJournal
    private lateinit var b: ObservationJournal
    private val worker = Executors.newSingleThreadExecutor()
    private val firstName = "a-${UUID.randomUUID().toString().take(6)}.db"
    private val secondName = "b-${UUID.randomUUID().toString().take(6)}.db"
    private val staged = mutableListOf<File>()
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        a = ObservationJournal(context, firstName, { 777L })
        b = ObservationJournal(context, secondName, { 888L })
    }
    @After fun cleanup() {
        run { a.close(); b.close() }
        worker.shutdownNow()
        context.deleteDatabase(firstName); context.deleteDatabase(secondName)
        staged.forEach { it.delete() }
        File(context.filesDir, "journal_recovery").listFiles()?.forEach { it.delete() }
    }
    private fun input(kind: String, wall: Long) = ObservationInput(UUID.randomUUID().toString(), kind,
        "synthetic_archive_fixture", "process", ObservationTime(wall, wall, "boot", "epoch"), "{}", "fixture_only")
    private fun archive(): File = File.createTempFile("archive-", ".fixture", context.cacheDir).also {
        staged.add(it); it.outputStream().use(a::writeArchive)
    }
    private fun restore(file: File, beforeCommit: (() -> Unit)? = null) = b.restoreArchive(file,
        ObservationTime(20000, 20000, "boot", "restored-epoch"), "new-process", beforeCommit = beforeCommit)
    private fun snapshot(store: ObservationJournal) = store.listeningSnapshot(0, 100000, "UTC")

    @Test fun roundTripRetainsIdsSequenceConfidenceAndCapturedTimesWithoutPromotion() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        val rows = a.readAfter(0)
        val decoded = mutableListOf<JournalObservation>()
        val file = archive()
        val summary = file.inputStream().use { JournalArchive.read(it, observation = decoded::add) }
        assertEquals(rows, decoded)
        assertEquals(2L, summary.count)
        assertEquals(AttributionConfidence.UNKNOWN, decoded.first().input.confidence)
    }
    @Test fun restoreClosesOpenIntervalAtLastEvidenceAndSurvivesReopenWithRecovery() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_STARTED", 5000))
        b.append(input("PLAYBACK_STARTED", 9000)); b.append(input("PLAYBACK_PAUSED", 12000))
        val previous = b.readAfter(0)
        val source = b.stats()["sourceId"]
        val file = archive()
        val restored = restore(file)
        assertEquals(4000L, snapshot(b)["unverifiedMs"])
        assertEquals(0L, snapshot(b)["confirmedMs"])
        assertEquals(a.readAfter(0), b.readAfter(0).take(2))
        assertEquals("COLLECTION_GAP", b.lastObservation()!!.input.kind)
        b.close(); b = ObservationJournal(context, secondName)
        assertEquals(4000L, snapshot(b)["unverifiedMs"])
        val recovery = b.recoveryArchive(restored["recoveryId"] as String)
        restore(recovery)
        assertEquals(source, b.stats()["sourceId"])
        assertEquals(previous, b.readAfter(0).take(2))
        assertEquals(3000L, snapshot(b)["unverifiedMs"])
    }
    @Test fun repeatedRestoreIsIdempotentAndDoesNotAddGapsOrRecoveryCopies() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        val file = archive()
        restore(file)
        val stats = b.stats()
        val copies = b.recoveryArchives()
        assertEquals(true, restore(file)["unchanged"])
        assertEquals(stats, b.stats())
        assertEquals(copies, b.recoveryArchives())
    }
    @Test fun failureImmediatelyBeforeCommitRollsBackSourceRowsCursorAndProjection() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        b.append(input("PLAYBACK_STARTED", 9000)); b.append(input("PLAYBACK_PAUSED", 12000))
        b.acknowledge("fixture", 2)
        val original = b.stats(); val rows = b.readAfter(0)
        assertThrows(IllegalStateException::class.java) { restore(archive()) { throw IllegalStateException("synthetic crash") } }
        assertEquals(original, b.stats()); assertEquals(rows, b.readAfter(0)); assertEquals(2L, b.cursor("fixture"))
        b.close(); b = ObservationJournal(context, secondName)
        assertEquals(3000L, snapshot(b)["unverifiedMs"])
    }
    @Test fun cancellationAfterFirstImportedRowRollsBackTheWholeReplacement() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        b.append(input("PLAYBACK_STARTED", 9000)); b.append(input("PLAYBACK_PAUSED", 12000))
        val original = b.stats(); val rows = b.readAfter(0)
        var checksAfterBackup = 0
        val canceled = {
            val retained = File(context.filesDir, "journal_recovery").listFiles()?.any { it.extension == "eartime" } == true
            retained && ++checksAfterBackup > 3
        }
        assertThrows(ArchiveCancelled::class.java) { b.restoreArchive(archive(),
            ObservationTime(20000, 20000, "boot", "epoch"), "process", canceled) }
        assertEquals(original, b.stats()); assertEquals(rows, b.readAfter(0))
    }
    @Test @Config(sdk = [28]) fun largeArchiveRestoresEveryPageWithoutTruncatingTotals() = run {
        repeat(1500) { session ->
            a.append(input("PLAYBACK_STARTED", session * 40L + 1))
            a.append(input("PLAYBACK_PAUSED", session * 40L + 11))
        }
        val file = archive()
        val result = restore(file)
        assertEquals(3000L, result["count"])
        assertEquals(15000L, snapshot(b)["unverifiedMs"])
        assertEquals(1500, snapshot(b)["intervalCount"])
        assertEquals(3001L, b.stats()["observationCount"])
        var cursor = 0L
        var count = 0
        while (true) {
            val page = b.readAfter(cursor)
            if (page.isEmpty()) break
            assertTrue(page.size <= 128)
            count += page.size; cursor = page.last().sequence
        }
        assertEquals(3001, count)
    }
    @Test fun corruptionTruncationFutureSchemaAndTrailingContentAreRejectedWithoutMutation() = run {
        a.append(input("PLAYBACK_STARTED", 1000))
        b.append(input("PLAYBACK_PAUSED", 3000))
        val original = b.stats()
        val text = archive().readText()
        val mutations = listOf(text.dropLast(20), text.replace("fixture_only", "altered"),
            text.replace("\"version\":1", "\"version\":2"), text + "{}\n")
        mutations.forEach { invalid ->
            val file = File.createTempFile("bad-", ".fixture", context.cacheDir).also { staged.add(it); it.writeText(invalid) }
            assertThrows(Exception::class.java) { restore(file) }
            assertEquals(original, b.stats())
        }
    }
    @Test fun cancellationRetainsSourceAndIncompleteExportCannotBeAccepted() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        val original = b.stats()
        assertThrows(ArchiveCancelled::class.java) { b.restoreArchive(archive(),
            ObservationTime(20000, 20000, "boot", "epoch"), "process", { true }) }
        assertEquals(original, b.stats())
        val output = ByteArrayOutputStream()
        var checks = 0
        assertThrows(ArchiveCancelled::class.java) { a.writeArchive(output) { ++checks > 2 } }
        assertThrows(Exception::class.java) { JournalArchive.read(ByteArrayInputStream(output.toByteArray())) }
        Unit
    }
    @Test fun conflictingSameSourceNeverOverwritesCommittedObservation() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        val valid = archive()
        restore(valid)
        val original = b.stats()
        val rows = a.readAfter(0).map { if (it.sequence == 1L) it.copy(input = it.input.copy(kind = "PLAYBACK_PAUSED")) else it }
        val conflict = File.createTempFile("conflict-", ".fixture", context.cacheDir).also { staged.add(it) }
        conflict.outputStream().use { JournalArchive.write(it, rows.first().sourceId, 2, { after -> rows.filter { row -> row.sequence > after } }) }
        assertThrows(IllegalArgumentException::class.java) { restore(conflict) }
        assertEquals(original, b.stats())
    }
    @Test fun restoreRefusesAnUnknownFutureProjectionInsteadOfDeletingIt() = run {
        a.append(input("PLAYBACK_PAUSED", 1000)); b.append(input("PLAYBACK_PAUSED", 2000))
        android.database.sqlite.SQLiteDatabase.openDatabase(context.getDatabasePath(secondName).path, null,
            android.database.sqlite.SQLiteDatabase.OPEN_READWRITE).use { it.execSQL("UPDATE listening_projection SET version = 99") }
        val original = b.stats(); val rows = b.readAfter(0)
        assertThrows(IllegalStateException::class.java) { restore(archive()) }
        assertEquals(original, b.stats()); assertEquals(rows, b.readAfter(0))
    }
    @Test fun concurrentAppendDoesNotEnterExportPastItsDeclaredCutoff() = run {
        a.append(input("PLAYBACK_STARTED", 1000)); a.append(input("PLAYBACK_PAUSED", 5000))
        val output = ByteArrayOutputStream()
        val source = a.stats()["sourceId"] as String
        JournalArchive.write(output, source, 2, { after ->
            if (after == 0L) a.append(input("PLAYBACK_STARTED", 9000))
            a.readAfter(after)
        })
        val summary = JournalArchive.read(ByteArrayInputStream(output.toByteArray()))
        assertEquals(2L, summary.count); assertEquals(3L, a.stats()["lastSequence"])
    }
    @Test fun oversizedSingleLineAndInvalidUtf8AreRejectedWithBoundedParsing() = run {
        assertThrows(IllegalArgumentException::class.java) { JournalArchive.read(ByteArrayInputStream(("x".repeat(524289) + "\n").toByteArray())) }
        assertThrows(Exception::class.java) { JournalArchive.read(ByteArrayInputStream(byteArrayOf(0xc3.toByte(), 0x28))) }
        Unit
    }
    @Test fun deepOrAmbiguousJsonIsRejectedBeforeTheRecursiveObjectParser() = run {
        val nested = "{\"nested\":".repeat(1000) + "0" + "}".repeat(1000) + "\n"
        assertThrows(IllegalArgumentException::class.java) { JournalArchive.read(ByteArrayInputStream(nested.toByteArray())) }
        assertThrows(IllegalArgumentException::class.java) { JournalArchive.read(ByteArrayInputStream("{\"x\":1,\"x\":2}\n".toByteArray())) }
        Unit
    }
    @Test fun restoreDoesNotChangePreferencesAndRecoveryIdentifiersCannotTraversePaths() = run {
        ListeningPreferences(context).update(mapOf("themeMode" to "dark", "dailyGoalMinutes" to 45))
        try {
            a.append(input("PLAYBACK_PAUSED", 1000)); restore(archive())
            assertEquals(45, ListeningPreferences(context).snapshot()["dailyGoalMinutes"])
            assertEquals("dark", ListeningPreferences(context).snapshot()["themeMode"])
            assertThrows(IllegalArgumentException::class.java) { b.recoveryArchive("../outside") }
        } finally { ListeningPreferences(context).update(mapOf("themeMode" to "system", "dailyGoalMinutes" to 0)) }
        Unit
    }
}
