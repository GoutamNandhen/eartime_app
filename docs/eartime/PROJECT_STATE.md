# EarTime Project State

## Current Phase: Phase 5 (Paused pending physical testing)
We have successfully completed Phase 6 (Core Sync Fixes). 
The exact next step is for the user to perform manual functional verification on their physical device (Tests A-G).
Once verified, we will resume Phase 5 (Per-ear BLE Research).

## High-Level Status
- **Phase 1-4**: COMPLETE. Passive A2DP playback detection, DB persistence, Timer UI.
- **Phase 6**: BLOCKED / BUGFIXING. Home screen unified synchronization state failed physical tests (Tests A, B, D, E, G). Root causes identified; regression tests prepared. Fixes pending implementation.
- **Phase 5**: PARTIALLY IMPLEMENTED. Diagnostic screens are built. Service discovery works. We are waiting to clear Phase 6 before proceeding to packet decoding.

## Repository State
The application successfully compiles (`flutter build apk`). 
A persistent background `AudioTrackingService` handles native Android audio and BLE events, bridging them to Flutter via an `EventChannel`.
Flutter uses Riverpod for state management and Drift for database storage.

## Phase 6 Fixes (A/B Issues Resolved)
* Confirmed SYNC_STATE contract bug where Kotlin sent connectedDevices at the root of the JSON map instead of inside the device key, causing Dart to falsely evaluate connected devices as empty.
* Confirmed Multi-Route Removal Bug where removing an SCO route falsely removed the physical device identity from connectedDevices, even if the A2DP route was still active.
* Exact Fixes: 
    * Wrapped SYNC_STATE payload inside a device key in Kotlin.
    * Modified onAudioDevicesRemoved to ensure no other remaining AudioManager output devices map to the same stableId before emitting DEVICE_DISCONNECTED.
* Tests added: Dart unit tests for TrackingEvent JSON deserialization.
* Current A/B Status: Fixes implemented. Ready for physical testing.
* Current G Status: Remains PASS.
