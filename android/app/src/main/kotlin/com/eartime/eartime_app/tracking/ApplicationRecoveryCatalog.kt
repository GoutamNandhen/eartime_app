package com.eartime.eartime_app.tracking

import android.content.Context
import java.io.File
import java.util.UUID

/** Filesystem-only catalog remains available even when journal startup/recovery is blocked. */
internal object ApplicationRecoveryCatalog {
    private val scopes = mapOf("native_observations_only" to ("journal_recovery" to "eartime"),
        "application_data" to ("application_recovery" to "eartimeapp"))
    fun file(context: Context, scope: String, id: String): File {
        require(UUID.fromString(id).toString() == id)
        val (name, extension) = scopes.getValue(scope)
        val directory = File(context.filesDir, name).canonicalFile
        return File(directory, "$id.$extension").canonicalFile.also {
            require(it.parentFile == directory && it.isFile) { "Recovery archive unavailable" }
        }
    }
    fun page(context: Context, offset: Int): Map<String, Any?> {
        require(offset in 0..1000000)
        val entries = scopes.flatMap { (scope, location) ->
            val (name, extension) = location
            File(context.filesDir, name).listFiles()?.mapNotNull { candidate ->
                if (candidate.extension != extension) null else runCatching {
                    val id = candidate.nameWithoutExtension
                    file(context, scope, id) to scope
                }.getOrNull()
            } ?: emptyList()
        }.sortedWith(compareByDescending<Pair<File, String>> { it.first.lastModified() }.thenBy { it.first.name })
        return mapOf("items" to entries.drop(offset).take(20).map { (file, scope) ->
            mapOf("id" to file.nameWithoutExtension, "createdUtcMs" to file.lastModified(), "bytes" to file.length(), "scope" to scope)
        }, "hasMore" to (offset + 20 < entries.size), "nextOffset" to minOf(offset + 20, entries.size))
    }
}
