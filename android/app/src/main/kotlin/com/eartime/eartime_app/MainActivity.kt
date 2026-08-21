package com.eartime.eartime_app

import android.content.Intent
import androidx.annotation.NonNull
import com.eartime.eartime_app.tracking.AudioTrackingService
import com.eartime.eartime_app.tracking.TrackingEventBroker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.eartime.app/tracking"
    private val EVENT_CHANNEL = "com.eartime.app/tracking_events"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        android.util.Log.i("EarTimeDiag", "[GFLOW] MainActivity.onCreate START")
        super.onCreate(savedInstanceState)
        android.util.Log.i("EarTimeDiag", "[GFLOW] MainActivity.onCreate END")
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        android.util.Log.i("EarTimeDiag", "[GFLOW] configureFlutterEngine START")
        super.configureFlutterEngine(flutterEngine)
        android.util.Log.i("EarTimeDiag", "[GFLOW] configureFlutterEngine AFTER SUPER")

        // Automatically start the tracking service to ensure passive monitoring
        android.util.Log.i("EarTimeDiag", "[START] Checking permissions before automatically starting tracking service on app launch")
        if (android.os.Build.VERSION.SDK_INT >= 31) { // Android 12+
            val hasBluetoothConnect = androidx.core.content.ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.BLUETOOTH_CONNECT
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            
            if (hasBluetoothConnect) {
                startTrackingService()
            } else {
                android.util.Log.w("EarTimeDiag", "[START] Skipped automatic tracking service startup: BLUETOOTH_CONNECT permission not yet granted.")
            }
        } else {
            startTrackingService()
        }

        // Method Channel for starting/stopping tracking
        android.util.Log.i("EarTimeDiag", "[GFLOW] MethodChannel REGISTERED")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    android.util.Log.i("EarTimeDiag", "[FLUTTER] MethodChannel start command received")
                    android.util.Log.i("EarTimeDiag", "[START] Monitoring start command received")
                    startTrackingService()
                    result.success(null)
                }
                "stopMonitoring" -> {
                    stopTrackingService()
                    result.success(null)
                }
                "startBleDiagnostic" -> {
                    val address = call.argument<String>("address")
                    val intent = Intent(this, AudioTrackingService::class.java).apply {
                        action = "ACTION_START_BLE_DIAGNOSTIC"
                        putExtra("address", address)
                    }
                    startService(intent)
                    result.success(null)
                }
                "getAudioDiagnostics" -> {
                    com.eartime.eartime_app.tracking.AudioDiagnosticHelper.getDiagnostics(this) { diagInfo ->
                        result.success(diagInfo)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Event Channel for receiving events
        android.util.Log.i("EarTimeDiag", "[GFLOW] EventChannel REGISTERED")
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    android.util.Log.i("EarTimeDiag", "[GFLOW] EventChannel onListen START")
                    TrackingEventBroker.setEventSink(events)
                    
                    // Force a sync of active audio devices to guarantee Flutter receives the latest state
                    val intent = Intent(this@MainActivity, AudioTrackingService::class.java).apply {
                        action = "ACTION_SYNC_STATE"
                    }
                    startService(intent)
                    android.util.Log.i("EarTimeDiag", "[GFLOW] ACTION_SYNC_STATE sent")
                    android.util.Log.i("EarTimeDiag", "[GFLOW] EventChannel onListen END")
                }

                override fun onCancel(arguments: Any?) {
                    android.util.Log.i("EarTimeDiag", "[FLUTTER] EventChannel listener cancelled")
                    TrackingEventBroker.setEventSink(null)
                }
            }
        )
        android.util.Log.i("EarTimeDiag", "[GFLOW] configureFlutterEngine END")
    }

    private fun startTrackingService() {
        android.util.Log.i("EarTimeDiag", "[GFLOW] startTrackingService START")
        val intent = Intent(this, AudioTrackingService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        android.util.Log.i("EarTimeDiag", "[GFLOW] startTrackingService END")
    }

    private fun stopTrackingService() {
        val intent = Intent(this, AudioTrackingService::class.java).apply {
            action = AudioTrackingService.ACTION_STOP
        }
        startService(intent) // Send STOP action
    }
}
