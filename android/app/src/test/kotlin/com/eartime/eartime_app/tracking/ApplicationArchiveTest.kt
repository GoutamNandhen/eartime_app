package com.eartime.eartime_app.tracking

import android.app.Application
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.*
import java.security.DigestOutputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class ApplicationArchiveTest {
    private lateinit var context: Context
    private lateinit var journal: ObservationJournal
    private val worker = Executors.newSingleThreadExecutor()
    private val name = "app-${UUID.randomUUID().toString().take(6)}.db"
    private val files = mutableListOf<File>()
    private fun <T> run(work: () -> T): T = try { worker.submit(Callable { work() }).get() }
        catch (error: ExecutionException) { throw error.cause ?: error }
    @Before fun setup() { context = RuntimeEnvironment.getApplication(); journal = ObservationJournal(context, name, { 777L }) }
    @After fun cleanup() {
        run { journal.close() }; worker.shutdownNow(); context.deleteDatabase(name)
        files.forEach { it.delete() }; ApplicationArchive.legacyFile(context).delete()
    }
    private fun input(id: String = UUID.randomUUID().toString(), wall: Long = 1000) = ObservationInput(id,
        "PLAYBACK_STARTED", "synthetic_application_export", "process", ObservationTime(wall, wall, "boot", "epoch"), "{}", "fixture_only")
    private fun file() = File.createTempFile("application-", ".fixture", context.cacheDir).also { files.add(it) }
    private fun export(cancelled: () -> Boolean = { false }) = file().also { journal.writeApplicationArchive(it, cancelled) }
    private fun parts(file: File): List<Pair<String, ByteArray>> = DataInputStream(file.inputStream()).use { stream ->
        stream.skipBytes("EARTIME_APPLICATION_ARCHIVE_1\n".length)
        List(5) { val name = stream.readUTF(); val size = stream.readLong(); stream.skipBytes(32)
            val bytes = ByteArray(size.toInt()); stream.readFully(bytes); name to bytes }
    }
    private fun bundle(parts: List<Pair<String, ByteArray>>): ByteArray {
        val result = ByteArrayOutputStream(); val sha = MessageDigest.getInstance("SHA-256")
        val stream = DataOutputStream(DigestOutputStream(result, sha))
        stream.writeBytes("EARTIME_APPLICATION_ARCHIVE_1\n")
        parts.forEach { (name, bytes) -> stream.writeUTF(name); stream.writeLong(bytes.size.toLong())
            stream.write(MessageDigest.getInstance("SHA-256").digest(bytes)); stream.write(bytes) }
        stream.flush(); result.write(sha.digest()); return result.toByteArray()
    }
    private fun legacy(version: Int = 1) {
        SQLiteDatabase.openOrCreateDatabase(ApplicationArchive.legacyFile(context), null).use { db ->
            db.execSQL("CREATE TABLE ear_time_events (id TEXT PRIMARY KEY NOT NULL, canonical_device_id TEXT NOT NULL, device_name TEXT NOT NULL, connection_type TEXT NOT NULL, event_type TEXT NOT NULL, playback_state TEXT, timestamp INTEGER NOT NULL)")
            db.version = version
            for ((index, id) in listOf("synthetic", "\uE000", "\uD800\uDC00").withIndex()) {
                db.execSQL("INSERT INTO ear_time_events VALUES (?, 'synthetic-legacy-device', 'Synthetic preserved device', 'bluetooth', 'PLAYBACK_STARTED', NULL, ?)", arrayOf<Any>(id, index.toLong()))
            }
        }
    }
    @Test fun exportsAllApplicationComponentsWithoutChangingSourcePreferencesOrLegacyHistory() = run {
        legacy()
        val original = input(); journal.append(original); journal.acknowledge("application-export", 1)
        assertThrows(ObservationConflict::class.java) { journal.append(input(original.id, 2000)) }
        ListeningPreferences(context).update(mapOf("themeMode" to "dark", "dailyGoalMinutes" to 45,
            "deviceNames" to mapOf("00000000-0000-4000-8000-000000000001" to "Synthetic alias")))
        context.getSharedPreferences("eartime_summary_delivery_v1", 0).edit().putLong("dailyHighWater", 1234).commit()
        val rows = journal.readAfter(0); val prefs = ListeningPreferences(context).snapshot(); val stats = journal.stats()
        val legacyBytes = ApplicationArchive.legacyFile(context).readBytes()
        val archive = export(); val summary = archive.inputStream().use { ApplicationArchive.read(it) }
        assertEquals(1L, summary.observations); assertEquals(3L, summary.legacy)
        val components = parts(archive).toMap()
        assertEquals(5, components.size)
        val decoded = mutableListOf<JournalObservation>()
        JournalArchive.read(ByteArrayInputStream(components.getValue("native.jsonl")), observation = decoded::add)
        assertEquals(rows, decoded)
        val settings = JSONObject(String(components.getValue("preferences.json"), Charsets.UTF_8)).getJSONObject("stores")
        assertTrue(settings.getJSONArray("eartime_preferences_v1").toString().contains("Synthetic alias"))
        assertTrue(settings.getJSONArray("eartime_summary_delivery_v1").toString().contains("dailyHighWater"))
        val state = String(components.getValue("journal_state.jsonl"), Charsets.UTF_8)
        assertTrue(state.contains("observation_id_payload_conflict")); assertTrue(state.contains("application-export"))
        assertEquals(rows, journal.readAfter(0)); assertEquals(prefs, ListeningPreferences(context).snapshot())
        assertEquals(stats, journal.stats()); assertArrayEquals(legacyBytes, ApplicationArchive.legacyFile(context).readBytes())
        assertArrayEquals(archive.readBytes(), export().readBytes())
    }
    @Test fun absentLegacyIsExplicitAndDoesNotCreateOrPromoteAHistoryDatabase() = run {
        journal.append(input())
        val archive = export()
        assertFalse(ApplicationArchive.legacyFile(context).exists())
        assertTrue(String(parts(archive).toMap().getValue("legacy.jsonl"), Charsets.UTF_8).contains("\"present\":false"))
        assertEquals(0L, archive.inputStream().use { ApplicationArchive.read(it) }.legacy)
        assertEquals(0L, journal.listeningSnapshot(0, 10000, "UTC")["confirmedMs"])
    }
    @Test fun futureLegacySchemaAndUnexpectedTablesFailWithoutChangingAnyOriginal() = run {
        legacy(2); journal.append(input()); val rows = journal.readAfter(0)
        val original = ApplicationArchive.legacyFile(context).readBytes(); val destination = file()
        assertThrows(IllegalArgumentException::class.java) { journal.writeApplicationArchive(destination) }
        assertFalse(destination.exists()); assertArrayEquals(original, ApplicationArchive.legacyFile(context).readBytes())
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.version = 1; it.execSQL("CREATE TABLE unrecognized (value TEXT)")
        }
        assertThrows(IllegalArgumentException::class.java) { export() }
        assertEquals(rows, journal.readAfter(0))
    }
    @Test fun cancellationDuringCaptureDeletesOnlyItsGeneratedTemporaryOutput() = run {
        repeat(30) { journal.append(input(wall = 1000L + it)) }
        val before = journal.readAfter(0); var checks = 0; val destination = file()
        assertThrows(ArchiveCancelled::class.java) { journal.writeApplicationArchive(destination) { ++checks > 15 } }
        assertTrue(checks > 15); assertFalse(destination.exists()); assertEquals(before, journal.readAfter(0))
        assertFalse(context.cacheDir.listFiles()!!.any { it.name.startsWith("application-export-") })
    }
    @Test fun corruptLegacyCannotTriggerAndroidDefaultCorruptionDeletion() = run {
        val file = ApplicationArchive.legacyFile(context)
        val bytes = ByteArray(4096) { (it % 251).toByte() }; file.writeBytes(bytes)
        assertThrows(Exception::class.java) { export() }
        assertTrue(file.exists()); assertArrayEquals(bytes, file.readBytes())
        assertEquals(0L, journal.stats()["lastSequence"])
    }
    @Test fun sqliteLikeTableNamesCannotHideUnexportedUserData() = run {
        legacy()
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("CREATE TABLE sqliteXhistory (value TEXT)")
        }
        assertThrows(IllegalArgumentException::class.java) { export() }
        Unit
    }
    @Test fun truncationDamageTrailingBytesAndReorderedComponentsAreRejected() = run {
        val archive = export(); val bytes = archive.readBytes(); val entries = parts(archive)
        for (bad in listOf(bytes.copyOf(bytes.size - 1), bytes + byteArrayOf(1), bytes.copyOf().also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() },
            bundle(entries.drop(1) + entries.first()), bundle(entries.dropLast(1)))) {
            assertThrows(Exception::class.java) { ApplicationArchive.read(ByteArrayInputStream(bad)) }
        }
    }
    @Test fun futureSchemasDuplicateJsonAndFalseCountsFailEvenWithRecomputedChecksums() = run {
        val entries = parts(export())
        val invalidManifest = entries.map { (name, bytes) -> name to if (name == "manifest.json") String(bytes, Charsets.UTF_8).replace("\"version\":1", "\"version\":2").toByteArray() else bytes }
        val duplicate = entries.map { (name, bytes) -> name to if (name == "preferences.json") String(bytes, Charsets.UTF_8).replaceFirst("\"version\":1", "\"version\":1,\"version\":1").toByteArray() else bytes }
        val count = entries.map { (name, bytes) -> name to if (name == "legacy.jsonl") String(bytes, Charsets.UTF_8).replace("\"count\":0", "\"count\":\"0\"").toByteArray() else bytes }
        for (invalid in listOf(invalidManifest, duplicate, count)) {
            assertThrows(Exception::class.java) { ApplicationArchive.read(ByteArrayInputStream(bundle(invalid))) }
        }
    }
    @Test fun hostileLengthsFailBeforeAllocatingOrReadingAComponent() = run {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).apply { writeBytes("EARTIME_APPLICATION_ARCHIVE_1\n"); writeUTF("manifest.json"); writeLong(Long.MAX_VALUE); flush() }
        assertThrows(IllegalArgumentException::class.java) { ApplicationArchive.read(ByteArrayInputStream(bytes.toByteArray())) }
        Unit
    }
    @Test fun exportRunsThroughTheActualSerializedNativeIngressOwner() {
        val database = "own-${UUID.randomUUID().toString().take(6)}.db"
        val ingress = NativeObservationIngress(context, {}, {}, database)
        val destination = file()
        try {
            ingress.submit(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to 1000L))
            val result = CompletableFuture<Map<String, Any?>>()
            ingress.exportApplication(destination, { false }, { result.complete(it) }, { result.completeExceptionally(IllegalStateException(it)) })
            val value = result.get(10, TimeUnit.SECONDS)
            assertEquals("application_data", value["scope"])
            assertEquals(2L, value["count"])
            val rows = mutableListOf<JournalObservation>()
            JournalArchive.read(ByteArrayInputStream(parts(destination).toMap().getValue("native.jsonl")), observation = rows::add)
            assertEquals(listOf("COLLECTION_STARTED", "PLAYBACK_STARTED"), rows.map { it.input.kind })
            assertTrue(rows.all { it.input.confidence == AttributionConfidence.UNKNOWN })
        } finally { ingress.close(); context.deleteDatabase(database) }
    }
    @Test @Config(sdk = [28]) fun largeLegacyAndNativeExportsRetainAllRowsBeyondEverySourcePage() = run {
        legacy()
        SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(context).path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            db.beginTransaction()
            try {
                repeat(1200) { index ->
                    db.execSQL("INSERT INTO ear_time_events VALUES (?, 'synthetic-device', 'Synthetic', 'bluetooth', 'PLAYBACK_STARTED', NULL, ?)",
                        arrayOf<Any>("synthetic-row-${index.toString().padStart(4, '0')}", index.toLong()))
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        repeat(1001) { journal.append(input(wall = 1000L + it)) }
        val archive = export()
        val value = archive.inputStream().use { ApplicationArchive.read(it) }
        assertEquals(1001L, value.observations); assertEquals(1203L, value.legacy)
        assertEquals(1001L, journal.stats()["lastSequence"])
        assertEquals(0L, journal.listeningSnapshot(0, 100000, "UTC")["confirmedMs"])
    }
}
