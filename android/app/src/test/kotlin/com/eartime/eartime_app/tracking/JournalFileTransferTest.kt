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
@Config(sdk = [28, 35], manifest = Config.NONE, application = Application::class, shadows = [DirectoryFsyncShadow::class])
class JournalFileTransferTest {
    @Test fun applicationRestoreUsesRealDocumentWorkerAndRetainsApplicationRecovery() {
        DirectoryFsyncShadow.resetFixture()
        org.robolectric.shadows.ShadowSQLiteConnection.setDefaultJournalMode("DELETE")
        org.robolectric.shadows.ShadowSQLiteConnection.setDefaultSyncMode("FULL")
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val activity = controller.get()
        val archive = java.io.File.createTempFile("restore-document-", ".eartimeapp", activity.cacheDir)
        val fixture = java.util.concurrent.Executors.newSingleThreadExecutor()
        val transfer = JournalFileTransfer(activity)
        val sourceName = "doc-${java.util.UUID.randomUUID().toString().take(6)}.db"
        val result = CompletableFuture<Map<String, Any?>>()
        try {
            fixture.submit {
                android.database.sqlite.SQLiteDatabase.openOrCreateDatabase(ApplicationArchive.legacyFile(activity), null).use {
                    it.version = 1
                    it.execSQL("CREATE TABLE ear_time_events(id TEXT PRIMARY KEY NOT NULL,canonical_device_id TEXT NOT NULL,device_name TEXT NOT NULL,connection_type TEXT NOT NULL,event_type TEXT NOT NULL,playback_state TEXT,timestamp INTEGER NOT NULL)")
                    it.execSQL("INSERT INTO ear_time_events VALUES ('synthetic','synthetic-device','Synthetic device','bluetooth','PLAYBACK_STARTED',NULL,1000)")
                }
                activity.getSharedPreferences("eartime_preferences_v1", 0).edit().putString("themeMode", "dark").commit()
                ObservationJournal(activity, sourceName).use { it.writeApplicationArchive(archive) }
                activity.getSharedPreferences("eartime_preferences_v1", 0).edit().putString("themeMode", "light").commit()
                android.database.sqlite.SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(activity).path, null, 0).use {
                    it.execSQL("DELETE FROM ear_time_events")
                }
            }.get(20, TimeUnit.SECONDS)
            NativeJournalRuntime.initialize(activity)
            val uri = Uri.parse("content://synthetic-application-restore/document")
            shadowOf(activity.contentResolver).registerInputStream(uri, ByteArrayInputStream(archive.readBytes()))
            transfer.select("restoreApp", { result.complete(it) }, { result.completeExceptionally(IllegalStateException(it)) })
            assertEquals(Intent.ACTION_OPEN_DOCUMENT, shadowOf(activity).nextStartedActivityForResult.intent.action)
            transfer.onActivityResult(JournalFileTransfer.REQUEST_CODE, Activity.RESULT_OK, Intent().setData(uri))
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(20)
            while (!result.isDone && System.nanoTime() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                try { result.get(10, TimeUnit.MILLISECONDS) } catch (_: TimeoutException) { }
            }
            val value = result.get(1, TimeUnit.SECONDS)
            assertEquals("application_data", value["scope"]); assertEquals(false, value["unchanged"])
            assertEquals(1L, value["legacyCount"])
            assertEquals("dark", activity.getSharedPreferences("eartime_preferences_v1", 0).getString("themeMode", null))
            val page = ApplicationRecoveryCatalog.page(activity, 0)
            val item = (page["items"] as List<*>).filterIsInstance<Map<*, *>>().single { it["scope"] == "application_data" }
            val recovery = ApplicationRecoveryCatalog.file(activity, "application_data", item["id"] as String)
            assertEquals(0L, recovery.inputStream().use { ApplicationArchive.read(it) }.legacy)
            android.database.sqlite.SQLiteDatabase.openDatabase(ApplicationArchive.legacyFile(activity).path, null,
                android.database.sqlite.SQLiteDatabase.OPEN_READONLY).use {
                assertEquals(1, it.rawQuery("SELECT id FROM ear_time_events", null).use { rows -> rows.count })
            }
        } finally {
            transfer.close(); fixture.shutdownNow(); archive.delete(); controller.pause().stop().destroy()
            NativeJournalRuntime::class.java.getDeclaredField("ingress").also { field ->
                field.isAccessible = true; (field.get(NativeJournalRuntime) as? NativeObservationIngress)?.close()
                field.set(NativeJournalRuntime, null)
            }
            activity.deleteDatabase("eartime_observations.sqlite"); activity.deleteDatabase(sourceName)
            android.database.sqlite.SQLiteDatabase.deleteDatabase(ApplicationArchive.legacyFile(activity))
        }
    }

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
