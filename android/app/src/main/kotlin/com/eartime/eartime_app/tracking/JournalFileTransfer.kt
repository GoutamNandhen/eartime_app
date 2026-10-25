package com.eartime.eartime_app.tracking

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** User-selected documents only. Slow document-provider I/O never runs on the journal or UI worker. */
class JournalFileTransfer(private val activity: Activity) : AutoCloseable {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor { Thread(it, "EarTimeArchive").apply { isDaemon = true } }
    private var pending: Request? = null
    private var closed = false
    private class Request(val mode: String, val success: (Map<String, Any?>) -> Unit, val failure: (String) -> Unit) {
        val cancelled = AtomicBoolean(false)
        var selectionHandled = false
    }

    fun select(mode: String, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        require(mode in setOf("export", "exportApp", "restore", "restoreApp"))
        if (closed || pending != null) { failure("A journal transfer is already active"); return }
        val request = Request(mode, success, failure).also { pending = it }
        try {
            activity.startActivityForResult(Intent(if (mode.startsWith("export")) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
                if (mode.startsWith("export")) putExtra(Intent.EXTRA_TITLE, if (mode == "exportApp") "EarTime-application.eartimeapp" else "EarTime-history.eartime")
            }, REQUEST_CODE)
        } catch (_: Exception) { finish(request, null, "Document picker unavailable") }
    }

    fun restoreRecovery(id: String, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit, application: Boolean = false) {
        if (closed || pending != null) { failure("A journal transfer is already active"); return }
        require(UUID.fromString(id).toString() == id)
        val request = Request(if (application) "restoreApp" else "restore", success, failure).also { it.selectionHandled = true; pending = it }
        executor.execute {
            try {
                val file = ApplicationRecoveryCatalog.file(activity,
                    if (application) "application_data" else "native_observations_only", id)
                file.inputStream().use { if (application) ApplicationArchive.read(it, request.cancelled::get) else JournalArchive.read(it, request.cancelled::get) }
                finish(request, restore(file, request), null)
            } catch (error: Exception) { finish(request,
                if (cancellation(request, error)) mapOf("cancelled" to true) else null,
                if (cancellation(request, error)) null else failureMessage(error)) }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        if (closed) return true
        val request = pending ?: return true
        if (request.selectionHandled) return true
        request.selectionHandled = true
        if (resultCode != Activity.RESULT_OK || data?.data == null) { finish(request, mapOf("cancelled" to true), null); return true }
        val uri = data.data!!
        if (uri.scheme != "content") { finish(request, null, "Unsupported document provider"); return true }
        executor.execute {
            var staged: File? = null
            try {
                val result = if (request.mode == "exportApp") {
                    val file = File.createTempFile("eartime-application-", ".partial", activity.cacheDir).also { staged = it }
                    val summary = await<Map<String, Any?>> { ok, fail -> NativeJournalRuntime.exportApplication(file, request.cancelled::get, ok, fail) }
                    if (request.cancelled.get()) throw ArchiveCancelled()
                    activity.contentResolver.openOutputStream(uri, "w")!!.use { output ->
                        file.inputStream().use { input ->
                            val buffer = ByteArray(16384)
                            while (true) {
                                if (request.cancelled.get()) throw ArchiveCancelled()
                                val count = input.read(buffer); if (count < 0) break
                                output.write(buffer, 0, count)
                            }
                        }
                        output.flush()
                    }
                    summary
                } else if (request.mode == "export") {
                    val info = await<Map<String, Any?>> { ok, fail -> NativeJournalRuntime.readPage(0, 1, ok, fail) }
                    activity.contentResolver.openOutputStream(uri, "w")!!.use { output ->
                        JournalArchive.write(output, info["sourceId"] as String, info["lastSequence"] as Long,
                            { after -> await { ok, fail -> NativeJournalRuntime.archivePage(after, ok, fail) } },
                            request.cancelled::get).toWire()
                    }
                } else {
                    val file = File.createTempFile("eartime-restore-", ".partial", activity.cacheDir).also { staged = it }
                    activity.contentResolver.openInputStream(uri)!!.use { input -> file.outputStream().use { output ->
                        val buffer = ByteArray(16384)
                        var bytes = 0L
                        while (true) {
                            if (request.cancelled.get()) throw ArchiveCancelled()
                            val count = input.read(buffer)
                            if (count < 0) break
                            bytes += count
                            require(bytes <= if (request.mode == "restoreApp") ApplicationArchive.MAX_BYTES else JournalArchive.MAX_BYTES) { "Archive exceeds size limit" }
                            output.write(buffer, 0, count)
                        }
                    } }
                    file.inputStream().use { if (request.mode == "restoreApp") ApplicationArchive.read(it, request.cancelled::get) else JournalArchive.read(it, request.cancelled::get) }
                    restore(file, request)
                }
                finish(request, result, null)
            } catch (error: Exception) {
                finish(request, if (cancellation(request, error)) mapOf("cancelled" to true) else null,
                    if (cancellation(request, error)) null else failureMessage(error))
            } finally { staged?.delete() }
        }
        return true
    }

    private fun restore(file: File, request: Request): Map<String, Any?> = await { ok, fail ->
        if (request.mode == "restoreApp") NativeJournalRuntime.restoreApplication(file, request.cancelled::get, ok, fail)
        else NativeJournalRuntime.restoreArchive(file, request.cancelled::get, ok, fail)
    }

    private fun cancellation(request: Request, error: Exception): Boolean = request.cancelled.get() &&
        generateSequence<Throwable>(error) { it.cause }.take(8).none { it is ApplicationRecoveryRequired || it.message?.contains("ApplicationRecoveryRequired") == true }

    private fun failureMessage(error: Exception): String {
        val messages = generateSequence<Throwable>(error) { it.cause }.take(8).mapNotNull { it.message }.toList()
        return when {
            messages.any { it.contains("ApplicationRecoveryRequired") || it.contains("Application recovery required") } ->
                "Application recovery is required. Prior data and the private recovery archive are retained. Do not delete app data. Retry recovery after checking available storage."
            messages.any { it.contains("Application archive limit") || it.contains("Application metadata exceeds") || it.contains("Application record exceeds") } ->
                "Application export limit exceeded (256 MiB total, 128 MiB per component, 200000 rows per history). Source data was not changed."
            messages.any { it.contains("preserved legacy") || it.contains("Unrecognized legacy") || it.contains("Preserved legacy corruption") } ->
                "Preserved history is damaged or has an unsupported schema. Export was not completed; original data was retained."
            messages.any { it.contains("Conflicting archive history") || it.contains("Archive omits committed") } ->
                "Archive conflicts with existing history from the same source. Nothing was replaced."
            messages.any { it.contains("Archive exceeds") } -> "Archive limit exceeded (128 MiB / 200000 observations). No history was replaced."
            messages.any { it.contains("Unsupported journal archive") } -> "Unsupported archive format or version. No history was replaced."
            messages.any { it.contains("Archive integrity") || it.contains("archive footer") || it.contains("Truncated archive") } ->
                "Archive is damaged or incomplete. No history was replaced."
            else -> "Journal transfer failed. Check the selected file and available storage. No success is assumed; incomplete exports cannot be restored."
        }
    }

    private fun <T> await(start: ((T) -> Unit, (String) -> Unit) -> Unit): T {
        val result = CompletableFuture<T>()
        start({ result.complete(it) }, { result.completeExceptionally(IllegalStateException(it)) })
        // Do not abandon an in-flight restore then delete its staged input. Native row/commit cancellation is cooperative.
        return result.get()
    }

    private fun finish(request: Request, value: Map<String, Any?>?, error: String?) {
        main.post {
            if (pending !== request) return@post
            pending = null
            if (!closed) {
                if (error != null) request.failure(error) else request.success(value ?: emptyMap())
            }
        }
    }

    fun cancel() {
        val request = pending ?: return
        request.cancelled.set(true)
        if (!request.selectionHandled) activity.finishActivity(REQUEST_CODE)
    }

    override fun close() { closed = true; cancel(); executor.shutdown() }
    companion object { const val REQUEST_CODE = 48721 }
}
