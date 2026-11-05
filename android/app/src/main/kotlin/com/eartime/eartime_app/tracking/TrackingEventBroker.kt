package com.eartime.eartime_app.tracking

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object TrackingEventBroker {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    // All fields below are only touched on the main thread (sendEvent may be called from binder threads).
    private val pendingEvents = ArrayDeque<Map<String, Any?>>()
    // Events buffered while no Flutter listener is attached (e.g. UI process killed, service alive).
    // Bounded so a long-lived service cannot grow memory without limit; SYNC_STATE reconciles the rest.
    private const val MAX_PENDING_EVENTS = 500
    
    private var latestDiagnosticState: Map<String, Any?>? = null
    private var latestDiscoveryResult: Map<String, Any?>? = null
    
    init {
        android.util.Log.i("EarTimeDiag", "[BLE-LIFECYCLE] TrackingEventBroker created")
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        mainHandler.post {
            eventSink = sink
            if (sink != null) {
                android.util.Log.i("EarTimeDiag", "[BLE-LIFECYCLE] EventChannel attached")
                
                // Replay cached states immediately upon connection
                latestDiagnosticState?.let {
                    android.util.Log.i("EarTimeDiag", "[BLE-LIFECYCLE] Replaying latestDiagnosticState")
                    sink.success(it)
                }
                latestDiscoveryResult?.let {
                    android.util.Log.i("EarTimeDiag", "[BLE-LIFECYCLE] Replaying latestDiscoveryResult")
                    sink.success(it)
                }
                
                if (pendingEvents.isNotEmpty()) {
                    pendingEvents.forEach { event ->
                        sink.success(event)
                        val type = event["type"] as? String ?: "UNKNOWN"
                        android.util.Log.i("EarTimeDiag", "[EVENT_CHANNEL]\n$type sent (buffered)")
                    }
                    pendingEvents.clear()
                }
            } else {
                android.util.Log.i("EarTimeDiag", "[BLE-LIFECYCLE] EventChannel cancelled")
            }
        }
    }

    fun clearLatestDiscoveryResult() {
        mainHandler.post { latestDiscoveryResult = null }
    }

    fun sendEvent(event: Map<String, Any?>) {
        val type = event["type"] as? String ?: "UNKNOWN"
        android.util.Log.i("EarTimeDiag", "[BROKER]\n$type emitted")
        
        mainHandler.post {
            // Cache important state events
            if (type == "BLE_DIAGNOSTIC_STATE") {
                latestDiagnosticState = event
            } else if (type == "BLE_DISCOVERY_RESULT") {
                latestDiscoveryResult = event
            }
            if (eventSink != null) {
                eventSink?.success(event)
                android.util.Log.i("EarTimeDiag", "[EVENT_CHANNEL]\n$type sent")
            } else {
                android.util.Log.i("EarTimeDiag", "Buffering event because EventSink is null")
                if (pendingEvents.size >= MAX_PENDING_EVENTS) pendingEvents.removeFirst()
                pendingEvents.addLast(event)
            }
        }
    }
}
