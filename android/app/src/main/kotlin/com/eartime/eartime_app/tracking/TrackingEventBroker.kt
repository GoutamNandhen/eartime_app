package com.eartime.eartime_app.tracking

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

object TrackingEventBroker {
    private val mainHandler = Handler(Looper.getMainLooper())
    // Delivery hints may be evicted: the journal, not this cache, owns product history.
    private val attachment = OwnedEventBuffer<Map<String, Any?>>(capacity = 256)
    private const val FLUSH_BATCH_SIZE = 32
    private var flushScheduled = false

    // Diagnostic correlation only, never event identity or durable generations.
    val procGen: String = StartupTrace.procGen
    val pid: Int get() = StartupTrace.pid
    var sinkGen: Int = 0
        private set

    private var latestDiagnosticState: Map<String, Any?>? = null
    private var latestDiscoveryResult: Map<String, Any?>? = null
    private var persistenceFailure: String? = null
    private var failureSink: Pair<String, EventChannel.EventSink>? = null

    init {
        Log.i("EarTimeDiag", "[LIFECYCLE:proc=$procGen:pid=$pid] BROKER_INITIALIZED")
    }

    fun attach(ownerToken: EngineAttachmentOwner, sink: EventChannel.EventSink) {
        mainHandler.post {
            val replaced = attachment.owner
            // Recheck here: cleanup can retire the engine after onListen posts us.
            if (!attachment.attach(ownerToken, sink::success,
                    listOfNotNull(latestDiagnosticState, latestDiscoveryResult))) {
                StartupTrace.mark("EVENT_SINK_ATTACH_REJECTED", "owner=${ownerToken.token} ownerEpoch=${ownerToken.generation} reason=retiredOrSuperseded activeOwner=${attachment.owner}")
                return@post
            }
            sinkGen++
            failureSink = ownerToken.token to sink
            persistenceFailure?.let { sink.error("JOURNAL_UNAVAILABLE", it, null) }
            StartupTrace.mark("EVENT_SINK_ATTACHED", "owner=${ownerToken.token} ownerEpoch=${ownerToken.generation} replaced=$replaced sinkGen=$sinkGen pending=${attachment.pendingCount}")
            scheduleFlush()
        }
    }

    fun detach(ownerToken: String) {
        mainHandler.post {
            val cleared = attachment.detach(ownerToken)
            if (cleared) failureSink = null
            StartupTrace.mark("EVENT_SINK_DETACH", "owner=$ownerToken cleared=$cleared activeOwner=${attachment.owner} sinkGen=$sinkGen pending=${attachment.pendingCount}")
        }
    }

    fun clearLatestDiscoveryResult() {
        mainHandler.post { latestDiscoveryResult = null }
    }

    fun sendEvent(event: Map<String, Any?>) {
        NativeJournalRuntime.submit(event)
    }

    fun reportPersistenceFailure(message: String) {
        mainHandler.post {
            val changed = persistenceFailure != message
            persistenceFailure = message
            Log.e("EarTimeDiag", "JOURNAL_FAILURE $message")
            if (changed) {
                attachment.owner?.let { owner ->
                    // Retain the attachment; a persistence failure must remain visible to Dart.
                    failureSink?.takeIf { it.first == owner }?.second?.error("JOURNAL_UNAVAILABLE", message, null)
                }
            }
        }
    }

    fun publishCommitted(event: Map<String, Any?>) {
        mainHandler.post {
                val type = event["type"] as? String ?: "UNKNOWN"
                if (type == "BLE_DIAGNOSTIC_STATE") latestDiagnosticState = event
                if (type == "BLE_DISCOVERY_RESULT") latestDiscoveryResult = event
                if (type == "SYNC_STATE") {
                    val devices = (event["connectedDevices"] as? List<*>)?.size ?: 0
                    Log.i("EarTimeDiag", "[LIFECYCLE:proc=$procGen:pid=$pid] SYNC_EMITTED devices=$devices isPlaying=${event["isPlaying"]} timestamp=${event["timestamp"]}")
                }
                attachment.enqueue(event)
                if (attachment.owner == null) {
                    Log.d("EarTimeDiag", "[LIFECYCLE:proc=$procGen:pid=$pid] TRACKING_EVENT_BUFFERED type=$type ts=${event["timestamp"]} pending=${attachment.pendingCount}")
                }
                scheduleFlush()
        }
    }

    private fun scheduleFlush() {
        if (flushScheduled || attachment.owner == null || attachment.pendingCount == 0) return
        flushScheduled = true
        mainHandler.post {
            flushScheduled = false
            val owner = attachment.owner ?: return@post
            try {
                val attempts = attachment.drain(FLUSH_BATCH_SIZE)
                Log.i("EarTimeDiag", "[LIFECYCLE:proc=$procGen:pid=$pid:sinkGen=$sinkGen] EVENT_SEND_ATTEMPTS owner=$owner count=$attempts pending=${attachment.pendingCount}; Dart receipt and DB commit are separate")
            } catch (error: RuntimeException) {
                attachment.detach(owner)
                failureSink = null
                Log.e("EarTimeDiag", "[LIFECYCLE:proc=$procGen:pid=$pid] EVENT_SEND_FAILURE owner=$owner pending=${attachment.pendingCount}", error)
            }
            scheduleFlush()
        }
    }
}
