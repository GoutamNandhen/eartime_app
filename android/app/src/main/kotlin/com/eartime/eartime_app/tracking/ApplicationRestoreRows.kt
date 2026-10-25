package com.eartime.eartime_app.tracking

import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.nio.charset.CodingErrorAction

/** Callbacks run before the footer: callers that write must own a rollback/recovery boundary. */
internal object ApplicationRestoreRows {
    fun read(file: File, cancelled: () -> Boolean = { false }, row: (JSONObject) -> Unit): Long {
        require(file.length() in 1..(128L * 1024 * 1024))
        val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
        BufferedReader(InputStreamReader(file.inputStream(), decoder)).use { reader ->
            var bytes = 0L
            fun next(): JSONObject {
                val text = StringBuilder()
                while (true) {
                    val value = reader.read(); require(value >= 0) { "Truncated application rows" }
                    check(++bytes <= 128L * 1024 * 1024) { "Application row work limit exceeded" }
                    if (value == 10) break
                    require(text.length < 524288); text.append(value.toChar())
                }
                return JournalArchive.validatedObject(text.toString())
            }
            val header = next()
            require(header.getString("record") == "header" && header.get("version") == 1)
            val legacy = header.has("present")
            if (legacy) require(header.get("present") is Boolean && header.get("schema") == 1)
            var count = 0L
            while (true) {
                if (cancelled()) throw ArchiveCancelled()
                val value = next()
                if (value.getString("record") == "footer") {
                    val expected = value.get("count"); require(expected is Int || expected is Long)
                    require((expected as Number).toLong() == count && reader.read() == -1)
                    return count
                }
                require(++count <= JournalArchive.MAX_RECORDS && (!legacy || header.getBoolean("present")))
                row(value)
            }
        }
    }
}
