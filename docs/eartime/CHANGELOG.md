# Changelog

## [Phase 6 Review Fixes – follow-up] - 2026-11-05
Branch `fix/phase6-review`. Closes the items left open by the first pass. Needs physical verification.

### Fixed (native, Kotlin)
- **Speaker playback counted while earbuds connected**: on API 34+ playback only counts when a media player is routed (`AudioPlaybackConfiguration.getAudioDeviceInfo()`) to a tracked earbud route. Players reporting no route fall back to the global `isMusicActive` check; older APIs unchanged.
- **Playback attribution**: on API 34+ `PLAYBACK_*` and `SYNC_STATE` name the device the media is actually routed to, not just the most recently connected one.
- **BLE GATT races**: `onConnectionStateChange` runs under the manager lock, so a late callback can no longer null out a newer connection, and the first callback of a new connection can no longer arrive before `currentGatt` is assigned (which closed it as "stale"). Notifications from stale GATT objects are dropped; `disconnect()` is locked.
- **TrackingEventBroker**: cache fields are only touched on the main thread (were written from binder threads); the buffer used while Flutter is detached is capped at 500 events (oldest dropped; `SYNC_STATE` reconciliation covers the gap) so a long-lived service cannot grow memory without bound.

### Added
- GitHub Actions CI (`.github/workflows/ci.yml`): `flutter analyze`, `flutter test`, `flutter build apk --debug` on Ubuntu, with the debug APK uploaded as the `eartime-debug-apk` artifact. First real Gradle verification of this branch.

## [Phase 6 Review Fixes] - 2026-11-05
Branch `fix/phase6-review`. Full code review; every finding fixed. Needs physical verification (see TEST_PLAN / CURRENT_STATE §15).

### Fixed (native, Kotlin)
- **A2 – false disconnect**: devices are now tracked per *route*. `AudioTrackingService` keeps `logicalId -> {systemRouteIds}` and only emits `DEVICE_DISCONNECTED` when the last route (A2DP/SCO/BLE) of a device disappears.
- **Stuck "connected" device**: removal looks the route up by `AudioDeviceInfo.id` instead of re-deriving the id from a half-torn-down device (which produced a different id).
- **Wrong device attribution**: Bluetooth name/MAC fallback no longer uses `a2dp.connectedDevices.firstOrNull()`; it matches by MAC, or only falls back when exactly one A2DP device is connected. Logical id no longer contains the route type.
- **Pause never detected**: playback = media-usage player present **and** `AudioManager.isMusicActive`, debounced 350 ms. Paused-but-unreleased players and notification sounds no longer count. Speaker playback (no external device) is not emitted.
- **Threading**: all tracking state mutated on the main thread (callbacks registered with a main `Handler`; init thread posts back). Removed check-then-put races and the early empty `SYNC_STATE` (`initCompleted` flag).
- **API < 29 crash**: `startForeground(id, n, type)` replaced with `ServiceCompat.startForeground`; `stopForeground(true)` replaced with `ServiceCompat.stopForeground(STOP_FOREGROUND_REMOVE)`; `stopMonitoring` uses `stopService()`.
- **SYNC_STATE** now also carries `deviceId` and `playbackStartedAt` so a reopened app shows the real elapsed time.
- **BleDiscoveryManager**: ignores callbacks from stale GATT objects, connects with `TRANSPORT_LE`, uses the API 33 `writeDescriptor`/`onCharacteristicChanged` overloads, `close()` called from service `onDestroy`, invalid MACs no longer throw.
- **AudioDiagnosticHelper**: replies to the MethodChannel exactly once (guard + 3 s timeout + `getProfileProxy` failure path); dropped the undeclared `BLUETOOTH_SCAN` check.
- `MainActivity` never starts the service without `BLUETOOTH_CONNECT` (incl. `onListen` sync and BLE diagnostics).

### Fixed (Flutter)
- **B1/B2 – SYNC_STATE ignored**: `TrackingEvent` parses root-level `connectedDevices`/`isPlaying`/`playbackStartedAt` (legacy nested format still accepted).
- **B4/D/E – timer keeps running**: new pure `LiveSessionReducer`; pause/stop sets `currentPlaybackStartTime = null`.
- **Double counting**: Home = today's *closed* intervals (`todayClosedListeningProvider`) + live elapsed; label is now "Today's listen time"; live part clipped at midnight.
- **EventChannel stolen by later subscribers**: `TrackingPlatform.eventStream` is a single cached broadcast stream shared by all consumers (`trackingEventStreamProvider`).
- **Pipeline**: `TrackingPipeline` class, serialised event queue, subscription cancelled on dispose, no attribution to a stale `lastKnownDeviceId`.
- **Stale timeline after process death**: `SyncReconciler` inserts synthetic events on `SYNC_STATE` (closes stale sessions at their last known event, opens missing ones).
- **Dropped events**: ids are `timestamp_device_type`, inserted with `insertOrIgnore`; `SessionManager` sorts same-millisecond events connect → play → pause → disconnect.
- Removed dead `lib/core/platform/` (wrong channel names, unimplemented methods).
- Devices tab reachable (nav index 4), shows every known device with its total listening time.
- Analytics implemented (`AnalyticsCalculator`): Today/Week/Month/Year tabs, time-of-day split, average/longest session, device share; NaN on < 1 min fixed.
- Wellbeing implemented: duration-based health score (WHO 40 h/week guideline), breaks, longest continuous run, recommendation. Volume dB fields are nullable (not measurable via public APIs) and no longer claimed on screen.
- Permissions: only `BLUETOOTH_CONNECT` gates the app; notifications optional; re-checked on resume; "Open Settings" only when permanently denied.
- `LiveTimerWidget` uses a 1 Hz timer instead of a per-frame ticker.
- Capability detection runs app-wide and disposes replaced providers.

### Project
- Real regression tests (33 passing), `flutter analyze` clean.
- Pinned dependency versions; removed EOL `sqlite3_flutter_libs` and unused `plugin_platform_interface`.
- Release signing via `android/key.properties`; app label "EarTime"; `android/build/` untracked.

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
