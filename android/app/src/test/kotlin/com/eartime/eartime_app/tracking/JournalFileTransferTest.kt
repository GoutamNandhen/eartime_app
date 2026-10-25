package com.eartime.eartime_app.tracking

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.net.Uri
import android.os.Looper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class JournalFileTransferTest {
    @Test fun applicationExportWritesVerifiedDocument() {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val activity = controller.get()
        val transfer = JournalFileTransfer(activity)
        val result = CompletableFuture<Map<String, Any?>>()
        val output = ByteArrayOutputStream()
        val uri = Uri.parse("content://synthetic-application-export/document")
        NativeJournalRuntime.initialize(activity)
        shadowOf(activity.contentResolver).registerOutputStream(uri, output)
        try {
            transfer.select("exportApp", { result.complete(it) }, { result.completeExceptionally(IllegalStateException(it)) })
            assertEquals(Intent.ACTION_CREATE_DOCUMENT, shadowOf(activity).nextStartedActivityForResult.intent.action)
            transfer.onActivityResult(JournalFileTransfer.REQUEST_CODE, Activity.RESULT_OK, Intent().setData(uri))
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(15)
            while (!result.isDone && System.nanoTime() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                try { result.get(10, TimeUnit.MILLISECONDS) } catch (_: TimeoutException) { }
            }
            val value = result.get(1, TimeUnit.SECONDS)
            val decoded = ApplicationArchive.read(ByteArrayInputStream(output.toByteArray()))
            assertEquals(decoded.wire(), value)
            assertEquals(1L, decoded.observations)
        } finally {
            transfer.close(); controller.pause().stop().destroy()
            // Runtime is process-scoped in production; retire this fixture's real worker between tests.
            NativeJournalRuntime::class.java.getDeclaredField("ingress").also { field ->
                field.isAccessible = true; (field.get(NativeJournalRuntime) as NativeObservationIngress).close()
                field.set(NativeJournalRuntime, null)
            }
            activity.deleteDatabase("eartime_observations.sqlite")
        }
    }
    @Test fun applicationExportHasAnExplicitDistinctDocumentTypeAndCancelsWithoutMutation() {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val transfer = JournalFileTransfer(controller.get())
        var result: Map<String, Any?>? = null
        try {
            transfer.select("exportApp", { result = it }, { fail(it) })
            val request = shadowOf(controller.get()).nextStartedActivityForResult
            assertEquals(Intent.ACTION_CREATE_DOCUMENT, request.intent.action)
            assertEquals("EarTime-application.eartimeapp", request.intent.getStringExtra(Intent.EXTRA_TITLE))
            transfer.onActivityResult(request.requestCode, Activity.RESULT_CANCELED, null)
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(true, result!!["cancelled"])
        } finally { transfer.close(); controller.pause().stop().destroy() }
    }
    @Test fun exportUsesUserCreateDocumentAndCancelDoesNotStartIoOrAssumeSuccess() {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val activity = controller.get()
        val transfer = JournalFileTransfer(activity)
        var result: Map<String, Any?>? = null
        try {
            transfer.select("export", { result = it }, { fail(it) })
            val request = shadowOf(activity).nextStartedActivityForResult
            assertEquals(Intent.ACTION_CREATE_DOCUMENT, request.intent.action)
            assertEquals("application/octet-stream", request.intent.type)
            assertTrue(request.intent.hasCategory(Intent.CATEGORY_OPENABLE))
            transfer.onActivityResult(request.requestCode, Activity.RESULT_CANCELED, null)
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(true, result!!["cancelled"])
        } finally { transfer.close(); controller.pause().stop().destroy() }
    }
    @Test fun restoreRejectsNonContentProviderAndDuplicateActivityResults() {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val transfer = JournalFileTransfer(controller.get())
        var failures = 0
        try {
            transfer.select("restore", { fail("No restore expected") }, { failures++ })
            val data = Intent().setData(Uri.parse("file:///untrusted.eartime"))
            transfer.onActivityResult(JournalFileTransfer.REQUEST_CODE, Activity.RESULT_OK, data)
            transfer.onActivityResult(JournalFileTransfer.REQUEST_CODE, Activity.RESULT_OK, data)
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(1, failures)
        } finally { transfer.close(); controller.pause().stop().destroy() }
    }
    @Test fun retiredActivityIgnoresDelayedPickerResultWithoutStartingAWorker() {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val transfer = JournalFileTransfer(controller.get())
        transfer.select("restore", { fail("Retired callback") }, { fail(it) })
        transfer.close()
        assertTrue(transfer.onActivityResult(JournalFileTransfer.REQUEST_CODE, Activity.RESULT_OK,
            Intent().setData(Uri.parse("content://test/archive"))))
        shadowOf(Looper.getMainLooper()).idle()
        controller.pause().stop().destroy()
    }
}
