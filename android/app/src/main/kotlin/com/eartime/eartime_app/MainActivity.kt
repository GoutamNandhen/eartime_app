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
import com.eartime.eartime_app.tracking.JournalFileTransfer
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
    private var navigationTarget: String? = null
    private var navigationChannel: MethodChannel? = null
    @Volatile private var navigationOwner: String? = null
    private val journalTransferDelegate = lazy { JournalFileTransfer(this) }
    private val journalTransfer by journalTransferDelegate

    private fun milestone(stage: String, fields: String = "") {
        StartupTrace.mark(stage, "act=$actId $fields")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        milestone("ACTIVITY_CREATED", "savedState=${savedInstanceState != null} boundary=onCreateBegin")
        Log.i("EarTimeDiag", "[GFLOW] MainActivity.onCreate START")
        navigationTarget = if (savedInstanceState == null) NavigationTarget.parse(intent)
            else savedInstanceState.getString("navigationTarget")
        super.onCreate(savedInstanceState)
        milestone("ACTIVITY_CREATE_END")
        Log.i("EarTimeDiag", "[GFLOW] MainActivity.onCreate END")
    }

    override fun onDestroy() {
        milestone("ACTIVITY_DESTROY_BEGIN", "isFinishing=$isFinishing")
        if (journalTransferDelegate.isInitialized()) journalTransfer.close()
        super.onDestroy()
        milestone("ACTIVITY_DESTROYED")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == JournalFileTransfer.REQUEST_CODE && journalTransferDelegate.isInitialized())
            journalTransfer.onActivityResult(requestCode, resultCode, data)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("navigationTarget", navigationTarget)
        super.onSaveInstanceState(outState)
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
        navigationTarget = NavigationTarget.parse(intent)
        if (navigationTarget != null) navigationChannel?.invokeMethod("navigationAvailable", null)
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
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eartime.app/navigation").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "consumeNavigationTarget" && owner.isActive && navigationOwner == owner.token) owner.runIfActive {
                    result.success(navigationTarget)
                    navigationTarget = null
                } else result.notImplemented()
            }
        }
        navigationOwner = owner.token
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
            fun inspect(address: String) {
                if (!owner.isActive || navigationOwner != owner.token || call.argument<Boolean>("confirmed") != true) {
                    result.error("CONFIRMATION_REQUIRED", "Current owner and explicit endpoint inspection consent required", null)
                    return
                }
                try {
                    com.eartime.eartime_app.tracking.BleDiagnosticAuthorization.consent.grant(address)
                    startService(Intent(this, AudioTrackingService::class.java).apply {
                        action = "ACTION_START_BLE_DIAGNOSTIC"
                        putExtra("address", address)
                    })
                    result.success(mapOf("queued" to true))
                } catch (_: Exception) {
                    com.eartime.eartime_app.tracking.BleDiagnosticAuthorization.consent.revoke()
                    result.error("INSPECTION_UNAVAILABLE", "Read-only endpoint inspection unavailable", null)
                }
            }
            when (call.method) {
                "readWellbeingNotificationStatus" -> NativeJournalRuntime.refreshWellbeing(
                    { value -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(value) } } },
                    { _ -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("NOTIFICATION_STATUS_UNAVAILABLE", "Notification scheduling status unavailable", null) } } })
                "inspectDeviceEndpoint" -> {
                    if (!owner.isActive || navigationOwner != owner.token || call.argument<Boolean>("confirmed") != true)
                        result.error("CONFIRMATION_REQUIRED", "Explicit endpoint inspection consent required", null)
                    else NativeJournalRuntime.diagnosticEndpoint(call.argument<String>("sourceId") ?: "",
                        call.argument<String>("aliasId") ?: "", call.argument<Number>("expectedRevision")?.toLong() ?: -1,
                        { address -> Handler(Looper.getMainLooper()).post { owner.runIfActive { inspect(address) } } },
                        { _ -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("INSPECTION_UNAVAILABLE", "Endpoint association changed; refresh and retry", null) } } })
                }
                "readDeviceIdentity" -> NativeJournalRuntime.deviceIdentity(call.argument<String>("deviceId") ?: "",
                    call.argument<Number>("aliasOffset")?.toInt() ?: 0, call.argument<Number>("candidateOffset")?.toInt() ?: 0,
                    { value -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(value) } } },
                    { _ -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("IDENTITY_READ_FAILED", "Device associations unavailable", null) } } })
                "changeDeviceIdentity" -> {
                    if (!owner.isActive || navigationOwner != owner.token || call.argument<Boolean>("confirmed") != true)
                        result.error("CONFIRMATION_REQUIRED", "Current owner and explicit association confirmation required", null)
                    else NativeJournalRuntime.changeDeviceIdentity(call.argument<String>("sourceId") ?: "", call.argument<String>("aliasId") ?: "",
                        call.argument<Number>("expectedRevision")?.toLong() ?: -1, call.argument<String>("targetDeviceId"),
                        { value -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(value) } } },
                        { _ -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("IDENTITY_UPDATE_FAILED", "Association changed or unavailable; refresh and retry", null) } } },
                        { owner.isActive && navigationOwner == owner.token })
                }
                "exportNativeJournal", "restoreNativeJournal", "restoreJournalRecovery" -> {
                    if (!owner.isActive || navigationOwner != owner.token) {
                        result.error("ENGINE_RETIRED", "This engine no longer owns commands", null)
                    } else if (call.method != "exportNativeJournal" && call.argument<Boolean>("confirmed") != true) {
                        result.error("CONFIRMATION_REQUIRED", "Explicit restore confirmation required", null)
                    } else {
                        val success: (Map<String, Any?>) -> Unit = { value -> owner.runIfActive { result.success(value) }; Unit }
                        val failure: (String) -> Unit = { message -> owner.runIfActive { result.error("JOURNAL_TRANSFER_FAILED", message, null) }; Unit }
                        try {
                            if (call.method == "restoreJournalRecovery") journalTransfer.restoreRecovery(call.argument<String>("id") ?: "", success, failure)
                            else journalTransfer.select(if (call.method == "exportNativeJournal") "export" else "restore", success, failure)
                        } catch (_: Exception) { failure("Invalid journal transfer request") }
                    }
                }
                "cancelJournalTransfer" -> {
                    if (!owner.isActive || navigationOwner != owner.token) {
                        result.error("ENGINE_RETIRED", "This engine no longer owns commands", null)
                    } else {
                        if (journalTransferDelegate.isInitialized()) journalTransfer.cancel()
                        result.success(null)
                    }
                }
                "listJournalRecoveries" -> NativeJournalRuntime.recoveryArchives(call.argument<Number>("offset")?.toInt() ?: 0,
                    { value -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(value) } } },
                    { _ -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("RECOVERY_READ_FAILED", "Recovery list unavailable", null) } } })
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
                    val deviceOffset = call.argument<Number>("deviceOffset")?.toInt() ?: 0
                    NativeJournalRuntime.readListening(from, until, zone, offset, limit,
                        { page -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.success(page) } } },
                        { message -> Handler(Looper.getMainLooper()).post { owner.runIfActive { result.error("PROJECTION_READ_FAILED", message, null) } } }, deviceOffset,
                        call.argument<String>("deviceId"))
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
                    inspect(call.argument<String>("address") ?: "")
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
        if (navigationOwner == owner?.token) {
            navigationChannel?.setMethodCallHandler(null)
            navigationChannel = null
            navigationOwner = null
        }
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
