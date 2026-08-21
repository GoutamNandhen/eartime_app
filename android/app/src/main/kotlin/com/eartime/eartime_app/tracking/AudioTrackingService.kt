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
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioManager.AudioPlaybackCallback
import android.media.AudioPlaybackConfiguration
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.ConcurrentHashMap

class AudioTrackingService : Service() {

    companion object {
        private const val TAG = "EarTimeDiag"
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_START_BLE_DIAGNOSTIC = "ACTION_START_BLE_DIAGNOSTIC"
        const val ACTION_SYNC_STATE = "ACTION_SYNC_STATE"
    }

    private lateinit var audioManager: AudioManager
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var a2dpProxy: BluetoothA2dp? = null
    private var bleDiscoveryManager: BleDiscoveryManager? = null

    private val notificationId = 1001
    private val channelId = "EarTimeTrackingChannel"
    private var isInitialized = false
    private var playbackCallback: AudioPlaybackCallback? = null

    // Track active devices to avoid duplicates
    private val connectedDevices = ConcurrentHashMap<String, Map<String, Any?>>()

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "[START] Service onCreate")
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = btManager.adapter
        bleDiscoveryManager = BleDiscoveryManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "[START] Service onStartCommand")
        if (intent?.action == ACTION_STOP) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent?.action == ACTION_START_BLE_DIAGNOSTIC) {
            var address = intent.getStringExtra("address")
            
            // If address is invalid or missing, try to auto-detect the best connected Bluetooth device
            if (address.isNullOrEmpty() || !address.contains(":")) {
                val best = getBestBluetoothDeviceInfo()
                address = best.second
            }

            if (address != null && address.contains(":")) {
                val btDevice = bluetoothAdapter?.getRemoteDevice(address)
                if (btDevice != null) {
                    Log.i(TAG, "[BLE-REFRESH] Starting diagnostic refresh")
                    Log.i(TAG, "[BLE-REFRESH] Selected GATT device:\nname=${btDevice.name}\naddress=${btDevice.address}")
                    bleDiscoveryManager?.discover(btDevice, forceRefresh = true)
                } else {
                    TrackingEventBroker.sendEvent(mapOf(
                        "type" to "BLE_DIAGNOSTIC_STATE",
                        "deviceId" to address,
                        "state" to "ERROR",
                        "message" to "BluetoothAdapter.getRemoteDevice returned null",
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
            } else {
                TrackingEventBroker.sendEvent(mapOf(
                    "type" to "BLE_DIAGNOSTIC_STATE",
                    "deviceId" to "unknown",
                    "state" to "ERROR",
                    "message" to "No address provided to ACTION_START_BLE_DIAGNOSTIC",
                    "timestamp" to System.currentTimeMillis()
                ))
            }
            // Allow to fall through so startForeground() is always called
        }
        if (intent?.action == ACTION_SYNC_STATE) {
            Log.i(TAG, "[BLE-LIFECYCLE] Sync state requested")
            if (isInitialized) {
                TrackingEventBroker.sendEvent(mapOf(
                    "type" to "SYNC_STATE",
                    "connectedDevices" to connectedDevices.values.toList(),
                    "isPlaying" to (lastIsPlaying ?: false),
                    "timestamp" to System.currentTimeMillis()
                ))
            }
            // Allow to fall through so startForeground() is always called
        }

        // Always ensure startForeground is called to satisfy Android 12+ requirements
        // when startForegroundService is used, even if already initialized.
        createNotificationChannel()
        var foregroundServiceType = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            foregroundServiceType = android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        }
        try {
            startForeground(notificationId, createNotification(), foregroundServiceType)
        } catch (e: SecurityException) {
            Log.e(TAG, "[SECURITY] Failed to start foreground service: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        if (!isInitialized) {
            Log.i(TAG, "SERVICE_RUNNING")

            Thread {
                try {
                    initBluetoothA2dp()
                    registerCallbacks()
                    checkInitialAudioState()
                } catch (e: Exception) {
                    Log.e(TAG, "[STARTUP] Exception during background initialization: ${e.message}")
                }
            }.start()
            isInitialized = true
        }
        
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "SERVICE_DESTROYED")
        if (isInitialized) {
            unregisterCallbacks()
            cleanupBluetoothA2dp()
        }
    }

    override fun onBind(intent: Intent): IBinder? = null

    private fun initBluetoothA2dp() {
        try {
            bluetoothAdapter?.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    if (profile == BluetoothProfile.A2DP) {
                        a2dpProxy = proxy as BluetoothA2dp
                        Log.d(TAG, "[DIAGNOSTIC] BluetoothA2dp proxy connected.")
                        compareSources()
                    }
                }

                override fun onServiceDisconnected(profile: Int) {
                    if (profile == BluetoothProfile.A2DP) {
                        a2dpProxy = null
                        Log.d(TAG, "[DIAGNOSTIC] BluetoothA2dp proxy disconnected.")
                    }
                }
            }, BluetoothProfile.A2DP)
        } catch (e: Exception) {
            Log.e(TAG, "[DIAGNOSTIC] Exception binding A2DP profile: ${e.message}")
        }
    }

    private fun cleanupBluetoothA2dp() {
        try {
            a2dpProxy?.let {
                bluetoothAdapter?.closeProfileProxy(BluetoothProfile.A2DP, it)
            }
        } catch (e: Exception) {
            Log.e(TAG, "[DIAGNOSTIC] Exception closing A2DP proxy: ${e.message}")
        }
    }

    private fun compareSources() {
        Log.d(TAG, "[DIAGNOSTIC] --- COMPARING SOURCE A (AudioManager) vs SOURCE B (BluetoothA2dp) ---")
        
        val amDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .filter { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }
        
        Log.d(TAG, "[DIAGNOSTIC] SOURCE A: AudioManager A2DP Output Devices: ${amDevices.size}")
        amDevices.forEach { device ->
            val addr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) device.address else "N/A"
            Log.d(TAG, "[DIAGNOSTIC]   A-> type=bt_a2dp, id=${device.id}, name='${device.productName}', addr='$addr'")
        }

        val btDevices = try {
            a2dpProxy?.connectedDevices ?: emptyList()
        } catch (e: SecurityException) {
            Log.e(TAG, "[DIAGNOSTIC] SOURCE B: SecurityException accessing A2DP connected devices.")
            emptyList<BluetoothDevice>()
        }

        Log.d(TAG, "[DIAGNOSTIC] SOURCE B: BluetoothA2dp Connected Devices: ${btDevices.size}")
        btDevices.forEach { bd ->
            val name = try { bd.name } catch (e: SecurityException) { "PermDenied" }
            val alias = try { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) bd.alias else null } catch (e: SecurityException) { null }
            val addr = bd.address
            Log.d(TAG, "[DIAGNOSTIC]   B-> name='$name', alias='$alias', addr='$addr'")
        }

        Log.d(TAG, "[DIAGNOSTIC] --- END COMPARISON ---")

        // Retrigger check just in case A2DP proxy connected after initial enumeration
        checkInitialAudioState()
    }

    private fun getBestBluetoothDeviceInfo(): Pair<String?, String?> {
        val bd = try {
            a2dpProxy?.connectedDevices?.firstOrNull()
        } catch (e: SecurityException) {
            null
        }
        if (bd != null) {
            val name = try { bd.name } catch (e: SecurityException) { null }
            val alias = try { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) bd.alias else null } catch (e: SecurityException) { null }
            val addr = bd.address
            return Pair(alias ?: name, addr)
        }
        
        // If not A2DP, try to find any connected bonded device that might be LE Audio
        try {
            val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val leDevices = btManager.getConnectedDevices(BluetoothProfile.GATT)
            val leDevice = leDevices.firstOrNull()
            if (leDevice != null) {
                val name = try { leDevice.name } catch (e: SecurityException) { null }
                val alias = try { if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) leDevice.alias else null } catch (e: SecurityException) { null }
                return Pair(alias ?: name, leDevice.address)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "[DIAGNOSTIC] SecurityException checking GATT connected devices.")
        }
        
        return Pair(null, null)
    }

    private fun registerCallbacks() {
        audioManager.registerAudioDeviceCallback(deviceCallback, null)
        Log.i(TAG, "[CALLBACK] AudioDeviceCallback registered")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            playbackCallback = object : AudioPlaybackCallback() {
                override fun onPlaybackConfigChanged(configs: List<AudioPlaybackConfiguration>?) {
                    handlePlaybackConfigs(configs)
                }
            }
            audioManager.registerAudioPlaybackCallback(playbackCallback!!, null)
            Log.i(TAG, "[CALLBACK] AudioPlaybackCallback registered")
        }
    }

    private fun unregisterCallbacks() {
        audioManager.unregisterAudioDeviceCallback(deviceCallback)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            playbackCallback?.let { audioManager.unregisterAudioPlaybackCallback(it) }
        }
    }

    private fun checkInitialAudioState() {
        Log.i(TAG, "[INITIAL_SCAN] started")
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        
        Log.i(TAG, "[INITIAL_SCAN] output device count = ${devices.size}")
        
        val activeDeviceList = mutableListOf<Map<String, Any?>>()

        devices.forEach { device ->
            val passedFilter = AudioDeviceDetector.isExternalListeningDevice(device)
            
            if (passedFilter) {
                Log.i(TAG, "[INITIAL_SCAN] compatible device = ${device.productName}")
                val info = handleDeviceAdded(device, "INITIAL_SCAN")
                if (info != null) {
                    activeDeviceList.add(info)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val configs = audioManager.activePlaybackConfigurations
            lastIsPlaying = configs?.isNotEmpty() == true
        } else {
            @Suppress("DEPRECATION")
            lastIsPlaying = audioManager.isMusicActive
        }

        Log.i(TAG, "INITIAL_SCAN_EXECUTED. Emitting SYNC_STATE.")
        
        TrackingEventBroker.sendEvent(mapOf(
            "type" to "SYNC_STATE",
            "connectedDevices" to activeDeviceList,
            "isPlaying" to (lastIsPlaying ?: false),
            "timestamp" to System.currentTimeMillis()
        ))
    }

    private var lastIsPlaying: Boolean? = null

    private fun handlePlaybackConfigs(configs: List<AudioPlaybackConfiguration>?) {
        val isPlaying = configs?.isNotEmpty() == true
        handlePlaybackStateChanged(isPlaying)
    }

    private fun handlePlaybackStateChanged(isPlaying: Boolean) {
        Log.d(TAG, "[DUPCHECK] playback state before = $lastIsPlaying")
        Log.d(TAG, "[DUPCHECK] playback state after = $isPlaying")

        if (isPlaying == lastIsPlaying) {
            Log.d(TAG, "[DUPCHECK] duplicate ignored = true")
            return
        }
        
        Log.d(TAG, "[DUPCHECK] duplicate ignored = false")
        lastIsPlaying = isPlaying

        val state = if (isPlaying) "PLAYBACK_STARTED" else "PLAYBACK_PAUSED"
        Log.i(TAG, "[PLAYBACK] EVENT_RECEIVED")
        Log.i(TAG, "[PLAYBACK] STATE=$state")

        // Identify the connected device for this playback event
        val activeDevice = connectedDevices.values.firstOrNull()
        val deviceId = activeDevice?.get("id") as? String
        val deviceName = activeDevice?.get("friendlyName") as? String
        val address = activeDevice?.get("hardwareAddress") as? String

        Log.i(TAG, "[PLAYBACK] DEVICE=$deviceName")
        Log.i(TAG, "[PLAYBACK] DEVICE_ADDRESS=$address")
        
        val eventTime = System.currentTimeMillis()
        Log.i(TAG, "[PLAYBACK] TIMESTAMP=$eventTime")

        val eventMap = mutableMapOf<String, Any>(
            "type" to state,
            "timestamp" to eventTime
        )
        
        if (deviceId != null) {
            eventMap["deviceId"] = deviceId
            eventMap["device"] = activeDevice
        }

        TrackingEventBroker.sendEvent(eventMap)
    }

    private fun handleDeviceAdded(device: AudioDeviceInfo, context: String = "CALLBACK"): Map<String, Any?>? {
        // If it's a Bluetooth device, we use SOURCE B to inject real name/mac if Android obscured it in SOURCE A
        val isBluetooth = device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || 
                          device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                          device.type == 26 || device.type == 27 || device.type == 30
        val (fallbackName, fallbackAddress) = if (isBluetooth) getBestBluetoothDeviceInfo() else Pair(null, null)

        val info = AudioDeviceDetector.extractDeviceInfo(device, fallbackName, fallbackAddress)
        val id = info["id"] as String
        val name = info["friendlyName"] as? String ?: "null"
        val type = info["nativeType"] as? Int ?: -1
        
        Log.i(TAG, "[NATIVE_DEVICE]\nDetected:\nname=$name\ntype=$type\nid=$id")
        
        if (context == "INITIAL_SCAN") {
            Log.i(TAG, "[INITIAL_SCAN] creating AudioDevice")
        }
        
        if (!connectedDevices.containsKey(id)) {
            connectedDevices[id] = info
            
            val eventMap = mapOf(
                "type" to "DEVICE_CONNECTED",
                "device" to info,
                "timestamp" to System.currentTimeMillis()
            )
            Log.i(TAG, "[NATIVE_EVENT]\nDEVICE_CONNECTED created")
            if (context == "INITIAL_SCAN") {
                Log.i(TAG, "[INITIAL_SCAN] emitting DEVICE_CONNECTED")
            }
            TrackingEventBroker.sendEvent(eventMap)

            // Trigger BLE discovery if we have a valid MAC address
            val hardwareAddress = info["hardwareAddress"] as? String
            if (hardwareAddress != null && hardwareAddress != "null") {
                val btDevice = bluetoothAdapter?.getRemoteDevice(hardwareAddress)
                if (btDevice != null) {
                    bleDiscoveryManager?.discover(btDevice)
                }
            }
            return info
        } else {
            Log.i(TAG, "Device $id is already tracked. Ignoring duplicate.")
            return connectedDevices[id]
        }
    }

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            Log.d(TAG, "[DIAGNOSTIC] onAudioDevicesAdded: ${addedDevices?.size ?: 0} devices")
            addedDevices?.forEach { device ->
                AudioDeviceDetector.logDeviceDiagnostic(device, "DEVICES_ADDED_CALLBACK")
                
                val passedFilter = AudioDeviceDetector.isExternalListeningDevice(device)
                Log.d(TAG, "[POST_FILTER_TRACE] DEVICES_ADDED_CALLBACK isExternalListeningDevice() -> $passedFilter")
                
                if (passedFilter) {
                    // Try to update A2DP sources first just in case
                    if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP && a2dpProxy != null) {
                        compareSources()
                    }
                    handleDeviceAdded(device, "CALLBACK")
                }
            }
        }

        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            Log.d(TAG, "[DIAGNOSTIC] onAudioDevicesRemoved: ${removedDevices?.size ?: 0} devices")
            removedDevices?.forEach { device ->
                AudioDeviceDetector.logDeviceDiagnostic(device, "DEVICES_REMOVED_CALLBACK")
                
                // If it's a Bluetooth device, provide the fallback
                val isBluetooth = device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || 
                                  device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                                  device.type == 26 || device.type == 27 || device.type == 30
                val (fallbackName, fallbackAddress) = if (isBluetooth) getBestBluetoothDeviceInfo() else Pair(null, null)

                val info = AudioDeviceDetector.extractDeviceInfo(device, fallbackName, fallbackAddress)
                val id = info["id"] as String
                
                if (connectedDevices.containsKey(id)) {
                    connectedDevices.remove(id)
                    val eventMap = mapOf(
                        "type" to "DEVICE_DISCONNECTED",
                        "deviceId" to id,
                        "timestamp" to System.currentTimeMillis()
                    )
                    TrackingEventBroker.sendEvent(eventMap)
                }
            }
        }
    }

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
        .setSmallIcon(android.R.drawable.ic_media_play) // Use a built-in icon for now
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()
}
