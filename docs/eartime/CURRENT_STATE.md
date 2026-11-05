# EarTime: Current State & Project Memory

## 1. Project Identity
**Project Name**: EarTime
**Description**: A Flutter application for tracking Bluetooth earbud usage (ambient listening time) with native Android Foreground Service integration for background monitoring.

## 2. Current Git Baseline
**Baseline Commit**: `baseline-phase6-debug-state`
**Status**: Pre-release / Phase 6. All review findings fixed on branch `fix/phase6-review` (2026-11-05); awaiting physical verification of Tests A–G.

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
- A2, B1/B2, B4, D1/D2, E2 and G have code fixes on `fix/phase6-review` (see CHANGELOG 2026-11-05). Not yet physically verified.
- Remaining limitation: `isMusicActive` is a global signal (see BUGS.md).

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

## 17. Root causes (confirmed in code review 2026-11-05)
- B: Kotlin sent SYNC_STATE fields at the root; Flutter read them from `device` → always empty.
- D/E: pause handler copied `currentPlaybackStartTime` forward; native also counted paused players as "playing".
- Random desync: every `TrackingPlatform.eventStream` access called `receiveBroadcastStream()`, so later subscribers stole the channel from the pipeline.

## 18. Current Investigation
- Physical verification of the fixes.

## 19. Known Regressions
- None known.

## 20. Important Architectural Constraints
- **FGS Requirement**: Android 14 strictly mandates runtime permissions *before* launching the service.
- **Single event stream**: never call `receiveBroadcastStream()` anywhere except `TrackingPlatform.eventStream`; consume via `trackingEventStreamProvider`.
- **Live vs persisted time**: Home shows closed DB intervals + the live interval; never add an open DB interval to the live timer.
- **Native threading**: tracking state in `AudioTrackingService` is main-thread only.

## 21. Files/Functions Associated With Subsystems
- **Audio Service**: `AudioTrackingService.kt`, `AudioDeviceDetector.kt`
- **Flutter state**: `providers/data_providers.dart` (`TrackingPipeline`), `domain/logic/live_session_reducer.dart`
- **Timeline/DB**: `domain/logic/session_manager.dart` (`SessionManager`, `SyncReconciler`), `data/database/database.dart`
- **Analytics/Wellbeing**: `domain/logic/analytics_calculator.dart`
- **UI**: `app_shell.dart`, `live_timer_widget.dart`

## 22. Next Planned Work
- Physically verify Tests A–G; then Phase 7 (historical charts).

## 23. Things That MUST NOT Be Changed Without Re-running Tests
- `LiveSessionReducer`, `SyncReconciler`, route tracking in `AudioTrackingService`.

## 24. Required Physical Verification
- A2: connect earbuds without playback; device must stay on screen (also during/after a call, which adds/removes the SCO route).
- B: kill the app from Recents with earbuds connected and playing, reopen; Home must show the device playing with the correct elapsed time.
- D/E: pause/resume several times; timer must stop on pause and resume from the accumulated total.
- G: reopen repeatedly after clearing from Recents; no crash.

## 25. Historical Architectural Decisions
- Switched from `StateNotifier` to `Notifier` (Riverpod 3.0+).
- Moved permission handling from Native to Flutter `PermissionScreen` to ensure user onboarding exists.

---
**FUTURE ENGINEERING RULE**: Every future feature, bug fix, architectural change, protocol change, state-model change, test, or important engineering discovery MUST update the persistent engineering documentation in the same implementation task. The documentation must contain enough information that the project can be handed to another AI agent after the conversation reaches its chat limit.