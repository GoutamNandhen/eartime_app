# Release Validation

2026-10-24. NOT RELEASE_READY. Do not publish the debug APK.

## Signing

Release packaging no longer inherits the debug signing key. Gradle requires:

- `EARTIME_KEYSTORE_PATH`
- `EARTIME_KEYSTORE_PASSWORD`
- `EARTIME_KEY_ALIAS`
- `EARTIME_KEY_PASSWORD`

Provide these through an authorized local/CI secret environment. Do not commit
values, keystores or signing properties, print credentials, invent signing keys,
or publish artifacts without authorization. `android/key.properties` is ignored
but not read by this environment-based configuration.

From `android`, `:app:checkReleaseSigning --offline` currently fails with missing
configuration as intended. Debug packaging and `:app:compileReleaseKotlin`
succeed without release keys. That compile check does not prove signed APK/AAB
packaging, R8/runtime behavior or store acceptance. Packaging tasks depend on
the signing check; there is no release-to-debug fallback.

## Data And Privacy

OS automatic backup/cloud/device-transfer exclusions cover databases, settings
and application files. Explicit user-controlled export/backup/restore/deletion
remain unimplemented. Existing data must not be cleared/uninstalled for upgrades.
Legacy Drift data stay local/read-only; native schema migrations preserve source
observations, source identity and replay cursors. System fonts work offline.
Inherited service/BLE logs and automatic discovery still need a privacy audit;
raw diagnostic logs may contain identifying device data.

## Remaining Acceptance

Run all automated gates in `CODEX_RESUME.md` after every integrated change.
Before release, validate real G rapid reopen, Recents removal, OS process death,
background/screen-off continuity, service initialization failure, revocation and
collection stop. Check speaker/USB/wired/Classic/LE/multiple routes, device
identity/name changes, wall-clock/timezone/midnight and database upgrades on
real supported devices. Validate launcher update/resize/font/unknown/stale states.

Current collector output attribution is UNKNOWN and production live extrapolation
is disabled without a validated lease. Proprietary battery/case/wearing support
has no hardware evidence. These are product blockers, not acceptable release
claims based on synthetic confirmed-route fixtures. Complete remaining feature,
localization, accessibility, storage/performance and signing gates first.
