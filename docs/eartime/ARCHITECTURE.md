# Architecture

## Dual-Layer System
EarTime relies on a persistent native background layer and a Flutter UI layer.

### 1. Native Android (`AudioTrackingService`)
- A foreground service ensuring EarTime is never killed. (Requires Android 12+ `startForeground` enforcement to prevent `ForegroundServiceDidNotStartInTimeException` upon app reopening).
- Uses `AudioManager` and `AudioDeviceCallback` to monitor when the earbuds connect or disconnect (robustly filtering out transient SCO routes).
- Monitors `AudioPlaybackCallback` to track music play/pause states.
- Identifies devices using `AudioDeviceInfo` and maps them to Bluetooth MACs using the `BluetoothA2dp` proxy.
- Broadcasts real-time events over a Flutter `EventChannel` (`TrackingEventBroker`).
- **BLE Diagnostic Pipeline**: Runs `BleDiscoveryManager` to perform GATT connections and stream raw BLE notifications (OPOv1 packets).

### 2. Flutter UI Layer
- **Live Session State**: `LiveSessionNotifier` acts as the *single source of truth* for the current live session. It listens to the `EventChannel` and updates memory immediately, avoiding database latency or persistence mismatches.
- **Database (Drift)**: The `trackingPipelineProvider` simultaneously inserts tracking events into a local SQLite DB for historical analysis and the Timeline view.
- **State Management**: `flutter_riverpod` provides reactive updates to the UI, particularly `LiveTimerWidget` and `HomeScreen`.

## Event Architecture
All events flow one way:
`Android OS` → `AudioTrackingService` → `TrackingEventBroker (EventChannel)` → `trackingPipelineProvider (Dart)` → `LiveSessionNotifier` / `Drift Database`.

## Phase 6 Fixes (A/B Issues Resolved)
* Confirmed SYNC_STATE contract bug where Kotlin sent connectedDevices at the root of the JSON map instead of inside the device key, causing Dart to falsely evaluate connected devices as empty.
* Confirmed Multi-Route Removal Bug where removing an SCO route falsely removed the physical device identity from connectedDevices, even if the A2DP route was still active.
* Exact Fixes: 
    * Wrapped SYNC_STATE payload inside a device key in Kotlin.
    * Modified onAudioDevicesRemoved to ensure no other remaining AudioManager output devices map to the same stableId before emitting DEVICE_DISCONNECTED.
* Tests added: Dart unit tests for TrackingEvent JSON deserialization.
* Current A/B Status: Fixes implemented. Ready for physical testing.
* Current G Status: Remains PASS.
