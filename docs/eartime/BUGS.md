# Known Bugs & Resolutions

## Resolved
- **[Phase 6] Stale Home State After Process Death**: App loaded with a false "PAUSED" state if the process died before a disconnect event could fire. Fixed by separating the DB history from the `LiveSessionNotifier` and introducing a native `SYNC_STATE` bootloader event.
- **[Phase 6] CPH2447 Misidentification**: The earbuds were showing up as the host phone model. Fixed by merging Bluetooth A2DP naming metadata with the AudioManager device properties.
- **[Phase 4] Splash Screen Freeze**: App locked up on the splash screen when reopened from a cold boot (cleared from Recents). Fixed by moving the synchronous `checkInitialAudioState` to a background thread.
- **[Phase 4] Unreliable GATT Service Discovery**: Service discovery was hanging after `connectGatt`. Fixed by ensuring `discoverServices` is explicitly invoked within `onConnectionStateChange`, particularly during refresh requests.

## Open / Pending Investigation
- **[Phase 6] False Disconnection (Test A)**: `AudioDeviceDetector` receives an SCO route removal and erroneously removes the matching A2DP device from the cache because they share the same ID.
- **[Phase 6] Missing Live State on Boot (Test B)**: `SYNC_STATE` payload mismatch. Kotlin sends `connectedDevices` at root, but Flutter `TrackingEvent.fromJson` ignores it, booting with a wiped state.
- **[Phase 6] Infinite Timer on Pause (Test D/E)**: `PLAYBACK_PAUSED` logic fails to set `currentPlaybackStartTime` to null, causing `LiveTimerWidget` to continue ticking.
- **[Phase 6] Crash on Reopen (Test G)**: `ForegroundServiceDidNotStartInTimeException`. When the service is already running (e.g., restarted by OS), reopening the app triggers `startForegroundService` but skips `startForeground` due to `isInitialized == true`.
