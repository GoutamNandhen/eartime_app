# EarTime Project Handoff

Welcome to the EarTime project! This document serves as the primary entry point for any new AI agent taking over engineering tasks.

## 1. What is EarTime?
EarTime is a Flutter application designed to passively track Bluetooth earbud ambient listening time (like Screen Time, but for audio). It relies on a persistent native Android foreground service to detect when earbuds connect, disconnect, play, or pause audio, and logs this data to a local SQLite database (Drift) to visualize listening habits.

## 2. What has already been implemented?
- A robust Drift (SQLite) database architecture (`SessionManager`).
- A Riverpod-based reactive pipeline (`LiveSessionNotifier`).
- A persistent Android foreground service (`AudioTrackingService`) that survives app termination.
- A platform channel (`EventChannel`) bridging Android audio callbacks to Flutter.
- A glassmorphic UI with real-time timers and a historical timeline.
- A permission onboarding flow.

## 3. How does the architecture work?
- **Native**: `AudioTrackingService` registers `AudioDeviceCallback` and `AudioPlaybackCallback`. It maps physical devices to logical models in `AudioDeviceDetector`. It pipes events to `TrackingEventBroker`.
- **Bridge**: `TrackingPlatform` listens to the `EventChannel` and emits strongly-typed `TrackingEvent`s.
- **Flutter**: `trackingPipelineProvider` routes events to `LiveSessionNotifier`, which builds the `LiveSessionState`. `SessionManager` silently commits new sessions and updates to Drift.

## 4. What is currently broken?
- As of 2026-11-05 all known bugs (A2, B, D/E, G) have code fixes on `fix/phase6-review`, pending physical verification. See CHANGELOG and BUGS.md.

## 5. What has actually been physically tested?
See `CURRENT_STATE.md` for the full physical test matrix. Disconnected launches (A1), disconnect events (A4), timeline accuracy (A5), and midnight crossing (F) all PASS.

## 6. What is confirmed?
- The app's startup "reopen failure" was confirmed to be a Flutter UI redraw loop (`cancelAndRedraw`), which is now FIXED.
- The A2 bug is confirmed to be an identity eviction bug in `onAudioDevicesRemoved` when secondary Bluetooth routes (like SCO) are disconnected by the OS.

## 7. What is only a hypothesis?
- The B/D/E root causes (SYNC_STATE parse mismatch, reducer not clearing the start time, paused players still listed as active) were found by code review and fixed, but not yet confirmed with device logs.
- Per-player routing (`getAudioDeviceInfo`, API 34+) is expected to be reported by OxygenOS 16; unverified on the CPH2447.

## 8. What files implement each feature?
- **Android Tracking**: `AudioTrackingService.kt` (route-set tracking, playback detection), `AudioDeviceDetector.kt`, `TrackingEventBroker.kt`, `BleDiscoveryManager.kt`
- **Flutter State**: `live_session_reducer.dart`, `live_session_state.dart`, `data_providers.dart` (`TrackingPipeline`), `session_manager.dart` (`SyncReconciler`)
- **Database**: `session_manager.dart`, `database.dart`
- **Analytics/Wellbeing**: `analytics_calculator.dart`
- **UI**: `app_shell.dart`, `live_timer_widget.dart`

## 9. What should NOT be changed?
- DO NOT modify the Drift database schema.
- DO NOT change the reducer, `SyncReconciler`, route-set tracking or playback detection without adding/adjusting tests (see CURRENT_STATE §23).
- DO NOT invent new Android architectural patterns (like WorkManager) to replace the existing FGS.

## 10. What is the exact next engineering task?
Run Tests A–G (CURRENT_STATE §24) on the CPH2447 / Nord Buds 3 Pro using the CI-built debug APK or `flutter run`, then fix anything that fails on `fix/phase6-review`.

## 11. What evidence is required before implementation?
For any failing test: `adb logcat` output filtered on `AudioTrackingService|EarTimeDiag|BleDiscoveryManager`, plus the exact steps and timestamps.

## 12. What documentation must be updated after every future change?
**FUTURE ENGINEERING RULE**: Every future feature, bug fix, architectural change, protocol change, state-model change, test, or important engineering discovery MUST update the persistent engineering documentation (including `CURRENT_STATE.md`, `TEST_RESULTS.md`, `BUGS.md`, and this `HANDOFF.md`) in the same implementation task.

You must leave enough information behind that another agent can read these files and immediately resume work.
