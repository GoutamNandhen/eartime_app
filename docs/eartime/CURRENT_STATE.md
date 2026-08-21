# EarTime: Current State & Project Memory

## 1. Project Identity
**Project Name**: EarTime
**Description**: A Flutter application for tracking Bluetooth earbud usage (ambient listening time) with native Android Foreground Service integration for background monitoring.

## 2. Current Git Baseline
**Baseline Commit**: `baseline-phase6-debug-state`
**Status**: Pre-release / Phase 6 Debugging. Clean working tree.

## 3. Current Phase
**Phase 6 Debugging** (Stabilizing A/B/D/E test matrix and Foreground Service initialization).

## 4. Complete Architecture
EarTime uses a hybrid architecture:
- **Native Android**: A persistent Foreground Service (`AudioTrackingService`) monitors audio and Bluetooth changes via native callbacks.
- **Platform Bridge**: An `EventChannel` streams native audio tracking events to Flutter.
- **Flutter Domain**: A Riverpod-based pipeline processes raw events, builds a `LiveSessionState`, and manages database persistence via Drift.

## 5. Native Android Architecture
- `MainActivity.kt`: Entry point. Requests `BLUETOOTH_CONNECT` permission (Android 12+) and launches `AudioTrackingService`. Provides Method/EventChannels.
- `AudioTrackingService.kt`: Persistent Foreground Service. Uses `AudioDeviceCallback` and `AudioPlaybackCallback` to monitor device connections and media playback. Tracks logical connections in `connectedDevices`.
- `AudioDeviceDetector.kt`: Filters devices (e.g., verifying `isSink`). Extracts stable `id` and friendly names.
- `BleDiscoveryManager.kt`: Probes BLE characteristics (like OPOv1 on OnePlus devices) for extended capabilities.
- `TrackingEventBroker.kt`: Pipes events from the service to the `EventSink` on the Flutter side.

## 6. Flutter Architecture
- **UI Layer**: Glassmorphic UI (vibrant colors, blur effects) composed of AppShell, HomeScreen, TimelineScreen, etc.
- **State Management**: Riverpod (`Notifier` and `Provider`).
- **Data Persistence**: Drift SQLite database (`Database` class).
- **Domain Layer**: Models for `LiveSessionState`, `TrackingEvent`, `AudioDevice`.

## 7. EventChannel Architecture
- Native `EventChannel` named `com.eartime.app/tracking_events`.
- Emits JSON payloads (`SYNC_STATE`, `DEVICE_CONNECTED`, `DEVICE_DISCONNECTED`, `PLAYBACK_STARTED`, `PLAYBACK_PAUSED`).
- Received by `TrackingPlatform.eventStream` and parsed into `TrackingEvent` objects.

## 8. Riverpod/State Architecture
- `trackingPipelineProvider`: Subscribes to `TrackingPlatform.eventStream`. Feeds events to `LiveSessionNotifier`.
- `LiveSessionNotifier` (`liveSessionProvider`): Maintains real-time `LiveSessionState`. Parses events and delegates persistence to `SessionManager`.
- `SessionManager`: Handles database commits for new sessions, updates, and closure.
- `PermissionNotifier`: Gates app access until permissions are granted.

## 9. Drift/Database Architecture
- Uses `drift` with SQLite3.
- Tables: `AudioDevices`, `ListeningSessions`, `ListeningEvents`.
- Dao pattern implicit in `Database` queries.

## 10. BLE Architecture
- Uses native Android `BluetoothGatt` inside `BleDiscoveryManager`.
- Probes specific UUIDs for battery, wearing state, and capabilities.

## 11. Widget Architecture
- **AppShell**: Root scaffold with floating `GlassNavigation`. Integrates `PermissionScreen` as a gatekeeper.
- **LiveTimerWidget**: Reads `liveSessionProvider` to display real-time active duration. Uses a `Ticker` when playing.
- **DeviceRow**: Displays connected device with gradient rings and capability icons.

## 12. Earbud Left/Right Tracking Architecture
- Data model supports `leftWearing`, `rightWearing`, `leftBattery`, `rightBattery` inside `EarbudCapabilities`.
- Triggered by native BLE GATT characteristics (when available).

## 13. Implemented Features
- Real-time Android audio device monitoring.
- Native UI permission gate.
- Real-time Flutter UI state synchronization.
- SQLite persistence of historical sessions.
- Glassmorphic UI dashboard and timeline.

## 14. Known Bugs
- **Bug A2**: Earbud connects, appears on UI, then instantly disappears.
- **Bug B1/B2**: Unknown playback sync issues when reconnecting.
- **Bug B4**: UI state changes to PAUSED but LiveTimer continues ticking.
- **Bug D1/D2**: LiveTimer logic bugs relating to pausing and resuming.
- **Bug E2**: UI remains PAUSED while timer glitches.

## 15. Physical Test Matrix (Current State)
| Test | Action | Result |
|---|---|---|
| **A1** | Launch with earbuds disconnected | **PASS** |
| **A2** | Connect earbuds without playback | **FAIL** (Device appears, then disappears) |
| **A3** | Device remains visible after connection | **PASS** (If playback prevents A2 drop) |
| **A4** | Disconnect | **PASS** |
| **A5** | Timeline | **PASS** |
| **B1/B2** | (Reopen state sync) | **FAIL** (Under investigation) |
| **B3** | Playback causes device/session to appear | **PASS** |
| **B4** | Pause playback | **FAIL** (Timer continues) |
| **C1/C2**| Capabilities / Battery | **PASS** |
| **D1-D3**| Live Timer Tests | **FAIL** (Timer glitches/keeps running) |
| **E1-E2**| Play/Pause Transitions | **FAIL** (State desync) |
| **F** | Midnight Crossing | **PASS** |
| **G** | Startup Crash | **PASS** (Fixed UI lockup, FGS protected) |

## 16. Confirmed Findings
- **Startup Reopen Failure**: Confirmed to be a Flutter Engine `cancelAndRedraw` UI loop caused by calling `Future.microtask` for permissions before the first frame was drawn. FIXED by switching to `addPostFrameCallback`.
- **G Crash**: Confirmed Android 14 FGS `connectedDevice` requires `BLUETOOTH_CONNECT`. FIXED by adding a `try-catch` in native and a UI permission gate.
- **A2 Bug**: Confirmed that `AudioTrackingService` maps A2DP and SCO routes to the exact same logical ID. When Android removes the SCO route, the logical ID is evicted, incorrectly sending `DEVICE_DISCONNECTED` even though A2DP remains active.

## 17. Unconfirmed Hypotheses
- B, D, and E timer glitch bugs are currently hypothesized to be state management desyncs in `LiveSessionNotifier` or `LiveTimerWidget`, but have not been formally diagnosed through logs.

## 18. Current Investigation
- Fixing the **A2** identity bug by modifying `onAudioDevicesRemoved` to verify if other routes exist for the same MAC address before eviction.

## 19. Known Regressions
- None currently verified. G was hypothesized as a regression but proved to be a Flutter UI lockup.

## 20. Important Architectural Constraints
- **FGS Requirement**: Android 14 strictly mandates runtime permissions *before* launching the service.
- **Riverpod Sync**: The tracking pipeline must remain passive (`ref.watch`) in the background.

## 21. Files/Functions Associated With Subsystems
- **Audio Service**: `AudioTrackingService.kt`, `AudioDeviceDetector.kt`
- **Flutter UI**: `app_shell.dart`, `live_timer_widget.dart`
- **Flutter State**: `data_providers.dart`, `live_session_state.dart`
- **Database**: `database.dart`, `session_manager.dart`

## 22. Next Planned Investigation
- Implement the A2 identity fix in `AudioTrackingService.kt`.
- Diagnose the B4/D/E timer bugs by tracing `PLAYBACK_PAUSED` logic in `LiveSessionNotifier`.

## 23. Things That MUST NOT Be Changed Yet
- DO NOT modify Timer (D) or Playback Pause/Resume (E) logic.
- DO NOT modify Timeline persistence.
- DO NOT modify BLE discovery mechanisms.

## 24. Required Physical Verification
- A2 fix must be physically verified by connecting an earbud and observing if it stays on screen without playback.

## 25. Historical Architectural Decisions
- Switched from `StateNotifier` to `Notifier` (Riverpod 3.0+).
- Moved permission handling from Native to Flutter `PermissionScreen` to ensure user onboarding exists.

---
**FUTURE ENGINEERING RULE**: Every future feature, bug fix, architectural change, protocol change, state-model change, test, or important engineering discovery MUST update the persistent engineering documentation in the same implementation task. The documentation must contain enough information that the project can be handed to another AI agent after the conversation reaches its chat limit.