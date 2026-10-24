package com.eartime.eartime_app.tracking

import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.CompletableFuture

class NativeObservationIngress(
    private val context: Context,
    private val publish: (Map<String, Any?>) -> Unit,
    private val onFailure: (String) -> Unit,
    private val databaseName: String = "eartime_observations.sqlite",
    queueCapacity: Int = 256,
) : AutoCloseable {
    private data class Pending(val event: Map<String, Any?>, val id: String, val time: ObservationTime,
        val collector: String, val completion: (Boolean) -> Unit)
    private val queue = BoundedIngressQueue<Pending>(queueCapacity)
    private val scheduled = AtomicBoolean(false)
    private val rejectedCount = AtomicLong(0)
    private val failedCount = AtomicLong(0)
    private val processGeneration = UUID.randomUUID().toString()
    private val epoch = UUID.randomUUID().toString()
    private val executor = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS,
        ArrayBlockingQueue(32), { task -> Thread(task, "EarTimeJournal").apply { isDaemon = true } })
    private var journal: ObservationJournal? = null
    private var bootId: String? = null
    private var started = false
    private var commitLossCount = 0L
    private var restoreFenceElapsed: Long? = null
    @Volatile private var lastError: String? = null
    private val lifecycleLock = Any()
    @Volatile private var closing = false

    init { command({ ensureStarted(); Unit }, { report(it) }) }

    private fun now(wall: Long = System.currentTimeMillis()) =
        ObservationTime(wall, SystemClock.elapsedRealtime(), bootId, epoch)

    private fun ensureStarted(): ObservationJournal {
        val store = journal ?: ObservationJournal(context, databaseName).also { journal = it }
        if (!started) {
            bootId = if (Build.VERSION.SDK_INT >= 24) try {
                Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)
                    .let { "android-boot-$it" }
            } catch (_: Exception) { null } else null
            val previous = store.lastObservation()
            store.append(ObservationInput(
                UUID.randomUUID().toString(), if (previous == null) "COLLECTION_STARTED" else "COLLECTION_GAP",
                "journal_runtime", processGeneration, now(),
                JournalJson.encode(mapOf(
                    "reason" to if (previous == null) "first_native_journal_collection" else "process_restart_unobserved_gap",
                    "previousObservationId" to previous?.input?.id,
                    "previousWallUtcMs" to previous?.input?.time?.wallUtcMs,
                    "previousCollectionEpoch" to previous?.input?.time?.collectionEpoch,
                    "continuityProven" to false,
                )), "journal_runtime_receipt", AttributionConfidence.UNKNOWN,
            ))
            started = true
        }
        return store
    }

    fun submit(event: Map<String, Any?>) = enqueue(event, "legacy_audio_service", null, {})

    internal fun submitObserver(event: Map<String, Any?>, capturedElapsedMs: Long, completion: (Boolean) -> Unit) =
        enqueue(event, CollectorHealth.SOURCE, capturedElapsedMs, completion)

    private fun complete(pending: Pending, accepted: Boolean) {
        try { pending.completion(accepted) }
        catch (_: Exception) { report("Observation completion callback failed; committed history retained") }
    }

    private fun enqueue(event: Map<String, Any?>, collector: String, capturedElapsedMs: Long?, completion: (Boolean) -> Unit) {
        synchronized(lifecycleLock) {
        if (closing) {
            report("Observation rejected: journal is closing")
            try { completion(false) } catch (_: Exception) { report("Observation rejection callback failed") }
            return
        }
        try {
            val immutable = JournalJson.snapshot(event)
            require(immutable["type"] is String &&
                (immutable["timestamp"] is Long || immutable["timestamp"] is Int))
            if (collector == CollectorHealth.SOURCE) {
                require(immutable["type"] in listOf("COLLECTOR_STATUS", "OUTPUT_EVIDENCE"))
                require(capturedElapsedMs != null && capturedElapsedMs in 0..SystemClock.elapsedRealtime())
            }
            val input = Pending(immutable, UUID.randomUUID().toString(),
                now((immutable["timestamp"] as Number).toLong()).let {
                    if (capturedElapsedMs == null) it else it.copy(elapsedMs = capturedElapsedMs)
                }, collector, completion)
            if (!queue.offer(input, input.time.elapsedMs ?: 0)) {
                rejectedCount.incrementAndGet()
                complete(input, false)
                report("Native observation queue overflow; collection gap will be journaled")
            }
            scheduleDrain()
        } catch (error: Exception) {
            failedCount.incrementAndGet()
            queue.reject(SystemClock.elapsedRealtime())
            scheduleDrain()
            report("Observation rejected: ${error.javaClass.simpleName}")
            try { completion(false) } catch (_: Exception) { report("Observation rejection callback failed") }
        }
        }
    }

    private fun scheduleDrain() {
        if (!queue.hasWork() || !scheduled.compareAndSet(false, true)) return
        try {
            executor.execute {
                try {
                    val store = ensureStarted()
                    var count = 0
                    while (count++ < 32) {
                        when (val entry = queue.poll() ?: break) {
                            is IngressEntry.Gap -> try {
                                store.append(ObservationInput(
                                    UUID.randomUUID().toString(), "COLLECTION_GAP", "journal_runtime", processGeneration, now(),
                                    JournalJson.encode(mapOf("reason" to "ingress_loss", "lostCount" to entry.count,
                                        "firstReceiptElapsedMs" to entry.firstElapsedMs, "lastReceiptElapsedMs" to entry.lastElapsedMs,
                                        "continuityProven" to false)), "journal_runtime_receipt",
                                ))
                            } catch (error: Exception) {
                                commitLossCount += entry.count
                                report("Journal gap commit failed: ${error.javaClass.simpleName}")
                            }
                            is IngressEntry.Observation -> {
                                val pending = entry.value
                                try {
                                    if (commitLossCount > 0) {
                                        store.append(ObservationInput(
                                            UUID.randomUUID().toString(), "COLLECTION_GAP", "journal_runtime", processGeneration,
                                            pending.time.copy(bootId = bootId),
                                            JournalJson.encode(mapOf("reason" to "previous_commit_failure",
                                                "lostCount" to commitLossCount, "continuityProven" to false)), "journal_runtime_receipt",
                                        ))
                                        commitLossCount = 0
                                    }
                                    val committed = store.append(ObservationInput(
                                        pending.id, pending.event["type"] as String, pending.collector,
                                        processGeneration, pending.time.copy(bootId = bootId,
                                            collectionEpoch = if (restoreFenceElapsed?.let { (pending.time.elapsedMs ?: -1) <= it } == true)
                                                "pre-restore-queued-$epoch" else epoch), JournalJson.encode(pending.event),
                                        if (pending.collector == CollectorHealth.SOURCE) "supported_audio_api_sample_wall_and_elapsed" else "legacy_collector_wall_and_broker_receipt_elapsed",
                                    ))
                                    try { publish(pending.event + ("journal" to committed.metadata())) }
                                    catch (error: Exception) { report("Journal delivery failed; committed observation retained: ${error.javaClass.simpleName}") }
                                    val accepted = if (pending.collector == CollectorHealth.SOURCE &&
                                        pending.event["type"] == "COLLECTOR_STATUS")
                                        runCatching { store.observerStatusAcknowledged(pending.event["generation"] as? Number,
                                            pending.event["continuityEpoch"] as? String, pending.event["state"] as? String,
                                            now()) }.getOrDefault(false) else true
                                    complete(pending, accepted)
                                } catch (error: Exception) {
                                    failedCount.incrementAndGet()
                                    commitLossCount++
                                    report("Journal commit failed: ${error.javaClass.simpleName}")
                                    complete(pending, false)
                                }
                            }
                        }
                    }
                } catch (error: Exception) {
                    report("Journal unavailable: ${error.javaClass.simpleName}")
                } finally {
                    scheduled.set(false)
                    // A failed open must not create a busy loop on the worker.
                    if (started && queue.hasWork()) scheduleDrain()
                }
            }
        } catch (_: RejectedExecutionException) {
            scheduled.set(false)
            report("Journal worker request capacity reached")
        }
    }

    fun readPage(after: Long, limit: Int, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        command({
            val store = ensureStarted()
            val stats = store.stats()
            require(after in 0..(stats["lastSequence"] as Long)) { "Replay cursor is outside the current journal" }
            val records = store.readAfter(after, limit)
            stats + health() + mapOf("observations" to records.map { it.toWire() },
                "nextCursor" to (records.lastOrNull()?.sequence ?: after),
                "hasMore" to ((records.lastOrNull()?.sequence ?: after) < stats["lastSequence"] as Long))
        }, failure, success)
    }

    fun acknowledge(sourceId: String, consumer: String, sequence: Long,
        success: (Long) -> Unit, failure: (String) -> Unit) {
        command({
            val store = ensureStarted()
            require(sourceId == store.stats()["sourceId"]) { "Journal source changed" }
            store.acknowledge(consumer, sequence)
        }, failure, success)
    }

    fun readListening(from: Long, until: Long, zoneId: String, offset: Int, limit: Int,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit, deviceOffset: Int = 0) {
        // A process clock is not a collector-liveness lease. The protected service has no durable
        // destruction/health hook, so production reads never extend beyond durable evidence.
        command({ ensureStarted().listeningSnapshot(from, until, zoneId, null, offset, limit, deviceOffset, now()) + health() }, failure, success)
    }

    fun preferences(values: Map<String, Any?>?, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        command({ ListeningPreferences(context).let {
            if (values == null) it.snapshot() else it.update(values).also {
                com.eartime.eartime_app.widgets.ListeningWidgets.observationCommitted(context)
            }
        } }, failure, success)
    }

    internal fun archivePage(after: Long, success: (List<JournalObservation>) -> Unit, failure: (String) -> Unit) {
        command({ ensureStarted().readAfter(after, 128) }, failure, success)
    }

    fun deviceIdentity(deviceId: String, aliasOffset: Int, candidateOffset: Int,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        command({ ensureStarted().deviceIdentity(deviceId, aliasOffset, candidateOffset) }, failure, success)
    }

    fun changeDeviceIdentity(source: String, aliasId: String, expectedRevision: Long, target: String?,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit, ownerActive: () -> Boolean = { true }) {
        command({
            check(ownerActive()) { "Identity command owner retired" }
            ensureStarted().changeEndpointIdentity(source, aliasId, expectedRevision, target, now(), processGeneration).also {
            if (it["unchanged"] == false) {
                ensureStarted().lastObservation()?.let { committed ->
                    try { publish(mapOf("type" to EndpointIdentity.KIND, "timestamp" to committed.input.time.wallUtcMs,
                        "journal" to committed.metadata())) } catch (_: Exception) { report("Identity committed; refresh delivery failed") }
                }
            }
        } }, failure, success)
    }

    internal fun recoveryArchives(offset: Int, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        command({ ensureStarted().recoveryArchives(offset) }, failure, success)
    }

    internal fun restoreArchive(file: java.io.File, cancelled: () -> Boolean,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        command({
            val store = ensureStarted()
            val restored = store.restoreArchive(file, now(), processGeneration, cancelled)
            if (restored["unchanged"] == false) {
                restoreFenceElapsed = SystemClock.elapsedRealtime()
                store.lastObservation()?.let {
                    try { publish(mapOf("type" to "COLLECTION_GAP", "timestamp" to it.input.time.wallUtcMs,
                        "journal" to it.metadata())) }
                    catch (_: Exception) { report("Restored history committed; refresh delivery failed") }
                }
            }
            restored
        }, failure, success)
    }

    private fun health(): Map<String, Any?> = mapOf("pendingCount" to queue.pendingCount(),
        "queueCapacity" to queue.capacity, "rejectedCount" to rejectedCount.get(),
        "failedCount" to failedCount.get(), "lastError" to lastError)

    private fun report(message: String) {
        if (lastError == message) return
        lastError = message
        onFailure(message)
    }

    private fun <T> command(work: () -> T, failure: (String) -> Unit, success: (T) -> Unit = {}) {
        try {
            executor.execute {
                try { success(work()) }
                catch (error: Exception) { failure("${error.javaClass.simpleName}: ${error.message?.take(160)}") }
                finally { scheduleDrain() }
            }
        } catch (_: RejectedExecutionException) { failure("Journal worker request capacity reached") }
    }

    override fun close() {
        synchronized(lifecycleLock) { check(!closing); closing = true }
        val closed = CompletableFuture<Unit>()
        val barrier = object : Runnable {
            override fun run() {
                if (queue.hasWork() || scheduled.get()) {
                    if (!started) { closed.completeExceptionally(IllegalStateException("Cannot close with uncommitted ingress")); return }
                    scheduleDrain()
                    executor.execute(this)
                } else {
                    try { journal?.close(); closed.complete(Unit) }
                    catch (error: Exception) { closed.completeExceptionally(error) }
                }
            }
        }
        executor.execute(barrier)
        try { closed.get(10, TimeUnit.SECONDS) }
        finally {
            executor.shutdown()
            check(executor.awaitTermination(10, TimeUnit.SECONDS)) { "Journal worker did not terminate" }
        }
    }
}

object NativeJournalRuntime {
    @Volatile private var ingress: NativeObservationIngress? = null

    fun initialize(context: Context) {
        check(ingress == null)
        ingress = NativeObservationIngress(context.applicationContext,
            { event ->
                TrackingEventBroker.publishCommitted(event)
                com.eartime.eartime_app.widgets.ListeningWidgets.observationCommitted(context)
            }, TrackingEventBroker::reportPersistenceFailure)
    }

    fun submit(event: Map<String, Any?>) {
        val target = ingress
        if (target == null) TrackingEventBroker.reportPersistenceFailure("Native journal was not initialized")
        else target.submit(event)
    }

    internal fun submitObserver(event: Map<String, Any?>, capturedElapsedMs: Long, completion: (Boolean) -> Unit) {
        val target = ingress
        if (target == null) completion(false) else target.submitObserver(event, capturedElapsedMs, completion)
    }

    fun readPage(after: Long, limit: Int, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized")
        else target.readPage(after, limit, success, failure)
    }

    fun acknowledge(sourceId: String, consumer: String, sequence: Long, success: (Long) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized")
        else target.acknowledge(sourceId, consumer, sequence, success, failure)
    }

    fun readListening(from: Long, until: Long, zoneId: String, offset: Int, limit: Int,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit, deviceOffset: Int = 0) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized")
        else target.readListening(from, until, zoneId, offset, limit, success, failure, deviceOffset)
    }

    fun preferences(values: Map<String, Any?>?, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized")
        else target.preferences(values, success, failure)
    }

    internal fun archivePage(after: Long, success: (List<JournalObservation>) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized") else target.archivePage(after, success, failure)
    }

    fun deviceIdentity(deviceId: String, aliasOffset: Int, candidateOffset: Int,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized") else target.deviceIdentity(deviceId, aliasOffset, candidateOffset, success, failure)
    }

    fun changeDeviceIdentity(source: String, aliasId: String, expectedRevision: Long, deviceId: String?,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit, ownerActive: () -> Boolean) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized") else target.changeDeviceIdentity(source, aliasId, expectedRevision, deviceId, success, failure, ownerActive)
    }

    fun recoveryArchives(offset: Int, success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized") else target.recoveryArchives(offset, success, failure)
    }

    fun restoreArchive(file: java.io.File, cancelled: () -> Boolean,
        success: (Map<String, Any?>) -> Unit, failure: (String) -> Unit) {
        val target = ingress
        if (target == null) failure("Native journal was not initialized") else target.restoreArchive(file, cancelled, success, failure)
    }
}
