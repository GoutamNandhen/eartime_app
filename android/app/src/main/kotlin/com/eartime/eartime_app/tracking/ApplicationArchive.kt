package com.eartime.eartime_app.tracking

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import io.flutter.util.PathUtils
import org.json.JSONObject
import java.io.*
import java.nio.charset.CodingErrorAction
import java.security.DigestInputStream
import java.security.DigestOutputStream
import java.security.MessageDigest
import java.util.UUID

internal data class ApplicationArchiveSummary(val observations: Long, val legacy: Long, val sha256: String) {
    fun wire(): Map<String, Any?> = mapOf("version" to 1, "scope" to "application_data",
        "count" to observations, "legacyCount" to legacy, "componentCount" to 5, "sha256" to sha256)
}

/** Fixed-name, length-delimited components. No paths, decompression, or database file replacement. */
internal object ApplicationArchive {
    const val MAX_BYTES = 256L * 1024 * 1024
    private const val MAX_COMPONENT = 128L * 1024 * 1024
    private val magic = "EARTIME_APPLICATION_ARCHIVE_1\n".toByteArray(Charsets.US_ASCII)
    private val names = listOf("manifest.json", "native.jsonl", "preferences.json", "legacy.jsonl", "journal_state.jsonl")
    internal val stores = listOf("eartime_preferences_v1", "eartime_summary_delivery_v1")
    internal val legacyColumns = listOf("id", "canonical_device_id", "device_name", "connection_type", "event_type", "playback_state", "timestamp")
    private fun digest() = MessageDigest.getInstance("SHA-256")
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
    private fun integer(value: JSONObject, key: String): Long {
        val raw = value.get(key); require(raw is Int || raw is Long); return (raw as Number).toLong()
    }
    internal fun legacyFile(context: Context) = File(PathUtils.getDataDirectory(context), "eartime_db.sqlite")

    private class BoundedOutput(output: OutputStream, private val bound: Long) : FilterOutputStream(output) {
        var bytes = 0L
        override fun write(value: Int) { check(++bytes <= bound) { "Application archive limit exceeded" }; out.write(value) }
        override fun write(buffer: ByteArray, offset: Int, length: Int) {
            bytes += length; check(bytes <= bound) { "Application archive limit exceeded" }; out.write(buffer, offset, length)
        }
    }
    private class PartInput(private val input: InputStream, var remaining: Long) : InputStream() {
        override fun read(): Int {
            if (remaining == 0L) return -1
            val result = input.read(); check(result >= 0) { "Truncated application archive" }; remaining--; return result
        }
        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            if (length == 0) return 0
            if (remaining == 0L) return -1
            val count = input.read(buffer, offset, minOf(length.toLong(), remaining).toInt())
            check(count > 0) { "Truncated application archive" }; remaining -= count; return count
        }
    }
    private fun line(output: OutputStream, value: Map<String, Any?>) {
        val bytes = (JournalJson.encode(value) + "\n").toByteArray(Charsets.UTF_8)
        require(bytes.size <= 524288) { "Application record exceeds limit" }; output.write(bytes)
    }
    private fun objectText(input: InputStream): JSONObject {
        val bytes = input.readBytes()
        require(bytes.size <= 524288) { "Application metadata exceeds limit" }
        val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
        return JournalArchive.validatedObject(decoder.decode(java.nio.ByteBuffer.wrap(bytes)).toString())
    }

    fun write(context: Context, journal: ObservationJournal, output: File,
        diagnostics: (OutputStream) -> Unit, cancelled: () -> Boolean = { false }): ApplicationArchiveSummary {
        val directory = File(context.cacheDir, "application-export-${UUID.randomUUID()}")
        check(directory.mkdir())
        val files = names.associateWith { File(directory, it) }
        try {
            fun component(name: String, block: (OutputStream) -> Unit) {
                if (cancelled()) throw ArchiveCancelled()
                FileOutputStream(files.getValue(name)).use { block(BoundedOutput(it, MAX_COMPONENT)); it.fd.sync() }
            }
            component("manifest.json") { line(it, mapOf("format" to "eartime.application", "version" to 1,
                "journalSchema" to 3, "projectionRebuildVersion" to ListeningProjection.VERSION, "legacySchema" to 1)) }
            component("native.jsonl") { journal.writeArchive(it, cancelled) }
            component("preferences.json") { out ->
                val data = stores.associateWith { name ->
                    context.getSharedPreferences(name, Context.MODE_PRIVATE).all.toSortedMap().map { (key, value) ->
                        require(key.length in 1..256)
                        val type = when (value) {
                            is String -> "string"; is Int -> "int"; is Long -> "long"; is Boolean -> "boolean"
                            is Float -> { require(value.isFinite()); "float" }
                            is Set<*> -> { require(value.all { it is String }); "strings" }
                            else -> error("Unsupported preference value; original data retained")
                        }
                        mapOf("key" to key, "type" to type, "value" to if (value is Set<*>) value.filterIsInstance<String>().sorted() else value)
                    }.also { require(it.size <= 4096) }
                }
                line(out, mapOf("version" to 1, "stores" to data))
            }
            component("legacy.jsonl") { out ->
                val file = legacyFile(context)
                line(out, mapOf("record" to "header", "version" to 1, "present" to file.exists(), "schema" to 1))
                var count = 0L
                if (file.exists()) {
                    SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY,
                        android.database.DatabaseErrorHandler { throw android.database.sqlite.SQLiteException("Preserved legacy corruption; original retained") }).use { db ->
                        require(db.version == 1) { "Unsupported preserved legacy schema; original retained" }
                        db.rawQuery("PRAGMA table_info(ear_time_events)", null).use { columns ->
                            val actual = mutableListOf<String>()
                            while (columns.moveToNext()) actual.add(columns.getString(columns.getColumnIndexOrThrow("name")))
                            require(actual.toSet() == legacyColumns.toSet()) { "Unsupported preserved legacy columns" }
                        }
                        db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT GLOB 'sqlite_*'", null).use { tables ->
                            val actual = mutableSetOf<String>(); while (tables.moveToNext()) actual.add(tables.getString(0))
                            require(actual - "android_metadata" == setOf("ear_time_events")) { "Unrecognized legacy tables; export refused" }
                            if ("android_metadata" in actual) db.rawQuery("PRAGMA table_info(android_metadata)", null).use { columns ->
                                require(columns.count == 1 && columns.moveToFirst() && columns.getString(columns.getColumnIndexOrThrow("name")) == "locale") { "Unsupported Android locale metadata" }
                            }
                        }
                        db.rawQuery("SELECT ${legacyColumns.joinToString(",")} FROM ear_time_events ORDER BY id", null).use { rows ->
                            while (rows.moveToNext()) {
                                if (cancelled()) throw ArchiveCancelled()
                                require(++count <= JournalArchive.MAX_RECORDS)
                                val values = legacyColumns.mapIndexed { index, key ->
                                    key to if (key == "timestamp") {
                                        require(rows.getType(index) == android.database.Cursor.FIELD_TYPE_INTEGER); rows.getLong(index)
                                    } else if (rows.isNull(index)) {
                                        require(key == "playback_state"); null
                                    } else {
                                        require(rows.getType(index) == android.database.Cursor.FIELD_TYPE_STRING)
                                        rows.getString(index).also { require(it.length <= 65536) }
                                    }
                                }.toMap()
                                line(out, values + ("record" to "event"))
                            }
                        }
                    }
                }
                line(out, mapOf("record" to "footer", "count" to count))
            }
            component("journal_state.jsonl", diagnostics)
            FileOutputStream(output).use { raw ->
                val bounded = BoundedOutput(raw, MAX_BYTES)
                val checksum = digest()
                val stream = DataOutputStream(DigestOutputStream(bounded, checksum))
                stream.write(magic)
                for (name in names) {
                    if (cancelled()) throw ArchiveCancelled()
                    val file = files.getValue(name)
                    val hash = file.inputStream().use { input ->
                        val sha = digest(); val buffer = ByteArray(16384)
                        while (true) { if (cancelled()) throw ArchiveCancelled(); val n = input.read(buffer); if (n < 0) break; sha.update(buffer, 0, n) }
                        sha.digest()
                    }
                    stream.writeUTF(name); stream.writeLong(file.length()); stream.write(hash)
                    file.inputStream().use { input ->
                        val buffer = ByteArray(16384)
                        while (true) { if (cancelled()) throw ArchiveCancelled(); val n = input.read(buffer); if (n < 0) break; stream.write(buffer, 0, n) }
                    }
                }
                stream.flush(); bounded.write(checksum.digest()); bounded.flush(); raw.fd.sync()
            }
            return output.inputStream().use { read(it, cancelled) }
        } catch (error: Throwable) { output.delete(); throw error }
        finally { files.values.forEach { it.delete() }; directory.delete() }
    }

    class Staged internal constructor(private val directory: File, val summary: ApplicationArchiveSummary,
        private val checksums: Map<String, ByteArray>) : AutoCloseable {
        fun component(name: String): File { require(name in names); return File(directory, name) }
        fun verify(cancelled: () -> Boolean = { false }) {
            names.forEach { name ->
                val sha = digest()
                component(name).inputStream().use { input ->
                    val buffer = ByteArray(16384)
                    var bytes = 0L
                    while (true) { if (cancelled()) throw ArchiveCancelled(); val count = input.read(buffer); if (count < 0) break
                        bytes += count; require(bytes <= MAX_COMPONENT); sha.update(buffer, 0, count) }
                }
                require(MessageDigest.isEqual(checksums.getValue(name), sha.digest())) { "Staged application component changed" }
            }
        }
        override fun close() { names.forEach { File(directory, it).delete() }; directory.delete() }
    }

    fun stage(context: Context, archive: File, cancelled: () -> Boolean = { false }): Staged {
        val directory = File(context.cacheDir, "application-restore-${UUID.randomUUID()}")
        check(directory.mkdir())
        try {
            val checksums = mutableMapOf<String, ByteArray>()
            val summary = archive.inputStream().use { readComponents(it, cancelled, directory, checksums) }
            return Staged(directory, summary, checksums.toMap())
        } catch (error: Throwable) {
            names.forEach { File(directory, it).delete() }; directory.delete()
            throw error
        }
    }

    fun read(input: InputStream, cancelled: () -> Boolean = { false }): ApplicationArchiveSummary =
        readComponents(input, cancelled, null)

    private fun readComponents(input: InputStream, cancelled: () -> Boolean, directory: File?, checksums: MutableMap<String, ByteArray>? = null): ApplicationArchiveSummary {
        val checksum = digest()
        val hashed = DigestInputStream(input, checksum)
        val stream = DataInputStream(hashed)
        val prefix = ByteArray(magic.size); stream.readFully(prefix)
        require(prefix.contentEquals(magic)) { "Unsupported application archive" }
        var bytes = magic.size.toLong()
        var observations = 0L; var legacy = 0L
        for (name in names) {
            if (cancelled()) throw ArchiveCancelled()
            val nameBytes = name.toByteArray(Charsets.US_ASCII)
            require(stream.readUnsignedShort() == nameBytes.size) { "Invalid application component name length" }
            val actualName = ByteArray(nameBytes.size); stream.readFully(actualName)
            require(actualName.contentEquals(nameBytes)) { "Missing or unordered application component" }
            val length = stream.readLong()
            bytes += 2 + name.length + 8 + 32 + length
            require(length in 1..MAX_COMPONENT && bytes + 32 <= MAX_BYTES) { "Application archive limit exceeded" }
            val expected = ByteArray(32); stream.readFully(expected)
            checksums?.put(name, expected.copyOf())
            val part = PartInput(stream, length)
            val partHash = digest()
            val hashedPart = DigestInputStream(part, partHash)
            val sink = directory?.let { FileOutputStream(File(it, name)) }
            val content = if (sink == null) hashedPart else object : InputStream() {
                override fun read(): Int = hashedPart.read().also { if (it >= 0) sink.write(it) }
                override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
                    hashedPart.read(buffer, offset, length).also { if (it > 0) sink.write(buffer, offset, it) }
            }
            try {
            when (name) {
                "manifest.json" -> {
                    require(length <= 4096)
                    val value = objectText(content)
                    require(value.keys().asSequence().toSet() == setOf("format", "version", "journalSchema", "projectionRebuildVersion", "legacySchema"))
                    require(value.getString("format") == "eartime.application" && value.get("version") == 1 &&
                        value.get("journalSchema") == 3 && value.get("legacySchema") == 1 && value.get("projectionRebuildVersion") == 5) { "Unsupported application schema" }
                }
                "native.jsonl" -> observations = JournalArchive.read(content, cancelled).count
                "preferences.json" -> {
                    require(length <= 524288)
                    val value = objectText(content)
                    require(value.get("version") == 1)
                    val data = value.getJSONObject("stores")
                    require(data.keys().asSequence().toSet() == stores.toSet())
                    stores.forEach { store ->
                        val entries = data.getJSONArray(store); require(entries.length() <= 4096)
                        val keys = mutableSetOf<String>()
                        for (index in 0 until entries.length()) {
                            val entry = entries.getJSONObject(index)
                            require(entry.keys().asSequence().toSet() == setOf("key", "type", "value"))
                            require(entry.getString("key").length in 1..256 && keys.add(entry.getString("key")))
                            val raw = entry.get("value")
                            require(when (entry.getString("type")) {
                                "string" -> raw is String
                                "int" -> raw is Int
                                "long" -> raw is Int || raw is Long
                                "boolean" -> raw is Boolean
                                "float" -> raw is Number && raw.toDouble().isFinite() && raw.toDouble().toFloat().isFinite()
                                "strings" -> raw is org.json.JSONArray && (0 until raw.length()).all { raw.get(it) is String }
                                else -> false
                            })
                        }
                    }
                }
                "legacy.jsonl", "journal_state.jsonl" -> {
                    val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
                    val reader = BufferedReader(InputStreamReader(content, decoder))
                    fun row(): JSONObject {
                        val text = StringBuilder()
                        while (true) { val char = reader.read(); require(char >= 0) { "Truncated component" }; if (char == 10) break
                            require(text.length < 524288); text.append(char.toChar()) }
                        return JournalArchive.validatedObject(text.toString())
                    }
                    val header = row(); require(header.getString("record") == "header" && header.get("version") == 1)
                    val isLegacy = name == "legacy.jsonl"
                    val present = if (isLegacy) { require(header.get("schema") == 1); header.getBoolean("present") } else true
                    var count = 0L
                    var lastId: ByteArray? = null
                    while (true) {
                        if (cancelled()) throw ArchiveCancelled()
                        val item = row()
                        if (item.getString("record") == "footer") {
                            require(integer(item, "count") == count && reader.read() == -1); break
                        }
                        require(present && ++count <= JournalArchive.MAX_RECORDS)
                        if (isLegacy) {
                            require(item.getString("record") == "event")
                            require(item.keys().asSequence().toSet() == (legacyColumns + "record").toSet())
                            val id = item.getString("id").toByteArray(Charsets.UTF_8)
                            val previous = lastId
                            if (previous != null) {
                                val differing = (0 until minOf(previous.size, id.size)).firstOrNull { previous[it] != id[it] }
                                require(if (differing == null) previous.size < id.size else (previous[differing].toInt() and 255) < (id[differing].toInt() and 255))
                            }
                            lastId = id
                            legacyColumns.forEach { key ->
                                val raw = item.get(key)
                                require(if (key == "timestamp") raw is Int || raw is Long else raw is String || key == "playback_state" && raw == JSONObject.NULL)
                            }
                        } else when (item.getString("record")) {
                            "cursor" -> {
                                require(Regex("[a-zA-Z0-9_.-]{1,64}").matches(item.getString("consumer")))
                                require(integer(item, "sequence") >= 0)
                            }
                            "fault" -> {
                                for (key in listOf("faultId", "observationId")) require(UUID.fromString(item.getString(key)).toString() == item.getString(key))
                                require(item.getString("reason").length <= 65536); integer(item, "detectedUtcMs")
                            }
                            else -> error("Unknown journal-state record")
                        }
                    }
                    if (isLegacy) legacy = count
                }
            }
            require(part.remaining == 0L && MessageDigest.isEqual(expected, partHash.digest())) { "Application component integrity failure" }
            sink?.fd?.sync()
            } finally { sink?.close() }
        }
        val hash = checksum.digest()
        hashed.on(false)
        val expected = ByteArray(32); stream.readFully(expected)
        require(MessageDigest.isEqual(hash, expected) && stream.read() == -1) { "Application archive integrity failure" }
        return ApplicationArchiveSummary(observations, legacy, hex(hash))
    }
}
