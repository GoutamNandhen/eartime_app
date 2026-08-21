# Phase 6: A2 Identity Analysis & Reopen Failure Diagnosis

## 1. New Startup Failure Exception
There is **NO** Android crash or `SecurityException`. The app failing to reopen reliably was caused by an infinite `cancelAndRedraw` loop within the Flutter ViewRootImpl.
- **Cause**: In the previous permission flow, `Future.microtask(() => checkPermissions())` was firing immediately upon provider initialization. This caused `permission_handler` (a native MethodChannel) to block the Flutter Engine *before* the first frame could be rendered, leading Android to constantly cancel the view traversal.
- **Status**: I already patched this by switching to `WidgetsBinding.instance.addPostFrameCallback` in `permission_provider.dart`. The UI now mounts successfully on cold-starts.

## 2. Whether G Regressed
**No regression.** The `try-catch` around `startForeground()` correctly prevents the `SecurityException` from crashing the app, and the service lifecycle respects the Flutter UI permission gate.

## 3. Exact A2 Event Sequence
When you connect the earbuds without playback:
1. Earbuds connect via **A2DP**.
2. `onAudioDevicesAdded` fires -> Maps to logical ID (MAC address) -> Emits `DEVICE_CONNECTED`.
3. Earbuds immediately connect a secondary route (e.g., **SCO** or LE Audio).
4. `onAudioDevicesAdded` fires -> Maps to the *same* logical ID -> Ignored as duplicate.
5. Android OS performs internal routing optimization and **removes** the secondary SCO route because there is no active voice call.
6. `onAudioDevicesRemoved` fires for the SCO route.
7. The service maps the SCO route to the logical ID (MAC) and blindly deletes it from `connectedDevices`, emitting `DEVICE_DISCONNECTED`.

## 4. Root Cause of A2
Multiple native audio routes (A2DP, SCO, BLE) share the same physical MAC address and therefore the same logical ID in `AudioDeviceDetector`. `onAudioDevicesRemoved` does not verify if the physical device still has *other* active routes. It blindly evicts the logical ID the moment *any* single route is removed. 

## 5. Files/Functions Responsible
- **File**: `android/app/src/main/kotlin/com/eartime/eartime_app/tracking/AudioTrackingService.kt`
- **Function**: `onAudioDevicesRemoved` callback inside `deviceCallback`.

## 6. Minimal Fix Required
We must update `onAudioDevicesRemoved` to verify that no active output routes remain for the logical ID before evicting it.

### Proposed Changes

#### [MODIFY] [AudioTrackingService.kt](file:///f:/projects/eartime_flutter/eartime_app/android/app/src/main/kotlin/com/eartime/eartime_app/tracking/AudioTrackingService.kt)
Update the `onAudioDevicesRemoved` block to query the `audioManager`:
```kotlin
if (connectedDevices.containsKey(id)) {
    // VERIFY: Are there any remaining output routes for this physical device?
    val activeOutputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    val stillConnected = activeOutputs.any { activeDevice ->
        AudioDeviceDetector.isExternalListeningDevice(activeDevice) &&
        AudioDeviceDetector.extractDeviceInfo(activeDevice, fallbackName, fallbackAddress)["id"] == id
    }

    if (!stillConnected) {
        connectedDevices.remove(id)
        val eventMap = mapOf(
            "type" to "DEVICE_DISCONNECTED",
            "deviceId" to id,
            "timestamp" to System.currentTimeMillis()
        )
        TrackingEventBroker.sendEvent(eventMap)
    } else {
        Log.i(TAG, "Device $id had a route removed, but another route remains active. Ignoring disconnect.")
    }
}
```

## User Review Required
Please review the diagnosis. Do I have your approval to implement this minimal fix for A2 and then proceed with B?
