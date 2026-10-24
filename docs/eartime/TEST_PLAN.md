# Regression Test Plan

Run from the repository root:

```powershell
flutter pub get
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
git diff --exit-code 0a8be43 -- android/app/src/main/kotlin/com/eartime/eartime_app/tracking/AudioTrackingService.kt
```

With Android SDK/Java 17/Gradle wrapper available, run from `android`:

```powershell
.\gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin :app:compileReleaseKotlin :app:assembleDebug --offline
.\gradlew.bat :app:checkReleaseSigning --offline
```

Offline execution requires previously resolved dependencies. The signing check
must refuse missing authorized keys; that expected failure is not a signed-build
success. Do not install/clear data/uninstall to make tests pass.

Native tests cover commit-before-publication, IDs/order/conflicts/cursors,
rollback, restart/loss gaps, migrations/rebuild, union/clipping/DST/identity,
preferences and actual RemoteViews resources on modeled API 28/35. Flutter tests
cover shared stream ownership, startup/disposal, native wire fixtures, real
compatibility assertions, settings and narrow/large-text layouts.

Physical acceptance remains separate: immediate G reopen, Recents removal,
screen-off/background, OS process death, permission/service failure, output
switching/speaker/multiple devices, identity/clock changes, launcher refresh and
telemetry freshness. Follow [Release Validation](RELEASE_VALIDATION.md). Do not
publish identifying test logs; record redacted outcomes and device/OS classes.
