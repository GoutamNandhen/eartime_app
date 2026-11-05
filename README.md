# EarTime

EarTime tracks how long you actually listen through your earbuds, like Screen Time for your ears. A native Android foreground service watches audio routes and media playback, streams events to Flutter over an `EventChannel`, and a Drift (SQLite) timeline powers the Home timer, analytics and wellbeing screens.

## Status
Pre-release (Phase 6). Android only; iOS/desktop builds run the UI without tracking.

## Run
```bash
flutter pub get
flutter run            # Android device, grant Bluetooth (Nearby devices) permission
flutter test           # unit + regression tests
flutter analyze
```
After changing a `@freezed` model or Drift table: `dart run build_runner build --delete-conflicting-outputs`.

## Release signing
Create `android/key.properties` (git-ignored):
```
storeFile=/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```
Without it, release builds are signed with the debug key and must not be published.

## Architecture
See `docs/eartime/` — start with `HANDOFF.md`, then `CURRENT_STATE.md` and `NATIVE_FLUTTER_CONTRACT.md`.
