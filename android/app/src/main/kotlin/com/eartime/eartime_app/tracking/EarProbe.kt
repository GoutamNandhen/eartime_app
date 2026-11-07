package com.eartime.eartime_app.tracking

import android.annotation.SuppressLint
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * B8/B9 research probe. Strictly passive and user-started: it listens to BLE advertisements, public Bluetooth
 * broadcasts and the global music-active flag while the user marks bud in/out moments. It never connects,
 * pairs, reads, subscribes or writes. Addresses are replaced by per-session salted hashes, nothing is
 * journaled, and the report exists only in memory until the user copies it.
 */
internal class EarProbe(private val context: Context) {
    data class Event(val atMs: Long, val source: String, val device: String, val field: String,
        val old: String?, val value: String, val rssi: Int?)
    data class Mark(val atMs: Long, val label: String)

    companion object {
        const val MAX_DURATION_MS = 300_000L
        const val MIN_RSSI = -75
        const val MAX_EVENTS = 3000
        const val MAX_DEVICES = 64
        const val MARK_WINDOW_MS = 6000L
        private const val VENDOR_CATEGORY = "android.bluetooth.headset.intent.category.companyid."

        fun hex(bytes: ByteArray?): String = bytes?.joinToString("") { "%02x".format(it) } ?: ""

        /**
         * Scores each (device, field) by how many of its value changes land within [MARK_WINDOW_MS] after a
         * mark versus elsewhere. A field that changes only around the user's marks is a candidate in-ear signal.
         */
        fun analyse(events: List<Event>, marks: List<Mark>): List<Map<String, Any?>> {
            if (marks.isEmpty()) return emptyList()
            return events.filter { it.old != null }.groupBy { it.device to it.field }.mapNotNull { (key, changes) ->
                val near = changes.count { change -> marks.any { change.atMs - it.atMs in 0..MARK_WINDOW_MS } }
                val marked = marks.count { mark -> changes.any { it.atMs - mark.atMs in 0..MARK_WINDOW_MS } }
                if (near == 0) null else mapOf("device" to key.first, "field" to key.second, "changes" to changes.size,
                    "nearMarks" to near, "marksExplained" to marked,
                    "score" to (marked.toDouble() / marks.size) * (near.toDouble() / changes.size))
            }.sortedByDescending { it["score"] as Double }.take(12)
        }

        /** Byte positions that differ between two equal-length hex payloads, for the human-readable report. */
        fun diff(old: String?, value: String): String {
            if (old == null || old.length != value.length) return ""
            return (0 until value.length / 2).filter { old.substring(it * 2, it * 2 + 2) != value.substring(it * 2, it * 2 + 2) }
                .joinToString(",") { "b$it" }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
    private val events = mutableListOf<Event>()
    private val marks = mutableListOf<Mark>()
    private val last = HashMap<Pair<String, String>, String>()
    private val devices = LinkedHashMap<String, String?>()
    private val receivers = mutableListOf<BroadcastReceiver>()
    private var startElapsed = 0L
    private var running = false
    private var dropped = 0
    private var musicActive: Boolean? = null
    private var scanCallback: ScanCallback? = null
    private var scanStatus = "not_started"

    private fun now() = SystemClock.elapsedRealtime() - startElapsed
    private fun alias(address: String?): String {
        if (address == null) return "unknown"
        devices[address]?.let { return it }
        if (devices.size >= MAX_DEVICES) return "other"
        val digest = MessageDigest.getInstance("SHA-256").apply { update(salt); update(address.toByteArray()) }.digest()
        return "dev-" + hex(digest).take(8)
    }

    @Synchronized private fun record(source: String, address: String?, field: String, value: String, rssi: Int?) {
        if (!running) return
        val device = alias(address)
        if (address != null && address !in devices && devices.size < MAX_DEVICES) devices[address] = device
        val key = device to field
        val old = last[key]
        if (old == value) return
        last[key] = value
        if (events.size >= MAX_EVENTS) { dropped++; return }
        events.add(Event(now(), source, device, field, old, value, rssi))
    }

    private fun granted(permission: String) = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    @Synchronized fun start(durationMs: Long): Map<String, Any?> {
        check(!running) { "Probe already running" }
        require(durationMs in 10_000..MAX_DURATION_MS)
        if (Build.VERSION.SDK_INT >= 31 && !granted(android.Manifest.permission.BLUETOOTH_CONNECT))
            throw IllegalStateException("Nearby devices permission is required")
        events.clear(); marks.clear(); last.clear(); devices.clear(); dropped = 0; musicActive = null
        startElapsed = SystemClock.elapsedRealtime(); running = true
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        // Public broadcasts: playback state, connection, battery (where the platform shares it) and HFP vendor events.
        val filter = IntentFilter().apply {
            addAction(BluetoothA2dp.ACTION_PLAYING_STATE_CHANGED)
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED); addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction("android.bluetooth.device.action.BATTERY_LEVEL_CHANGED")
        }
        val receiver = object : BroadcastReceiver() {
            @SuppressLint("MissingPermission")
            override fun onReceive(ctx: Context, intent: Intent) {
                val device = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    else @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                val address = device?.address
                when (intent.action) {
                    BluetoothA2dp.ACTION_PLAYING_STATE_CHANGED -> record("a2dp", address, "playing",
                        if (intent.getIntExtra(BluetoothProfileState.EXTRA_STATE, -1) == BluetoothA2dp.STATE_PLAYING) "PLAYING" else "NOT_PLAYING", null)
                    BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED -> record("a2dp", address, "connection",
                        intent.getIntExtra(BluetoothProfileState.EXTRA_STATE, -1).toString(), null)
                    BluetoothDevice.ACTION_ACL_CONNECTED -> record("acl", address, "acl", "CONNECTED", null)
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> record("acl", address, "acl", "DISCONNECTED", null)
                    "android.bluetooth.device.action.BATTERY_LEVEL_CHANGED" -> record("battery", address, "battery",
                        intent.getIntExtra("android.bluetooth.device.extra.BATTERY_LEVEL", -1).toString(), null)
                    BluetoothHeadset.ACTION_VENDOR_SPECIFIC_HEADSET_EVENT -> {
                        val command = intent.getStringExtra(BluetoothHeadset.EXTRA_VENDOR_SPECIFIC_HEADSET_EVENT_CMD) ?: "?"
                        val args = (intent.extras?.get(BluetoothHeadset.EXTRA_VENDOR_SPECIFIC_HEADSET_EVENT_ARGS) as? Array<*>)
                            ?.joinToString(",") { it.toString().take(32) } ?: ""
                        record("hfp_vendor", address, "at:${command.take(32)}", args.take(256), null)
                    }
                }
            }
        }
        fun register(value: IntentFilter) {
            if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, value, Context.RECEIVER_EXPORTED)
            else context.registerReceiver(receiver, value)
        }
        register(filter)
        // Vendor AT events carry a company-id category; an intent only matches filters listing its category.
        for (block in 0 until 4) {
            register(IntentFilter(BluetoothHeadset.ACTION_VENDOR_SPECIFIC_HEADSET_EVENT).apply {
                for (id in block * 512 until (block + 1) * 512) addCategory(VENDOR_CATEGORY + id)
            })
        }
        receivers.add(receiver)
        // Bonded audio devices: name and classic service UUIDs only (no address leaves the probe).
        val bonded = try {
            adapter?.bondedDevices?.filter { it.bluetoothClass?.majorDeviceClass == BluetoothClass.Device.Major.AUDIO_VIDEO }
                ?.take(8)?.map { device ->
                    mapOf<String, Any?>("device" to alias(device.address).also { devices[device.address] = it },
                        "name" to (device.name ?: "").take(64), "uuids" to (device.uuids?.map { it.toString() } ?: emptyList()))
                } ?: emptyList()
        } catch (_: SecurityException) { emptyList() }
        // BLE advertisements from nearby devices (strong signal only, so the buds dominate).
        scanStatus = if (Build.VERSION.SDK_INT < 31) "unsupported_before_android_12"
            else if (!granted(android.Manifest.permission.BLUETOOTH_SCAN)) "permission_denied"
            else try {
                val scanner = adapter?.bluetoothLeScanner ?: throw IllegalStateException()
                val callback = object : ScanCallback() {
                    override fun onScanResult(callbackType: Int, result: ScanResult) {
                        if (result.rssi < MIN_RSSI) return
                        val record = result.scanRecord ?: return
                        val address = result.device?.address
                        val manufacturer = record.manufacturerSpecificData
                        for (index in 0 until (manufacturer?.size() ?: 0))
                            record("ble", address, "mfr:%04x".format(manufacturer!!.keyAt(index)), hex(manufacturer.valueAt(index)).take(128), result.rssi)
                        record.serviceData?.forEach { (uuid, data) ->
                            record("ble", address, "svc:${uuid.uuid.toString().take(8)}", hex(data).take(128), result.rssi)
                        }
                    }
                    override fun onScanFailed(errorCode: Int) { scanStatus = "failed_$errorCode" }
                }
                scanner.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), callback)
                scanCallback = callback
                "scanning"
            } catch (_: Exception) { "unavailable" }
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val poll = object : Runnable {
            override fun run() {
                if (!running) return
                val active = audio?.isMusicActive
                if (active != null && active != musicActive) { musicActive = active; record("audio", null, "musicActive", active.toString(), null) }
                if (now() >= durationMs) stop() else main.postDelayed(this, 500)
            }
        }
        main.post(poll)
        return mapOf("scan" to scanStatus, "bonded" to bonded, "durationMs" to durationMs)
    }

    @Synchronized fun mark(label: String) {
        require(label.length in 1..32 && label.none { Character.isISOControl(it) })
        if (running && marks.size < 200) marks.add(Mark(now(), label))
    }

    @SuppressLint("MissingPermission")
    @Synchronized fun stop(): Map<String, Any?> {
        if (running) {
            running = false
            receivers.forEach { runCatching { context.unregisterReceiver(it) } }; receivers.clear()
            scanCallback?.let { callback ->
                runCatching { (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter?.bluetoothLeScanner?.stopScan(callback) }
            }
            scanCallback = null
        }
        val candidates = analyse(events, marks)
        val text = buildString {
            appendLine("EarTime ear probe v1, scan=$scanStatus, events=${events.size}, dropped=$dropped, marks=${marks.size}")
            marks.forEach { appendLine("MARK %7.1fs %s".format(it.atMs / 1000.0, it.label)) }
            appendLine("CANDIDATES")
            candidates.forEach { appendLine("  ${it["device"]} ${it["field"]} changes=${it["changes"]} nearMarks=${it["nearMarks"]} explained=${it["marksExplained"]}") }
            appendLine("EVENTS")
            events.forEach {
                appendLine("%7.1fs %s %s %s %s%s%s".format(it.atMs / 1000.0, it.source, it.device, it.field, it.value,
                    diff(it.old, it.value).let { d -> if (d.isEmpty()) "" else " [$d]" }, it.rssi?.let { r -> " rssi=$r" } ?: ""))
            }
        }
        return mapOf("running" to false, "scan" to scanStatus, "eventCount" to events.size, "dropped" to dropped,
            "marks" to marks.map { mapOf("atMs" to it.atMs, "label" to it.label) },
            "candidates" to candidates, "report" to text.take(400_000))
    }
}

/** EXTRA_STATE shared by Bluetooth profile broadcasts. */
private object BluetoothProfileState { const val EXTRA_STATE = android.bluetooth.BluetoothProfile.EXTRA_STATE }
