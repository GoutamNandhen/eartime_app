# App Version Policy

2026-10-24. H25 production versioning, not authorization to publish a release.

`pubspec.yaml` is the single version declaration. The current development build
is `1.1.0-dev.1+2`. Names use `major.minor.patch`, optionally `-dev.N` or `-rc.N`;
build numbers are canonical positive decimal integers up to 2100000000. A stable
name does not certify readiness or signing. Every changed version must increase
the build number; never recycle a published number. Keep a failed published
checkpoint recoverable with revert/corrective commits, not history rewriting.

`tools/check_app_version.ps1 -PreviousRef HEAD` compares the working declaration
against an existing Git ref and rejects decreasing/reused numbers. Use the last
published checkpoint for a release-candidate comparison. `-SelfTest` executes
17 format/boundary/progression cases, including CRLF and integer overflow. Source
declarations use exactly one unquoted top-level version scalar; ambiguous forms
are rejected rather than heuristically interpreted as YAML.

Gradle `checkAppVersion` is a dependency of `preBuild`: both Android version
properties must match the declaration. This catches stale ignored local.properties
and arbitrary Flutter version overrides. Build through `flutter build apk
--debug --no-pub` to refresh properties; change the tracked declaration for a new
build, not an untracked local override. Existing signing refusal remains intact.
[Android versioning contract](https://developer.android.com/studio/publish/versioning).

Settings -> About reads actual installed PackageManager metadata on the existing
bounded native worker, only after explicit navigation. Replies are engine-owner
fenced. No startup package query, extra executor, certificate read, network lookup,
path/device identifier, fabricated Git SHA or readiness verdict is added. Android
API 28+ long version codes are not truncated; older versions use versionCode.
Debuggable is a package flag, not proof of signer identity or production approval.
[PackageInfo fields](https://developer.android.com/reference/android/content/pm/PackageInfo).

Four API 24/28/35 tests (12 executions) cover the packaged manifest, installed
metadata changes, long codes, missing/corrupt fields and debug-flag independence.
Four Flutter cases cover strict contracts, missing/error retry, actual Settings
navigation, licenses and 360px/2x text. Full gates: 167 Flutter / 354 native (27
suites), analyzer clean, Kotlin debug/release and debug APK pass. `aapt dump badging`
verified actual package `com.eartime.eartime_app`, versionName `1.1.0-dev.1`,
versionCode `2`, debuggable. No APK installation, signing or release publication.
