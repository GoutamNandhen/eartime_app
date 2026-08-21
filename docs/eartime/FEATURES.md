# Features

## Implemented / Verified
- **Passive Background Tracking**: Application tracks audio sessions without manual start/stop interaction.
- **Persistent Database**: All tracking events are saved in SQLite using Drift.
- **Real-Time UI**: `LiveSessionNotifier` keeps the Home screen perfectly synced with the exact state of the earbuds.
- **Live Timer**: Accurately counts elapsed listening time based on play/pause timestamps.
- **BLE Diagnostics**: App connects to the earbud's GATT server and streams OPOv1 characteristic notifications for reverse engineering.

## Implemented / Requires Device Verification
- **Core Sync Fix**: Home screen correctly resets to "IDLE" if app is killed and reopened when earbuds are not connected.
- **Device Identity Fix**: Connects and displays "OnePlus Nord Buds 3 Pro" instead of the Android `AudioManager` device route (`CPH2447`).

## Planned / Proposed
- **Phase 5: Per-Ear Detection**: Decode OPOv1 BLE packets to determine whether the user is wearing the Left, Right, or Both earbuds independently.
- **Phase 7: Historical Analytics**: Render charts and daily summaries from the Drift database.
