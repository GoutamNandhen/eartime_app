package com.eartime.eartime_app.tracking

import org.json.JSONObject
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import java.util.UUID
import android.util.JsonReader
import android.util.JsonToken
import java.io.StringReader

class ArchiveCancelled : IllegalStateException("Journal transfer canceled")
data class JournalArchiveSummary(val sourceId: String, val lastSequence: Long, val count: Long, val sha256: String) {
    fun toWire(): Map<String, Any?> = mapOf("sourceId" to sourceId, "lastSequence" to lastSequence,
        "count" to count, "sha256" to sha256, "scope" to "native_observations_only", "version" to 1)
}

/** Streaming, bounded, plaintext archive. SHA-256 detects damage, not authenticity. */
object JournalArchive {
    const val MAX_BYTES = 128L * 1024 * 1024
    const val MAX_RECORDS = 200000L
    private const val MAX_LINE = 524288
    private fun digest() = MessageDigest.getInstance("SHA-256")
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
    private fun uuid(value: String): String { require(UUID.fromString(value).toString() == value); return value }
    private fun json(text: String): JSONObject {
        // Bound nesting before JSONObject's recursive parser sees untrusted document bytes.
        var nodes = 0
        JsonReader(StringReader(text)).use { reader ->
            fun value(depth: Int) {
                require(depth <= 16 && ++nodes <= 16384) { "Archive structure exceeds bound" }
                when (reader.peek()) {
                    JsonToken.BEGIN_OBJECT -> {
                        val keys = mutableSetOf<String>()
                        reader.beginObject()
                        while (reader.hasNext()) { require(keys.add(reader.nextName())) { "Duplicate archive key" }; value(depth + 1) }
                        reader.endObject()
                    }
                    JsonToken.BEGIN_ARRAY -> { reader.beginArray(); while (reader.hasNext()) value(depth + 1); reader.endArray() }
                    JsonToken.STRING -> { require(reader.nextString().length <= 65536) }
                    JsonToken.NUMBER -> { require(reader.nextString().toDouble().isFinite()) }
                    JsonToken.BOOLEAN -> reader.nextBoolean()
                    JsonToken.NULL -> reader.nextNull()
                    else -> throw IllegalArgumentException("Invalid archive JSON")
                }
            }
            require(reader.peek() == JsonToken.BEGIN_OBJECT)
            value(0)
            require(reader.peek() == JsonToken.END_DOCUMENT)
        }
        return JSONObject(text)
    }
    private fun number(map: JSONObject, key: String): Long {
        val value = map.get(key)
        require(value is Int || value is Long) { "Invalid archive integer" }
        return (value as Number).toLong()
    }

    fun write(output: OutputStream, sourceId: String, lastSequence: Long,
        readPage: (Long) -> List<JournalObservation>, cancelled: () -> Boolean = { false }): JournalArchiveSummary {
        uuid(sourceId); require(lastSequence >= 0)
        val checksum = digest()
        var bytes = 0L
        fun line(map: Map<String, Any?>, hashed: Boolean = true) {
            if (cancelled()) throw ArchiveCancelled()
            val text = JournalJson.encode(map)
            require(text.length <= MAX_LINE)
            val data = (text + "\n").toByteArray(Charsets.UTF_8)
            bytes += data.size
            require(bytes <= MAX_BYTES) { "Archive exceeds size limit" }
            output.write(data)
            if (hashed) checksum.update(data)
        }
        line(mapOf("record" to "header", "format" to "eartime.native_journal", "version" to 1,
            "journalSchema" to 3, "scope" to "native_observations_only", "sourceId" to sourceId, "lastSequence" to lastSequence))
        var after = 0L
        var count = 0L
        while (after < lastSequence) {
            if (cancelled()) throw ArchiveCancelled()
            val page = readPage(after).takeWhile { it.sequence <= lastSequence }
            check(page.isNotEmpty()) { "Archive source changed or truncated" }
            page.forEach {
                require(it.sourceId == sourceId && it.sequence > after && ++count <= MAX_RECORDS)
                line(it.toWire() + ("record" to "observation"))
                after = it.sequence
            }
        }
        val hash = hex(checksum.digest())
        line(mapOf("record" to "footer", "count" to count, "lastSequence" to after, "sha256" to hash), false)
        output.flush()
        return JournalArchiveSummary(sourceId, after, count, hash)
    }

    /** Callback may run before the footer is verified: consumers must stage or use a rollback transaction. */
    fun read(input: InputStream, cancelled: () -> Boolean = { false },
        observation: (JournalObservation) -> Unit = {}): JournalArchiveSummary {
        val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val reader = java.io.BufferedReader(java.io.InputStreamReader(input, decoder))
        val checksum = digest()
        var bytes = 0L
        fun line(): String? {
            if (cancelled()) throw ArchiveCancelled()
            val text = StringBuilder()
            while (true) {
                val c = reader.read()
                if (c == -1) { require(text.isEmpty()) { "Truncated archive line" }; return null }
                if (c == 10) break
                require(c != 13 && text.length < MAX_LINE) { "Invalid or oversized archive line" }
                text.append(c.toChar())
            }
            bytes += text.toString().toByteArray(Charsets.UTF_8).size + 1
            require(bytes <= MAX_BYTES) { "Archive exceeds size limit" }
            return text.toString()
        }
        fun hashed(text: String) { checksum.update((text + "\n").toByteArray(Charsets.UTF_8)) }
        val headerText = requireNotNull(line()) { "Missing archive header" }
        val header = json(headerText)
        require(header.getString("record") == "header" && header.getString("format") == "eartime.native_journal" &&
            number(header, "version") == 1L && number(header, "journalSchema") == 3L &&
            header.getString("scope") == "native_observations_only") { "Unsupported journal archive" }
        val source = uuid(header.getString("sourceId"))
        val expectedLast = number(header, "lastSequence").also { require(it >= 0) }
        hashed(headerText)
        var after = 0L
        var count = 0L
        while (true) {
            val text = requireNotNull(line()) { "Missing archive footer" }
            val row = json(text)
            when (row.getString("record")) {
                "footer" -> {
                    val hash = hex(checksum.digest())
                    require(number(row, "count") == count && number(row, "lastSequence") == after &&
                        after == expectedLast && row.getString("sha256") == hash && line() == null) { "Archive integrity check failed" }
                    return JournalArchiveSummary(source, after, count, hash)
                }
                "observation" -> {
                    require(++count <= MAX_RECORDS) { "Archive exceeds record limit" }
                    require(row.getString("sourceId") == source) { "Archive source mismatch" }
                    val sequence = number(row, "sequence")
                    require(sequence > after && sequence <= expectedLast)
                    val elapsed = if (row.isNull("elapsedMs")) null else number(row, "elapsedMs")
                    val inputRow = ObservationInput(uuid(row.getString("observationId")), row.getString("kind"),
                        row.getString("collector").also { require(it.length <= 128) },
                        row.getString("processGeneration").also { require(it.length <= 128) },
                        ObservationTime(number(row, "wallUtcMs"), elapsed,
                            if (row.isNull("bootId")) null else row.getString("bootId").also { require(it.length <= 128) },
                            row.getString("collectionEpoch").also { require(it.length <= 128) }),
                        row.getJSONObject("payload").toString(), row.getString("provenance").also { require(it.length <= 256) },
                        AttributionConfidence.valueOf(row.getString("confidence")),
                        number(row, "payloadVersion").also { require(it in 1..Int.MAX_VALUE) }.toInt())
                    hashed(text)
                    observation(JournalObservation(source, sequence, inputRow, number(row, "committedUtcMs")))
                    after = sequence
                }
                else -> throw IllegalArgumentException("Unknown archive record")
            }
        }
    }
}
