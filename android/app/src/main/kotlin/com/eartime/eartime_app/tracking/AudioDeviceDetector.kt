package com.eartime.eartime_app.tracking

import android.media.AudioDeviceInfo
import android.os.Build
import android.util.Log

object AudioDeviceDetector {

    private const val TAG = "EarTimeDiag"

    /**
     * Determines if the audio device is an external listening device that we care about.
     * Ignores built-in speakers, earpieces, and internal virtual A2DP routes (e.g. CPH2447).
     */
    fun isExternalListeningDevice(device: AudioDeviceInfo): Boolean {
        val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.address
        } else {
            "N/A"
        }
        val name = device.productName?.toString() ?: "null"
        
        Log.i(TAG, "[DETECTOR] examining device\nname=$name\ntype=${device.type}\naddress=$address\nid=${device.id}\nsink=${device.isSink}\nsource=${device.isSource}")

        if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP && device.isSink) {
            Log.i(TAG, "[DETECTOR] *** NORD_BUDS_CANDIDATE_FOUND ***")
        }

        // SINK CHECK
        if (!device.isSink) {
            Log.i(TAG, "[DETECTOR] sink check = FAIL")
            Log.i(TAG, "[DETECTOR] exact reason if rejected: Device is not an output sink")
            Log.i(TAG, "[DETECTOR] compatibility result = FAIL")
            return false
        }
        Log.i(TAG, "[DETECTOR] sink check = PASS")

        val type = device.type
        val isBluetooth = type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || 
                          type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                          type == 26 || // TYPE_BLE_HEADSET
                          type == 27 || // TYPE_BLE_SPEAKER
                          type == 30    // TYPE_BLE_BROADCAST
                          
        // ADDRESS CHECK
        if (isBluetooth) {
            if (address.isNullOrEmpty() || address == "00:00:00:00:00:00") {
                Log.w(TAG, "[DETECTOR] address check = WARN (Missing or zeroed MAC address)")
            } else {
                Log.i(TAG, "[DETECTOR] address check = PASS")
            }
        } else {
            Log.i(TAG, "[DETECTOR] address check = N/A (Not BT)")
        }

        // TYPE CHECK
        val isValidType = when (type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            26, 27, 30, // Android 13+ BLE Audio types
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> true
            else -> false
        }

        if (!isValidType) {
            Log.i(TAG, "[DETECTOR] type check = FAIL")
            Log.i(TAG, "[DETECTOR] exact reason if rejected: Unsupported device type $type")
            Log.i(TAG, "[DETECTOR] compatibility result = FAIL")
            return false
        }
        Log.i(TAG, "[DETECTOR] type check = PASS")

        Log.i(TAG, "[DETECTOR] exact reason if accepted: Device passed all filters (type $type, isSink=true)")
        Log.i(TAG, "[DETECTOR] compatibility result = PASS")
        return true
    }

    /**
     * Maps Android AudioDeviceInfo to a string connection type.
     */
    fun getConnectionType(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            26, 27, 30 -> "bluetooth"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired"
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb"
            else -> "unknown"
        }
    }

    /** Returns [address] if it is a real, non-zero Bluetooth MAC, otherwise null. */
    fun validMacOrNull(address: String?): String? {
        if (address.isNullOrEmpty()) return null
        if (address == "00:00:00:00:00:00" || address == "02:00:00:00:00:00") return null
        return if (MAC_REGEX.matches(address)) address.uppercase() else null
    }

    private val MAC_REGEX = Regex("^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$")

    /**
     * Extracts structured device info to a Map.
     * Uses provided fallbackName/fallbackAddress if Android AudioManager obscures them.
     *
     * The logical id intentionally does NOT include the route type: the A2DP and SCO (or BLE)
     * routes of one earbud must collapse onto a single logical device.
     */
    fun extractDeviceInfo(
        device: AudioDeviceInfo,
        fallbackName: String? = null,
        fallbackAddress: String? = null
    ): Map<String, Any?> {
        val routeAddress = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) device.address else null
        val hardwareAddress = validMacOrNull(routeAddress) ?: validMacOrNull(fallbackAddress)

        // Prefer the Bluetooth-provided name (fallbackName) because Android's AudioManager
        // often incorrectly reports the system hardware model (e.g. CPH2447) instead of the earbud name.
        val name = fallbackName?.takeIf { it.isNotEmpty() }
            ?: device.productName?.toString()?.takeIf { it.isNotEmpty() }
            ?: "Bluetooth Audio Device"
        val connectionType = getConnectionType(device.type)

        // Use MAC address as stable ID if available, otherwise connection type + name.
        val stableId = hardwareAddress ?: "$connectionType:$name"

        val info = mapOf(
            "id" to stableId,
            "systemId" to device.id.toString(), // The volatile system route ID
            "hardwareAddress" to hardwareAddress,
            "friendlyName" to name,
            "connectionType" to connectionType,
            "nativeType" to device.type
        )
        Log.i(TAG, "[DETECTOR] Device model created: $info")
        return info
    }

    /**
     * Diagnostic logging for identifying devices on the physical hardware.
     */
    fun logDeviceDiagnostic(device: AudioDeviceInfo, context: String, reason: String = "") {
        // Obsolete, keeping empty or minimal to avoid duplicative logs
    }
}
