package com.eartime.eartime_app.tracking

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioManager.AudioPlaybackCallback
import android.media.AudioPlaybackConfiguration
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Persistent foreground service that tracks external audio sinks and media playback.
 *
 * Threading model: every mutation of tracking state ([logicalDevices], [systemIdToLogicalId],
 * [lastIsPlaying], [playbackStartedAt]) happens on the main thread. Heavy start-up work
 * (A2DP proxy binding) runs on a background thread and posts its results back to [mainHandler].
 *
 * Device identity: Android exposes one [AudioDeviceInfo] per *route* (A2DP, SCO, BLE...). Several
 * routes can belong to the same physical earbud and resolve to the same logical id (the MAC).
 * We therefore keep, per logical device, the set of system route ids that are currently present
 * and only emit DEVICE_DISCONNECTED when the last route of that device disappears.
 */
class AudioTrackingService : Service() {

    companion object {
        private const val TAG = "EarTimeDiag"
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_START_BLE_DIAGNOSTIC = "ACTION_START_BLE_DIAGNOSTIC"
        const val ACTION_SYNC_STATE = "ACTION_SYNC_STATE"

        /** Debounce window used to let AudioManager settle after a playback config change. */
        private const val PLAYBACK_SETTLE_MS = 350L

        private val BLUETOOTH_TYPES = setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            26, // TYPE_BLE_HEADSET
            27, // TYPE_BLE_SPEAKER
            30  // TYPE_BLE_BROADCAST
        )
    }

    private lateinit var audioManager: AudioManager
    private var bluetoothAdapter: BluetoothAdapter? = null
    @Volatile private var a2dpProxy: BluetoothA2dp? = null
    private var bleDiscoveryManager: BleDiscoveryManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val notificationId = 1001
    private val channelId = "EarTimeTrackingChannel"

    /** True once start-up was kicked off (guards against double initialisation). */
    private var initStarted = false
    /** True once callbacks are registered and the initial scan has completed. */
    private var initCompleted = false

    private var playbackCallback: AudioPlaybackCallback? = null
    private var callbacksRegistered = false

    /** logicalId -> device info map sent to Flutter. Main thread only. */
    private val logicalDevices = LinkedHashMap<String, Map<String, Any?>>()
    /** logicalId -> system route ids currently present for that device. Main thread only. */
    private val logicalRoutes = HashMap<String, MutableSet<Int>>()
    /** system route id -> logicalId, so removal never has to re-derive the id. Main thread only. */
    private val systemIdToLogicalId = HashMap<Int, String>()

    private var lastIsPlaying: Boolean? = null
    private var playbackStartedAt: Long? = null

    private val playbackEvaluation = Runnable { evaluatePlaybackState() }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "[START] Service onCreate")
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
        bluetoothAdapter = btManager?.adapter
        bleDiscoveryManager = BleDiscoveryManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "[START] Service onStartCommand action=${intent?.action}")

        // Every start command must satisfy the startForegroundService() contract, including
        // re-deliveries while the service is already running (Test G).
        if (!enterForeground()) {
            return START_NOT_STICKY
        }

        when (intent?.action) {
            ACTION_STOP -> {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START_BLE_DIAGNOSTIC -> startBleDiagnostic(intent.getStringExtra("address"))
            ACTION_SYNC_STATE -> {
                Log.i(TAG, "[BLE-LIFECYCLE] Sync state requested (initCompleted=$initCompleted)")
                // Before init completes the initial scan emits SYNC_STATE itself, so an early
                // request must not publish an empty (and therefore wrong) snapshot.
                if (initCompleted) emitSyncState()
            }
        }

        if (!initStarted) {
            initStarted = true
            Log.i(TAG, "SERVICE_RUNNING")
            initialize()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "SERVICE_DESTROYED")
        mainHandler.removeCallbacksAndMessages(null)
        if (callbacksRegistered) unregisterCallbacks()
        cleanupBluetoothA2dp()
        bleDiscoveryManager?.close()
        bleDiscoveryManager = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent): IBinder? = null

    // ---------------------------------------------------------------------------------------
    // Foreground / lifecycle
    // ---------------------------------------------------------------------------------------

    private fun enterForeground(): Boolean {
        createNotificationChannel()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        } else {
            0
        }
        return try {
            // ServiceCompat picks the right overload: the 3-arg startForeground() only exists on API 29+.
            ServiceCompat.startForeground(this, notificationId, createNotification(), type)
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "[SECURITY] Failed to start foreground service: ${e.message}")
            stopSelf()
            false
        } catch (e: IllegalStateException) {
            // e.g. ForegroundServiceStartNotAllowedException when started from the background.
            Log.e(TAG, "[FGS] Foreground start not allowed: ${e.message}")
            stopSelf()
            false
        }
    }

    private fun initialize() {
        Thread {
            try {
                initBluetoothA2dp()
            } catch (e: Exception) {
                Log.e(TAG, "[STARTUP] Exception binding A2DP: ${e.message}")
            }
            mainHandler.post {
                try {
                    registerCallbacks()
                    checkInitialAudioState()
                } catch (e: Exception) {
                    Log.e(TAG, "[STARTUP] Exception during initialization: ${e.message}")
                } finally {
                    initCompleted = true
                }
            }
        }.start()
    }

    // ---------------------------------------------------------------------------------------
    // Bluetooth helpers
    // ---------------------------------------------------------------------------------------

    private fun initBluetoothA2dp() {
        bluetoothAdapter?.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                if (profile == BluetoothProfile.A2DP) {
                    a2dpProxy = proxy as BluetoothA2dp
                    Log.d(TAG, "[DIAGNOSTIC] BluetoothA2dp proxy connected.")
                    // Names/MACs may only become resolvable now; refresh the snapshot on main.
                    mainHandler.post { if (initCompleted) checkInitialAudioState() }
                }
            }

            override fun onServiceDisconnected(profile: Int) {
                if (profile == BluetoothProfile.A2DP) {
                    a2dpProxy = null
                    Log.d(TAG, "[DIAGNOSTIC] BluetoothA2dp proxy disconnected.")
                }
            }
        }, BluetoothProfile.A2DP)
    }

    private fun cleanupBluetoothA2dp() {
        try {
            a2dpProxy?.let { bluetoothAdapter?.closeProfileProxy(BluetoothProfile.A2DP, it) }
        } catch (e: Exception) {
            Log.e(TAG, "[DIAGNOSTIC] Exception closing A2DP proxy: ${e.message}")
        }
        a2dpProxy = null
    }

    private fun connectedA2dpDevices(): List<BluetoothDevice> = try {
        a2dpProxy?.connectedDevices ?: emptyList()
    } catch (e: SecurityException) {
        emptyList()
    }

    private fun bluetoothName(device: BluetoothDevice): String? {
        val alias = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) device.alias else null
        } catch (e: SecurityException) { null }
        val name = try { device.name } catch (e: SecurityException) { null }
        return alias ?: name
    }

    /**
     * Resolves the Bluetooth name/MAC for an audio route.
     *
     * - If the route exposes a MAC, the name is taken from the A2DP device with the same MAC.
     * - If it does not, we only fall back to the A2DP list when it is unambiguous (exactly one
     *   connected device); guessing with firstOrNull() attributed sessions to the wrong device.
     */
    private fun resolveBluetoothIdentity(device: AudioDeviceInfo): Pair<String?, String?> {
        if (device.type !in BLUETOOTH_TYPES) return Pair(null, null)
        val routeAddress = AudioDeviceDetector.validMacOrNull(device.address)
        val a2dp = connectedA2dpDevices()
        if (routeAddress != null) {
            val match = a2dp.firstOrNull { it.address.equals(routeAddress, ignoreCase = true) }
            return Pair(match?.let { bluetoothName(it) }, routeAddress)
        }
        if (a2dp.size == 1) {
            val only = a2dp.first()
            return Pair(bluetoothName(only), only.address)
        }
        return Pair(null, null)
    }

    private fun getBestBluetoothDeviceAddress(): String? {
        // Prefer the device that is actually tracked (it is the one routing audio).
        logicalDevices.values.lastOrNull { it["hardwareAddress"] != null }?.let {
            return it["hardwareAddress"] as String
        }
        connectedA2dpDevices().singleOrNull()?.let { return it.address }
        return try {
            val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            btManager.getConnectedDevices(BluetoothProfile.GATT).singleOrNull()?.address
        } catch (e: SecurityException) {
            null
        }
    }

    private fun remoteDeviceOrNull(address: String?): BluetoothDevice? {
        if (address == null || !BluetoothAdapter.checkBluetoothAddress(address)) return null
        return try {
            bluetoothAdapter?.getRemoteDevice(address)
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    private fun startBleDiagnostic(requested: String?) {
        val address = AudioDeviceDetector.validMacOrNull(requested?.uppercase())
            ?: getBestBluetoothDeviceAddress()
        val btDevice = remoteDeviceOrNull(address)
        if (btDevice != null) {
            Log.i(TAG, "[BLE-REFRESH] Starting diagnostic refresh for ${btDevice.address}")
            bleDiscoveryManager?.discover(btDevice, forceRefresh = true)
        } else {
            TrackingEventBroker.sendEvent(mapOf(
                "type" to "BLE_DIAGNOSTIC_STATE",
                "deviceId" to (address ?: "unknown"),
                "state" to "ERROR",
                "message" to if (address == null) "No valid Bluetooth address available" else "Invalid Bluetooth address: $address",
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    // ---------------------------------------------------------------------------------------
    // Callbacks
    // ---------------------------------------------------------------------------------------

    private fun registerCallbacks() {
        audioManager.registerAudioDeviceCallback(deviceCallback, mainHandler)
        Log.i(TAG, "[CALLBACK] AudioDeviceCallback registered")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val callback = object : AudioPlaybackCallback() {
                override fun onPlaybackConfigChanged(configs: List<AudioPlaybackConfiguration>?) {
                    schedulePlaybackEvaluation()
                }
            }
            playbackCallback = callback
            audioManager.registerAudioPlaybackCallback(callback, mainHandler)
            Log.i(TAG, "[CALLBACK] AudioPlaybackCallback registered")
        }
        callbacksRegistered = true
    }

    private fun unregisterCallbacks() {
        audioManager.unregisterAudioDeviceCallback(deviceCallback)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            playbackCallback?.let { audioManager.unregisterAudioPlaybackCallback(it) }
        }
        callbacksRegistered = false
    }

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            Log.d(TAG, "[DIAGNOSTIC] onAudioDevicesAdded: ${addedDevices?.size ?: 0} devices")
            addedDevices?.forEach { device ->
                if (AudioDeviceDetector.isExternalListeningDevice(device)) {
                    handleRouteAdded(device, "CALLBACK")
                }
            }
            // Audio may already be playing when a device appears; re-evaluate attribution.
            schedulePlaybackEvaluation()
        }

        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            Log.d(TAG, "[DIAGNOSTIC] onAudioDevicesRemoved: ${removedDevices?.size ?: 0} devices")
            removedDevices?.forEach { handleRouteRemoved(it) }
            schedulePlaybackEvaluation()
        }
    }

    // ---------------------------------------------------------------------------------------
    // Device tracking
    // ---------------------------------------------------------------------------------------

    private fun checkInitialAudioState() {
        Log.i(TAG, "[INITIAL_SCAN] started")
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val presentSystemIds = HashSet<Int>()
        devices.forEach { device ->
            if (AudioDeviceDetector.isExternalListeningDevice(device)) {
                presentSystemIds.add(device.id)
                handleRouteAdded(device, "INITIAL_SCAN")
            }
        }
        // Drop routes we believed present but which disappeared while callbacks were not registered.
        systemIdToLogicalId.keys.filter { it !in presentSystemIds }.forEach { removeRoute(it) }

        evaluatePlaybackState(emit = false)
        Log.i(TAG, "INITIAL_SCAN_EXECUTED. Emitting SYNC_STATE.")
        emitSyncState()
    }

    private fun handleRouteAdded(device: AudioDeviceInfo, context: String) {
        val (fallbackName, fallbackAddress) = resolveBluetoothIdentity(device)
        val info = AudioDeviceDetector.extractDeviceInfo(device, fallbackName, fallbackAddress)
        val logicalId = info["id"] as String

        systemIdToLogicalId[device.id] = logicalId
        val routes = logicalRoutes.getOrPut(logicalId) { HashSet() }
        routes.add(device.id)

        if (logicalDevices.containsKey(logicalId)) {
            Log.i(TAG, "[$context] Route ${device.id} (type=${device.type}) joined existing device $logicalId")
            return
        }

        logicalDevices[logicalId] = info
        Log.i(TAG, "[NATIVE_EVENT] DEVICE_CONNECTED $logicalId via $context")
        TrackingEventBroker.sendEvent(mapOf(
            "type" to "DEVICE_CONNECTED",
            "deviceId" to logicalId,
            "device" to info,
            "timestamp" to System.currentTimeMillis()
        ))

        remoteDeviceOrNull(info["hardwareAddress"] as? String)?.let {
            bleDiscoveryManager?.discover(it)
        }
    }

    private fun handleRouteRemoved(device: AudioDeviceInfo) {
        // Look the route up by its system id; recomputing the id from a half-torn-down
        // AudioDeviceInfo (empty address, A2DP proxy already updated) produced a different id
        // and left the device stuck in the "connected" state.
        if (!systemIdToLogicalId.containsKey(device.id)) return
        removeRoute(device.id)
    }

    private fun removeRoute(systemId: Int) {
        val logicalId = systemIdToLogicalId.remove(systemId) ?: return
        val routes = logicalRoutes[logicalId]
        routes?.remove(systemId)
        if (!routes.isNullOrEmpty()) {
            Log.i(TAG, "[ROUTE] Route $systemId removed; $logicalId still has routes $routes. Keeping device.")
            return
        }
        logicalRoutes.remove(logicalId)
        logicalDevices.remove(logicalId)
        Log.i(TAG, "[NATIVE_EVENT] DEVICE_DISCONNECTED $logicalId")
        TrackingEventBroker.sendEvent(mapOf(
            "type" to "DEVICE_DISCONNECTED",
            "deviceId" to logicalId,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    /** The device playback is attributed to: the most recently connected tracked device. */
    private fun activeDevice(): Map<String, Any?>? = logicalDevices.values.lastOrNull()

    private fun emitSyncState() {
        val active = activeDevice()
        // Root-level keys are the contract (see docs/eartime/NATIVE_FLUTTER_CONTRACT.md).
        TrackingEventBroker.sendEvent(mapOf(
            "type" to "SYNC_STATE",
            "deviceId" to active?.get("id"),
            "connectedDevices" to logicalDevices.values.toList(),
            "isPlaying" to (lastIsPlaying == true && active != null),
            "playbackStartedAt" to if (lastIsPlaying == true && active != null) playbackStartedAt else null,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    // ---------------------------------------------------------------------------------------
    // Playback tracking
    // ---------------------------------------------------------------------------------------

    private fun schedulePlaybackEvaluation() {
        mainHandler.removeCallbacks(playbackEvaluation)
        mainHandler.postDelayed(playbackEvaluation, PLAYBACK_SETTLE_MS)
    }

    /**
     * Playback counts as "playing" only when a media-type player exists AND the music stream is
     * actually active. activePlaybackConfigurations alone also lists paused-but-unreleased players
     * and notification/assistant sounds, which kept the state stuck on "playing".
     */
    private fun isMediaPlaying(): Boolean {
        @Suppress("DEPRECATION")
        val musicActive = audioManager.isMusicActive
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return musicActive
        val hasMediaPlayer = audioManager.activePlaybackConfigurations.any { config ->
            when (config.audioAttributes.usage) {
                AudioAttributes.USAGE_MEDIA,
                AudioAttributes.USAGE_GAME,
                AudioAttributes.USAGE_UNKNOWN -> true
                else -> false
            }
        }
        return musicActive && hasMediaPlayer
    }

    private fun evaluatePlaybackState(emit: Boolean = true) {
        val isPlaying = isMediaPlaying()
        if (isPlaying == lastIsPlaying) return
        lastIsPlaying = isPlaying
        playbackStartedAt = if (isPlaying) System.currentTimeMillis() else null
        if (!emit) return

        val device = activeDevice()
        if (device == null) {
            // Speaker playback is not earbud listening time; nothing to attribute it to.
            Log.i(TAG, "[PLAYBACK] isPlaying=$isPlaying with no external device; not emitting.")
            return
        }
        val state = if (isPlaying) "PLAYBACK_STARTED" else "PLAYBACK_PAUSED"
        Log.i(TAG, "[PLAYBACK] $state on ${device["id"]}")
        TrackingEventBroker.sendEvent(mapOf(
            "type" to state,
            "deviceId" to device["id"],
            "device" to device,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    // ---------------------------------------------------------------------------------------
    // Notification
    // ---------------------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Audio Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground service for monitoring audio wellbeing"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification() = NotificationCompat.Builder(this, channelId)
        .setContentTitle("EarTime")
        .setContentText("Monitoring audio sessions for your wellbeing")
        .setSmallIcon(android.R.drawable.ic_media_play)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setOngoing(true)
        .build()
}
