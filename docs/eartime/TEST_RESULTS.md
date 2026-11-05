# Test Results

## Phase 6 Review Fixes – follow-up (2026-11-05)
- Kotlin compiles (kotlinc 2.2.20, android-36). Dart side unchanged, so the 33/33 test run stands.
- GitHub Actions CI (run 41982224296, commit cfacb63): `flutter analyze` no issues, `flutter test` 33 passed, `flutter build apk --debug` succeeded (first real Gradle build of this branch). Debug APK uploaded as artifact `eartime-debug-apk`.
- Physical tests A–G: NOT RUN. Additional check: with buds connected, route playback to the speaker; the timer must not run (API 34+).

## Device run 1 – 2026-11-05 (build apk-phase6-review-1, CPH2447 / Nord Buds 3 Pro)
- Buds disconnected mid-song, music continued on speaker: timer stopped and did not count speaker time. PASS.
- Buds reconnected without pausing, music moved to buds: device detected but state stayed PAUSED until manual pause/play. FAIL -> fixed by route watch (build apk-phase6-review-2), re-test pending.
- After pause/play: normal. Tests A–G individually: not yet reported.

## Phase 6 Review Fixes (branch fix/phase6-review) – 2026-11-05
- **Automated**: `flutter test` 33/33 passing (pipeline regression 1–14 implemented, reducer/reconciler, analytics, LiveTimerWidget, SYNC_STATE contract). `flutter analyze`: no issues. Kotlin sources compile against android-36 + Flutter embedding (kotlinc 2.2.20).
- **Physical**: NOT YET RUN. Re-run Tests A–G on CPH2447 / Nord Buds 3 Pro.

## Phase 6 Core Sync Fixes
- **Test Date**: TBD (Pending User Verification)
- **Environment**: OnePlus CPH2447, Android 16 (API 36), OnePlus Nord Buds 3 Pro
- **Results**:
  - Test A (Empty State Recovery): FAIL (Partial) - Device appeared briefly and disappeared due to SCO route removal.
  - Test B (Seamless Connection): FAIL (Partial) - Device not shown until playback due to SYNC_STATE mismatch.
  - Test C (Playback Initialization): PASS
  - Test D (Playback Pause): FAIL - Timer never stops due to missing null-assignment.
  - Test E (Playback Resumption): FAIL - Timer continues increasing when paused.
  - Test F (Device Disconnection): PASS
  - Test G (Session Recovery): FAIL - App crash on reopen due to ForegroundServiceDidNotStartInTimeException.

## Phase 5 BLE Discovery
- **Status**: Verified working.
- **Details**: 
  - `connectGatt` and `discoverServices` complete successfully.
  - Earbud identity is successfully located via BLE.
  - Raw OPOv1 diagnostic payloads are successfully streaming into the Flutter UI via the Native tracking service.
  - We are currently awaiting manual packet analysis by the user.
