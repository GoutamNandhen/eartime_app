# Approved Feature Matrix

Updated 2026-10-24. Each row is an implementation task, not a claim of completion.
`IN_PROGRESS` includes inherited partial behavior. `NOT_STARTED` means the
approved production acceptance path is not implemented. Physical evidence is
pending for all new native behavior. None of these rows implies RELEASE_READY.

Executable evidence keys:

- S: `flutter test --no-pub test/phase2cb1_rapid_reopen_test.dart test/phase2cb_startup_test.dart`.
- L: `flutter test --no-pub test/phase2_device_scope_test.dart test/phase2b_stale_attribution_test.dart`.
- D: `flutter test --no-pub test/observation_journal_test.dart`.
- J: `android/gradlew.bat :app:testDebugUnitTest --tests '*ObservationJournalTest' --tests '*NativeObservationIngressTest'` (run from `android` as `.\gradlew.bat`).
- R: same Gradle task with `--tests '*TrackingContractTest' --tests '*BoundedIngressQueueTest'`.
- P: `ListeningProjectionTest` (48 API 28/35 cases), including shared JSON fixture,
  B02, atomic rollback, replay/rebuild, v1/v2 migrations, DST and aggregate parity.
- U: `flutter test --no-pub test/listening_projection_test.dart` (17 cases).
- Q: `ListeningPreferencesTest` (12 native cases) and `test/listening_settings_test.dart` (4 Flutter cases).
- W: `ListeningWidgetTest` (6 native resource/render cases); physical launcher acceptance pending.
- T: `test/telemetry_capability_test.dart` (2 conservative capability cases).
- OPEN: executable production acceptance test is missing. Add it with the
  implementation; never count this row as passing based on a source review.

## A: Core Listening

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| A1 | Actual playback duration | IN_PROGRESS; P/U canonical accounting; real CONFIRMED route/liveness collector OPEN |
| A2 | Connected/listening/paused/idle states | IN_PROGRESS; L; authoritative idle/gap projection OPEN |
| A3 | Play/pause/reconnect transitions | IN_PROGRESS; L; physical route tests pending |
| A4 | Closed UI/Recents/screen-off collection | IN_PROGRESS; J models Flutter absence; physical service continuity pending |
| A5 | Reopen continuity and gaps | IN_PROGRESS; J/P/U durable recovery and B02 opening pass; physical/liveness OPEN |
| A6 | Reject stale earbuds during speaker playback | IN_PROGRESS; L after disconnect; connected speaker proof OPEN |
| A7 | Classic/A2DP/LE routes | IN_PROGRESS; R contracts; verified collector OPEN |
| A8 | Wired 3.5 mm | IN_PROGRESS; inherited detection; physical/projection OPEN |
| A9 | USB-C/USB audio | IN_PROGRESS; inherited detection; physical/projection OPEN |
| A10 | Multiple devices/output switching | IN_PROGRESS; L/R isolation; actual route selection OPEN |
| A11 | Midnight/timezone boundaries | IMPLEMENTED / AUTOMATED_PASS P; UTC clipping and local 23/25-hour days; physical clock acceptance pending |
| A12 | Idempotent events/interval union | IMPLEMENTED / AUTOMATED_PASS J/P; overlapping route/device unions and replay parity |

## B: Earbud Intelligence

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| B1 | Evidence-backed physical identity | IN_PROGRESS; R typed IDs; persistent association OPEN |
| B2 | Device/route/endpoint/alias/name distinction | IN_PROGRESS; R contracts; collector integration OPEN |
| B3 | Editable device names | IN_PROGRESS; Q/P durable display-only overrides and UI; physical identity/rename acceptance pending |
| B4 | Device history/totals | IN_PROGRESS; P native per-device union/known-device pages; provisional identities not merged; history drilldown OPEN |
| B5 | Left/right battery | NOT_STARTED; standard/vendor observation tests OPEN |
| B6 | Case battery | NOT_STARTED; compatibility/physical evidence OPEN |
| B7 | Charging indicators | NOT_STARTED; capability/freshness tests OPEN |
| B8 | In-ear/in-case states | NOT_STARTED; physical-role validation OPEN |
| B9 | Independent wearing durations | NOT_STARTED; wearing interval tests OPEN |
| B10 | Unknown/unsupported/stale telemetry | IN_PROGRESS; U/W unknown batteries/wearing; T prevents false per-ear claims; freshness collector OPEN |
| B11 | Optional OnePlus vendor telemetry | NOT_STARTED; historical research must be reviewed; adapter gating OPEN |
| B12 | Capability discovery/reconnect/freshness | IN_PROGRESS; inherited experimental discovery; safe adapter OPEN |
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
| C8 | Permission/stale/error status | IN_PROGRESS; S/D/U visible journal errors/gaps; complete collector health OPEN |
| C9 | Cross-screen/widget consistency | IN_PROGRESS; P/U/W share native query; physical launcher/engine parity pending |
| C10 | Efficient live updates | IN_PROGRESS; U coalesced foreground-only reads/cancellation; liveness ticking and long-run profiling OPEN |

## D: Timeline

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| D1 | Chronological sessions | IN_PROGRESS; P/U sequence-ordered interval pages; richer grouped sessions OPEN |
| D2 | Start/end timestamps | IN_PROGRESS; P/U durable timestamps and uncertainty labels; physical clock acceptance pending |
| D3 | Session durations | IN_PROGRESS; P/U corrected canonical interval durations; grouped sessions/liveness OPEN |
| D4 | Pause/resume segments | IMPLEMENTED / AUTOMATED_PASS P/U; paused time excluded |
| D5 | Connection/output transitions | IN_PROGRESS; connections only; route evidence OPEN |
| D6 | Device details | IN_PROGRESS; candidate identities; persistence/UI OPEN |
| D7 | Date filters | IN_PROGRESS; U native query windows/date picker; exhaustive picker interaction acceptance OPEN |
| D8 | Incomplete/uncertain labels | IMPLEMENTED / AUTOMATED_PASS P/U; gaps/lost continuity/unverified attribution visible |
| D9 | Restart-correct durations | IMPLEMENTED / AUTOMATED_PASS P/J; close at last evidence, never bridge process gap; OS death pending |
| D10 | Timeline/analytics reconciliation | IMPLEMENTED / AUTOMATED_PASS P/U; native shared clipping/union, no Flutter reducer |
| D11 | Pagination/performance | IN_PROGRESS; P/U 100-interval pages/work ceiling; long-history profiling/cooperative replay OPEN |

## E: Analytics

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| E1 | Calendar/custom totals | IN_PROGRESS; P/U native day/week/month/year/custom windows; exhaustive UI acceptance OPEN |
| E2 | Connected/listening/idle comparison | NOT_STARTED; projection tests OPEN |
| E3 | Daily/hourly trends | IN_PROGRESS; P native DST-aware buckets and U presentation; full chart acceptance OPEN |
| E4 | Per-device comparisons | IN_PROGRESS; P per-device union totals; actual identity attribution OPEN |
| E5 | Longest session | IN_PROGRESS; P longest continuous union run; grouped-session semantics OPEN |
| E6 | Average duration | IN_PROGRESS; P average continuous union run; grouped-session semantics OPEN |
| E7 | Listening frequency | IN_PROGRESS; P confirmed run count; richer frequency metrics OPEN |
| E8 | Breaks/break lengths | NOT_STARTED; gap-vs-break tests OPEN |
| E9 | Wearing trends | NOT_STARTED; validated role data OPEN |
| E10 | Goals/streaks | NOT_STARTED; local goal/calendar tests OPEN |
| E11 | Calendar/date boundaries | IMPLEMENTED / AUTOMATED_PASS P; midnight and spring/autumn DST reconciliation |
| E12 | Empty/zero/partial/uncertain data | IN_PROGRESS; U truthful empty/error/zero states, no divide-by-zero; full acceptance pending |
| E13 | Accessible charts | IN_PROGRESS; hourly progress semantics and large-text U; full assistive-technology audit OPEN |
| E14 | Efficient projections | IN_PROGRESS; P incremental/checkpoint/rebuild/bounded results; realistic load/cooperative replay OPEN |

## F: Wellbeing

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| F1 | Daily duration goals | IMPLEMENTED / AUTOMATED_PASS Q/U; native-backed personal goal, explicit disable, no fabricated exposure threshold |
| F2 | Continuous-listening reminders | NOT_STARTED; duration/scheduler tests OPEN |
| F3 | Break reminders | NOT_STARTED; scheduler tests OPEN |
| F4 | Daily/weekly summaries | IN_PROGRESS; P native range/day totals in Wellbeing; scheduled summaries OPEN |
| F5 | Notification controls/quiet hours | NOT_STARTED; schedule/permission tests OPEN |
| F6 | Duration insights | NOT_STARTED; actual-data derivation OPEN |
| F7 | Goal/streak/break recommendations | NOT_STARTED; deterministic rules tests OPEN |
| F8 | Guidance distinct from sound exposure | IN_PROGRESS; U explicit not-measured exposure and personal-goal copy; content/accessibility audit OPEN |

## G: Reliability

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| G1 | Android-owned durable journal | IMPLEMENTED / AUTOMATED_PASS J; real process/service test PHYSICAL_PENDING |
| G2 | Persistent observation IDs | IMPLEMENTED / AUTOMATED_PASS J/L |
| G3 | Serialized sequence/transactions | IMPLEMENTED / AUTOMATED_PASS J/R |
| G4 | Duplicate-safe processing/replay | IMPLEMENTED / AUTOMATED_PASS J/P/U; product reads native projection, hints not history |
| G5 | Device-scoped state | IN_PROGRESS; L/R; legacy global context remains |
| G6 | Evidence-backed attribution | IN_PROGRESS; explicit UNKNOWN journal; verified collector OPEN |
| G7 | One authoritative interval projection | IMPLEMENTED / AUTOMATED_PASS P/U/W; production confirmed attribution/liveness remain gated |
| G8 | Live/history agreement | IN_PROGRESS; P/U B02 observed opening corrected; validated production live lease OPEN |
| G9 | Durable recovery/migrations | IN_PROGRESS; J/P v1/v2 migrations/replay preserve raw/source/cursors; legacy read-only preservation, import OPEN |
| G10 | Collection-gap uncertainty | IMPLEMENTED / AUTOMATED_PASS J/P/U; no invented gap duration; physical service death pending |
| G11 | Bounded startup | IMPLEMENTED inherited S; native/OEM timing PHYSICAL_PENDING |
| G12 | Engine/sink ownership | IMPLEMENTED / AUTOMATED_PASS S + JVM owner tests |
| G13 | Rapid reopen/splash | IN_PROGRESS; S model passes; physical root cause UNPROVEN |
| G14 | Permitted background collection | IN_PROGRESS; existing FGS; API/device matrix OPEN |
| G15 | Foreground notification/permissions | IN_PROGRESS; S permissions; physical recovery OPEN |
| G16 | Bounded diagnostics/logs | IN_PROGRESS; R/D bounds; full legacy logging audit OPEN |
| G17 | Visible crashes/errors | IN_PROGRESS; journal/stream errors; global crash retention OPEN |
| G18 | Memory/performance safeguards | IN_PROGRESS; bounded ingress/hints/results, indexed device pages, window work ceiling; profiling OPEN |
| G19 | Regression/integration suite | IN_PROGRESS; 126 Flutter/116 native; 15 placeholders replaced; actual engine/OS tests OPEN |
| G20 | Reproducible hardware validation | IN_PROGRESS; saved rapid-reopen plan; final combined plan OPEN |

## H: Product and Release

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| H1 | Material 3 UI | IN_PROGRESS; existing theme/screens; cohesive acceptance OPEN |
| H2 | Light/dark themes | IMPLEMENTED / AUTOMATED_PASS Q; native-backed system/light/dark, offline fonts; physical acceptance pending |
| H3 | Responsive layouts | IN_PROGRESS; D journal large-text check; all-screen matrix OPEN |
| H4 | Home | IN_PROGRESS; U canonical confirmed/unverified totals, goals and errors; live collector lease OPEN |
| H5 | Timeline | IN_PROGRESS; P/U native interval pages/date windows/gaps; grouped sessions OPEN |
| H6 | Analytics | IN_PROGRESS; P/U native actual aggregates, no placeholder scores; full metrics OPEN |
| H7 | Devices | IN_PROGRESS; U native known-device next/previous pages/details/name overrides; verified aliases/telemetry OPEN |
| H8 | Wellbeing | IN_PROGRESS; Q/U persisted goals/native summaries; reminders OPEN |
| H9 | Settings | IN_PROGRESS; Q themes/goals, legacy/journal diagnostics; export/restore/delete OPEN |
| H10 | Developer diagnostics | IN_PROGRESS; D journal screen delivered; safe vendor controls OPEN |
| H11 | Android widgets | IN_PROGRESS; W multi-device dark two-column native provider; unknown battery honest; physical launcher/freshness pending |
| H12 | Foreground notification/controls | IN_PROGRESS; inherited notification; control/status tests OPEN |
| H13 | Goals/reminders/preferences | IN_PROGRESS; Q native goals/themes/names; reminders/quiet-hours OPEN |
| H14 | Data-management settings | IN_PROGRESS; paged read-only preserved legacy history; destructive/export/import controls OPEN |
| H15 | Local-first privacy | IN_PROGRESS; OS cloud/transfer backup excluded; inherited native logs/BLE discovery audit OPEN |
| H16 | Offline functionality | IN_PROGRESS; native/local queries and system fonts; full offline acceptance OPEN |
| H17 | Export | NOT_STARTED; versioned format/roundtrip tests OPEN |
| H18 | Backup/restore | NOT_STARTED; idempotent/conflict/rollback tests OPEN |
| H19 | User deletion | NOT_STARTED; explicit-confirmation/transaction tests OPEN |
| H20 | Accessibility | IN_PROGRESS; D large-text test; all-screen semantics OPEN |
| H21 | Localization readiness | NOT_STARTED; string extraction/locale tests OPEN |
| H22 | Battery/performance | IN_PROGRESS; queue bounds; hardware profiling OPEN |
| H23 | Release build configuration | IN_PROGRESS; debug/release Kotlin compile; release packaging fails closed without authorized keys |
| H24 | Signing configuration/instructions | IN_PROGRESS; explicit EARTIME environment-key configuration; no debug fallback/no release key created |
| H25 | Versioning | IN_PROGRESS; inherited 1.0.0+1; release policy OPEN |
| H26 | Release validation | IN_PROGRESS; analyzer/debug gates green, signing refusal verified; signed RC/physical gates OPEN |
| H27 | Crash testing | IN_PROGRESS; J pre-commit injection; process/OS matrix OPEN |
| H28 | Honest privacy/permission descriptions | IN_PROGRESS; startup states; complete policy/copy OPEN |

## I: Approved Advanced Features

| ID | Feature | State / evidence / remaining gate |
| --- | --- | --- |
| I1 | Additional widgets | NOT_STARTED; variants/native-provider tests OPEN |
| I2 | App shortcuts | NOT_STARTED; safe-intent/deep-link tests OPEN |
| I3 | Personalized reports | NOT_STARTED; actual-data deterministic report tests OPEN |

Excluded: cloud sync/accounts, ANC/EQ controls, additional vendor adapters and
uncalibrated acoustic-dose estimates. No excluded scope was implemented.
