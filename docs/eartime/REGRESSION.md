# Regression Ledger

Updated 2026-10-24. Preserve the known-good G service blob at `0a8be43`.
Automated acceptance is distinct from physical G acceptance.

## Native observation ingress

Downstream consumers: observation journal, EventChannel broker, Dart event
decoder/invalidation hints, native projection, product screens, widget and diagnostics.

Dependency evidence: `rg -n 'NativeJournalRuntime|ObservationJournal|JournalIdentity|ObservationJournalScreen|trackingPipelineProvider' android/app/src/main/kotlin lib`.
Reviewed production edges: Application -> NativeJournalRuntime;
service -> broker.sendEvent -> ingress worker -> source/projection commit -> broker.publishCommitted;
MainActivity RPC -> journal -> Dart client -> settings journal screen;
EventChannel -> TrackingEvent -> projection invalidation. Legacy Drift writer is
not activated by AppShell; preserved history is read-only and separate.

Regression acceptance commands (repository root unless noted):

```powershell
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
# Working directory: android
.\gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin :app:assembleDebug --offline
```

Propagation rule: any native payload, schema, journal or broker behavior change
requires both complete suites, Kotlin compile, debug packaging, analyzer and
protected-service comparison. Source/schema changes may not waive consumers
based only on a local model test. Repository commands were reviewed: local
build/test writes only; initial Robolectric download was separately authorized
through the tool boundary. No device install/data mutation.

Current evidence: Flutter 163 pass; JVM 334 pass; analyzer exit 0/no issues;
debug/release Kotlin compile and debug packaging exit 0. Fifteen former
placeholders now have real assertions. Signing refusal without keys is an
expected exit 1, not a signed release success. Exact artifact: `CODEX_RESUME.md`.

## Device and route contracts

Downstream consumers: journal timestamps/confidence and disposable endpoint alias
projection. Supported A2DP samples now commit random endpoint associations before
publication; names are not matching keys. Explicit edits close affected routes
at last evidence without rewriting history or the B02 opening. The pure route
reducer is not yet a confirmed legacy collector attribution path. See
`ENDPOINT_IDENTITY.md`; physical matching and live-route proof remain pending.

Regression acceptance: complete JVM suite plus Flutter scoped-device/journal
targets. Preserve source confidence UNKNOWN on all legacy observations.
Propagation rule: integrating normalization/route proof requires new cross-layer
tests and physical route acceptance; contract tests alone cannot exempt it.

## Legacy live/history compatibility

Downstream consumers: read-only legacy history and inherited compatibility tests;
Home/Timeline/Analytics/Devices/Wellbeing no longer read its accounting.
Dependency evidence: provider imports/watches in `lib/features` and
`lib/providers/data_providers.dart`; reconstruction in `SessionManager`.

Regression acceptance: full Flutter suite; focused
`test/phase2_device_scope_test.dart`, `test/phase2b_stale_attribution_test.dart`,
and inherited lifecycle/shared-stream tests.
Propagation rule: keep historical data and old payload support while replacing
accounting with a native projection. Product native replay/parity now permits a
256-event bounded invalidation cache. B02's observed opening passes native and
Dart fixture tests; production extrapolation still requires a collector lease.

## Unified Projection And Widget

Downstream consumers: `readListeningProjection`, shared Flutter workspace,
native launcher widget, preferences/display-name overrides and goal progress.
Native `ListeningProjectionTest` verifies duplicates, route unions, pauses,
identity changes, gaps, pre-commit rollback, rebuild and v1/v2 migrations on
API 28/35. Ingress integration checks raw and projection commit visibility
through another SQLite connection before publication. JSON fixture parity
crosses native reduction and Dart RPC decoding/widget tests; it is not a real
FlutterEngine/hardware test.

Any schema/normalizer/interval change requires complete Flutter/native suites,
analyzer, debug/release Kotlin compile, debug packaging and protected-service
comparison. Changes to native names/goals/widget rendering additionally require
preferences and actual RemoteViews tests. Hardware confidence and live leases
remain explicit gates; no test may mark global playback CONFIRMED for green.

## Physical G

Health contract evidence: `CollectorHealthTest` covers registration acknowledgment,
generation/epoch retirement, lease expiry, gaps, clock/boot, duplicate/crash/replay.
`OutputAttributionTest` contains 16 synthetic policy scenarios, not actual Android
route-transition integration. The runtime inventory/activity adapter has owner,
API 24/28/35 and source/ack tests; it grants no live-credit eligibility.
See `COLLECTOR_HEALTH.md`.

Unverified runtime edges: real FlutterActivity/renderer/OxygenOS startup,
foreground-service restart and rapid Recents removal/reopen, hardware routing.
Acceptance: ten correlated immediate reopen/Recents cycles on the target OEM,
recording first framework/raster/native-display milestones, service state and
visible splash dismissal, followed by the physical matrix in `TEST_PLAN.md`.
Private identifying logs remain local. Status: PHYSICAL_PENDING, not all-green.

Protected source check:

```powershell
git diff --exit-code 0a8be43 -- android/app/src/main/kotlin/com/eartime/eartime_app/tracking/AudioTrackingService.kt
tools/check_collector_baseline.ps1 -AllowObserverLifecycleHooks
```

The plain equality diff now intentionally exits 1: exactly four observer lifecycle
lines were added after recoverable checkpoint `9fd94b5`. The hook-only guard
passes only when removing those exact lines leaves all prior source unchanged.
Neither guard establishes behavior on hardware. The historical A/B regression
mechanism remains unproven; no speculative G fix was applied.
