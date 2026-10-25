# EarTime Resume Checkpoint

Updated 2026-10-25. Paths in this document are repository-relative.
Latest resumed D7/E1 checkpoint: preserved all five unfinished calendar files;
credits-blocked formatting/tests completed. Shared local-calendar bounds and
scrollable localized date entry fix reproduced stock-header overflow. Validation,
cancel/rollback, paging/scope, old history, inclusive end and year labels tested.
Full executed gates: 186 Flutter / 362 native in 28 suites, zero failures/errors/
skips; analyzer clean; both Kotlin variants/debug APK/version/protected guard pass.
Counts: 32 IMPLEMENTED / 71 IN_PROGRESS / 15 NOT_STARTED / 1 BLOCKED_BY_PLATFORM.
13 Flutter/four native new cases. Source schema 3/projection 5, four prior service
hooks unchanged. Prior 9df34d4003a3e9c79d1fdb3653ba4b2380c1e5e7 was pushed and
remote-verified. Main remains 13ae6609d22cb2a0daf8890fca081fb97c93b36b.
See CALENDAR_FILTERS.md. No physical/route/G/release claim. Next independent phase:
E12 product-state consistency for empty, unverified-only, incomplete and failed
history, then canonical grouped sessions and remaining exact matrix/data controls.
Latest ignored debug APK SHA-256:
`2B308D7D67E3AE097C3882AC19D21726436A883AF7586E02C1C9059EE5A62F5D`.

## Privacy Checkpoint

Latest H28 checkpoint: offline privacy/permission disclosures reachable before
grant and from Settings. Two existing large-font overflows reproduced and fixed
without clamping or startup ownership changes. Six Flutter/four native new cases.
Full gates: 173 Flutter / 358 native in 28 suites, no failures/errors/skips;
analyzer clean, both Kotlin variants/debug APK/protected four-hook guard pass.
Counts: 30 IMPLEMENTED / 73 IN_PROGRESS / 15 NOT_STARTED / 1 BLOCKED_BY_PLATFORM.
Prior 9a1bd3b216bf14f3f087d0bef9ce9731e6294ace pushed/remote-verified; main
unchanged. PRIVACY_DISCLOSURES.md explicitly leaves full backup/deletion/log audit
open. No physical/service-file/release claim. Next D7/E1 calendar/custom date
acceptance and paging-reset correctness, then remaining exact matrix.
Latest ignored debug APK SHA-256:
`1DEBEDA2D251E7FC87BA1A5E1A8BEC4730FF2CF5F001574AA33FB5785BAE425E`.

## Version Checkpoint

Latest checkpoint: H25 version policy and installed-package About. Full gates:
167 Flutter / 354 native in 27 suites, zero failures/errors/skips; analyzer clean;
debug/release Kotlin, debug APK, version checks and protected four-hook guard pass.
17 version-tool cases plus 12 native/4 Flutter new cases. Actual APK inspected:
1.1.0-dev.1, build 2, debuggable. See VERSIONING.md; no release or install.
Counts: 29 IMPLEMENTED / 74 IN_PROGRESS / 15 NOT_STARTED / 1 BLOCKED_BY_PLATFORM.
Prior f40a11325ada92fee3d986ae1ce26b4cf245dc84 was pushed/remote-verified; main
remains 13ae6609d22cb2a0daf8890fca081fb97c93b36b. No service-file edits.
Next: H28 precise offline privacy/permission disclosures linked from Settings and
the permission gate; repair/test permission-page large text without changing
startup ownership, then continue remaining data/product/reliability matrix.
Latest ignored debug APK SHA-256:
`5F396F254FB2582B12135A5BBB536A541B3C3028C7C3EA08AD4DD0A72866968C`.

## Recorded Summary Checkpoint

Latest continuation: F4/F5 opt-in native recorded daily/weekly summaries, quiet
hours and notification controls. Private default-disabled receiver is enabled
only after opt-in; inexact alarms enqueue nonblocking jobs, all accounting reads
stay on the canonical journal worker. Native startup/timezone/reboot reconciliation,
permission/channel/unknown states, quiet deferral, DST/fixed-offset windows,
dated private notifications and durable calendar high-water receipts are tested.
At most one attempt per period, not guaranteed exactly-once physical delivery.
F2/F3 live-dependent reminders remain unavailable. See WELLBEING_SUMMARIES.md.
Full executed gates: 163 Flutter / 342 native in 26 suites, zero failures/errors/
skips; analyzer clean; debug/release Kotlin and debug APK pass. API 24 notification
branch plus API 28/35 policy/delivery/restart models included. Original 2x stock
time-picker overflow was fixed with a scrollable numeric editor, not font clamp.
Counts: 28 IMPLEMENTED / 75 IN_PROGRESS / 15 NOT_STARTED / 1 BLOCKED_BY_PLATFORM
= 119. A1 remains generic-route platform-blocked; no confidence promotion,
service-file change, real notification/device test, physical G or release claim.
Prior checkpoint `ddd02766435abbfd4f558cb0d0c7cecf551fe536` was pushed and remote-
verified; main remains `13ae6609d22cb2a0daf8890fca081fb97c93b36b`.
Source schema 3/projection 5 preserved; optional preference corruption cannot
block canonical reports. Full-app backup/legacy/preferences deletion still open.
Next safe independent work: H25 build/version policy and actual Settings build
metadata, then the remaining exact product/data/reliability matrix. Do not
present this checkpoint as all-feature completion or request routine hardware tests.
Local ignored debug APK SHA-256:
`7B4F0165400DDF2C26E4765AFBD260C95BD47B23D165690DA695C97C6152D99E`.
Delayed job-stop ownership reproduced three failures before correction. Durable
request UUID extras now fence replacements (not JobParameters object identity);
six ownership cases pass. Stored summary preferences use a bounded flat parser.

## Diagnostic Checkpoint

Latest hardening: inherited automatic GATT/vendor CCCD writes replaced with
consent-only bounded read-only service catalogs. Diagnostic opening/cancel do not
connect. Endpoint UI uses source/alias/revision and current-owner rechecks; private
resolution stays native. Diagnostic observations have their own source and
captured clocks, not legacy audio-service provenance. Source schema 3/projection 5
unchanged. See READ_ONLY_DIAGNOSTICS.md for ownership/bounds/Binder limits.
Full actual gates: 155 Flutter / 297 native in 23 suites (zero failures/errors/
skips), analyzer clean, both Kotlin variants and debug APK pass. Full-suite bounds
test first exposed wrong error labeling; control flow fixed, assertions retained.
No collector-service edits; strict previous-four-hook guard passes. No hardware,
vendor telemetry, physical G, signed release or production readiness claim.
Count: 26 IMPLEMENTED / 76 IN_PROGRESS / 16 NOT_STARTED / 1 BLOCKED_BY_PLATFORM =
119. A1 generic cross-app actual-output evidence is explicitly platform-blocked;
the public configuration-route field was documented as never populated. Narrower
A2DP acquisition is still independent work, not a generic solution. See
PLATFORM_ATTRIBUTION_LIMITS.md; do not waive the listening proof requirement.
Prior history checkpoint `00a0e17eafb8996cf83b5049df8d4060d50245ab` was pushed
and remote-verified; remote main remains `13ae6609d22cb2a0daf8890fca081fb97c93b36b`.
Next safe phase: F4/F5 opt-in native daily/weekly recorded summaries, quiet hours,
notification permission/channel controls, inexact scheduling and reboot/timezone
recovery using canonical queries. F2/F3 live-dependent reminders stay gated until
actual confirmed-route continuity exists. Then full-app data controls and exact
remaining matrix. No notification scheduling implementation is claimed yet.
Local debug APK SHA-256 (ignored/unpublished):
`53342EB136CD2D2BDD51A0BF76701DF84A358C62C8F46E2B3D1A23CF48C7E2D0`.

## Device History Checkpoint

Latest device-history continuation: canonical indexed device UUID filtering,
Devices-details/Analytics -> Timeline navigation, date ranges and independent
interval paging. Strict scope validation refuses a global/wrong-device reply.
B3 software acceptance is complete: actual name edit/cancel/save/error/recreation
plus native reconnect/replay persistence. Count: 26 IMPLEMENTED / 77 IN_PROGRESS /
16 NOT_STARTED = 119. B1/B2/B4 still need physical/route/transport acceptance.
Full gates: 151 Flutter / 272 native in 22 suites, both Kotlin variants and debug
APK pass. Source schema stays 3; disposable projection 5 replays v2/v3/v4 and adds
an index, retaining raw observations, identity records and consumer cursors.
Prior endpoint checkpoint `cbfb3106849615d5dd47222803f3d8bda08102b6` was pushed
and remote-verified; main stayed `13ae6609d22cb2a0daf8890fca081fb97c93b36b`.
Next safe hardening: inherited BleDiscoveryManager automatically connects and
writes vendor CCCD, and developer diagnostics trigger on open. Remove automatic
device interaction/vendor writes, require explicit one-shot consent and bounded
read-only diagnostics without new collector-service edits. Then continue the
remaining exact matrix, route-specific continuity and full-app data management.
No new physical or telemetry support is claimed. See `DEVICE_HISTORY.md`.
Debug APK SHA-256 (ignored/unpublished):
`B5A75DE1CDAEC152A0E2A888E20AD3B87519B4D0B2565ABDA599D81C6A73356E`.

## Endpoint Checkpoint

Latest resumed implementation: durable endpoint identities/reversible associations,
owner/revision/source fencing and truthful unknown-connection rendering. Full
gates: 146 Flutter / 264 native (22 suites, zero failures/errors/skips), analyzer
clean, debug/release Kotlin compilation and debug APK pass. Four-hook service
guard and public-tree audit pass. Source schema 3, disposable projection 4.
See `ENDPOINT_IDENTITY.md`. Count remains 25 IMPLEMENTED / 78 IN_PROGRESS /
16 NOT_STARTED = 119; this does not finish physical identity or route attribution.
Prior verified remote tip: `3d879aabce3d19f5e5375453ddc1bf7f321b68d5`.
Next safe work: native-filtered per-device history drilldown using the canonical
projection, then remaining tracking/data/product acceptance gaps. Do not promote
legacy global activity to a device or infer confirmed time from A2DP samples.
Debug APK SHA-256 (ignored, unpublished):
`31BD5423EDC000DBC12D3E8E01274674319D82511B6F572406D79A65355854C2`.
No hardware interaction, physical G or signed release validation occurred.

## Earlier Checkpoints

Latest continuation: reports/recorded goal streaks, widget variants/navigation
and integrated native journal export/confirmed transactional restore/recovery.
Reports checkpoint `a3d60dcfdff542eb074c38bda05d8ab670d3ab76` is remote-verified;
remote main remains `13ae6609d22cb2a0daf8890fca081fb97c93b36b`.
Full gates: 140 Flutter / 237 native, analyzer clean, both Kotlin variants and
debug APK pass, including the final command-owner recheck. Count: 25 IMPLEMENTED /
78 IN_PROGRESS / 16 NOT_STARTED (119). H17/H18 remain partial: native-only archives
exclude legacy history/preferences. This is NOT feature-complete or RELEASE_READY.
See `JOURNAL_ARCHIVES.md` and `REPORTS_AND_NAVIGATION.md`. No service edits.
Warm-navigation correction `7be2bbb9ae6e8c5a85435de106fd8dba4d4c5930` is remote-
verified; actual-shell failure/fix is tested. Public per-device A2DP acquisition
is now integrated into existing durable OUTPUT_EVIDENCE, still UNKNOWN attribution
and not live-eligible. See `A2DP_OBSERVATIONS.md` for API/error/ownership limits.
Next: persistent endpoint/physical identity and reversible aliases, then validated
route-specific continuity/projection integration. Continue full legacy/preferences
backup/restore/deletion and the rest of the matrix. No feature-count increase is
claimed for raw A2DP observations. Physical G/output/telemetry remain pending.
Review branch `codex/production-checkpoint-20261024`; protected baseline `0a8be43`.
Initial publication verified at `1b3ee7ea4d56afef30ffc018749e1ed25a841af5`;
the follow-up adds known-device pagination without changing listening accounting.
The interrupted health/attribution contract work is now completed and tested.
Contract checkpoint `9fd94b55a7e0c9eb31c0dcd6edae786c02accddd` was pushed and
remote-verified before runtime integration. A service-owned passive observer is
now integrated; it is NOT a confirmed route producer. See `COLLECTOR_HEALTH.md`.
Read `PRODUCTION_IMPLEMENTATION_LEDGER.md`, `LISTENING_PROJECTION.md` and
`FEATURE_MATRIX.md`. Autonomous implementation remains authorized; do not ask
for routine phase approval. This is NOT RELEASE_READY.

## Protected Baseline

`0a8be43` remains the known-good G reference. Its original collector was:

- SHA-256 `EF1DA5B8FF5AB092ACA80F2CCC78C7CEFE727C5F20FDFC045BF58E8E3752AC1D`.
- Git blob `78353ae1cd1d97897137360be8df24354f6c0bff`.
- Source equality held through `9fd94b5`. It is now **FALSE**: exactly four added
  lifecycle-hook lines own the passive observer (field, start, stop, destroy).
- Current Git blob `0d0c8df1b57824c895ad11dabce2b0dbf99de4dd`;
  raw SHA-256 `CDB9585BC875F2BBFF36D0C6EB0C6714D0FD978A6BAA636D51A4F9E2F8A3A1CC`.
- `tools/check_collector_baseline.ps1 -AllowObserverLifecycleHooks` passes by
  removing only those four exact lines in memory and comparing every remaining
  line against the baseline. Plain equality intentionally fails. No existing
  collector callback/Bluetooth/playback/initialization logic was edited.

Physical G and the historical A/B splash regression mechanism are still
UNPROVEN. The hook-only guard does not establish G for the changed application.
No app install, data clear, device command or physical test was performed in
this continuation. Current hardware attachment status was not checked.

## Current Implementation

Native journal schema **3**, listening projection version **3**:

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
- A valid current service-owner stop now closes routes at last durable evidence;
  later SYNC cannot bridge known downtime. Retired/duplicate stops are fenced.
  Projection v2 caches replay automatically to v3 without deleting raw rows,
  source IDs or acknowledgments. Internal rebuild cancellation stops at 128-row
  transaction boundaries; reads finish catch-up before returning complete totals.
  See `HISTORY_REPLAY.md` for the pre-fix failures and 1200-session load evidence.
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
- Service-owned `SupportedAudioObserver` registers/samples/cleans up on its own
  HandlerThread. Captured API samples enter the same bounded journal ingress,
  retain source/provenance and get durable health-state acknowledgments. It uses
  public inventory/global activity/communication/prediction APIs only, never GATT
  or route writes. Delayed callbacks trigger fresh reads, not stale route claims.
- Scoped 15s leases, 10s polls, one pending acknowledgment and one sample/second
  bound callback storms. Failure/denial retries back off 30s; rejected commits
  back off 10s and reinitialize with a new generation/epoch. Cleanup uncertainty
  prevents duplicate listener owners. Physical timing/energy behavior is pending.
- Handler/owner creation occurs in `onLooperPrepared`, never via a main-thread
  `getLooper` wait. Stop can return while worker initialization is blocked;
  closed initialization cannot register callbacks. Four API 28/35 worker tests
  cover blocked startup and exactly-once cleanup.

## Important Runtime Limits

**No current collector emits CONFIRMED output attribution.** Its global playback
flag can describe phone-speaker audio even with a headset connected. Therefore
real protected-collector activity is **UNVERIFIED**, not confirmed listening.
Nonzero confirmed route tests use explicitly identified synthetic native input,
not validated hardware. Do not interpret confirmed zero as measured silence.

**No validated route-specific listening lease exists.** The new observer's
durable health concerns inventory/global activity only, not legacy callback
success or another application's actual media output. Service stop/destruction
closes the observer; initialization failure, expired leases, unknown boot and
process gaps cannot grant health. Production queries do not extrapolate open
intervals beyond durable evidence. The reducer's explicit live path is model-tested, but
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

- Flutter: **129 passed**, exit 0. Original 103 slots retained, including 15
  formerly empty/trivial tests rewritten as actual assertions; 26 additional
  projection/settings/telemetry/layout cases. No skips/excluded test files.
- Analyzer: **No issues found**, exit 0. All 21 inherited findings and final
  formatter-exposed block lints corrected without suppression.
- Native: **173 passed**, 0 failures/errors/skips. Original 46 plus 127 new:
  projection 48; preferences 12; widget 6; durable hint buffer 2; ingress 4 total;
  health 20, synthetic output-policy 16, observer owner 10, Android adapter 3,
  history/load/cache upgrade 3, worker startup/close 4.
  Adapter API 24/28/35; SQLite/projection/preferences/widget/health API 28/35 models.
- Kotlin debug/release compile and debug packaging: exit 0, BUILD SUCCESSFUL.
  Inherited Kotlin/Gradle/old BLE API deprecation warnings remain; service code
  was not edited to remove them.
- Release signing check: expected exit 1, missing signing configuration. This
  validates a fail-closed gate, NOT a successful signed release build.
- `git diff --check`: exit 0; only CRLF advisory warnings. Earlier device inventory
  was empty; latest continuation performs no hardware interaction.
- Readable test-fixture Home captures at 360/1200 pixels in `build/qa/`; five main
  view large-text layout cases passed at 360 pixels / 2x text. Captures were
  inspected with local Roboto/Material Icons. Not device/launcher screenshots.

Interim failures were fixed, not hidden: RPC deadline leaked after disposal;
Windows native SQLite fixture paths exceeded practical path length; ingress
close raced queued work; final formatting exposed missing block braces.

Previous local debug artifact (historical, not installed/released/published):

- `build/app/outputs/apk/debug/app-debug.apk` and
  `build/app/outputs/flutter-apk/app-debug.apk`, each 158947452 bytes.
- Both SHA-256: `28E80584E5D57B36AB901F6D68BB3628EEAE35A83E1F82F801FFB832D04529E7`.

Prior pagination debug artifact (historical hash, not the current build):

- `build/app/outputs/flutter-apk/app-debug.apk`, 158947452 bytes.
- SHA-256 `1FB489CA9C3B2AB4C1C6B58002BA5EF2962ADB2B27DC89BA925A76BFD393F943`.
- Both debug APK paths have the same hash. Initial checkpoint AAPT confirmed debuggable, label
  EarTime, ID `com.eartime.eartime_app`, min SDK 24/target SDK 36.

## Preservation And Next Work

Native archive continuation: 139 Flutter pass; 222 native across 20 suites with
zero failures/errors/skips. New archive native coverage: 27 parser/SQLite cases,
six Activity picker cases and one runtime restore/drain fence case. Seven Flutter
transfer UI/contract cases, including 360px / 2x text confirmation. 1500 sessions /
3000 source observations round-trip without dropped pages; mid-import cancellation
and precommit fault preserve original rows/source/cursor. Initial non-void JUnit
declarations and analyzer style findings were corrected. The mobile test now
scrolls to a lazily built action and scales the Navigator/dialog, not just home.
No warnings or assertions were suppressed. Archives contain private plaintext
observations, not full-app data, and must never be published. Stalled-provider
hard cancellation, whole-app backup/deletion and physical durability remain open.
Schema/projection stay 3; existing fault evidence/preferences/legacy are retained.
Latest ignored debug APK SHA-256:
`B9CC2833BF3C2A011A1178034AF872920AF3E20A912404801B34D41E3F38E570`.
Artifact was not installed, signed for production, released or published.

Latest reports/widgets/navigation validation: 132 Flutter tests passed, 188
native tests in 18 suites, zero failures/errors/skips. Native additions: five
report algorithm cases, two persisted-goal/reopen/rebuild cases, six shortcut/
safe-intent/manifest cases and two summary-widget cases. Flutter additions:
navigation consume/disposal case plus report contract and large-text UI cases.
One analyzer block-style finding was fixed, not suppressed. Both Kotlin variants
and debug APK packaged successfully; inherited Gradle/SDK warnings remain.
APK SHA-256: `4DBA01C4BEB7B1278ADCD8B14876551655615EBFE179BB149F35F5F8B1A33A59`.
No signed release, install, device interaction or physical validation.

Pre-phase and pre-publication checkpoints remain local and unpublished.
The pre-publication index/source copy is under ignored `.local-checkpoints/`.
Before public staging, the saved index SHA-256 was:
`9CC0E1BFF5FC75D56E204784398E419812266CD247BB6C3BCFFEBF75276A69EA`.
Publication uses reviewed feature-branch commits only; no destructive migration,
main update, force push or device mutation. See `PUBLIC_CHECKPOINT.md`.

1. Establish route-specific listening evidence, not merely observer health.
   Scoped runtime ownership/health/cleanup now pass automation. Keep production
   extrapolation/reminders disabled until real lifetime/route evidence exists.
   Preserve all unknown/gap behavior and the explicit hook-only baseline guard.
2. Finish evidence-backed identity/alias normalization and a permitted route
   collector. Generic global playback or a discovered UUID is not that proof.
3. Add long-history load/cancellation/replay fairness tests, including device
   paging under concurrent observations. The 1200-session/2400-row model and
   internal rebuild cancellation now pass; normal startup fairness, cross-layer
   cancellation and larger/device profiles remain open. Never return partial totals.
4. Implement versioned local export/backup/restore/deletion with explicit user
   confirmation for destructive actions, conflict-safe transactions and tests.
5. Continue the remaining matrix: connected/idle partitions, richer analytics,
   reminders/quiet hours only for validated inputs, reports/streaks, additional
   widgets/shortcuts, localization and accessibility across every screen.
6. Finish authorized signing/release packaging and physical G/background/
   process-death/routing/launcher/telemetry acceptance. No release-ready claim.
