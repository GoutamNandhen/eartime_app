# Architectural & Engineering Decisions

## 1. Deprecating `activeDeviceProvider` for `LiveSessionNotifier`
- **Context**: We previously relied on the SQLite event history (`activeDeviceProvider`) to determine what the Home screen should display.
- **Problem**: If the app was killed while a session was active, and the earbuds were disconnected while the app was dead, reopening the app resulted in it falsely pulling the last historical "PAUSED" state and displaying it as currently active.
- **Decision**: Home screen now completely ignores the DB for its live state. It uses `LiveSessionNotifier`, a purely memory-bound state that is initialized by an explicit `SYNC_STATE` native event upon app startup.

## 2. AudioDeviceDetector Name Resolution
- **Context**: Android `AudioManager` occasionally reports Bluetooth headphones using the phone's hardware model (e.g., `CPH2447`) as the generic route name.
- **Decision**: Modified `AudioDeviceDetector.kt` to prefer the `fallbackName` injected via `BluetoothA2dp` proxy. We prioritize the true Bluetooth identity over the internal AudioManager product name.

## 3. Background Thread Initialization
- **Context**: During startup, attempting to enumerate devices on the main UI thread occasionally caused application freeze/ANR when the user cleared the app from Recents.
- **Decision**: Initial audio state scanning in `AudioTrackingService` is heavily deferred to a background thread.
