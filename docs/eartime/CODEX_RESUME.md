# EarTime Resume Checkpoint

Updated 2026-10-24. Paths in this document are repository-relative.
Review branch `codex/production-checkpoint-20261024`; protected baseline `0a8be43`.
Initial publication verified at `1b3ee7ea4d56afef30ffc018749e1ed25a841af5`;
the follow-up adds known-device pagination without changing listening accounting.
The interrupted health/attribution contract work is now completed and tested.
See `COLLECTOR_HEALTH.md`; no runtime observer or confirmed route producer is
implied by that contract checkpoint.
Read `PRODUCTION_IMPLEMENTATION_LEDGER.md`, `LISTENING_PROJECTION.md` and
`FEATURE_MATRIX.md`. Autonomous implementation remains authorized; do not ask
for routine phase approval. This is NOT RELEASE_READY.

## Protected Baseline

`AudioTrackingService.kt` is byte-identical to `0a8be43`:

- SHA-256 `EF1DA5B8FF5AB092ACA80F2CCC78C7CEFE727C5F20FDFC045BF58E8E3752AC1D`.
- Git blob `78353ae1cd1d97897137360be8df24354f6c0bff`.
- `git diff --exit-code 0a8be43 -- android/app/src/main/kotlin/com/eartime/eartime_app/tracking/AudioTrackingService.kt`: exit 0.

Physical G and the historical A/B splash regression mechanism are still
UNPROVEN. Source equality does not establish G for the changed application.
No phone was attached, installed, cleared, commanded or physically tested.

## Current Implementation

Native journal schema **3**, listening projection version **2**:

- All service/BLE broker emissions enter bounded native ingress. A raw row and
  its incremental projection/cursor commit atomically before publication.
  Publication failure retains committed history and does not fabricate a gap.
- UUID observation IDs, transactional sequence/source identity, idempotent
  duplicate handling, durable collision faults, source-aware replay/ack cursors.
- Additive v1 migration, v2 derived-cache migration, bounded 128-row replay
  transactions and deterministic rebuild. No raw journal deletion/migration
  rewrite. Unsupported future schema refuses access without deleting data.
- Restart/overflow/invalid-input/commit-loss gaps close at last durable evidence.
  Clock discontinuity, lost attribution and changed identity cannot bridge time.
- Global overlap union, per-device union, local calendar clipping, DST-aware
  day/hour buckets, longest/average continuous runs and bounded interval paging.
- `readListeningProjection` is shared by Home, Timeline, Analytics, Devices,
  Wellbeing and the native launcher widget. Flutter no longer reconstructs
  product intervals or adds a local DateTime timer to closed history.
- B02 mechanism is proven in regressions: the compatibility reducer loses its
  in-memory opening on Dart replacement; its SYNC fallback is S. The native
  projection retains T1 when durable continuity is valid. A process restart
  invalidates continuity instead of inventing T1-to-restart time.
- Legacy Drift schema/data remain intact. The product shell no longer starts
  its writer; Settings -> Preserved legacy history provides paged read-only
  access. Legacy adapters/reducers remain for compatibility regressions, not
  canonical product accounting. No automatic import or confidence promotion.
- Live delivery is now only an invalidation hint, capped at 256 events and
  flushed 32 per turn. Product history comes from journal/projection replay.
- Native widget: dark rounded container, two-column cards, icons, truncated
  names, connection labels, honest unknown batteries, large-font row reduction,
  event-coalesced refresh and platform periodic update. No Flutter DB dependency.
- Native-backed theme, personal daily goal and user display names. Names do not
  change physical IDs, observations or listening totals. Home/Wellbeing use
  confirmed totals for goal progress; no exposure score or fake telemetry.
- Devices navigation is reachable. Actual date ranges/paging replace cosmetic
  analytics tabs. Offline system fonts replace startup font downloads.
- Optional diagnostics use exact UUID matching; service presence does not prove
  per-ear identity, wearing or actual LE playback. Failed/superseded Dart
  protocol providers are disposed. No vendor packet decoder/support invented.
- Android backup/transfer exclusions added. Release builds cannot fall back to
  the debug key; explicit signing configuration is required.

## Important Runtime Limits

**No current collector emits CONFIRMED output attribution.** Its global playback
flag can describe phone-speaker audio even with a headset connected. Therefore
real protected-collector activity is **UNVERIFIED**, not confirmed listening.
Nonzero confirmed route tests use explicitly identified synthetic native input,
not validated hardware. Do not interpret confirmed zero as measured silence.

**No validated collector-liveness lease exists.** The protected service has no
durable destruction/health marker, and may fail initialization while the process
survives. Production queries do not extrapolate open intervals beyond durable
evidence. The native reducer's explicit live-lease path is unit-tested, but
production live ticking and automatic listening reminders remain gated. A new
SYNC can extend an observed interval without replacing its original opening.

Legacy physical identity remains provisional and epoch-scoped; no name/MAC
fallback is promoted or merged across restarts. Device lists return 100 rows per
page with independent device cursors and next/previous controls. Connected rows
sort first, then last evidence and identity. Pages are live offset queries, not
a frozen multi-page snapshot; new observations may reorder them. Window aggregation has a
100,000-row work ceiling and returns an error rather than truncated totals.
Large-history profiling and cooperative startup replay remain open.

Inherited automatic experimental BLE discovery is still in the protected
collector. Do not claim it has become opt-in or physically validated. User data
export/restore/deletion, full connected/idle accounting, reminders/quiet hours,
streaks/reports, more widget variants, localization and final release acceptance
are not complete. See the feature matrix and release blockers.

## Executed Gates

```powershell
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
# Working directory: android
.\gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin :app:compileReleaseKotlin :app:assembleDebug --offline
.\gradlew.bat :app:checkReleaseSigning --offline
```

- Flutter: **128 passed**, exit 0. Original 103 slots retained, including 15
  formerly empty/trivial tests rewritten as actual assertions; 25 additional
  projection/settings/telemetry/layout cases. No skips/excluded test files.
- Analyzer: **No issues found**, exit 0. All 21 inherited findings and final
  formatter-exposed block lints corrected without suppression.
- Native: **148 passed**, 0 failures/errors/skips. Original 46 plus 102 new:
  projection 48; preferences 12; widget 6; durable hint buffer 2; ingress 2 new
  (3 total); health 16 and synthetic output-policy 16. API 28/35 modeled for SQLite/projection/preferences/widget/health tests.
- Kotlin debug/release compile and debug packaging: exit 0, BUILD SUCCESSFUL.
  Inherited Kotlin/Gradle/old BLE API deprecation warnings remain; service code
  was not edited to remove them.
- Release signing check: expected exit 1, missing signing configuration. This
  validates a fail-closed gate, NOT a successful signed release build.
- `git diff --check`: exit 0; only CRLF advisory warnings. Device inventory empty.
- Readable test-fixture Home captures at 360/1200 pixels in `build/qa/`; five main
  view large-text layout cases passed at 360 pixels / 2x text. Captures were
  inspected with local Roboto/Material Icons. Not device/launcher screenshots.

Interim failures were fixed, not hidden: RPC deadline leaked after disposal;
Windows native SQLite fixture paths exceeded practical path length; ingress
close raced queued work; final formatting exposed missing block braces.

Prior pagination debug artifact (not installed/released; historical hash):

- `build/app/outputs/flutter-apk/app-debug.apk`, 158947452 bytes.
- SHA-256 `1FB489CA9C3B2AB4C1C6B58002BA5EF2962ADB2B27DC89BA925A76BFD393F943`.
- Both debug APK paths have the same hash. Initial checkpoint AAPT confirmed debuggable, label
  EarTime, ID `com.eartime.eartime_app`, min SDK 24/target SDK 36.

## Preservation And Next Work

Pre-phase and pre-publication checkpoints remain local and unpublished.
The pre-publication index/source copy is under ignored `.local-checkpoints/`.
Before public staging, the saved index SHA-256 was:
`9CC0E1BFF5FC75D56E204784398E419812266CD247BB6C3BCFFEBF75276A69EA`.
Publication uses reviewed feature-branch commits only; no destructive migration,
main update, force push or device mutation. See `PUBLIC_CHECKPOINT.md`.

1. Establish a validated collector health/continuity contract without silently
   altering the protected service. Durable generation/epoch/lease contract and
   status UI now pass; actual observer ownership/cleanup integration is next.
   Keep production extrapolation disabled until
   real lifetime/route evidence exists; retain all unknown/gap behavior.
2. Finish evidence-backed identity/alias normalization and a permitted route
   collector. Generic global playback or a discovered UUID is not that proof.
3. Add long-history load/cancellation/replay fairness tests, including device
   paging under concurrent observations. Do not return partial aggregates as complete totals.
4. Implement versioned local export/backup/restore/deletion with explicit user
   confirmation for destructive actions, conflict-safe transactions and tests.
5. Continue the remaining matrix: connected/idle partitions, richer analytics,
   reminders/quiet hours only for validated inputs, reports/streaks, additional
   widgets/shortcuts, localization and accessibility across every screen.
6. Finish authorized signing/release packaging and physical G/background/
   process-death/routing/launcher/telemetry acceptance. No release-ready claim.
