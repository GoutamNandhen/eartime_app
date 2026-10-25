package com.eartime.eartime_app.tracking

import android.content.ContentValues
import android.content.Context
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.util.AtomicFile
import android.system.Os
import android.system.OsConstants
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

internal class ApplicationRecoveryRequired(cause: Throwable) :
    IllegalStateException("Application recovery required; prior data and recovery archive retained", cause)

/** Worker-owned recoverable transaction. Native SQLite commits LAST; never changes journal modes. */
internal class ApplicationRestoreCoordinator(private val context: Context, private val journal: ObservationJournal) {
    private val db get() = journal.applicationDatabase()
    private val intent get() = AtomicFile(File(context.filesDir, "application-restore.intent"))
    private val recoveryDirectory get() = File(context.filesDir, "application_recovery")
    private val markerKey = "application_restore_commit_v1"

    private fun syncDirectory(directory: File) {
        check(directory.isDirectory)
        val descriptor = Os.open(directory.path, OsConstants.O_RDONLY, 0)
        try { Os.fsync(descriptor) } finally { Os.close(descriptor) }
    }

    private fun durable(connection: SQLiteDatabase) {
        val mode = connection.rawQuery("PRAGMA journal_mode", null).use { it.moveToFirst(); it.getString(0).lowercase() }
        val sync = connection.rawQuery("PRAGMA synchronous", null).use { it.moveToFirst(); it.getInt(0) }
        check(mode in setOf("wal", "delete", "persist", "truncate") && sync >= 2) {
            "Application restore requires durable SQLite journaling and FULL synchronization (mode=$mode sync=$sync)"
        }
    }

    private data class Prepared(val operation: String, val input: String, val recovery: String,
        val recoveryHash: String, val target: String) {
        fun json() = JSONObject().put("version", 1).put("operation", operation).put("input", input)
            .put("recovery", recovery).put("recoveryHash", recoveryHash).put("target", target)
        val marker get() = "$operation:$input"
    }

    private fun readIntent(): Prepared? {
        val file = intent
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) return null
        val bytes = file.openRead().use { input ->
            val buffer = ByteArray(4097); var count = 0
            while (count < buffer.size) { val n = input.read(buffer, count, buffer.size - count); if (n < 0) break; count += n }
            require(count in 1..4096); buffer.copyOf(count)
        }
        val value = JournalArchive.validatedObject(String(bytes, Charsets.UTF_8))
        require(value.keys().asSequence().toSet() == setOf("version", "operation", "input", "recovery", "recoveryHash", "target"))
        require(value.get("version") == 1)
        val prepared = Prepared(value.getString("operation"), value.getString("input"), value.getString("recovery"),
            value.getString("recoveryHash"), value.getString("target"))
        for (id in listOf(prepared.operation, prepared.recovery)) require(UUID.fromString(id).toString() == id)
        for (hash in listOf(prepared.input, prepared.recoveryHash)) require(Regex("[0-9a-f]{64}").matches(hash))
        require(prepared.target == File(db.path).name) { "Recovery target mismatch" }
        return prepared
    }

    private fun prepare(value: Prepared) {
        val file = intent
        val stream = file.startWrite()
        try {
            stream.write(value.json().toString().toByteArray(Charsets.UTF_8)); stream.fd.sync()
            file.finishWrite(stream)
            syncDirectory(context.filesDir)
        } catch (error: Throwable) { file.failWrite(stream); throw error }
        check(readIntent() == value) { "Application recovery intent could not be verified" }
    }

    private fun committed(value: Prepared): Boolean = db.rawQuery(
        "SELECT value FROM journal_metadata WHERE key=?", arrayOf(markerKey),
    ).use { it.moveToFirst() && it.getString(0) == value.marker }

    /** Must run before normal queries/publication, including on an already-running worker. */
    fun recover(): Boolean {
        try {
            val prepared = readIntent() ?: return false
            check(!db.inTransaction()) { "Recovery cannot run inside a transaction" }
            if (!committed(prepared)) {
                val file = File(recoveryDirectory, "${prepared.recovery}.eartimeapp")
                ApplicationArchive.stage(context, file).use { old ->
                    require(old.summary.sha256 == prepared.recoveryHash) { "Recovery archive checksum changed" }
                    val preferences = ApplicationRestorePreferences.read(old.component("preferences.json"), false)
                    old.verify()
                    applyLegacy(old.component("legacy.jsonl"))
                    preferences.apply(context)
                }
            }
            intent.delete()
            syncDirectory(context.filesDir)
            check(readIntent() == null) { "Application recovery intent cleanup failed" }
            return true
        } catch (error: Exception) { throw ApplicationRecoveryRequired(error) }
    }

    private fun applyLegacy(file: File, cancelled: () -> Boolean = { false }) {
        val target = ApplicationArchive.legacyFile(context)
        require(target.isFile) { "Initialize preserved history through Drift before restore" }
        val corruption = DatabaseErrorHandler { throw SQLiteException("Preserved legacy corruption; original retained") }
        val mode = SQLiteDatabase.openDatabase(target.path, null, SQLiteDatabase.OPEN_READONLY, corruption).use { source ->
            source.rawQuery("PRAGMA journal_mode", null).use { it.moveToFirst(); it.getString(0).lowercase() }
        }
        val flags = SQLiteDatabase.OPEN_READWRITE or if (mode == "wal") SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING else 0
        SQLiteDatabase.openDatabase(target.path, null, flags, corruption).use { legacy ->
            require(legacy.version == 1)
            legacy.rawQuery("PRAGMA table_info(ear_time_events)", null).use { columns ->
                val names = mutableSetOf<String>()
                while (columns.moveToNext()) names.add(columns.getString(columns.getColumnIndexOrThrow("name")))
                require(names == ApplicationArchive.legacyColumns.toSet())
            }
            legacy.execSQL("PRAGMA synchronous=FULL")
            durable(legacy)
            check(mode == legacy.rawQuery("PRAGMA journal_mode", null).use { it.moveToFirst(); it.getString(0).lowercase() }) {
                "Preserved history journal mode changed; restore refused"
            }
            legacy.beginTransaction()
            try {
                legacy.delete("ear_time_events", null, null)
                ApplicationRestoreRows.read(file, cancelled) { row ->
                    require(row.getString("record") == "event")
                    legacy.insertOrThrow("ear_time_events", null, ContentValues().apply {
                        ApplicationArchive.legacyColumns.forEach { key ->
                            if (key == "timestamp") put(key, row.getLong(key))
                            else if (row.isNull(key)) { require(key == "playback_state"); putNull(key) }
                            else put(key, row.getString(key))
                        }
                    })
                }
                if (cancelled()) throw ArchiveCancelled()
                legacy.setTransactionSuccessful()
            } finally { legacy.endTransaction() }
        }
    }

    private fun legacyDigest(file: File, cancelled: () -> Boolean): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        ApplicationRestoreRows.read(file, cancelled) { row ->
            // Fixed column ordering, not input object-key ordering or absent-vs-empty metadata.
            val values = ApplicationArchive.legacyColumns.associateWith { JournalJson.toValue(row.get(it)) }
            digest.update((JournalJson.encode(values) + "\n").toByteArray(Charsets.UTF_8))
        }
        return digest.digest()
    }

    private fun faults(file: File, lastSequence: Long, apply: Boolean, cancelled: () -> Boolean): Boolean {
        var unchanged = true
        val ids = mutableSetOf<String>(); val consumers = mutableSetOf<String>()
        ApplicationRestoreRows.read(file, cancelled) { row ->
            if (row.getString("record") == "cursor") {
                require(consumers.add(row.getString("consumer")) && row.getLong("sequence") <= lastSequence)
                // Exported cursors are diagnostics, not authority to skip this process's replay.
            } else {
                require(row.getString("record") == "fault" && ids.add(row.getString("faultId")))
                val exists = db.rawQuery("SELECT observation_id,reason,detected_utc_ms FROM journal_faults WHERE fault_id=?",
                    arrayOf(row.getString("faultId"))).use { cursor ->
                    if (!cursor.moveToFirst()) false else {
                        require(cursor.getString(0) == row.getString("observationId") && cursor.getString(1) == row.getString("reason") &&
                            cursor.getLong(2) == row.getLong("detectedUtcMs")) { "Conflicting diagnostic evidence" }; true
                    }
                }
                if (!exists) {
                    unchanged = false
                    if (apply) db.insertOrThrow("journal_faults", null, ContentValues().apply {
                        put("fault_id", row.getString("faultId")); put("observation_id", row.getString("observationId"))
                        put("reason", row.getString("reason")); put("detected_utc_ms", row.getLong("detectedUtcMs"))
                    })
                }
            }
        }
        return unchanged
    }

    fun restore(file: File, time: ObservationTime, generation: String, cancelled: () -> Boolean = { false },
        checkpoint: (String) -> Unit = {}): Map<String, Any?> {
        recover()
        check(!db.inTransaction())
        durable(db)
        ApplicationArchive.stage(context, file, cancelled).use { incoming ->
            val preferences = ApplicationRestorePreferences.read(incoming.component("preferences.json"), true).preserveDeliveryEvidence(context)
            val inspected = journal.inspectArchive(incoming.component("native.jsonl"), cancelled)
            val sameFaults = faults(incoming.component("journal_state.jsonl"), inspected.summary.lastSequence, false, cancelled)
            require(ApplicationArchive.legacyFile(context).isFile) { "Initialize preserved history through Drift before restore" }
            val prior = File.createTempFile("restore-prior-", ".eartimeapp", context.cacheDir)
            try {
                journal.writeApplicationArchive(prior, cancelled)
                ApplicationArchive.stage(context, prior, cancelled).use { old ->
                    val sameLegacy = MessageDigest.isEqual(legacyDigest(incoming.component("legacy.jsonl"), cancelled),
                        legacyDigest(old.component("legacy.jsonl"), cancelled))
                    if (inspected.unchanged && sameFaults && sameLegacy && preferences.equivalent(context))
                        return incoming.summary.wire() + ("unchanged" to true)
                    incoming.verify(cancelled); old.verify(cancelled)
                    val id = UUID.randomUUID().toString()
                    check(recoveryDirectory.isDirectory || recoveryDirectory.mkdirs())
                    syncDirectory(context.filesDir)
                    val recovery = File(recoveryDirectory, "$id.eartimeapp")
                    FileOutputStream(recovery).use { out ->
                        prior.inputStream().use { input ->
                            val buffer = ByteArray(16384)
                            while (true) { if (cancelled()) throw ArchiveCancelled(); val count = input.read(buffer); if (count < 0) break; out.write(buffer, 0, count) }
                        }; out.fd.sync()
                    }
                    val saved = recovery.inputStream().use { ApplicationArchive.read(it, cancelled) }
                    require(saved == old.summary)
                    syncDirectory(recoveryDirectory)
                    val prepared = Prepared(UUID.randomUUID().toString(), incoming.summary.sha256, id, saved.sha256, File(db.path).name)
                    prepare(prepared)
                    try {
                        checkpoint("prepared")
                        db.beginTransaction()
                        try {
                            journal.restoreArchive(incoming.component("native.jsonl"), time, generation, cancelled)
                            checkpoint("native_staged")
                            applyLegacy(incoming.component("legacy.jsonl"), cancelled)
                            checkpoint("legacy_committed")
                            preferences.apply(context) { checkpoint("before_$it") }
                            checkpoint("preferences_committed")
                            incoming.verify(cancelled)
                            faults(incoming.component("journal_state.jsonl"), inspected.summary.lastSequence, true, cancelled)
                            if (inspected.unchanged) journal.append(ObservationInput(UUID.randomUUID().toString(), "COLLECTION_GAP",
                                "application_restore", generation, time, JournalJson.encode(mapOf("reason" to "user_restored_application",
                                    "continuityProven" to false)), "local_application_restore"))
                            db.insertWithOnConflict("journal_metadata", null, ContentValues().apply {
                                put("key", markerKey); put("value", prepared.marker)
                            }, SQLiteDatabase.CONFLICT_REPLACE)
                            if (cancelled()) throw ArchiveCancelled()
                            checkpoint("before_native_commit")
                            db.setTransactionSuccessful()
                        } finally { db.endTransaction() }
                        checkpoint("native_committed")
                        recover()
                        return incoming.summary.wire() + mapOf("unchanged" to false, "recoveryId" to id)
                    } catch (error: Exception) {
                        val won = committed(prepared)
                        recover()
                        if (won) return incoming.summary.wire() + mapOf("unchanged" to false, "recoveryId" to id)
                        throw error
                    }
                }
            } finally { prior.delete() }
        }
    }
}
