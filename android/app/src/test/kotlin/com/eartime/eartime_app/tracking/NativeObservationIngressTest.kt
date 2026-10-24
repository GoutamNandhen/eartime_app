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
    @Test fun observerCaptureSourceAndHealthAcknowledgmentAreDurableWithoutConfirmedListening() {
        val context = RuntimeEnvironment.getApplication()
        val name = "o-${UUID.randomUUID().toString().take(8)}.db"
        android.provider.Settings.Global.putInt(context.contentResolver, android.provider.Settings.Global.BOOT_COUNT, 7)
        val published = CopyOnWriteArrayList<Map<String, Any?>>()
        val ingress = NativeObservationIngress(context, published::add, {}, name)
        fun submit(phase: String): Boolean {
            val future = CompletableFuture<Boolean>()
            ingress.submitObserver(mapOf("type" to "COLLECTOR_STATUS", "timestamp" to System.currentTimeMillis(),
                "contractVersion" to 1, "generation" to 1L, "continuityEpoch" to "fixture-epoch",
                "state" to phase, "leaseMs" to 15000L, "deviceListenerRegistered" to true,
                "activityObservationReady" to true, "sampleSucceeded" to true),
                android.os.SystemClock.elapsedRealtime(), future::complete)
            return future.get(20, TimeUnit.SECONDS)
        }
        try {
            assertTrue("Startup acknowledgment needs a synthetic known boot", submit("STARTING"))
            assertTrue("Healthy acknowledgment must follow durable initialization", submit("HEALTHY"))
            val result = page(ingress)
            val rows = (result["observations"] as List<*>).drop(1).map { it as Map<*, *> }
            assertEquals(2, rows.size)
            assertTrue(rows.all { it["collector"] == CollectorHealth.SOURCE && it["confidence"] == "UNKNOWN" })
            assertTrue(rows.all { it["provenance"] == "supported_audio_api_sample_wall_and_elapsed" })
            assertEquals(2, published.size)
            assertTrue(submit("STOPPED")); assertFalse(submit("HEALTHY"))
            val snapshot = CompletableFuture<Map<String, Any?>>()
            ingress.readListening(System.currentTimeMillis() - 86400000, System.currentTimeMillis() + 1000, "UTC", 0, 100, snapshot::complete,
                { snapshot.completeExceptionally(IllegalStateException(it)) })
            val projected = snapshot.get(20, TimeUnit.SECONDS)
            assertEquals(0L, projected["confirmedMs"])
            assertEquals("CONTINUITY_LOST", (projected["collectorHealth"] as Map<*, *>)["state"])
        } finally { ingress.close(); context.deleteDatabase(name) }
    }
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
