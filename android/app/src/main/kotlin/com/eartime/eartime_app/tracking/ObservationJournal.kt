package com.eartime.eartime_app.tracking

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.database.sqlite.SQLiteOpenHelper
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.UUID

data class ObservationInput(
    val id: String,
    val kind: String,
    val collector: String,
    val processGeneration: String,
    val time: ObservationTime,
    val payloadJson: String,
    val provenance: String = "legacy_collector_wall_and_broker_receipt_elapsed",
    val confidence: AttributionConfidence = AttributionConfidence.UNKNOWN,
    val payloadVersion: Int = 1,
) {
    init {
        require(UUID.fromString(id).toString() == id)
        require(kind.isNotBlank() && kind.length <= 128 && collector.isNotBlank() && processGeneration.isNotBlank())
        require(payloadVersion > 0 && payloadJson.toByteArray(Charsets.UTF_8).size <= MAX_PAYLOAD_BYTES)
    }
    companion object { const val MAX_PAYLOAD_BYTES = 65536 }
}

data class JournalObservation(
    val sourceId: String,
    val sequence: Long,
    val input: ObservationInput,
    val committedUtcMs: Long,
) {
    fun metadata(): Map<String, Any?> = mapOf(
        "observationId" to input.id, "sourceId" to sourceId, "sequence" to sequence,
        "collector" to input.collector, "processGeneration" to input.processGeneration,
        "collectionEpoch" to input.time.collectionEpoch, "bootId" to input.time.bootId,
        "wallUtcMs" to input.time.wallUtcMs, "elapsedMs" to input.time.elapsedMs,
        "provenance" to input.provenance, "confidence" to input.confidence.name,
        "payloadVersion" to input.payloadVersion, "committedUtcMs" to committedUtcMs,
    )

    fun toWire(): Map<String, Any?> = metadata() + ("payload" to
        JournalJson.toValue(JSONObject(input.payloadJson))) + ("kind" to input.kind)
}

class ObservationConflict(val observationId: String) : IllegalStateException("Conflicting observation ID: $observationId")

/** The only owner of eartime_observations.sqlite; all calls run on the ingress worker. */
class ObservationJournal(
    context: Context,
    databaseName: String = "eartime_observations.sqlite",
    private val commitClock: () -> Long = System::currentTimeMillis,
) : AutoCloseable {
    private val preferences = ListeningPreferences(context)
    private val helper = object : SQLiteOpenHelper(
        context.applicationContext, databaseName, null, 3,
        DatabaseErrorHandler { throw SQLiteException("Journal corruption; original database retained") },
    ) {
        override fun onConfigure(db: SQLiteDatabase) {
            db.setForeignKeyConstraintsEnabled(true)
            db.execSQL("PRAGMA synchronous=FULL")
        }

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE journal_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)")
            db.execSQL("INSERT INTO journal_metadata VALUES ('source_id', ?)", arrayOf(UUID.randomUUID().toString()))
            db.execSQL("""CREATE TABLE observations (
                sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                observation_id TEXT UNIQUE NOT NULL,
                kind TEXT NOT NULL, collector TEXT NOT NULL, process_generation TEXT NOT NULL,
                collection_epoch TEXT NOT NULL, boot_id TEXT, wall_utc_ms INTEGER NOT NULL,
                elapsed_ms INTEGER, payload_version INTEGER NOT NULL CHECK(payload_version > 0),
                payload_json TEXT NOT NULL, provenance TEXT NOT NULL, confidence TEXT NOT NULL,
                fingerprint TEXT NOT NULL, committed_utc_ms INTEGER NOT NULL
            )""")
            db.execSQL("""CREATE TABLE consumer_cursors (
                consumer TEXT PRIMARY KEY NOT NULL, sequence INTEGER NOT NULL CHECK(sequence >= 0)
            )""")
            db.execSQL("""CREATE TABLE journal_faults (
                fault_id TEXT PRIMARY KEY NOT NULL, observation_id TEXT NOT NULL,
                reason TEXT NOT NULL, detected_utc_ms INTEGER NOT NULL
            )""")
            ListeningProjection.create(db)
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion == 1 && newVersion == 3) ListeningProjection.create(db)
            else if (oldVersion == 2 && newVersion == 3) {
                ListeningProjection.createDevices(db)
                db.delete("listening_intervals", null, null)
                db.delete("listening_projection", null, null)
            }
            else throw SQLiteException("Unsupported journal upgrade $oldVersion -> $newVersion; data retained")
        }

        override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            throw SQLiteException("Unsupported journal downgrade $oldVersion -> $newVersion; data retained")
        }
    }

    private fun database(): SQLiteDatabase {
        check(Looper.myLooper() != Looper.getMainLooper()) { "Journal access on Android main thread" }
        return helper.writableDatabase
    }

    private fun sourceId(db: SQLiteDatabase): String = db.rawQuery(
        "SELECT value FROM journal_metadata WHERE key = 'source_id'", null,
    ).use { check(it.moveToFirst()); it.getString(0) }

    /** ID collision and sequence assignment are checked in the same transaction as the insert. */
    fun append(input: ObservationInput, beforeCommit: (() -> Unit)? = null): JournalObservation {
        val db = database()
        catchUpProjection(db)
        val fingerprint = fingerprint(input)
        try {
            return transaction(db) {
                db.rawQuery("SELECT * FROM observations WHERE observation_id = ?", arrayOf(input.id)).use { cursor ->
                    if (cursor.moveToFirst()) {
                        if (cursor.getString(cursor.getColumnIndexOrThrow("fingerprint")) != fingerprint) {
                            throw ObservationConflict(input.id)
                        }
                        return@transaction readRow(cursor, sourceId(db))
                    }
                }
                val committed = commitClock()
                val values = ContentValues().apply {
                    put("observation_id", input.id); put("kind", input.kind); put("collector", input.collector)
                    put("process_generation", input.processGeneration); put("collection_epoch", input.time.collectionEpoch)
                    put("boot_id", input.time.bootId); put("wall_utc_ms", input.time.wallUtcMs)
                    put("elapsed_ms", input.time.elapsedMs); put("payload_version", input.payloadVersion)
                    put("payload_json", input.payloadJson); put("provenance", input.provenance)
                    put("confidence", input.confidence.name); put("fingerprint", fingerprint)
                    put("committed_utc_ms", committed)
                }
                val sequence = db.insertOrThrow("observations", null, values)
                val observation = JournalObservation(sourceId(db), sequence, input, committed)
                ListeningProjection(db).apply(observation)
                beforeCommit?.invoke()
                observation
            }
        } catch (conflict: ObservationConflict) {
            // Separate transaction retains a fault even though the conflicting append rolled back.
            db.insertOrThrow("journal_faults", null, ContentValues().apply {
                put("fault_id", UUID.randomUUID().toString()); put("observation_id", input.id)
                put("reason", "observation_id_payload_conflict"); put("detected_utc_ms", commitClock())
            })
            throw conflict
        }
    }

    fun readAfter(after: Long, limit: Int = 64): List<JournalObservation> {
        require(after >= 0 && limit in 1..128)
        val db = database()
        val source = sourceId(db)
        return db.rawQuery("SELECT * FROM observations WHERE sequence > ? ORDER BY sequence LIMIT ?",
            arrayOf(after.toString(), limit.toString())).use { cursor ->
            buildList { while (cursor.moveToNext()) add(readRow(cursor, source)) }
        }
    }

    fun lastObservation(): JournalObservation? {
        val db = database()
        return db.rawQuery("SELECT * FROM observations ORDER BY sequence DESC LIMIT 1", null).use {
            if (it.moveToFirst()) readRow(it, sourceId(db)) else null
        }
    }

    fun acknowledge(consumer: String, sequence: Long): Long {
        require(Regex("[a-zA-Z0-9_.-]{1,64}").matches(consumer))
        val db = database()
        return transaction(db) {
            require(sequence in 0..lastSequence(db)) { "Cannot acknowledge uncommitted observations" }
            val accepted = maxOf(sequence, cursor(consumer))
            db.insertWithOnConflict("consumer_cursors", null, ContentValues().apply {
                put("consumer", consumer); put("sequence", accepted)
            }, SQLiteDatabase.CONFLICT_REPLACE)
            accepted
        }
    }

    fun cursor(consumer: String): Long = database().rawQuery(
        "SELECT sequence FROM consumer_cursors WHERE consumer = ?", arrayOf(consumer),
    ).use { if (it.moveToFirst()) it.getLong(0) else 0L }

    fun stats(): Map<String, Any?> {
        val db = database()
        return mapOf(
            "sourceId" to sourceId(db), "schemaVersion" to 3, "lastSequence" to lastSequence(db),
            "observationCount" to scalar(db, "SELECT COUNT(*) FROM observations"),
            "conflictCount" to scalar(db, "SELECT COUNT(*) FROM journal_faults"),
            "gapCount" to scalar(db, "SELECT COUNT(*) FROM observations WHERE kind = 'COLLECTION_GAP'"),
        )
    }

    private fun catchUpProjection(db: SQLiteDatabase) {
        val projection = ListeningProjection(db)
        while (projection.cursor() < lastSequence(db)) {
            val batch = readAfter(projection.cursor(), 128)
            check(batch.isNotEmpty())
            transaction(db) { batch.forEach(projection::apply) }
        }
    }

    fun listeningSnapshot(from: Long, until: Long, zoneId: String, now: ObservationTime? = null,
        offset: Int = 0, limit: Int = 100, deviceOffset: Int = 0, healthTime: ObservationTime? = now): Map<String, Any?> {
        val db = database()
        catchUpProjection(db)
        return transaction(db) {
            val result = ListeningProjection(db).snapshot(from, until, zoneId, now, offset, limit, deviceOffset, healthTime)
            val devices = (result["devices"] as List<*>).map { item ->
                val device = item as Map<*, *>
                device + mapOf("observedName" to device["name"],
                    "name" to (preferences.deviceName(device["id"] as String) ?: device["name"]))
            }
            result + mapOf("sourceId" to sourceId(db), "devices" to devices)
        }
    }

    fun rebuildListeningProjection() {
        val db = database()
        transaction(db) { ListeningProjection(db).reset() }
        catchUpProjection(db)
    }

    internal fun observerStatusAcknowledged(generation: Number?, epoch: String?, phase: String?, now: ObservationTime): Boolean {
        val health = ListeningProjection(database()).collectorHealth(now)
        return health["state"] == phase && (health["generation"] as? Number)?.toLong() == generation?.toLong() &&
            health["continuityEpoch"] == epoch
    }

    private fun lastSequence(db: SQLiteDatabase) = scalar(db, "SELECT COALESCE(MAX(sequence), 0) FROM observations")
    private fun scalar(db: SQLiteDatabase, sql: String) = db.rawQuery(sql, null).use { it.moveToFirst(); it.getLong(0) }

    private fun readRow(cursor: Cursor, source: String): JournalObservation {
        fun text(key: String) = cursor.getString(cursor.getColumnIndexOrThrow(key))
        fun number(key: String) = cursor.getLong(cursor.getColumnIndexOrThrow(key))
        fun optionalLong(key: String): Long? {
            val column = cursor.getColumnIndexOrThrow(key)
            return if (cursor.isNull(column)) null else cursor.getLong(column)
        }
        return JournalObservation(source, number("sequence"), ObservationInput(
            id = text("observation_id"), kind = text("kind"), collector = text("collector"),
            processGeneration = text("process_generation"),
            time = ObservationTime(number("wall_utc_ms"), optionalLong("elapsed_ms"), text("boot_id"), text("collection_epoch")),
            payloadJson = text("payload_json"), provenance = text("provenance"),
            confidence = AttributionConfidence.valueOf(text("confidence")), payloadVersion = number("payload_version").toInt(),
        ), number("committed_utc_ms"))
    }

    private fun fingerprint(input: ObservationInput): String {
        val content = JournalJson.encode(mapOf(
            "kind" to input.kind, "collector" to input.collector, "process" to input.processGeneration,
            "epoch" to input.time.collectionEpoch, "boot" to input.time.bootId,
            "wall" to input.time.wallUtcMs, "elapsed" to input.time.elapsedMs,
            "version" to input.payloadVersion, "payload" to JournalJson.toValue(JSONObject(input.payloadJson)),
            "provenance" to input.provenance, "confidence" to input.confidence.name,
        ))
        return MessageDigest.getInstance("SHA-256").digest(content.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    private fun <T> transaction(db: SQLiteDatabase, work: () -> T): T {
        db.beginTransaction()
        try {
            val result = work()
            db.setTransactionSuccessful()
            return result
        } finally { db.endTransaction() }
    }

    override fun close() { helper.close() }
}

/** Structured JSON codec with stable map ordering; never persist mutable collector maps. */
object JournalJson {
    fun encode(value: Map<String, Any?>): String = toJson(value).toString()

    private fun toJson(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> JSONObject().apply {
            value.keys.map { require(it is String); it }.sorted().forEach { put(it, toJson(value[it])) }
        }
        is List<*> -> JSONArray().apply { value.forEach { put(toJson(it)) } }
        is String, is Boolean, is Int, is Long, is Double, is Float -> value
        else -> throw IllegalArgumentException("Unsupported observation payload value")
    }

    fun toValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { toValue(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { toValue(value.get(it)) }
        else -> value
    }

    fun snapshot(event: Map<String, Any?>): Map<String, Any?> {
        var nodes = 0
        var characters = 0
        fun copy(value: Any?, depth: Int): Any? {
            require(depth <= 12 && ++nodes <= 4096) { "Observation structure exceeds bound" }
            return when (value) {
                null, is Boolean, is Int, is Long -> value
                is String -> {
                    characters += value.length
                    require(value.length <= 32768 && characters <= ObservationInput.MAX_PAYLOAD_BYTES)
                    value
                }
                is Double -> { require(value.isFinite()); value }
                is Float -> { require(value.isFinite()); value }
                is Map<*, *> -> value.entries.associate { require(it.key is String)
                    it.key as String to copy(it.value, depth + 1) }
                is List<*> -> value.map { copy(it, depth + 1) }
                else -> throw IllegalArgumentException("Unsupported observation payload value")
            }
        }
        @Suppress("UNCHECKED_CAST")
        return copy(event, 0) as Map<String, Any?>
    }
}
