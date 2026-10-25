# Approved Feature Matrix

Updated 2026-10-26. Each row is an implementation task, not a claim of completion.
User-requested shutdown pause: frequency work is saved as WIP, not promoted to
completion. Latest gates: 247 Flutter /468 native, analyzer clean, debug/release
Kotlin/debug APK pass. Resume E7 acceptance review from CODEX_RESUME.md.
`IN_PROGRESS` includes inherited partial behavior. `NOT_STARTED` means the
approved production acceptance path is not implemented. Physical evidence is
pending for all new native behavior. None of these rows implies RELEASE_READY.

Implementation count: **44 IMPLEMENTED, 60 IN_PROGRESS, 14 NOT_STARTED,
1 BLOCKED_BY_PLATFORM = 119**. A1's generic cross-app output dependency is now
explicitly platform-blocked, not silently treated as unfinished UI or hardware-only
verification. Its acceptance criteria remain unchanged; see PLATFORM_ATTRIBUTION_LIMITS.md.
Latest software-complete IDs: E3/E13, H14/H18, H19/H17, D1/D2/D3/E5/E6, E12, D7/E1, H28, H25, F4/F5; B3 and earlier E10, F6, I1, I2, I3 retained. Hardware-dependent acceptance
remains PHYSICAL_PENDING, not RELEASE_READY. F7 remains partial (break guidance).

Executable evidence keys:

- C3: eight Flutter trend cases: actual Analytics at 1x/3x, 14-row pages, exact
  semantic durations, zero/unknown separation, malformed hourly contracts,
  keyboard activation, both app themes, labeled/minimum-size targets and contrast.
  Existing P/C2 native calendar/DST/union/replay acceptance retained.
  ANALYTICS_TRENDS.md; physical assistive-technology/font/OS acceptance pending.

- X4: ApplicationRestoreCoordinatorTest (20 API 28/35 executions), eight added
  archive staging/preferences executions, two real helper/provider restore executions,
  eight TEST-ONLY ATTACH research executions, seven Flutter restore/access cases.
  Actual native commit-last/compensation/restart, WAL flags, fault/cursor handling,
  duplicate/cancel, typed settings, Drift gate/provider invalidation and 1x/3x
  destructive consent. Windows directory syscalls are explicitly modeled with
  failure injection, not physical fsync proof. APPLICATION_RESTORE_CONTRACT.md.

- S: `flutter test --no-pub test/phase2cb1_rapid_reopen_test.dart test/phase2cb_startup_test.dart`.
- L: `flutter test --no-pub test/phase2_device_scope_test.dart test/phase2b_stale_attribution_test.dart`.
- D: `flutter test --no-pub test/observation_journal_test.dart`.
- J: `android/gradlew.bat :app:testDebugUnitTest --tests '*ObservationJournalTest' --tests '*NativeObservationIngressTest'` (run from `android` as `.\gradlew.bat`).
- R: same Gradle task with `--tests '*TrackingContractTest' --tests '*BoundedIngressQueueTest'`.
- P: `ListeningProjectionTest` (66 API 28/35 cases), including shared JSON fixture,
  B02, atomic rollback, replay/rebuild, v1/v2 migrations, DST and aggregate parity.
- U: `flutter test --no-pub test/listening_projection_test.dart` (20 cases).
- C: `CollectorHealthTest` (20 API 28/35 cases) and `OutputAttributionTest`
  (16 synthetic policy cases); `AudioObserverOwnerTest` (10), Android adapter
  (3 API 24/28/35 cases), scoped source/ack ingress and Flutter hint decoding.
  `SupportedAudioObserverTest` adds four API 28/35 blocked-worker/cleanup cases.
- V: `ListeningHistoryLoadTest` (3 API 28 cases): 1200 sessions, transaction-bound
  rebuild cancellation/reopen parity, live paging insertion and v2-cache upgrade.
- Q: `ListeningPreferencesTest` (12 native cases) and `test/listening_settings_test.dart` (4 Flutter cases).
- W: `ListeningWidgetTest` (8 native resource/render cases); physical launcher acceptance pending.
- T: `test/telemetry_capability_test.dart` (2 conservative capability cases).
- N: `ListeningReportTest`, projection persisted-goal/reopen/replay case,
  `NavigationTargetTest`, summary widget render cases and Flutter
  `app_navigation_test.dart` / `listening_report_test.dart`.
  See `REPORTS_AND_NAVIGATION.md` for scope and limits.
  `test/app_navigation_shell_test.dart` proves warm hints dismiss Settings and
  show the requested actual product screen; pre-fix failure reproduced.
- X: `JournalArchiveTest`, `JournalFileTransferTest`, restore-boundary ingress
  case and `test/journal_transfer_test.dart`. Native-only transfers; full-app
  backup is unfinished. See `JOURNAL_ARCHIVES.md`.
- Y: `A2dpStreamProbeTest` (14 native cases), actual backend API 24/28/35 and
  durable candidate ingress. `A2DP_OBSERVATIONS.md`: raw public-API acquisition
  is integrated; confidence/live eligibility are still UNKNOWN/false.
- OPEN: executable production acceptance test is missing. Add it with the
  implementation; never count this row as passing based on a source review.
- X3: `ApplicationDataDeletionTest` (19 native executions across API 24/28/35),
  four Flutter deletion cases: scoped consent, actual settings/dialog at 1x/3x,
  retry/error/protocol, public self-data API and queued owner fencing. Request
  acknowledgement is NOT actual erasure proof; APPLICATION_DELETION.md.
- X2: `ApplicationArchiveTest` (21 native executions) and two further API 28/35
  picker/document integration cases (four executions), three Flutter application
  transfer cases. Actual native/preferences/legacy export and integrity, source
  preservation, cancellation, schema refusal, 1001/1203-row capture and real
  helper/runtime/provider path; APPLICATION_EXPORTS.md. Whole-app restore is open.
- Z: `EndpointIdentityTest` (24 API 28/35 cases), retired-owner ingress and
  widget unknown-state regressions; `test/device_identity_test.dart` (6 cases).
  `ENDPOINT_IDENTITY.md`: durable random endpoint UUIDs, explicit reversible
  associations and replay/migration/restore, not verified physical identity.
  Four further API 28/35 projection cases (8 executions) and five Flutter
  `device_history_test.dart` cases cover scoped union/paging/index migration,
  actual Devices navigation, native-scope rejection and name edit/cancel/error/
  owner recreation. `DEVICE_HISTORY.md`; source schema stays 3, projection 5.
- O: `BleDiagnosticSafetyTest` (22 API 28/35 executions), private endpoint
  resolution and dedicated-source ingress, plus four Flutter consent cases.
  `READ_ONLY_DIAGNOSTICS.md`: no automatic GATT or vendor subscriptions/writes;
  bounded explicitly authorized catalog inspection is not telemetry support.
- M: `WellbeingSummaryTest` (34 API 28/35 executions), 2 API 24 legacy
  notification cases, native startup/replacement and 2 manifest cases; 8 Flutter
  `wellbeing_notifications_test.dart` cases. WELLBEING_SUMMARIES.md: opt-in
  recorded summaries, quiet hours and permission controls, not live reminders.
  Six request-token ownership regressions additionally protect replaced jobs.
- K: `AppBuildInformationTest` (12 API 24/28/35 executions), four Flutter
  `app_build_information_test.dart` cases, 17 version-tool self-tests, Gradle
  preBuild consistency gate and actual APK metadata inspection; VERSIONING.md.
- O2: `PrivacyConfigurationTest` (4 API 28/35 executions) and six Flutter
  `privacy_permissions_test.dart` cases; offline disclosure navigation and
  original 2x/3x permission overflow RED-to-GREEN. PRIVACY_DISCLOSURES.md.
- C2: `listening_calendar_test.dart` (13 Flutter cases), four further P native
  executions; actual picker/form, pagination/scope and SQLite date-union/replay
  acceptance at 1x/2x/3x. CALENDAR_FILTERS.md; no new duration reducer or timer.
- R2: `listening_record_states_test.dart` (31 Flutter cases), four further P
  native executions; strict loss/chart/interval validation, actual record/error/
  retry states at 3x, foreground ownership/disposal and positive-run average
  correction with RED evidence. RECORD_STATES.md; recorded totals stay native.

## A: Core Listening

Session evidence S2: `ListeningProjectionTest` adds five cases (10 API 28/35
executions); `listening_sessions_test.dart` adds five Flutter cases. Native
grouping, union/clock/gap/scope/replay, 105-session/contributor pages, transition
details, strict decoding and actual 1x/3x navigation; TIMELINE_SESSIONS.md.

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| A1 | Actual playback duration | BLOCKED_BY_PLATFORM; P/U canonical accounting exists, but generic third-party actual output lacks a populated public configuration-route API; PLATFORM_ATTRIBUTION_LIMITS.md; narrower A2DP work remains A7, not full completion |
| A2 | Connected/listening/paused/idle states | IN_PROGRESS; L; authoritative idle/gap projection OPEN |
| A3 | Play/pause/reconnect transitions | IN_PROGRESS; L; physical route tests pending |
| A4 | Closed UI/Recents/screen-off collection | IN_PROGRESS; J models Flutter absence; physical service continuity pending |
| A5 | Reopen continuity and gaps | IN_PROGRESS; J/P/U durable recovery and B02 opening pass; physical/liveness OPEN |
| A6 | Reject stale earbuds during speaker playback | IN_PROGRESS; L after disconnect; connected speaker proof OPEN |
| A7 | Classic/A2DP/LE routes | IN_PROGRESS; R/Y public per-device A2DP samples durably acquired; identity/continuity integration and LE attribution OPEN |
| A8 | Wired 3.5 mm | IN_PROGRESS; inherited detection; physical/projection OPEN |
| A9 | USB-C/USB audio | IN_PROGRESS; inherited detection; physical/projection OPEN |
| A10 | Multiple devices/output switching | IN_PROGRESS; L/R isolation; actual route selection OPEN |
| A11 | Midnight/timezone boundaries | IMPLEMENTED / AUTOMATED_PASS P; UTC clipping and local 23/25-hour days; physical clock acceptance pending |
| A12 | Idempotent events/interval union | IMPLEMENTED / AUTOMATED_PASS J/P; overlapping route/device unions and replay parity |

## B: Earbud Intelligence

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| B1 | Evidence-backed physical identity | IN_PROGRESS; R/Z persistent endpoint association integrated; physical/cross-profile proof OPEN |
| B2 | Device/route/endpoint/alias/name distinction | IN_PROGRESS; R/Z journal-backed random UUIDs and reversible user associations; LE/wired/USB integration OPEN |
| B3 | Editable device names | IMPLEMENTED / AUTOMATED_PASS Q/P/Z; actual UI cancel/save/error/recreation and UUID-keyed overrides through endpoint reconnect/reopen/replay; PHYSICAL_PENDING, no physical identity promotion |
| B4 | Device history/totals | IN_PROGRESS; P/Z indexed native-scoped history, Devices/Analytics drilldown and 105-interval pages integrated; real confirmed route producer/physical acceptance OPEN, provisional identities not merged |
| B5 | Left/right battery | NOT_STARTED; standard/vendor observation tests OPEN |
| B6 | Case battery | NOT_STARTED; compatibility/physical evidence OPEN |
| B7 | Charging indicators | NOT_STARTED; capability/freshness tests OPEN |
| B8 | In-ear/in-case states | NOT_STARTED; physical-role validation OPEN |
| B9 | Independent wearing durations | NOT_STARTED; wearing interval tests OPEN |
| B10 | Unknown/unsupported/stale telemetry | IN_PROGRESS; U/W unknown batteries/wearing; T prevents false per-ear claims; freshness collector OPEN |
| B11 | Optional OnePlus vendor telemetry | NOT_STARTED; historical research must be reviewed; adapter gating OPEN |
| B12 | Capability discovery/reconnect/freshness | IN_PROGRESS; O explicit source/revision/owner-fenced bounded read-only catalog, no automatic connect/write; standard/vendor acquisition, reconnect/freshness OPEN |
| B13 | Other-earbud fallback | IN_PROGRESS; generic display; unsupported-state acceptance OPEN |

## C: Home

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| C1 | Authoritative persisted live timer | IN_PROGRESS; P/U preserve T1 rather than S; production extrapolation disabled until validated collector lease |
| C2 | Connected device and active output | IN_PROGRESS; L fixes device leakage; output proof OPEN |
| C3 | Playback confidence | IMPLEMENTED / AUTOMATED_PASS U; confirmed/unverified separated in product views; current collector remains UNKNOWN |
| C4 | Today's total | IMPLEMENTED / AUTOMATED_PASS P/U; one native clipped total; no legacy/global playback promoted |
| C5 | Connected/listening/idle breakdown | NOT_STARTED; interval partition tests OPEN |
| C6 | Battery/wearing indicators | NOT_STARTED; capability widgets OPEN |
| C7 | Goal progress | IMPLEMENTED / AUTOMATED_PASS Q/U; personal duration goal uses confirmed native total; not an exposure limit |
| C8 | Permission/stale/error status | IN_PROGRESS; S/D/U/C durable scoped runtime health/expiry/denial/recovery; physical recovery acceptance OPEN |
| C9 | Cross-screen/widget consistency | IN_PROGRESS; P/U/W share native query; physical launcher/engine parity pending |
| C10 | Efficient live updates | IN_PROGRESS; U coalesced foreground-only reads/cancellation; liveness ticking and long-run profiling OPEN |

## D: Timeline

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| D1 | Chronological sessions | IMPLEMENTED / AUTOMATED_PASS S2/P; native bounded overlap groups, source-order clock safety, pause/resume/gap boundaries and contributor drilldown; PHYSICAL_PENDING |
| D2 | Start/end timestamps | IMPLEMENTED / AUTOMATED_PASS S2/P; original captured/clipped native bounds, full dates/seconds/local UTC offset and incomplete labels; physical clock acceptance pending |
| D3 | Session durations | IMPLEMENTED / AUTOMATED_PASS S2/P; native clipped contributor union, no overlap addition, open points unknown and lost continuity ends at last evidence; live extrapolation remains gated, PHYSICAL_PENDING |
| D4 | Pause/resume segments | IMPLEMENTED / AUTOMATED_PASS P/U; paused time excluded |
| D5 | Connection/output transitions | IN_PROGRESS; connections only; route evidence OPEN |
| D6 | Device details | IN_PROGRESS; Z persistent endpoint association/reset, names and device history UI; verified physical matching/telemetry OPEN |
| D7 | Date filters | IMPLEMENTED / AUTOMATED_PASS C2; shared calendar windows, localized scrollable date entry, inclusive bounds, validation/cancel/clock rollback, reset paging and retained device scope; physical clock acceptance pending |
| D8 | Incomplete/uncertain labels | IMPLEMENTED / AUTOMATED_PASS P/U; gaps/lost continuity/unverified attribution visible |
| D9 | Restart-correct durations | IMPLEMENTED / AUTOMATED_PASS P/J; close at last evidence, never bridge process gap; OS death pending |
| D10 | Timeline/analytics reconciliation | IMPLEMENTED / AUTOMATED_PASS P/U; native shared clipping/union, no Flutter reducer |
| D11 | Pagination/performance | IN_PROGRESS; P/U/V 100-row pages and 1200-session replay parity; device profiling/startup fairness OPEN |

## E: Analytics

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| E1 | Calendar/custom totals | IMPLEMENTED / AUTOMATED_PASS P/C2; actual day/week/month/year/custom control-to-query acceptance and canonical clipped union/bucket reconciliation across reopen/replay; physical date/timezone acceptance pending |
| E2 | Connected/listening/idle comparison | NOT_STARTED; projection tests OPEN |
| E3 | Daily/hourly trends | IMPLEMENTED / AUTOMATED_PASS P/C2/C3; canonical native daily and local-hour buckets, bounded mode/page controls, localized labels, zero/unknown/unverified separation and strict hourly reconciliation; no Flutter accounting, PHYSICAL_PENDING |
| E4 | Per-device comparisons | IN_PROGRESS; P per-device union totals; actual identity attribution OPEN |
| E5 | Longest session | IMPLEMENTED / AUTOMATED_PASS S2/P; native longest measured confirmed grouped session integrated into Analytics/Wellbeing, separate from existing continuous-run metric; PHYSICAL_PENDING |
| E6 | Average duration | IMPLEMENTED / AUTOMATED_PASS S2/P/R2; native mean of measured confirmed grouped sessions excludes zero-duration/unverified observations; continuous-run mean retained; PHYSICAL_PENDING |
| E7 | Listening frequency | IN_PROGRESS; WIP native original-start frequency contract/day/hour counts and integrated Analytics/Wellbeing; five native methods (10 executions) /three Flutter cases pass; final acceptance review pending; LISTENING_FREQUENCY.md |
| E8 | Breaks/break lengths | NOT_STARTED; gap-vs-break tests OPEN |
| E9 | Wearing trends | NOT_STARTED; validated role data OPEN |
| E10 | Goals/streaks | IMPLEMENTED / AUTOMATED_PASS N; native recorded goal days/window streaks, partial-day and DST tests; lower bounds, not all-time/completeness claims |
| E11 | Calendar/date boundaries | IMPLEMENTED / AUTOMATED_PASS P; midnight and spring/autumn DST reconciliation |
| E12 | Empty/zero/partial/uncertain data | IMPLEMENTED / AUTOMATED_PASS R2; distinct empty/unverified/unknown/confirmed records, missing-duration wording in totals/detail rows, lower-bound/incomplete notices, malformed metadata unavailable, real retry/foreground/disposal tests; physical coverage remains unverified |
| E13 | Accessible charts | IMPLEMENTED / AUTOMATED_PASS C3; one date/hour-and-duration semantic row per native bucket, labeled mode/page controls, keyboard activation, minimum target/contrast checks in both app themes at 1x/3x; duration-as-progress and selected contrast defects corrected, actual assistive-technology acceptance PHYSICAL_PENDING |
| E14 | Efficient projections | IN_PROGRESS; P/V incremental/cache upgrade/bounded rebuild cancellation/1200 sessions; runtime fairness/device profiles OPEN |

## F: Wellbeing

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| F1 | Daily duration goals | IMPLEMENTED / AUTOMATED_PASS Q/U; native-backed personal goal, explicit disable, no fabricated exposure threshold |
| F2 | Continuous-listening reminders | NOT_STARTED; duration/scheduler tests OPEN |
| F3 | Break reminders | NOT_STARTED; scheduler tests OPEN |
| F4 | Daily/weekly summaries | IMPLEMENTED / AUTOMATED_PASS P/M; opt-in native calendar summaries, inexact alarms/jobs, canonical union, dated lower bounds, durable at-most-one-attempt receipts; OS/OEM delivery PHYSICAL_PENDING |
| F5 | Notification controls/quiet hours | IMPLEMENTED / AUTOMATED_PASS M; persisted categories/time/quiet ranges, disable/cancel, default-off receiver, permission/channel/unknown/error recovery and native restart reconciliation; PHYSICAL_PENDING |
| F6 | Duration insights | IMPLEMENTED / AUTOMATED_PASS N; actual native recorded activity/goal insights in Analytics/Wellbeing; no medical or exposure claims |
| F7 | Goal/streak/break recommendations | IN_PROGRESS; N personal-goal guidance integrated; observed-break derivation/guidance OPEN |
| F8 | Guidance distinct from sound exposure | IN_PROGRESS; U explicit not-measured exposure and personal-goal copy; content/accessibility audit OPEN |

## G: Reliability

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| G1 | Android-owned durable journal | IMPLEMENTED / AUTOMATED_PASS J; real process/service test PHYSICAL_PENDING |
| G2 | Persistent observation IDs | IMPLEMENTED / AUTOMATED_PASS J/L |
| G3 | Serialized sequence/transactions | IMPLEMENTED / AUTOMATED_PASS J/R |
| G4 | Duplicate-safe processing/replay | IMPLEMENTED / AUTOMATED_PASS J/P/U; product reads native projection, hints not history |
| G5 | Device-scoped state | IN_PROGRESS; L/R; legacy global context remains |
| G6 | Evidence-backed attribution | IN_PROGRESS; C/Y rejects inventory/global/communication/predicted claims, acquires per-device A2DP stream candidates; canonical route evidence/lease integration OPEN |
| G7 | One authoritative interval projection | IMPLEMENTED / AUTOMATED_PASS P/U/W; production confirmed attribution/liveness remain gated |
| G8 | Live/history agreement | IN_PROGRESS; P/U B02 observed opening corrected; validated production live lease OPEN |
| G9 | Durable recovery/migrations | IN_PROGRESS; J/P/X migrations/replay plus transactional native archive restore/recovery/queued-event fence; full-app legacy/preferences restoration OPEN |
| G10 | Collection-gap uncertainty | IMPLEMENTED / AUTOMATED_PASS J/P/U/C/V; known owner stops close at last evidence, stale/duplicate stops fenced; physical death pending |
| G11 | Bounded startup | IMPLEMENTED inherited S; native/OEM timing PHYSICAL_PENDING |
| G12 | Engine/sink ownership | IMPLEMENTED / AUTOMATED_PASS S + JVM owner tests |
| G13 | Rapid reopen/splash | IN_PROGRESS; S model passes; physical root cause UNPROVEN |
| G14 | Permitted background collection | IN_PROGRESS; FGS-owned passive public-API observer/cleanup; physical/OEM matrix OPEN |
| G15 | Foreground notification/permissions | IN_PROGRESS; S permissions; physical recovery OPEN |
| G16 | Bounded diagnostics/logs | IN_PROGRESS; R/D bounds; full legacy logging audit OPEN |
| G17 | Visible crashes/errors | IN_PROGRESS; journal/stream errors; global crash retention OPEN |
| G18 | Memory/performance safeguards | IN_PROGRESS; V 1200-session model, transaction-bound rebuild cancellation and indexed pages; startup fairness/device profiling OPEN |
| G19 | Regression/integration suite | IN_PROGRESS; 247 Flutter/468 native; 15 placeholders replaced; actual engine/OS tests OPEN |
| G20 | Reproducible hardware validation | IN_PROGRESS; saved rapid-reopen plan; final combined plan OPEN |

## H: Product and Release

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| H1 | Material 3 UI | IN_PROGRESS; existing theme/screens; cohesive acceptance OPEN |
| H2 | Light/dark themes | IMPLEMENTED / AUTOMATED_PASS Q; native-backed system/light/dark, offline fonts; physical acceptance pending |
| H3 | Responsive layouts | IN_PROGRESS; D journal large-text check; all-screen matrix OPEN |
| H4 | Home | IN_PROGRESS; U canonical confirmed/unverified totals, goals and errors; live collector lease OPEN |
| H5 | Timeline | IN_PROGRESS; S2/P/U native session/contributor pages, date/device windows, gaps and transitions integrated; connection-only history, physical device details and full performance acceptance OPEN |
| H6 | Analytics | IN_PROGRESS; P/U native actual aggregates, no placeholder scores; full metrics OPEN |
| H7 | Devices | IN_PROGRESS; U native known-device next/previous pages/details/name overrides; verified aliases/telemetry OPEN |
| H8 | Wellbeing | IN_PROGRESS; Q/U persisted goals/native summaries; reminders OPEN |
| H9 | Settings | IN_PROGRESS; Q/X/X2/X3/M themes/goals, summary/quiet/permission controls, export, explicit Android-managed full deletion, native recovery and diagnostics; whole-app restore OPEN |
| H10 | Developer diagnostics | IN_PROGRESS; D/O journal and consent-only read-only catalog paths; vendor values/compatibility remain unknown, full diagnostics/privacy acceptance OPEN |
| H11 | Android widgets | IN_PROGRESS; W multi-device dark two-column native provider; unknown battery honest; physical launcher/freshness pending |
| H12 | Foreground notification/controls | IN_PROGRESS; inherited notification; control/status tests OPEN |
| H13 | Goals/reminders/preferences | IN_PROGRESS; Q/M native goals/themes/names, summary categories/time and quiet hours; live-dependent F2/F3 OPEN |
| H14 | Data-management settings | IMPLEMENTED / AUTOMATED_PASS X/X2/X3/X4; integrated consent-bound native/application export, restore, scoped recovery catalog and explicit Android-managed deletion; legacy access serialized through native recovery barrier, operation-owned invalidation; physical provider/storage/erasure acceptance PHYSICAL_PENDING |
| H15 | Local-first privacy | IN_PROGRESS; OS cloud/transfer backup excluded; O automatic BLE and vendor writes removed, explicit ephemeral consent; protected collector logs/full privacy audit OPEN |
| H16 | Offline functionality | IN_PROGRESS; native/local queries and system fonts; full offline acceptance OPEN |
| H17 | Export | IMPLEMENTED / AUTOMATED_PASS X/X2; integrated versioned application-state export includes native/identity rows, typed preferences/notification state, legacy history and cursor/conflict metadata with bounded integrity validation, consent/cancel and actual synthetic document-provider path; caches/logs/older recovery copies excluded; PHYSICAL_PENDING |
| H18 | Backup/restore | IMPLEMENTED / AUTOMATED_PASS X/X2/X4; native plus legacy/typed-preference restore uses verified private recovery, bounded durable intent and final native commit marker with restart compensation before publication; source-prefix/conflict/duplicate/cancel policy, WAL preservation, diagnostic fault union and no imported cursor skipping; cooperative provider cancellation only, physical OS/power-loss durability PHYSICAL_PENDING |
| H19 | User deletion | IMPLEMENTED / AUTOMATED_PASS X3; explicit checkbox/dialog and native scope/owner fences invoke Android's public self-data clear on the serialized worker; accepted requests are not completion receipts, no reversible/forensic-wipe claim; actual OS erasure/termination PHYSICAL_PENDING |
| H20 | Accessibility | IN_PROGRESS; D large-text test; all-screen semantics OPEN |
| H21 | Localization readiness | NOT_STARTED; string extraction/locale tests OPEN |
| H22 | Battery/performance | IN_PROGRESS; queue bounds; hardware profiling OPEN |
| H23 | Release build configuration | IN_PROGRESS; debug/release Kotlin compile; release packaging fails closed without authorized keys |
| H24 | Signing configuration/instructions | IN_PROGRESS; explicit EARTIME environment-key configuration; no debug fallback/no release key created |
| H25 | Versioning | IMPLEMENTED / AUTOMATED_PASS K; single tracked 1.1.0-dev.1+2, monotonic comparison tool, Gradle metadata gate, installed-package About and actual APK inspection; no release claim |
| H26 | Release validation | IN_PROGRESS; analyzer/debug gates green, signing refusal verified; signed RC/physical gates OPEN |
| H27 | Crash testing | IN_PROGRESS; J pre-commit injection; process/OS matrix OPEN |
| H28 | Honest privacy/permission descriptions | IMPLEMENTED / AUTOMATED_PASS O2; nine offline disclosure sections before grant/in Settings, actual data/permissions/diagnostic/archive/deletion limits, scrollable startup at 2x/3x; separate privacy audit H15 remains OPEN |

## I: Approved Advanced Features

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| I1 | Additional widgets | IMPLEMENTED / AUTOMATED_PASS N; native compact last-observed activity and daily summary variants; launcher resizing/timing PHYSICAL_PENDING |
| I2 | App shortcuts | IMPLEMENTED / AUTOMATED_PASS N; four static shortcuts, whitelisted cold/warm links, disposal fencing; actual launcher PHYSICAL_PENDING |
| I3 | Personalized reports | IMPLEMENTED / AUTOMATED_PASS N/M; automatically regenerated native reports integrated into Analytics/Wellbeing; selected-period lower bounds; opt-in scheduled summaries F4, physical delivery pending |

Excluded: cloud sync/accounts, ANC/EQ controls, additional vendor adapters and
uncalibrated acoustic-dose estimates. No excluded scope was implemented.
