package com.eartime.eartime_app.tracking

import android.app.Application
import android.database.sqlite.SQLiteDatabase
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE, application = Application::class)
class NativeObservationIngressTest {
    private fun page(ingress: NativeObservationIngress): Map<String, Any?> {
        val future = CompletableFuture<Map<String, Any?>>()
        ingress.readPage(0, 128, future::complete, { future.completeExceptionally(IllegalStateException(it)) })
        return future.get(20, TimeUnit.SECONDS)
    }

    @Test fun flutterAbsentCollectionCommitsBeforePublishingAndSurvivesReopen() {
        val context = RuntimeEnvironment.getApplication()
        val name = "i-${UUID.randomUUID().toString().take(8)}.db"
        val published = CopyOnWriteArrayList<Map<String, Any?>>()
        val failures = CopyOnWriteArrayList<String>()
        var ingress = NativeObservationIngress(context, { event ->
            val identity = event["journal"] as Map<*, *>
            SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READONLY).use { reader ->
                reader.rawQuery("SELECT COUNT(*) FROM observations WHERE observation_id = ?",
                    arrayOf(identity["observationId"] as String)).use {
                    assertTrue(it.moveToFirst())
                    assertEquals("Publication must follow a commit visible to another connection", 1L, it.getLong(0))
                }
                reader.rawQuery("SELECT sequence FROM listening_projection WHERE singleton = 1", null).use {
                    assertTrue(it.moveToFirst())
                    assertEquals("Projection must commit before publication", identity["sequence"], it.getLong(0))
                }
            }
            published.add(event)
        }, failures::add, name)
        try {
            ingress.submit(mapOf("type" to "DEVICE_CONNECTED", "timestamp" to 1000L,
                "device" to mapOf("id" to "legacy-name_8")))
            ingress.submit(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to 1000L))
            val before = page(ingress)
            assertTrue(failures.toString(), failures.isEmpty())
            assertEquals(3L, before["observationCount"])
            assertEquals(2, published.size)
            val firstMetadata = published[0]["journal"] as Map<*, *>
            val secondMetadata = published[1]["journal"] as Map<*, *>
            assertNotEquals(firstMetadata["observationId"], secondMetadata["observationId"])
            assertEquals("UNKNOWN", firstMetadata["confidence"])
            assertEquals(2L, firstMetadata["sequence"])
            assertEquals(3L, secondMetadata["sequence"])
            ingress.close()
            ingress = NativeObservationIngress(context, published::add, failures::add, name)
            val recovered = page(ingress)
            assertEquals(before["sourceId"], recovered["sourceId"])
            assertEquals(4L, recovered["observationCount"])
            assertEquals(1L, recovered["gapCount"])
            // Reopening the journal does not replay old events through a new live EventSink.
            assertEquals(2, published.size)
            val observations = recovered["observations"] as List<*>
            assertEquals("COLLECTION_GAP", (observations.last() as Map<*, *>)["kind"])
        } finally {
            ingress.close()
            context.deleteDatabase(name)
        }
    }

    @Test fun deliveryFailureDoesNotTurnCommittedHistoryIntoACollectionGap() {
        val context = RuntimeEnvironment.getApplication()
        val name = "d-${UUID.randomUUID().toString().take(8)}.db"
        val failures = CopyOnWriteArrayList<String>()
        val ingress = NativeObservationIngress(context, { throw IllegalStateException("sink gone") }, failures::add, name)
        try {
            ingress.submit(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to 1000L))
            page(ingress)
            ingress.submit(mapOf("type" to "PLAYBACK_PAUSED", "timestamp" to 2000L))
            val result = page(ingress)
            assertEquals(3L, result["observationCount"]); assertEquals(0L, result["gapCount"])
            assertTrue(failures.any { it.contains("delivery failed") })
        } finally { ingress.close(); context.deleteDatabase(name) }
    }

    @Test fun malformedNativeEventRecordsGapBeforeLaterValidObservation() {
        val context = RuntimeEnvironment.getApplication()
        val name = "m-${UUID.randomUUID().toString().take(8)}.db"
        val ingress = NativeObservationIngress(context, {}, {}, name)
        try {
            ingress.submit(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to "invalid"))
            page(ingress)
            ingress.submit(mapOf("type" to "PLAYBACK_STARTED", "timestamp" to 2000L))
            val result = page(ingress)
            assertEquals(1L, result["gapCount"])
            val rows = result["observations"] as List<*>
            val kinds = rows.map { (it as Map<*, *>)["kind"] }
            assertTrue(kinds.indexOf("COLLECTION_GAP") < kinds.indexOf("PLAYBACK_STARTED"))
        } finally { ingress.close(); context.deleteDatabase(name) }
    }
}
