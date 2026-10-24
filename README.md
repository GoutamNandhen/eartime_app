# EarTime

Android-first listening observations with a Flutter interface and native durable
journal/projection. This is an **unreleased development checkpoint**.

Read the [feature matrix](docs/eartime/FEATURE_MATRIX.md),
[resume checkpoint](docs/eartime/CODEX_RESUME.md),
[architecture](docs/eartime/ARCHITECTURE.md) and
[public review boundaries](docs/eartime/PUBLIC_CHECKPOINT.md).

The protected collector matches `0a8be43`. Real playback attribution is still
unknown; unverified activity is not confirmed listening. Production live ticking,
hardware telemetry, physical G and release readiness are not claimed.

## Local Checks

Use a Flutter SDK compatible with Dart 3.11, Java 17 and Android SDK 36:

```powershell
flutter pub get
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
flutter build apk --debug
```

Flutter supplies ignored Gradle wrapper files on the first Android build. Then,
from `android`, run `:app:testDebugUnitTest :app:compileDebugKotlin` with the
platform wrapper. See [test plan](docs/eartime/TEST_PLAN.md) for full commands,
offline-cache requirements and separate physical/signing gates.

Before committing/pushing, manually review the exact file set and run
`tools/audit_public_tree.ps1`. Keep private logs, device data, research, signing
material, databases and build artifacts local. Publish development commits only
on the review branch; use `git revert` for rollback. Do not force-push, merge to
main or publish a release as part of checkpoint work.
