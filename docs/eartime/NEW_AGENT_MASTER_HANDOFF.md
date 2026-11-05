# EAR TIME — COMPLETE PROJECT HANDOFF & NEW-AGENT MASTER BRIEF
**Authored:** 2026-11-05  |  **Verified code snapshot:** 5775b59b8a2edaabdc0a87a53696a09e82926d28
**Repository:** https://github.com/GoutamNandhen/eartime_app
**Review branch:** codex/production-checkpoint-20261024  |  **Main SHA:** 13ae6609d22cb2a0daf8890fca081fb97c93b36b
**Purpose:** A standalone orientation, exact feature inventory, architecture/risk map and executable continuation instruction for a new coding agent.

> **Current user state:** EarTime implementation was explicitly PAUSED for a PC shutdown. The latest saved code commit is a WIP checkpoint. This document is not authorization to restart implementation. Wait until the user says to resume; then inspect the latest Git state, which may be newer than the frozen source snapshot here.
> **Release:** NOT RELEASE_READY. No physical G, actual generic output-routing, Nord Buds telemetry, signed build or device acceptance has been established.

## 1. NEW-AGENT EXECUTIVE INSTRUCTION
Take ownership of the existing EarTime Flutter/Android project. Do not treat it as a greenfield application. The user wants the entire original **119-feature approved scope** implemented as far as the platform permits, then to discuss any optional extra features, then perform consolidated hands-on phone/earbud tests, fix bugs and complete production/release readiness. Resolve deterministic defects immediately during implementation rather than postponing them.
On explicit user RESUME: fetch and inspect the current review branch, working tree, index, untracked files and new commit history. Read the newest CODEX_RESUME, FEATURE_MATRIX, ARCHITECTURE, PRODUCTION_IMPLEMENTATION_LEDGER, RELEASE_BLOCKERS and topic-specific evidence. Preserve the existing native source, uncommitted work, local data and source IDs. Start by reviewing saved WIP E7 frequency. Continue implementing other genuine gaps in bounded, tested, public-safe commits. Do not halt after one minor feature, ask routine approval, force-push, touch main, publish a release, delete app data or claim physical verification. Leave an exact resume checkpoint whenever interrupted.
**Truth requirement:** Never mark 119/119 by removing or weakening criteria. Distinguish actual production implementation, automated tests, hardware-pending acceptance and platform-impossible behavior. A1 must remain BLOCKED_BY_PLATFORM until a legitimate supported solution is demonstrated. Synthetic confirmed-route test rows must never be promoted to real listening.

## 2. LIVE-VERIFIED BASELINE
- Before this handoff's own documentation-only commit, the review branch HEAD was [5775b59 — WIP listening frequency](https://github.com/GoutamNandhen/eartime_app/commit/5775b59b8a2edaabdc0a87a53696a09e82926d28). This is the **source snapshot**, not necessarily the branch HEAD after handoff publication.
- Source matrix: **44 IMPLEMENTED, 60 IN_PROGRESS, 14 NOT_STARTED, 1 BLOCKED_BY_PLATFORM = 119**; software completion 36.97% (often rounded 37%). The “37/100” phrasing means percentage, not feature count.
- Codex local-gate report: 247 Flutter tests passed; 468 native tests passed across 32 suites; analyzer clean; debug/release Kotlin compilation and debug APK packaging passed; four-hook collector guard passed. These results are documented on GitHub but not independently rerun here and are not hardware/CI proof.
- WIP saved: E7 recorded listening frequency is source-implemented with regression tests and native Analytics/Wellbeing display but final feature-acceptance review was intentionally paused. E7 remains IN_PROGRESS.
- Journal source schema 3; disposable projection/cache version 5. Current app development version 1.1.0-dev.1+2, min SDK 24, target SDK 36. Flutter toolchain documented as Dart 3.11-compatible, JDK 17, Android SDK 36.
- Historic local checkout path supplied by the user: F:\projects\eartime_flutter\eartime_app; this is not guaranteed in a fresh agent environment. Public repository access is the recoverable shared source.
- The latest main branch was verified unchanged at 13ae6609d22cb2a0daf8890fca081fb97c93b36b. No release/tag/merge authorized.

### Counts by family
| Domain | Implemented | In progress | Not started | Platform blocked |
|---|---:|---:|---:|---:|
| A | 2 | 9 | 0 | 1 |
| B | 1 | 6 | 6 | 0 |
| C | 3 | 5 | 2 | 0 |
| D | 8 | 3 | 0 | 0 |
| E | 8 | 3 | 3 | 0 |
| F | 4 | 2 | 2 | 0 |
| G | 8 | 12 | 0 | 0 |
| H | 7 | 20 | 1 | 0 |
| I | 3 | 0 | 0 | 0 |
| **TOTAL** | **44** | **60** | **14** | **1** |

Families: A Core Listening (12); B Earbud Intelligence (13); C Home (10); D Timeline (11); E Analytics (14); F Wellbeing (8); G Reliability (20); H Product/Release (28); I Approved Advanced (3).

## 3. PRODUCT GOAL, APPROVED SCOPE AND EXCLUSIONS
EarTime is Android-first, local-first listening observation and duration/wellbeing software with Flutter Material 3 UI and Kotlin native evidence collection. It must count **actual supported evidence of audio being routed through the output**, not merely Bluetooth connectivity or a global media-playback boolean. Users should see truthful UNKNOWN, UNVERIFIED, NONE RECORDED and stale states; no fabricated measured silence, battery, wearing time or health exposure.
Approved components: accurate playback/connection/route transitions; Classic/A2DP/LE/wired/USB and multiple-device handling where justified; device identity/aliases/history and optional OnePlus Nord Buds 3 Pro per-ear/case intelligence; Home; session Timeline; Analytics including duration/frequency/breaks/streaks; personal duration goals, reminders, summaries and quiet hours; durable native journal, recovery and diagnostics; data export/backup/restore/delete; accessibility/localization; offline privacy; native Android widgets/shortcuts/reports; performance/release tooling.
Explicit exclusions: cloud accounts/sync, ANC/EQ controls, vendor adapters beyond permitted OnePlus/OPPO research, speculative acoustic dose or medical exposure predictions. The user intends to review possible extra features only after the approved scope is substantially implemented.

## 4. CANONICAL TECHNICAL ARCHITECTURE
- Core path: Android audio/Bluetooth callbacks and protected AudioTrackingService/BLE broker -> bounded serialized NativeJournalRuntime ingress -> ObservationJournal raw event + ListeningProjection cursor/cache transaction -> committed invalidation hints -> Flutter queries. EarTimeApplication initializes native worker independently of Flutter; native widgets read the same canonical query.
- Journal owns raw observation UUID, source UUID, sequence, source/capture clocks, process/collection epochs, conflict/fault markers and replay/ack cursors. Projection version 5 is disposable/rebuildable and derives UTC-clipped unions, daily/hour buckets, devices/aliases, intervals, sessions and reports. Bounded replay uses 128-row transactions; complete totals may explicitly refuse oversized scans, never silently truncate.
- Flutter's product screens (Home, Timeline, Analytics, Devices, Wellbeing) use readListeningProjection. Old Dart/Drift reducers are compatibility artifacts, not the canonical product clock. EventChannel events invalidate snapshots; they are not independent history.
- Runtime collector health has generation/epoch-scoped acknowledgments and <=15s inventory/global activity lease with approximately 10s polls. The separate service-owned SupportedAudioObserver uses a background HandlerThread and nonblocking registration/cleanup. HEALTHY inventory/global observer is **not** a healthy actual output route and cannot authorize confirmed ticking or live-dependent reminders.
- Actual route attribution remains UNKNOWN in the real production collector. Public per-device BluetoothA2dp.isA2dpPlaying is acquired as bounded source-tagged STREAMING_REPORTED candidate evidence, but an API false/empty result is ambiguous and a positive cannot alone establish cross-app confirmed route duration.
- Durable endpoint random UUID and alias associations are source/revision/owner fenced, reversible, never matched by name alone. Physical identity across Classic/LE/wired/USB and vendor roles remains unproven. A user-assigned alias is not physical identity proof.
- Native journal schema 3, projection 5, legacy Drift v1 preserved read-only, typed preferences stored natively, Android widget provider independent of Flutter, worker-serialized archive and restore flows.

## 5. ALREADY BUILT: DO NOT REPEAT THESE PHASES
**Durability:** atomic commit before publication; duplicate-safe UUID/seq handling, source/cursor replay, migration/rebuild/rollback, loss/clock boundaries, bounded worker/hints/results and 1200-session model tests. Software-complete IDs include G1/G2/G3/G4/G7/G10/G11/G12 and A11/A12.
**Timeline:** query-only canonical measured session groups; exact original/UTC/local start/end, clipped union duration, pause/resume, uncertainty, contributor/detail pages, date/device scope and source-order safety. D1–D4, D7–D10, E5/E6 software pass. D5/D6/D11/H5 retain connection/physical/performance acceptance.
**Calendar/analytics:** day/week/month/year/custom filters, DST/leap correctness, native daily and hourly trends, paged semantics/accessibility, lower bounds and distinct zero/unknown/unverified records, recorded goal/streak duration insights and personalized reports. E1/E3/E10/E11/E12/E13 implemented. E7 frequency in WIP final review.
**Data controls:** H17 versioned five-component application export including native source, typed preferences/summary state, preserved legacy Drift and cursor/conflict data; H18 integrated application restore with durable prepared intent, verified recovery archive, legacy/preference compensation and native commit-LAST marker; H19 explicit consent plus Android ActivityManager.clearApplicationUserData request (not erasure proof); H14 settings integration. No automatic data deletion or silent import of legacy into confirmed time. Actual provider power-loss/OS deletion still PHYSICAL_PENDING.
**Devices/privacy:** B3 editable names pass. Native per-device history, endpoint association/alias revision editing and consent-only bounded read-only BLE diagnostics exist, but physical ID and telemetry do not. Earlier automatic vendor CCCD writes were removed, not authorized as a future feature. Offline disclosures/permissions and private local data practices have been implemented (H28).
**Wellbeing/widgets:** recorded daily/weekly summaries, optional notification categories/preferred time/quiet hours with persisted native receipts (F4/F5), personal goals (F1), duration insights (F6). Three native widget variants include the requested dark two-column device grid, compact last-observed activity and daily summary; app shortcuts, deep links and personalized reports implemented (I1/I2/I3). Actual launcher/OEM notifications/earbud telemetry untested.
**Build/UI:** native-backed themes (H2), version policy and installed About (H25), real large-font fixes, chart contrast and keyboard semantics, analyzer clean and debug packaging. Release signing remains fail-closed without owner-supplied credentials.

## 6. IMMEDIATE RESUME TASK AND CONTINUATION PRIORITIES
**PAUSE FENCE:** Do not implement new code solely because this document was created. Await explicit user instruction to resume. On resume first inspect saved WIP commit 5775b59 and current worktree. The exact next action in CODEX_RESUME is E7 frequency final acceptance review, not rewriting already completed Timeline/data-export work.
**E7 frequency WIP contract:** count original measured confirmed canonical session-group starts whose captured opening falls within the selected window; never treat clipping or later SYNC as a new start. Exclude zero/unknown/unverified/speaker; retain replay, duplicate, per-device, overlapping-route, gap/clock rollback, midnight/repeated DST hour and page-independence constraints. Native/Flutter tests passed at pause, but E7 remains IN_PROGRESS pending final review.
**Next safe software candidates:** C5/E2 connected/listening/idle partitions without equating missing data to idle; E8 observed break intervals and F7 honest break guidance; D5 richer connection/route transition timeline; C6/B10/B13 truthfully unsupported battery/wearing and generic fallback; H21 string extraction/locale testing; H1/H3/H20 full screen-size/TalkBack coverage; G16/G17/G18/E14/D11 diagnostics, long-run replay fairness and paging consistency; H15/H16 privacy/offline review; G19/G20 reproducible test plan.
**Hardware-dependent work:** A2–A10 route states and source proof, B1/B2/B4/B5–B12 physical/cross-profile identity and standard/vendor capabilities, C1/C2/C8–C10 live eligibility, G5/G6/G8/G13–G15 callback/OS acceptance. Work on independently testable subcontracts, but do not mark anything physically verified without physical evidence. F2/F3 real continuous/break reminders remain gated by verified route-scoped listening.
**Exactly 14 NOT_STARTED rows at checkpoint:** B5 Left/right battery; B6 Case battery; B7 Charging indicators; B8 In-ear/in-case states; B9 Independent wearing durations; B11 Optional OnePlus vendor telemetry; C5 Connected/listening/idle breakdown; C6 Battery/wearing indicators; E2 Connected/listening/idle comparison; E8 Breaks/break lengths; E9 Wearing trends; F2 Continuous-listening reminders; F3 Break reminders; H21 Localization readiness.
**One platform blocker:** A1 actual generic third-party playback duration, detailed in PLATFORM_ATTRIBUTION_LIMITS.md. Do not force fake 119/119; explain evidence-backed limitations and obtain approval before changing scope.

## 7. SPECIFIC REGRESSIONS TO KEEP FIXED
- **Physical G rapid reopen/splash:** the original 0a8be43 service is the historical known-good reference; the failure mechanism has never been conclusively proven in phone traces. The current service is NOT byte-identical: exactly four reviewed passive-observer lifecycle hooks were added after recovery checkpoint 9fd94b5. Strict check_collector_baseline.ps1 -AllowObserverLifecycleHooks removes those four in memory and compares every original line. It does not imply physical G PASS.
- **B02 opening continuity:** source opening T1=1000, later SYNC S=5000, pause=9000 must yield duration 8000, not 4000. Preserve T1 across engine replacement when durable same-epoch continuity is valid; never bridge an actual restart/process gap.
- **Stale connection/speaker playback:** connected earbuds do not prove actual output. Unknown connection/failure cannot be represented as known disconnect or measured silence.
- **Measured-run means:** zero-length retained observations cannot dilute averages of positive measured runs. Session pages are not a replacement for canonical global union totals.
- **UI:** retain tests for 360px and 2x/3x text, date/time picker overflow, chart semantic values, minimum interactive target and contrast. Do not clamp fonts to hide errors.
- **Concurrency:** observer startup nonblocking, stop/cleanup generation fencing, disposed Flutter owners, notification request token ownership, bounded archive cancellation, restore compensation before publication and queued event epoch isolation.

## 8. IMPORTANT ANDROID / VENDOR LIMITATIONS
Public AudioManager.getDevices is connected inventory, getCommunicationDevice is communication routing and getAudioDevicesForAttributes is predicted policy; none proves another app's actual media output. AudioRouting.getRoutedDevice belongs to a specific owned AudioTrack. AudioPlaybackConfiguration.getAudioDeviceInfo was never populated for generic cross-app usage, per Android documentation. A1 is therefore BLOCKED_BY_PLATFORM under the current ordinary-app acceptance criteria, although narrower A2DP candidate work may proceed.
OnePlus Nord Buds 3 Pro left/right/case battery, charging, in-ear/in-box and wearing duration are unverified. Historical HeyMelody interoperability notes were exploratory, local/private and not validated packets. Do not invent role mapping, use decompiled code, issue vendor writes, auto-pair, modify firmware, control ANC/EQ or attempt hidden permissions. Use supported read-only capability- and consent-gated code, freshness and UNKNOWN labels.
Do not substitute synthetic CONFIRMED observations for real earbuds/phone testing. No validated route-specific listening health lease yet exists, so current production confirmed live ticking and live-dependent reminders remain disabled.

## 9. PRIVACY, DATA LOSS AND RELEASE SAFETY
- The repository is PUBLIC. Stage only reviewed source/tests/public documentation. Exclude raw ADB/Bluetooth logs, device addresses/serials, personal histories, SQLite, APK/AAB, keystores, local research/decompiled material and credentials. Run tools/audit_public_tree.ps1 and manually review file/tree diff.
- Legacy Drift v1 remains separately preserved/read-only unless an explicit user-approved restore acts; no silent import/confidence promotion. Application export contains plaintext potentially sensitive data and user-chosen SAF providers may be cloud-backed by the provider; EarTime itself does not implement cloud sync. Checksums detect corruption, not authenticity.
- Whole-app restore uses recovered intent/compensation, not one cross-SQLite WAL transaction. Physical OS fsync, provider stalls and power-loss remain unproven. Destructive clearApplicationUserData returns accepted/requested, never verified erased; test only on disposable profile after external backup.
- Signing requires owner-provided EARTIME_KEYSTORE_PATH, EARTIME_KEYSTORE_PASSWORD, EARTIME_KEY_ALIAS and EARTIME_KEY_PASSWORD in authorized environment. Never put secrets in repo/chat/debug output. Missing signing config must refuse release packaging rather than use a debug key.
- Do not merge main, force-push, erase published Git history, install to user's phone or publish a release without permission. Published rollback should use git revert/corrective commit. A revoked leaked secret requires more than a revert.

## 10. AUTOMATED VALIDATION AND ACCEPTANCE EVIDENCE
Windows PowerShell from repo root (adjust for installed tools and verify scripts):
    flutter pub get
    flutter test --no-pub --reporter expanded
    flutter analyze --no-pub
    flutter build apk --debug
    powershell -ExecutionPolicy Bypass -File tools/check_collector_baseline.ps1 -AllowObserverLifecycleHooks
    powershell -ExecutionPolicy Bypass -File tools/audit_public_tree.ps1
    git diff --check
From android/ with Java 17, SDK 36 and resolved dependencies:
    .\gradlew.bat :app:testDebugUnitTest :app:compileDebugKotlin :app:compileReleaseKotlin :app:assembleDebug --offline --no-daemon
    .\gradlew.bat :app:checkReleaseSigning --offline
Also follow version guard tools/check_app_version.ps1 and run fresh native tests (e.g. --rerun-tasks) when cache may conceal results. The release-signing check without keys is expected to fail safely, not count as a successful signed build. Note old TEST_PLAN.md's byte-equality command is superseded by four-hook guard. Regressions must be fixed, not skipped, suppressed or converted into trivial assertions.
Latest reported local gate: **247 Flutter / 468 native**, analyzer clean, both Kotlin compilations, debug packaging, collector guard. No physical install/route/G/telemetry/launcher/signed-release verification is implied.

## 11. CONSOLIDATED REAL-DEVICE ACCEPTANCE (LATER, USER-CONDUCTED)
Target historical test setup: OnePlus 11 5G CPH2447 / Android 16 and OnePlus Nord Buds 3 Pro. Do not assume availability; confirm later. Only after most independent implementation is done, deliver a single reproducible checklist with redacted timestamps/build hash, UI trace and evidence tiers:
1. Rapid G reopening/splash, cold/warm startup, service foreground ownership, repeated Recents removal, screen-off/background and OS process kill/restart.
2. Actual speaker versus earbud output while both are connected; A2DP/LE/SCO/HFP, wired/USB-C, route changes, multiple devices, pause/resume and disconnect while media persists.
3. Date/timezone/midnight/DST/rollback, owner/gap recovery, B02 T1 continuity and no unjustified time extrapolation.
4. Physical transport identity/reconnect/aliases, same-name devices, per-ear/case battery/wearing/charging/freshness only with validated capability.
5. SAF export/restore on disposable test state, provider errors, process interruption/power loss, recovery/integrity; deletion only on a disposable profile with independently verified external backup.
6. Real Android launcher widgets variants/resize/refresh/large font, shortcut behavior, real notifications/quiet hours, offline, power/thermal/storage profiling.
7. Release-signed/minified build, security/privacy logs, permissions, crash and Play-store/distribution checks after user authorizes credentials/release.
Passing synthetic or Robolectric tests does not fulfill those OS/OEM acceptance gates.

## 12. GIT CHECKPOINT AND REPORT CONTRACT
One writer per repository. Preserve stage/unstaged/untracked files and private local checkpoints. Review changed paths explicitly rather than git add -A. Keep commits on codex/production-checkpoint-20261024, update FEATURE_MATRIX.md, CODEX_RESUME.md, TEST_RESULTS.md, PRODUCTION_IMPLEMENTATION_LEDGER.md and RELEASE_BLOCKERS.md after each tested phase. Push normally; verify remote SHA. Do not alter main. A commit labeled WIP is a recovery point, not implementation completion.
Report: exact branch/SHA, feature IDs newly implemented and updated 119 counts, actual files/production behaviors, RED/GREEN tests, full Flutter/native/analyzer/build/guard, public audit, supported vs physical/platform limitations, next safe action. If credits end, preserve and publish only audited safe WIP; do not promise unsupported automatic future execution.

## 13. RECOMMENDED READING ORDER AND SOURCE NAVIGATION
**First:** [CODEX_RESUME.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/CODEX_RESUME.md) · [FEATURE_MATRIX.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/FEATURE_MATRIX.md) · [ARCHITECTURE.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/ARCHITECTURE.md) · [PRODUCTION_IMPLEMENTATION_LEDGER.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/PRODUCTION_IMPLEMENTATION_LEDGER.md) · [RELEASE_BLOCKERS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/RELEASE_BLOCKERS.md) · [TEST_RESULTS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/TEST_RESULTS.md)
**Tracking:** [LISTENING_PROJECTION.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/LISTENING_PROJECTION.md) · [NATIVE_FLUTTER_CONTRACT.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/NATIVE_FLUTTER_CONTRACT.md) · [COLLECTOR_HEALTH.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/COLLECTOR_HEALTH.md) · [PLATFORM_ATTRIBUTION_LIMITS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/PLATFORM_ATTRIBUTION_LIMITS.md) · [A2DP_OBSERVATIONS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/A2DP_OBSERVATIONS.md) · [ENDPOINT_IDENTITY.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/ENDPOINT_IDENTITY.md) · [HISTORY_REPLAY.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/HISTORY_REPLAY.md) · [TIMELINE_SESSIONS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/TIMELINE_SESSIONS.md) · [LISTENING_FREQUENCY.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/LISTENING_FREQUENCY.md)
**UI/feature evidence:** [CALENDAR_FILTERS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/CALENDAR_FILTERS.md) · [ANALYTICS_TRENDS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/ANALYTICS_TRENDS.md) · [DEVICE_HISTORY.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/DEVICE_HISTORY.md) · [REPORTS_AND_NAVIGATION.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/REPORTS_AND_NAVIGATION.md) · [WELLBEING_SUMMARIES.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/WELLBEING_SUMMARIES.md) · [RECORD_STATES.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/RECORD_STATES.md) · [READ_ONLY_DIAGNOSTICS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/READ_ONLY_DIAGNOSTICS.md) · [PRIVACY_DISCLOSURES.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/PRIVACY_DISCLOSURES.md)
**Data/release:** [APPLICATION_EXPORTS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/APPLICATION_EXPORTS.md) · [APPLICATION_RESTORE_CONTRACT.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/APPLICATION_RESTORE_CONTRACT.md) · [APPLICATION_DELETION.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/APPLICATION_DELETION.md) · [JOURNAL_ARCHIVES.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/JOURNAL_ARCHIVES.md) · [VERSIONING.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/VERSIONING.md) · [PUBLIC_CHECKPOINT.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/PUBLIC_CHECKPOINT.md) · [RELEASE_VALIDATION.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/RELEASE_VALIDATION.md) · [TEST_PLAN.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/TEST_PLAN.md)
**Historical and sometimes stale:** [DECISIONS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/DECISIONS.md) · [BUGS.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/BUGS.md) · [PROJECT_STATE.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/PROJECT_STATE.md) · [CURRENT_STATE.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/CURRENT_STATE.md) · [HANDOFF.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/HANDOFF.md)
Some historical docs claim LiveSessionNotifier is product truth, export/restore/deletion do not exist, experimental BLE writes still occur, or the service must be byte-equal. These descriptions are superseded by newer implementation/architecture and must be reconciled with actual source rather than copied blindly.

## 14. CRITICAL SOURCE PATHS
Native Kotlin: android/app/src/main/kotlin/com/eartime/eartime_app/{EarTimeApplication.kt, MainActivity.kt, tracking/AudioTrackingService.kt, tracking/SupportedAudioObserver.kt, tracking/CollectorHealth.kt, tracking/NativeJournalRuntime.kt, tracking/ObservationJournal.kt, tracking/ListeningProjection.kt, tracking/ListeningSessions.kt, tracking/EndpointIdentity.kt, tracking/A2dpStreamProbe.kt, tracking/OutputAttribution.kt, tracking/ApplicationArchive.kt, tracking/ApplicationRestoreCoordinator.kt, tracking/ApplicationDataDeletion.kt, tracking/WellbeingSummaries.kt, widgets/ListeningWidgetProvider.kt}.
Flutter: lib/main.dart; lib/data/listening_projection.dart; lib/data/listening_calendar.dart; lib/data/application_data_access.dart; lib/data/journal_transfer.dart; lib/providers/listening_projection_provider.dart; lib/features/listening/listening_workspace.dart, listening_trends.dart, listening_session_screen.dart; lib/features/{home,timeline,analytics,devices,wellbeing,settings,shell}/*.dart.
Tests: test/; android/app/src/test/. Tools: tools/audit_public_tree.ps1, tools/check_collector_baseline.ps1, tools/check_app_version.ps1. Review exact current tree for additions.
**Architecture invariants:** native source/projection is single truth; no Dart accounting timer; no legacy rewrite; no guessed identity; no duration across lost evidence; no fake A1 confirmation; no vendor writes; no unauthorized user-data/device operation.

## 15. LIMITATIONS AND VALIDITY OF THIS HANDOFF
Evidence was taken from GitHub branch codex/production-checkpoint-20261024 at source commit 5775b59b8a2edaabdc0a87a53696a09e82926d28 on 2026-11-05, plus user-provided historical physical target/workflow. This document does not know the state of an unseen new agent workspace, hidden local checkpoints, later pushes, credentials, real OEM telemetry or physical test outcomes. The public repo confirms source and published documentation; it cannot independently prove 247/468 local tests ran or a clean private working tree. The user must explicitly resume implementation after the shutdown pause. This documentation publication changes no application source code.
**A1 remains BLOCKED_BY_PLATFORM.** The desired 119/119 count is a target, not license to fabricate a proof or claim production readiness.

---
## APPENDIX A — COMPLETE 119-ITEM APPROVED FEATURE MATRIX (VERBATIM SOURCE SNAPSHOT)
Copied from [FEATURE_MATRIX.md](https://github.com/GoutamNandhen/eartime_app/blob/5775b59b8a2edaabdc0a87a53696a09e82926d28/docs/eartime/FEATURE_MATRIX.md) at source commit 5775b59b8a2edaabdc0a87a53696a09e82926d28. Each row has original ID, exact feature name, state, available evidence and remaining acceptance gate. This is a frozen historical snapshot; update the live matrix after future code changes.

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

---
**END OF DOCUMENT — preserve the original source matrix and its evidence. On resume, refresh Git before editing or reporting.**
