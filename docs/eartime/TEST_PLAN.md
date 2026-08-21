# Test Plan

## Core Verification (Phase 6)
The following 7 manual functional tests govern the stability of the application. The system must pass all of them before advancing.

### TEST A: Empty State Recovery
1. Disconnect earbuds.
2. Force-close/clear EarTime from Android Recents.
3. Open EarTime.
4. **EXPECTED**: Home must NOT show a device as currently paused. Current state must be IDLE/NO DEVICE.

### TEST B: Seamless Connection
1. Connect OnePlus Nord Buds 3 Pro.
2. Wait for device detection.
3. **EXPECTED**: Home must update automatically (no manual refresh). Timeline may record `DEVICE_CONNECTED`.

### TEST C: Playback Initialization
1. Start music.
2. **EXPECTED**: Home immediately changes to "PLAYBACK PLAYING - OnePlus Nord Buds 3 Pro". Timer begins.

### TEST D: Playback Pause
1. Pause music.
2. **EXPECTED**: Home immediately changes to "PLAYBACK PAUSED". Timer stops increasing.

### TEST E: Playback Resumption
1. Resume music.
2. **EXPECTED**: Home immediately changes to "PLAYBACK PLAYING". Timer resumes from its previous position.

### TEST F: Device Disconnection
1. Disconnect earbuds.
2. **EXPECTED**: Home leaves the active playback state entirely. No stale paused/playing state remains.

### TEST G: Session Recovery
1. Start playing music.
2. Clear app from Recents.
3. Reopen.
4. **EXPECTED**: Home loads normally. Current state is reconstructed accurately (PLAYING). No splash freeze.

## BLE Diagnostic Testing (Phase 5)
1. Ensure the earbud is connected.
2. Go to the Diagnostic Screen.
3. Remove Left Earbud -> Note raw hex payload.
4. Insert Left Earbud -> Note raw hex payload.
5. Repeat for Right Earbud.
6. Verify whether any byte reliably corresponds to per-ear activity without false positives.

## Automated Regression Tests (Phase 6 Fixes)
An automated Riverpod/Stream test suite is maintained in `test/pipeline_regression_test.dart` to enforce the following data-flow rules:
1. Launch with earbuds disconnected -> Empty state.
2. Connect earbuds after launch -> Device appears, Timer off.
3. Device remains visible after connection despite transient SCO route drops.
4. DEVICE_CONNECTED without playback -> Correct state mapping.
5. PLAYBACK_STARTED after DEVICE_CONNECTED -> Timer starts.
6. PLAYBACK_PAUSED stops live timer by setting start time to null.
7. PLAYBACK_PAUSED stops session accumulation in DB.
8. PLAYBACK_RESUMED continues from accumulated duration.
9. Repeated play/pause transitions do not duplicate sessions.
10. No duplicate timers/subscriptions exist in the pipeline.
11. App lifecycle/reopen does not crash due to missing `startForeground`.
12. SYNC_STATE with connected device parses correctly (payload mismatch fixed).
13. SYNC_STATE with no connected device clears UI.
14. Home and Timeline consistency is maintained.
