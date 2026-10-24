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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class)
class JournalFileTransferTest {
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
