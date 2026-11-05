# Known Bugs & Resolutions

## Resolved
- **[Phase 6] Stale Home State After Process Death**: App loaded with a false "PAUSED" state if the process died before a disconnect event could fire. Fixed by separating the DB history from the `LiveSessionNotifier` and introducing a native `SYNC_STATE` bootloader event.
- **[Phase 6] CPH2447 Misidentification**: The earbuds were showing up as the host phone model. Fixed by merging Bluetooth A2DP naming metadata with the AudioManager device properties.
- **[Phase 4] Splash Screen Freeze**: App locked up on the splash screen when reopened from a cold boot (cleared from Recents). Fixed by moving the synchronous `checkInitialAudioState` to a background thread.
- **[Phase 4] Unreliable GATT Service Discovery**: Service discovery was hanging after `connectGatt`. Fixed by ensuring `discoverServices` is explicitly invoked within `onConnectionStateChange`, particularly during refresh requests.

## Resolved in fix/phase6-review (2026-11-05) – pending physical verification
- **[Phase 6] False Disconnection (Test A)**: route-set tracking per logical device; disconnect only when the last route goes.
- **[Phase 6] Missing Live State on Boot (Test B)**: Flutter parses root-level SYNC_STATE fields; timeline reconciled with the snapshot.
- **[Phase 6] Infinite Timer on Pause (Test D/E)**: reducer clears `currentPlaybackStartTime`; native pause detection uses `isMusicActive`.
- **[Phase 6] Crash on Reopen (Test G)**: `startForeground` on every start command via `ServiceCompat` (also fixes API < 29).
- **EventChannel multi-listener**: single shared stream.
- **BLE GATT callback races / unbounded event buffer / broker cache written off main thread**: fixed in follow-up.
- **Double-counted listening time / stale device attribution / dropped same-ms events / stuck connected device**: see CHANGELOG.

## Open / Pending Investigation
- Verify all of the above on the CPH2447 + Nord Buds 3 Pro (Tests A–G).
- `isMusicActive` is global below API 34: playback on a non-tracked output while earbuds are connected still counts there. Fixed on API 34+ via per-player routing (2026-11-05 follow-up); verify on the CPH2447 by playing on the speaker with the buds connected but out of the ear / routed away.
- A paused-but-unreleased media player routed to the buds plus music on the speaker could still read as "playing" (no public per-player state API). Rare; noted for completeness.

- Toolchain: Flutter 3.47 warns that support for Gradle 8.14, AGP 8.11.1 and Kotlin 2.2.20 will soon be dropped (wants Gradle ≥ 9.1, AGP ≥ 9.0.1, Kotlin ≥ 2.3.20). Builds fine today; AGP 9 is a major upgrade, do it as its own change.

## Previously listed (now resolved, kept for history)
- **[Phase 6] False Disconnection (Test A)**: `AudioDeviceDetector` receives an SCO route removal and erroneously removes the matching A2DP device from the cache because they share the same ID.
- **[Phase 6] Missing Live State on Boot (Test B)**: `SYNC_STATE` payload mismatch. Kotlin sends `connectedDevices` at root, but Flutter `TrackingEvent.fromJson` ignores it, booting with a wiped state.
- **[Phase 6] Infinite Timer on Pause (Test D/E)**: `PLAYBACK_PAUSED` logic fails to set `currentPlaybackStartTime` to null, causing `LiveTimerWidget` to continue ticking.
- **[Phase 6] Crash on Reopen (Test G)**: `ForegroundServiceDidNotStartInTimeException`. When the service is already running (e.g., restarted by OS), reopening the app triggers `startForegroundService` but skips `startForeground` due to `isInitialized == true`.
