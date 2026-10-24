package com.eartime.eartime_app

import android.content.Intent
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import com.eartime.eartime_app.tracking.AudioTrackingService
import com.eartime.eartime_app.tracking.TrackingEventBroker
import com.eartime.eartime_app.tracking.EngineAttachmentOwner
import com.eartime.eartime_app.tracking.StartupTrace
import com.eartime.eartime_app.tracking.NativeJournalRuntime
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.IdentityHashMap
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.eartime.app/tracking"
    private val EVENT_CHANNEL = "com.eartime.app/tracking_events"
    private val actId: String by lazy { Integer.toHexString(System.identityHashCode(this)) }
    private val engineOwners = IdentityHashMap<FlutterEngine, EngineAttachmentOwner>()

    private fun milestone(stage: String, fields: String = "") {
        StartupTrace.mark(stage, "act=$actId $fields")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        milestone("ACTIVITY_CREATED", "savedState=${savedInstanceState != null} boundary=onCreateBegin")
        Log.i("EarTimeDiag", "[GFLOW] MainActivity.onCreate START")
        super.onCreate(savedInstanceState)
        milestone("ACTIVITY_CREATE_END")
        Log.i("EarTimeDiag", "[GFLOW] MainActivity.onCreate END")
    }

    override fun onDestroy() {
        milestone("ACTIVITY_DESTROY_BEGIN", "isFinishing=$isFinishing")
        super.onDestroy()
        milestone("ACTIVITY_DESTROYED")
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        milestone("ENGINE_RESOLUTION_BEGIN", "path=embeddingDefaultUnlessIntentCache")
        return super.provideFlutterEngine(context)
    }

    override fun onStart() {
        milestone("ACTIVITY_START_BEGIN")
        super.onStart()
        milestone("ACTIVITY_START_END")
    }

    override fun onFlutterUiDisplayed() {
        val engine = flutterEngine
        milestone("FIRST_FRAME_OBSERVED", "kind=nativeFlutterUiDisplayed eng=${engine?.let { Integer.toHexString(System.identityHashCode(it)) }} owner=${engineOwners[engine]?.token}")
        super.onFlutterUiDisplayed()
        milestone("FLUTTER_UI_DISPLAY_CALLBACK_RETURNED")
    }

    override fun onFlutterUiNoLongerDisplayed() {
        milestone("FLUTTER_UI_NO_LONGER_DISPLAYED")
        super.onFlutterUiNoLongerDisplayed()
    }

    override fun onNewIntent(intent: Intent) {
        milestone("ACTIVITY_NEW_INTENT", "action=${intent.action}")
        super.onNewIntent(intent)
    }

    override fun onResume() {
        milestone("ACTIVITY_RESUME_BEGIN")
        super.onResume()
        milestone("ACTIVITY_RESUMED")
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        val engId = Integer.toHexString(System.identityHashCode(flutterEngine))
        val owner = EngineAttachmentOwner(UUID.randomUUID().toString())
        engineOwners[flutterEngine] = owner
        milestone("FLUTTER_ENGINE_CONFIGURE_BEGIN", "eng=$engId owner=${owner.token} ownerEpoch=${owner.generation} dartExecuting=${flutterEngine.dartExecutor.isExecutingDart}")
        Log.i("EarTimeDiag", "[GFLOW] configureFlutterEngine START")
        super.configureFlutterEngine(flutterEngine)
        milestone("FLUTTER_PLUGINS_CONFIGURED", "eng=$engId owner=${owner.token}")
        Log.i("EarTimeDiag", "[GFLOW] configureFlutterEngine AFTER SUPER")

        // Automatically start the tracking service to ensure passive monitoring
        Log.i("EarTimeDiag", "[START] Checking permissions before automatically starting tracking service on app launch")
        if (android.os.Build.VERSION.SDK_INT >= 31) { // Android 12+
            val hasBluetoothConnect = androidx.core.content.ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.BLUETOOTH_CONNECT
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            
            if (hasBluetoothConnect) {
                startTrackingService()
            } else {
                Log.w("EarTimeDiag", "[START] Skipped automatic tracking service startup: BLUETOOTH_CONNECT permission not yet granted.")
            }
        } else {
            startTrackingService()
        }

        // Method Channel for starting/stopping tracking
        Log.i("EarTimeDiag", "[GFLOW] MethodChannel REGISTERED")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "readListeningPreferences", "updateListeningPreferences" -> {
                    val rawValues = call.arguments as? Map<*, *>
                    val values = if (call.method == "updateListeningPreferences" && rawValues != null && rawValues.keys.all { it is String })
                        rawValues.entries.associate { it.key as String to it.value } else null
                    if (call.method == "updateListeningPreferences" && values == null) result.error("INVALID_PREFERENCES", "Missing preferences", null)
                    else NativeJournalRuntime.preferences(values,
                        { value -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(value) } } },
                        { message -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("PREFERENCES_FAILED", message, null) } } })
                }
                "readListeningProjection" -> {
                    val from = call.argument<Number>("fromUtcMs")?.toLong() ?: 0L
                    val until = call.argument<Number>("untilUtcMs")?.toLong() ?: 0L
                    val zone = call.argument<String>("zoneId") ?: java.util.TimeZone.getDefault().id
                    val offset = call.argument<Number>("offset")?.toInt() ?: 0
                    val limit = call.argument<Number>("limit")?.toInt() ?: 100
                    NativeJournalRuntime.readListening(from, until, zone, offset, limit,
                        { page -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(page) } } },
                        { message -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("PROJECTION_READ_FAILED", message, null) } } })
                }
                "readObservationJournal" -> {
                    val after = call.argument<Number>("after")?.toLong() ?: 0L
                    val limit = call.argument<Number>("limit")?.toInt() ?: 64
                    NativeJournalRuntime.readPage(after, limit,
                        { page -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(page) } } },
                        { message -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("JOURNAL_READ_FAILED", message, null) } } })
                }
                "acknowledgeObservations" -> {
                    val source = call.argument<String>("sourceId") ?: ""
                    val consumer = call.argument<String>("consumer") ?: ""
                    val sequence = call.argument<Number>("sequence")?.toLong() ?: -1L
                    NativeJournalRuntime.acknowledge(source, consumer, sequence,
                        { accepted -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(accepted) } } },
                        { message -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("JOURNAL_ACK_FAILED", message, null) } } })
                }
                "getAndroidSdkVersion" -> {
                    milestone("DART_NATIVE_CORRELATED", "eng=$engId owner=${owner.token} dart=${call.argument<String>("dart")} sdk=${android.os.Build.VERSION.SDK_INT}")
                    result.success(android.os.Build.VERSION.SDK_INT)
                }
                "startMonitoring" -> {
                    Log.i("EarTimeDiag", "[FLUTTER] MethodChannel start command received")
                    Log.i("EarTimeDiag", "[START] Monitoring start command received")
                    startTrackingService()
                    result.success(null)
                }
                "stopMonitoring" -> {
                    NativeJournalRuntime.submit(mapOf("type" to "COLLECTION_GAP", "timestamp" to System.currentTimeMillis(),
                        "reason" to "user_requested_collection_stop", "continuityProven" to false))
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
        Log.i("EarTimeDiag", "[GFLOW] EventChannel REGISTERED")
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    milestone("EVENT_CHANNEL_LISTEN", "eng=$engId owner=${owner.token} active=${owner.isActive}")
                    if (!owner.runIfActive {
                        Log.i("EarTimeDiag", "[GFLOW] EventChannel onListen START")
                        if (events != null) TrackingEventBroker.attach(owner, events)

                        // Request a fresh snapshot; this remains independent of rendering.
                        milestone("SYNC_REQUESTED", "eng=$engId owner=${owner.token}")
                        val intent = Intent(this@MainActivity, AudioTrackingService::class.java).apply {
                            action = "ACTION_SYNC_STATE"
                        }
                        startService(intent)
                        milestone("SYNC_REQUEST_RETURNED", "eng=$engId owner=${owner.token}")
                        Log.i("EarTimeDiag", "[GFLOW] ACTION_SYNC_STATE sent")
                        Log.i("EarTimeDiag", "[GFLOW] EventChannel onListen END")
                    }) {
                        milestone("EVENT_CHANNEL_LISTEN_REJECTED", "eng=$engId owner=${owner.token} reason=engineRetired")
                    }
                }

                override fun onCancel(arguments: Any?) {
                    Log.i("EarTimeDiag", "[FLUTTER] EventChannel listener cancelled")
                    TrackingEventBroker.detach(owner.token)
                }
            }
        )
        milestone("FLUTTER_ENGINE_CONFIGURED", "eng=$engId owner=${owner.token}")
        Log.i("EarTimeDiag", "[GFLOW] configureFlutterEngine END")
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val engId = Integer.toHexString(System.identityHashCode(flutterEngine))
        val owner = engineOwners.remove(flutterEngine)
        milestone("ENGINE_CLEANUP_BEGIN", "eng=$engId owner=${owner?.token}")
        // Revoke before posting detach, so already-queued callbacks cannot resurrect A.
        owner?.retire()
        if (owner != null) TrackingEventBroker.detach(owner.token)
        super.cleanUpFlutterEngine(flutterEngine)
        milestone("ENGINE_CLEANUP_END", "eng=$engId owner=${owner?.token} boundary=hostHook")
    }

    private fun startTrackingService() {
        milestone("SERVICE_START_REQUEST_BEGIN")
        Log.i("EarTimeDiag", "[GFLOW] startTrackingService START")
        val intent = Intent(this, AudioTrackingService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        milestone("SERVICE_START_REQUEST_RETURNED")
        Log.i("EarTimeDiag", "[GFLOW] startTrackingService END")
    }

    private fun stopTrackingService() {
        val intent = Intent(this, AudioTrackingService::class.java).apply {
            action = AudioTrackingService.ACTION_STOP
        }
        startService(intent) // Send STOP action
    }
}
