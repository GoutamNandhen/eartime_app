# Changelog

## [Phase 6 Investigation] - 2026-08-19
### Identified
- **Bug A**: Transient SCO route removal causes false `DEVICE_DISCONNECTED` event.
- **Bug B**: `SYNC_STATE` JSON payload mismatch prevents Flutter from initializing with connected devices.
- **Bug D & E**: `trackingPipelineProvider` fails to set `currentPlaybackStartTime` to null on pause, causing the Live Timer to tick infinitely.
- **Bug G**: `startForegroundService` called on a restarted background service without subsequent `startForeground`, causing Android 12+ `ForegroundServiceDidNotStartInTimeException`.

### Added
- Created `test/pipeline_regression_test.dart` to simulate and assert event stream behaviors.

### Changed
- Extensive documentation updates mapping root causes.
- **Fix 1 (Test G) Part A**: Relocated `startForeground` in `AudioTrackingService.kt` to safely execute on every `onStartCommand` loop, satisfying Android 12+ foreground requirements without double-initialization.
- **Fix 1 (Test G) Part B**: Fixed `ConcurrentModificationException` during app reopen by converting `connectedDevices` to `ConcurrentHashMap` and simplifying `ACTION_SYNC_STATE` to emit the current state instead of redundantly triggering a concurrent main-thread scan.

## [Phase 6 Fixes Execution] - 2026-08-20
### Fixed
- **Fix 1 (Bug G)**: Removed early returns from `AudioTrackingService.onStartCommand` for intent actions like `ACTION_SYNC_STATE`. This ensures that `startForeground()` is unconditionally executed for any service restart on Android 12+, properly preventing `ForegroundServiceDidNotStartInTimeException` crash loops when the app is cleared from Recents.
- **Fix 1 (Bug G - SecurityException)**: Fixed Android 14+ targetSDK 36 crash (`SecurityException: Starting FGS with type connectedDevice requires permissions: android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE`) by:
  1. Adding a runtime check in `MainActivity.kt` to only automatically start the tracking service if the prerequisite `BLUETOOTH_CONNECT` permission is granted.
  2. Wrapping `startForeground()` in a try-catch block in `AudioTrackingService.kt` to gracefully call `stopSelf()` instead of crashing if the system enforces missing FGS runtime requirements.
