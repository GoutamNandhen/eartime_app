# EarTime Production Implementation Ledger

Date: 2026-10-24. User authorization: master autonomous implementation request
and subsequent resume instruction. Historical STOP entries are superseded for
implementation; their unresolved physical findings remain valid.

Latest checkpoint: record-state consistency/average correction, 217 Flutter / 366 native
passing tests, analyzer clean. The recovery baseline below is historical.
`LISTENING_PROJECTION.md` describes current attribution/liveness limitations.

## E12 Recorded-State Consistency

2026-10-25 continued from remote-verified 248c1d6f876614a355ae41c45594372c52a726a4.
Actual RED cases exposed accepted negative metadata and missing Home empty-state
semantics. Native read errors also reproduced default Riverpod backoff replacing
the already-owned refresh stream and leaving timers. Only this provider's duplicate
framework retries are disabled; bounded foreground refresh, errors, manual retry,
event hints and cancellation are retained. A lifecycle fixture was corrected to
valid intermediate states, not by changing production lifecycle assertions.
3x tests caught a trailing-label layout failure; the failing render storm was
interrupted and the same assertions rerun after duration moved below details.
Real-shaped daily buckets then caught another numeric-zero cell: consistent
recorded-only wording and naturally flowing daily/device details fix it.
31 new Flutter tests cover malformed data, all seven states across four views,
retry, paused inactivity and disposal. Existing shared-view zero assertion now
requires None recorded, while its positive-duration/source assertions remain.
Native review found averageMs included zero-length spans in its denominator while
listeningRuns excluded them. Two API 28/35 RED tests proved expected 4000ms versus
actual 2000ms. The one-line query filter now excludes zero spans only from aggregate
confirmed runs; raw observations and both interval rows/open count survive replay.
No schema/cache migration, writer, attribution promotion or protected-service edit.
Four new native executions; final full gates: 217 Flutter / 366 native, 28 suites,
zero failures/errors/skips; analyzer clean; both Kotlin variants/debug APK pass.
Four style findings fixed without suppression. E12 software complete; count
33/70/15/1 = 119. E6 remains partial pending grouped-session semantics. Next bounded
canonical Timeline grouping, then remaining approved data/product/reliability work.
No physical output/G, whole-app data-control completion or release-ready claim.

## D7/E1 Calendar Filters And Totals

2026-10-25 resumed from 9df34d4003a3e9c79d1fdb3653ba4b2380c1e5e7 and preserved
all five interrupted files. The prior auto-review usage-limit rejection executed
no formatting/test command; no permission bypass attempted. Credits restoration
allowed those commands normally. Calendar/date work now passes all actual gates.
Shared local-calendar bounds retain canonical native accounting. Inclusive custom
dates, 366-day limits, 1970+ preserved history, cancellation, clock rollback and
year-bearing labels work in the real UI. Both offsets reset defensively; device
UUID remains scoped. Stock header overflow was actually reproduced at 360px;
localized scrollable Flutter date fields replace it, without font clamping.
13 Flutter new tests include 100-row pages and 1x/2x/3x controls. Four API 28/35
native executions verify actual SQLite calendar union/buckets, overlap, invalid
query refusal, reopen/replay/raw/cursor retention. Full gates: 186 Flutter / 362
native in 28 suites, zero failures/errors/skips, clean analyzer, debug/release
Kotlin and debug packaging. Version/diff/protected-four-hook checks pass.
D7/E1 software-complete; count 32/71/15/1 = 119, no source/projection schema change,
collector edit, physical G, real route or release claim. Next E12 product-state
consistency, grouped sessions and remaining approved data/product/reliability work.

## H28 Disclosures And Permission Layout

Continued after remote-verified 9a1bd3b216bf14f3f087d0bef9ce9731e6294ace.
Nine offline sections expose actual data, permission, networking, diagnostics,
native-only archive and missing-deletion limits before grant and in Settings.
Disclosure navigation performs no platform/device/data action. Existing fixed
startup layout reproduced 1084px/3032px overflow at 2x/3x; safe-area scrolling and
natural controls fix it without font clamping or startup/collector logic edits.
Four native merged-permission/backup-rule executions plus six Flutter cases pass.
Lazy-list tests explicitly render/ensure targets instead of suppressing missed
taps. All older rapid-reopen/owner assertions retained. Full gates: 173 Flutter /
358 native in 28 suites, zero failures/errors/skips, clean analyzer, both Kotlin
variants and debug packaging. H28 software complete; count 30/73/15/1 = 119.
H15/privacy audit, H17/H18/full backup and H19/deletion are still open, not hidden
behind policy copy. No physical G, accessibility-service, device/backup behavior,
signed release or readiness claim. Next D7/E1 calendar/date acceptance.

## H25 Version Policy And Installed Metadata

Continued after remote-verified f40a11325ada92fee3d986ae1ce26b4cf245dc84.
Version 1.1.0-dev.1+2 is tracked once in pubspec; Gradle preBuild refuses stale
Android metadata/overrides. A 17-case checked Git comparison tool rejects reused/
decreased numbers, malformed names, integer overflow and ambiguous declarations.
Initial capture-group and CRLF bugs were caught and fixed by real executions.
About reads installed metadata on the existing bounded worker with owner-fenced
replies, error/retry, selectable values and licenses, not a hardcoded source name.
Twelve API 24/28/35 native cases plus four Flutter cases pass, including 64-bit
codes and actual Settings navigation at normal/2x text. Ambiguous test scroll
targets were explicitly scoped; two analyzer findings fixed without suppression.
Full gates: 167 Flutter / 354 native in 27 suites, zero failures/errors/skips;
analyzer clean, Kotlin debug/release and debug packaging pass. Aapt inspected the
actual APK: 1.1.0-dev.1, code 2, debuggable. H25 becomes software complete; count
29/74/15/1 = 119. No protected-service change, device interaction, signed release,
readiness or physical G claim. Next H28 privacy/permission copy and layout, then
remaining exact matrix; no feature-completion verdict.

## F4/F5 Native Recorded Summaries

Continued from remote-verified `ddd02766435abbfd4f558cb0d0c7cecf551fe536`.
Implemented opt-in daily/weekly summary categories, preferred time, daytime/
overnight/all-day quiet hours, permission/channel recovery and honest unavailable
states in Settings. Native inexact alarms/private default-disabled boot/timezone/
update receiver/nonblocking jobs use the same canonical journal query. Receiver
enable changes use DONT_KILL_APP. No Dart accounting timer, new listening store,
network dependency, exact-alarm permission or protected-service edit.

Calendar windows and quiet deferral preserve original report periods across
refresh/restart/DST. Fixed-offset timezone IDs are accepted without unknown-zone
fallback. Delivery rechecks config/permissions/quiet/job ownership, dates private
notifications, excludes unknown time and refuses query-error zero substitution.
Durable high-water receipts prevent repeated/older calendar alerts after clock
changes. Semantics are at most one attempt: receipt-before-post cancellation/
crash can miss delivery. Late jobs entering quiet hours are suppressed, not a
backlog. Physical timing/permission/OEM/lock-screen acceptance remains pending.

Added 45 native cases (34 API 28/35 policy/delivery cases, 2 API 24 notification
branches, 1 native startup/process replacement, 2 manifest cases, 6 job ownership
cases) and 8 Flutter cases. Full gates: 163 Flutter / 342 native, 26 suites, zero failures/errors/skips;
analyzer clean; debug/release Kotlin and debug packaging pass. Test return-type,
nullable metadata/import and style issues fixed. Stock time picker actually
overflowed at 2x text: replaced with scrollable full-width numeric editor and
retained validation/cancel/large-font tests. Retry test also awaits/scans the
changed error-state layout. No skipped cases, font clamping or weakened assertions.
Delayed stop callbacks originally removed a replacement job by numeric ID: three
of four RED ownership cases proved it. Every enqueued job now has request UUID
extras; stop matches serialized token values, finish compare-removes its owner.
Six final cases include reparceled token equality and 500 replacements. No
JobParameters object-identity assumption. Stored preferences reject deep/duplicate/
oversized JSON before recursive parsing; optional corruption cannot block history.

F4/F5 become software-complete/PHYSICAL_PENDING. Count: 28 implemented, 75 partial,
15 not started, 1 platform-blocked = 119. F2/F3 are not implemented and remain
gated by actual output/continuity. Preference-corruption isolation is tested;
preferences/receipts are still excluded from native-only archives, so H17/H18/
H19 remain incomplete. Next: H25 build/version metadata/policy, then remaining
approved data/product/reliability work. No physical or release validation.

## Read-Only Diagnostic Privacy Hardening

Started after remote-verified `00a0e17eafb8996cf83b5049df8d4060d50245ab`.
Source inspection proved automatic inventory GATT connections, vendor CCCD writes
and screen-open diagnostic interaction. Replaced the manager outside the protected
service with explicit ephemeral endpoint consent and bounded off-main read-only
catalog inspection. No characteristic reads, subscriptions, vendor writes or
notification-payload forwarding remain in that path. Owner/source/revision fences
keep private address resolution native. Dedicated diagnostic source/provenance
is durable before committed broker delivery. See READ_ONLY_DIAGNOSTICS.md.

22 API 28/35 safety cases, 2 private-resolution cases, 1 captured-source ingress
case and 4 Flutter consent cases added. Full-suite run first failed twice on an
oversized live catalog: finally closed with finished before error handling. This
was a real reason-label defect, not a bounds escape. Success/error closure was
separated; unchanged assertions passed. Final full gates: 155 Flutter / 297 native
in 23 suites, zero failures/errors/skips; analyzer clean; debug/release Kotlin and
debug APK pass. No new service-file change, device interaction, physical G or
telemetry compatibility evidence. Inherited deprecation/SDK XML warnings remain.

A fresh primary API review verified the generic attribution platform boundary:
AudioPlaybackConfiguration.getAudioDeviceInfo is documented as never populated;
owned-player AudioRouting and predicted attributes are not a replacement for
other apps' actual output. A1 is explicitly BLOCKED_BY_PLATFORM without changing
its acceptance requirement. Narrower A2DP candidate work remains possible/open.
Counts: 26 implemented / 76 partial / 16 not started / 1 platform-blocked = 119.
This is not a completion claim. Next: opt-in canonical daily/weekly summaries and
quiet/permission controls (F4/F5), not fabricated live-dependent reminders.

## Canonical Device History And B3 Acceptance

Endpoint checkpoint `cbfb3106849615d5dd47222803f3d8bda08102b6` was pushed and
remote-verified before this phase; remote main stayed unchanged. Added native SQL
device filtering before all canonical aggregates/pages, a composite device/window
index and the real Devices/Analytics -> device Timeline path. Echoed scope and
returned IDs are checked in Flutter, including provider-cache identity. Global
goals are not relabeled as device goals; legacy global activity stays unattributed.
Derived v2/v3/v4 caches replay as v5, source schema remains 3. See DEVICE_HISTORY.md.

Four API 28/35 projection tests (8 executions) cover union/clipping/global
reconciliation, 105 device intervals interleaved with another identity, replay/
reopen, invalid/unknown UUIDs and v4-index migration/raw/consumer preservation.
Five Flutter acceptance tests cover strict method-channel scope rejection, actual
normal/large-font navigation/paging and name cancel/save/error/UI recreation.
Native identity tests already prove UUID/name persistence through reconnect/
reopen/replay. B3 therefore becomes IMPLEMENTED / AUTOMATED_PASS / PHYSICAL_PENDING;
physical identity itself is B1, still partial. Counts: 26/77/16 = 119.
Full gates: 151 Flutter / 272 native (22 suites, zero failures/errors/skips), debug/
release Kotlin and debug APK pass. Analyzer block-style findings in new tests were
fixed without suppressions. Baseline guard permits exactly the previous four
hooks; no new service edit or physical validation. Public audit required before
publication. Inherited automatic BLE connection/vendor CCCD writes were found by
source inspection; next phase must gate/remove these, not enable vendor telemetry.

## Interrupted Endpoint Work Resumed

Resumed from `3d879aabce3d19f5e5375453ddc1bf7f321b68d5`, preserving all
12 unfinished source/test files and local checkpoints. Completed the journal-
backed endpoint registry, production association/reset UI, source/revision/owner
fences, cache-v4 replay and honest connection uncertainty. Display names are
captured off-main and remain independent of stable random transport associations.
No name-only merging, history relabeling, verified physical identity, real route
confirmation or listening timer was introduced. See `ENDPOINT_IDENTITY.md`.

Added 24 API 28/35 identity cases, one queued-owner ingress regression, two
widget unknown-state cases and six Flutter contract/UI cases. Existing A2DP
probe assertions now verify name sanitization and explicit connection evidence.
Full gates: 146 Flutter, 264 native in 22 suites, zero failures/errors/skips;
analyzer clean; debug/release Kotlin and debug packaging pass; strict hook-only
guard and diff checks pass. Initial lints, scroll-frame/layout test issues and
Windows fixture database-path failure were repaired without weakened assertions.
Build reports inherited SDK XML-version/Gradle deprecation warnings, not errors.
The first staged audit passed 305 files/274 text candidates; rerun the exact
final tree after documentation staging before publication. No new service edit.
Feature counts remain 25/78/16 (119): B1/B2/B3 advance but retain unresolved
physical/transport/rename acceptance. Continue per-device history and the exact
remaining matrix; this is not final feature completion or physical G evidence.

## Recovery and baseline

- Branch: `g-regression-experiment`; HEAD: `0a8be43b9f064f3dc9d029c66bb1377d810ac315`.
- Before publication, inherited dirty/staged content was preserved without commits.
- Recoverable source/test/docs/config/index snapshots remain local and unpublished.
- Protected `AudioTrackingService.kt` Git blob: `78353ae1cd1d97897137360be8df24354f6c0bff`;
  source equaled known-good `0a8be43` before the later observer hooks.
- Baseline: `flutter test --no-pub --reporter compact`: exit 0, 90 tests.
- Baseline: `android/gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin --offline`:
  exit 0, existing 15 JVM tests (Gradle up-to-date results).
- Analyzer: exit 1; 21 inherited issues (16 warnings, 5 infos), zero errors;
  final new-code lints repaired; no additional analyzer issue remains.
- Read-only ADB inventory: no connected devices; no configured AVD returned.

## Reports, Widgets And Navigation Continuation

Resumed clean from remote-verified `2d7195524a4de4bda28d2ea8d3ca083b1d137a5f`.
Implemented E10, F6, I1, I2 and I3. F7 now partial, not complete: personal-goal
guidance exists; observed-break guidance remains open. Count is 25/119 implemented,
76 in progress and 18 not started. No excluded feature or confidence promotion.

Production components: native read-only ListeningReport attached to canonical
snapshot, persisted-goal/window streak metrics and actual-data insights in
Analytics/Wellbeing; current-activity/daily-summary native widgets; four static
shortcuts, strict navigation URI parser, pending cold/warm destination channel
with disposal/engine-owner fences. No competing timer or new history store.

All gates executed: 132 Flutter pass; 188 native pass (18 suites, zero failures/
errors/skips); analyzer exit 0; debug/release Kotlin and debug APK exit 0.
Hook-only baseline guard and diff whitespace check pass. The service itself was
not edited. Manifest explicitly disables Flutter's default deep-link handler to
avoid a competing initial route path; actual XML is regression-tested. An analyzer
block-style finding was repaired without suppression. Native report tests use
synthetic confirmed history, not physical output proof. Launcher/OEM/G remains
PHYSICAL_PENDING. No signed release or installation. Next: data management and
the remaining exact approved matrix, not additional scope.

## Implementation phases

### Public A2DP Acquisition

Publication correction: commit `15c417b4d963801b26d99381a0b773596f4147b6`
was pushed after the audit flagged a newly invented second synthetic test address
outside its existing allowlist. The orchestration incorrectly continued after
that failure. No user device address/credential was used. The corrective commit
uses an already approved distinct fixture; the scanner and assertions are not
weakened. Tests/audit must pass before corrective publication. History is retained;
future orchestration checks each gate's exit status before commit/push.

Continued after remote-verified navigation commit `7be2bbb9ae6e8c5a85435de106fd8dba4d4c5930`.
Implemented passive public profile proxy acquisition/query/cleanup on native
workers; fresh per-device streaming candidates now enter the existing durable
OUTPUT_EVIDENCE path. No new service hooks, routing writes, GATT or reflection.
API false/empty fallback stays ambiguous; endpoint address is not a physical ID.
Confidence and live eligibility remain UNKNOWN/false. No confirmed duration,
second timer/projection or extra feature-complete claim. Count stays 25/78/16.

14 probe regressions, actual API 24/28/35 backend wiring and one durable ingress
case cover owner/request generations, late/off-main cleanup, bounded reservations,
fresh queries, false/empty/permission states, duplicate identity and clock/owner
loss. Full gates: 140 Flutter, 237 native in 21 suites with zero failures/errors/
skips; analyzer clean; Kotlin debug/release and debug APK pass. Guard checks all
preexisting service lines against `0a8be43`. Physical G/routing/energy pending.
Unresolved proxy callbacks/failed cleanup retain bounded reservations, so capacity
may stay unavailable until process restart; do not call that recovery complete.
Next: persistent endpoint/physical identity/aliases and evidence-gated canonical
continuity, then remaining data/product scope. See `A2DP_OBSERVATIONS.md`.

### Warm Navigation Correction

Archive commit `0aba4f67b3599c60dc501e5e19b17342f0e18c1b` is remote-verified.
A warm native hint changed the shell tab underneath Settings. An actual-shell
test reproduced the failure, then passed with Navigator route dismissal. Full
Flutter 140 pass; analyzer/native/Kotlin debug+release/debug APK gates pass,
222 native cases. No service edits/physical validation; count stays 25/78/16.

Next supported-route investigation: public BluetoothA2dp.isA2dpPlaying reports
per-device transport streaming rather than global activity/inventory. AOSP also
returns false on API/service failure; false is not proof of health or silence.
Do not enable confirmed intervals or live leases from research alone. Integrate
bounded samples/ownership/failure semantics first. Primary references are linked
in `REPORTS_AND_NAVIGATION.md`. No reflection, vendor writes or pairing changes.

### Native Journal Archives

Continued after normally pushing and verifying reports checkpoint
`a3d60dcfdff542eb074c38bda05d8ab670d3ab76`; main/baseline refs unchanged.
Delivered streaming versioned native export, bounded/checksummed validation,
explicitly confirmed transactional restore, synced local recovery archives and
paged recovery UI. Restore closes at last evidence and fences pre-restore queued
events from subsequent collection. Document I/O has its own worker; no new
storage permission or automatic export/import. Transfer setup is lazy: normal
startup/reopen/teardown does not initialize a worker or call picker cleanup.
Retired/superseded engines cannot start/cancel transfers or consume the newer
engine's navigation target. No collector edits or hardware interaction.

H17/H18 move to IN_PROGRESS, not IMPLEMENTED: native-only archives exclude
preserved legacy history/preferences/fault evidence. Existing preferences,
legacy history and fault records remain intact. H19 deletion is still NOT_STARTED.
No automatic recovery-history pruning. Count: 25 IMPLEMENTED / 78 IN_PROGRESS /
16 NOT_STARTED. Format, limits and remaining work: `JOURNAL_ARCHIVES.md`.

All gates executed: 139 Flutter, 222 native in 20 suites, zero failures/errors/
skips; analyzer clean; debug/release Kotlin and debug APK pass, rerun after final
engine fencing. Coverage includes 1500 sessions/3000 observations, corruption/
version/depth/UTF-8/duplicate-key refusal, atomic crash/mid-import cancellation
rollback, reopen/idempotence, picker lifecycle and queued/future epoch separation.
Initial JUnit return declarations, analyzer style findings and off-screen mobile
fixture interaction were repaired without removing assertions or suppression.
Stalled-provider cancellation, full-app backup/deletion and physical OS death/
power loss remain open, along with the remaining exact approved matrix.

| Phase | Scope / feature IDs | State | Evidence / next work |
| --- | --- | --- | --- |
| 0 | Recovery, checkpoint, baseline | IMPLEMENTED | Both checkpoints preserved; analyzer now clean |
| 1 | G11-G13, G19 startup and engine ownership | AUTOMATED_PASS / PHYSICAL_PENDING | Inherited 2C-B.1 verified by baseline; OnePlus splash cause unproven |
| 2 | B1-B4, A10, G5-G6 identity, routes, per-device state | IN_PROGRESS | Five scoped-device Flutter tests, seven native contract tests pass; registry/normalization integration remains |
| 3 | G1-G4, G9-G10 native durable ingress | IN_PROGRESS | Schema 3/projection/cursors and v1/v2 migrations pass; legacy read-only preservation; import/export OPEN |
| 4 | A11-A12, C1-C5, D1-D11, G7-G8 interval projection | IN_PROGRESS | Shared native query/B02 observed opening pass; real route attribution and liveness lease OPEN |
| 5 | A1-A10, G14-G15 collectors and route proof | NOT_STARTED | Service baseline protected; bounded collector changes require evidence |
| 6 | B5-B13 vendor/standard telemetry | NOT_STARTED | Proprietary interoperability pending; keep unverified adapter disabled |
| 7 | C-H screens and accessibility | IN_PROGRESS | Canonical five views, real date queries, offline fonts, responsive fixture checks; full acceptance OPEN |
| 8 | H11, I widgets, shortcuts, reports | IN_PROGRESS | Native dark two-column multi-device widget/resource tests; physical launcher/variants/shortcuts OPEN |
| 9 | F1-F8, H13-H19 settings/data control | IN_PROGRESS | Native themes/goals/names and legacy history; reminders/export/restore/delete OPEN |
| 10 | G16-G20, H20-H22 hardening | IN_PROGRESS | Bounded hints/results, indexed devices, loss markers, clean analyzer; long-run/OS tests OPEN |
| 11 | H23-H28 release candidate | IN_PROGRESS | Debug APK/release Kotlin compile pass; signing fail-closed/backup exclusions; signed RC/physical gates OPEN |

## Evidence limits

G means the historical physical reopen scenario, not merely section G of the
feature specification. Its A/B regression mechanism is unproven. A successful
framework post-frame trace cannot exclude service work in other failing runs,
nor establish native display/starting-window dismissal. Do not repeat prior
claims that the two historical A/B edits have been ruled out.

Known inherited limitations: native fallback identity, global playback,
pre-emission collector state and automatic experimental BLE discovery. Product
consumers no longer use the volatile legacy delivery/history calculation. B02's
observed opening is corrected; production live ticking remains disabled without
collector-liveness proof. No production-ready or physical-PASS claim.

## Verification protocol

Run focused tests, full Flutter tests, analyzer and native test/compile gates
after each integrated phase. Check protected service against `0a8be43` and
preserve staged work. Record automation separately from physical evidence.
Resume instructions and exact next work live in `CODEX_RESUME.md`.

## Current checkpoint evidence

Final suite: 129 Flutter tests passed (original 103 slots including 15 rewritten
placeholder cases, plus 26 new). Native: 173 passing tests (original 46 plus 127),
0 failures/errors/skips. SQLite/projection/preferences/widget models use API
28/35. Kotlin debug/release compile and debug APK packaging pass offline.
Analyzer exits 0, no issues. Signing check intentionally exits 1 without
authorized signing configuration; release debug-key fallback was removed.

All 119 approved feature IDs are tracked individually in `FEATURE_MATRIX.md`.
`JOURNAL_FOUNDATION.md` documents delivered architecture, preserved legacy data,
limits of the previous foundation. `LISTENING_PROJECTION.md` supersedes its old
accounting/buffer state. No release readiness is claimed.

## Initial Projection Phase Evidence And Preservation

- Pre-phase gates: 103 Flutter pass; original 46 native cases/compile pass;
  service equal to `0a8be43` before and after. No speculative G fix applied.
- Source/test/docs/config/index checkpoints remain local. A pre-publication
  copy is preserved under ignored `.local-checkpoints/`.
- Saved pre-publication index SHA-256:
  `9CC0E1BFF5FC75D56E204784398E419812266CD247BB6C3BCFFEBF75276A69EA`.
  This is historical preservation evidence; subsequent reviewed staging and
  feature-branch commits are authorized. No user DB deletion or device mutation.
- Raw service SHA-256 still
  `EF1DA5B8FF5AB092ACA80F2CCC78C7CEFE727C5F20FDFC045BF58E8E3752AC1D`.
- Native detail: projection 44, preferences 12, widget 6, durable hints 2,
  ingress 3, original journal 20, contracts 7, queue 3, buffer 5, ownership 10.
- Flutter additions: shared projection/fixture/RPC/lifecycle/layout 14, settings
  4, telemetry 2. All test files run. The 14 empty pipeline tests and trivial
  widget test now execute real assertions; none were dropped/skipped for green.
- B02 proof preceded product cutover: T1=1000, SYNC S=5000, pause=9000 yields
  8000 with T1 retained, not 4000. Confirmed synthetic route/replay and
  gap-separated recovery also pass. This is not proof of physical G causality.
- Product activation no longer writes Drift. Legacy data are separate read-only
  observations, not silently imported or promoted to confirmed listening.
- Current collector always UNKNOWN. Production never treats process lifetime
  as a live lease. Confirmed route fixtures and modeled death are not physical
  route support or OS process-kill evidence.
- Repaired interim failures: RPC timeout on disposal, Windows SQLite fixture
  paths, queued-worker close race and formatter-exposed block lints.
- `build/qa/home-360.png` / `home-1200.png` use local Roboto/Material Icons and
  synthetic fixture data. Text/controls inspected; not phone/launcher captures.
  Large-font widget reduces to one two-column row; batteries remain unknown.
- Debug APK: 158947452 bytes, SHA-256
  `183D9D53A04367E6E2DEE90BD572B79B9D9A938C5E8450A5E5A4ACAA8ED255AB`.
  No signed release APK/AAB produced/published; ADB inventory empty. Continue
  exact next work in `CODEX_RESUME.md`.

## Public Publication And Device Pagination Follow-Up

- Initial tested checkpoint: `1b3ee7ea4d56afef30ffc018749e1ed25a841af5`,
  normally pushed to `codex/production-checkpoint-20261024`. Remote SHA and
  required documentation/protected-service blobs verified via fetch/ls-tree.
- Initial gates: 123 Flutter / 112 native, analyzer clean, debug/release Kotlin
  compile and debug packaging pass. Native tests also forced fresh with
  `:app:testDebugUnitTest --offline --rerun-tasks`.
- Reviewed 111 changed paths explicitly, including inherited staged tests.
  Exact public tree audit: 260 files / 229 text candidates, no prohibited
  matches. Hardware-derived fixture addresses replaced by synthetic ones.
  Local screenshots, reports, research and original index remain preserved.
- Local main remained `d5de30c75f5547c9973a4a445b5f4b435a849745`;
  remote main remained `13ae6609d22cb2a0daf8890fca081fb97c93b36b`.
  Original branch/baseline untouched. Future published rollback uses `git revert`.
- Follow-up: native known-device queries now accept independent `deviceOffset`
  and return bounded 100-row pages, total count, next offset and continuation.
  Flutter validates response cursors and exposes next/previous device pages.
  The Devices date selector is removed because known devices are not date-filtered.
- Three new Flutter tests and four API 28/35 native cases verify 205 devices,
  no duplicates across unchanged pages, reopen parity, invalid/out-of-range
  cursors and independent listening totals. Full gates: 126 Flutter / 116 native,
  zero failures/errors/skips, analyzer clean, both Kotlin variants and debug
  packaging pass. Protected service still equals `0a8be43`.
- Paging is a live ordered view; source changes may reorder rows between pages.
  Frozen paging, large-load profiling and cooperative replay remain open.
- Follow-up local debug APK: 158947452 bytes, SHA-256
  `1FB489CA9C3B2AB4C1C6B58002BA5EF2962ADB2B27DC89BA925A76BFD393F943`.
  APK remains ignored/unpublished; no new hardware/signing acceptance claimed.

## Recovered Health And Attribution Contract Checkpoint

- Resumed the existing ten unfinished source/test changes after the usage-limit
  interruption; preserved all modifications. No reset/clean, migration deletion,
  device interaction or protected-service edit.
- Durable health contract folds into the existing projection transaction, with
  owner generations, continuity epochs, registration/sample acknowledgment,
  bounded 15s leases, expiry/clock/boot fencing and explicit unavailable states.
  Health time is not the live-extrapolation clock. UI reports scoped health;
  old snapshots decode as UNKNOWN. No runtime health producer exists yet.
- Supported Android API semantics reviewed against official references in
  `COLLECTOR_HEALTH.md`. Cross-app playback route cannot be inferred from device
  inventory, global playback, communication routing or attribute predictions.
  The owned-player policy is pure/inactive; no real confirmed collector added.
- New tests: 16 API 28/35 durable health cases, 16 synthetic route-policy cases,
  two Flutter health contract/status cases. Full Flutter 128; native 148;
  analyzer clean, debug/release Kotlin and debug packaging successful.
- An initial native rerun failed because an interrupted Gradle process retained
  `output.bin`. Read-only process/daemon inspection identified the idle build
  daemon; stopped it normally and reran with `--no-daemon`, preserving reports.
  This infrastructure failure is not counted as a passing test run.
- Feature totals remain 20 IMPLEMENTED, 75 IN_PROGRESS, 24 NOT_STARTED = 119;
  partial contracts do not complete production attribution or live continuity.
- Next: separately tested native observer ownership/cleanup and captured-source
  ingress. Any necessary service lifecycle hooks require an isolated reversible
  change after this recoverable, source-equal checkpoint. Physical G stays pending.

## Observer Integration Necessity (Before Service Edit)

- Recoverable contract checkpoint published and remote-verified:
  `9fd94b55a7e0c9eb31c0dcd6edae786c02accddd`. At that point the protected
  service still exactly matched `0a8be43` and all 128 Flutter / 148 native gates passed.
- A process singleton or EventChannel cannot acknowledge actual service owner
  start/stop. The new passive observer therefore needs explicit service ownership.
  Proposed narrow service diff: one nullable owner field, asynchronous start
  after successful foreground entry, idempotent close on ACTION_STOP and onDestroy.
  No existing callback, Bluetooth, routing, initialization or playback logic is
  to be changed. Independent observer tests precede these four added lines.
- This only establishes the sidecar's inventory/global-activity scope. A failed
  legacy callback initialization must not become a claim of healthy legacy
  tracking or confirmed output. The sidecar never emits confirmed intervals.
- Source equality will no longer hold if those hooks are integrated. Record the
  exact baseline diff and use a strict hook-only guard; never report equality or
  physical G PASS for a changed service. Published rollback remains `git revert`.

## Scoped Runtime Observer Implementation

- Independent tests passed before the service edit. Integrated exactly four
  lifecycle additions; all existing collector lines remain unchanged against
  `0a8be43`. Guard: `tools/check_collector_baseline.ps1 -AllowObserverLifecycleHooks`.
  Plain equality is now FALSE, not a passing baseline-equality result.
- Observer registers on an owned HandlerThread after foreground entry and
  closes asynchronously/idempotently on stop/destruction. Immediate restart
  accepts a new owner. No service callback, A2DP/BLE or legacy playback logic changed.
- Public API samples retain captured wall/elapsed time and their distinct source
  through bounded ingress. Commit acknowledgments verify durable projected
  generation/epoch/state, not receipt or process uptime. No route confidence is
  upgraded; samples never create listening duration. No native route/GATT writes.
- Sampling/ack bounds, 10s polls, 15s scoped leases and retry backoffs (10s commit,
  30s API/permission) prevent callback storms/retry spins. Cleanup uncertainty
  inhibits new registrations. Long-run storage/battery measurements remain open.
- Added 10 owner tests (including 500 replacements and 1000 callback calls),
  three adapter API models (24/28/35), one durable-ingress case and one Flutter
  observer-hint decoder test. Full gates: 129 Flutter / 162 native, analyzer clean,
  Kotlin debug/release and debug packaging pass. Existing B02, migrations,
  rebuild and rapid-reopen models remain green. No physical testing performed.
- Initial ingress test correctly failed with no modeled boot identity. Added an
  explicit synthetic BOOT_COUNT fixture; production boot/clock refusal was kept,
  and status acknowledgments now validate every requested phase, not only HEALTHY.
- Remaining core blockers: cross-app actual output evidence, stable physical
  identity, route-specific live continuity; inventory health is not that proof.
  Feature counts stay 20 IMPLEMENTED / 75 IN_PROGRESS / 24 NOT_STARTED (119).
  Continue independent load/replay, identity and data-management work; do not
  enable confirmed ticking/reminders based on this scoped observer.
- Observer debug APK (local/unpublished): 158947452 bytes, SHA-256
  `DB3530312DB28152E82B1D2B95C16E6EBD8030C588475497F01D42FD9F523809`.

## Proven Owner-Stop Gap And Replay Hardening

- Observer commit `53277bee8591e3f5f800663c8801324d7ff30083` was normally
  pushed and remote-verified before this phase. Main remained unchanged.
- Two new owner-stop regressions ran RED on API 28/35 (four failures): health
  STOPPED left a legacy interval open. After proof, the canonical reducer closes
  at last evidence, never the later stop clock. Later SYNC starts a new interval;
  valid B02 continuity still retains T1. Retired/duplicate stops cannot invalidate
  newer ownership or multiply gaps. No additional service changes were required.
- Disposable projection v2 -> v3 cache replay corrects already-consumed STOP rows.
  Raw journal schema stays 3; source rows/IDs/cursors/legacy data are retained.
  Future cache versions fail closed without deletion. Flutter accepts known v3.
- Internal rebuild cancellation checks before reset and each 128-row transaction.
  Partial committed cursors survive cancellation/reopen; reads finish catch-up
  before returning totals. Normal startup fairness and cross-layer cancellation
  are NOT yet implemented; do not claim that the worker now yields cooperatively.
- Three API 28 load/migration cases exercise 1200 sessions / 2400 observations,
  full pages/totals, cursor-384 cancellation, reopen parity, consumer preservation,
  206-device paging with insertion and stale/future cache behavior. Focused model
  run: seed 9071ms, total 9945ms, DB 1466368 bytes (not a phone performance SLA).
- Full gates: 129 Flutter / 173 native, analyzer clean, Kotlin debug/release and
  debug packaging pass; strict four-hook service guard unchanged. No device,
  physical G, telemetry or signed release validation. Feature counts stay
  20 IMPLEMENTED / 75 IN_PROGRESS / 24 NOT_STARTED = 119.
- Next independent work: evidence-backed identity/alias integration, local data
  controls and remaining analytics; preserve the route/live/reminder correctness
  gate and the unresolved physical/OEM/energy acceptance. See `HISTORY_REPLAY.md`.
- Startup review identified a new helper wait boundary: Android documents that
  [HandlerThread.getLooper](https://developer.android.com/reference/android/os/HandlerThread#getLooper())
  may block until Looper initialization. Moved handler/backend/owner creation
  into `onLooperPrepared`; service start/close never await that initialization.
  Four worker lifecycle models on API 28/35 prove return-before-unblock and
  exactly-once cleanup. Backend initialization failures remain caught by the
  owner. This is a corrective hardening change, not proof of historical G causality.
- Final local debug APK: 158947452 bytes; both output paths SHA-256
  `28E80584E5D57B36AB901F6D68BB3628EEAE35A83E1F82F801FFB832D04529E7`.
  Artifact remains ignored/unpublished; no signing credentials or release used.
