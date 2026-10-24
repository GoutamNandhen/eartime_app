# EarTime Production Implementation Ledger

Date: 2026-10-24. User authorization: master autonomous implementation request
and subsequent resume instruction. Historical STOP entries are superseded for
implementation; their unresolved physical findings remain valid.

Latest checkpoint: unified projection and device pagination, 126 Flutter / 116 native
passing tests, analyzer clean. The recovery baseline below is historical.
`LISTENING_PROJECTION.md` describes current attribution/liveness limitations.

## Recovery and baseline

- Branch: `g-regression-experiment`; HEAD: `0a8be43b9f064f3dc9d029c66bb1377d810ac315`.
- Before publication, inherited dirty/staged content was preserved without commits.
- Recoverable source/test/docs/config/index snapshots remain local and unpublished.
- Protected `AudioTrackingService.kt` Git blob: `78353ae1cd1d97897137360be8df24354f6c0bff`;
  current source equals known-good `0a8be43`.
- Baseline: `flutter test --no-pub --reporter compact`: exit 0, 90 tests.
- Baseline: `android/gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin --offline`:
  exit 0, existing 15 JVM tests (Gradle up-to-date results).
- Analyzer: exit 1; 21 inherited issues (16 warnings, 5 infos), zero errors;
  final new-code lints repaired; no additional analyzer issue remains.
- Read-only ADB inventory: no connected devices; no configured AVD returned.

## Implementation phases

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

Final suite: 126 Flutter tests passed (original 103 slots including 15 rewritten
placeholder cases, plus 23 new). Native: 116 passing tests (original 46 plus 70),
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
