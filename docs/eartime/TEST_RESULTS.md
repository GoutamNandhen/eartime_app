# Automated Results

Last verified implementation baseline: 2026-10-25.

D7/E1 adds 13 Flutter cases and four native API 28/35 executions. Calendar custom
entry/preset controls, 100-row paging, device scope, cancellation/invalid/oversized
input and backward-clock editor initialization pass at 1x/2x/3x. Actual stock
date-header overflow fixed, assertions retained. SQLite day/week/month/year/custom
union/buckets reconcile across leap day, overlap, reopen and replay with raw/cursor
retention. Invalid queries cannot fall back to global history. CALENDAR_FILTERS.md.

H28 adds 4 native API 28/35 permission/backup configuration executions and six
Flutter cases. Original permission page overflowed 1084px at 2x and 3032px at 3x;
scrollable presentation fixes both with same assertions. Actual offline disclosure
navigation/back is tested before grant and in failed-native Settings at 1x/3x.
All existing startup/rapid-reopen tests pass; no permission or device action is
performed on disclosure opening. PRIVACY_DISCLOSURES.md records remaining limits.

H25 adds 12 API 24/28/35 native executions and 4 Flutter cases, plus 17 version
tool self-tests. Actual APK metadata was inspected (1.1.0-dev.1, code 2, debug).
CRLF/capture-group tool defects and ambiguous Flutter scroll targets were fixed;
two new analyzer findings corrected without suppressions. VERSIONING.md records
the gate, source formats, installed-metadata behavior and release limitations.

F4/F5 adds 45 native executions and 8 Flutter cases: opt-in/inexact scheduling,
API 24 legacy builder, permission/channel/quiet/calendar/DST/fixed-offset rules,
canonical SQLite-to-notification totals, restart/high-water/cancel/query-failure,
native process replacement without Flutter and private/disabled/permission-bound
components. Stock-picker 2x overflow was repaired with a scrollable numeric
editor; assertions remain. No real notifications or devices were exercised.
Three of four initial job-ownership assertions reproduced stale-stop failures;
request UUID extras and compare-remove ownership fix them. Six final ownership
cases include 500 replacements and reparceled equal-token strings. Two additional
API 28/35 executions reject deep/duplicate/oversized stored preferences.

Read-only diagnostic hardening adds 25 native executions (22 safety, 2 private
endpoint resolution, 1 own-source captured-clock ingress) and four Flutter cases.
Full run initially failed 2/296 on wrong oversized-catalog error labeling; the
production finally/control-flow defect was repaired with assertions unchanged.
Final complete counts below include that fix and the dedicated-source regression.

Device-history continuation adds 8 API 28/35 executions and five Flutter tests:
native-scoped union/pages/rebuild/index upgrade, strict channel scope, actual
Devices navigation/large text and B3 edit/cancel/save/error/recreation. All raw
identity/source rows and consumer cursors survive the v4 -> v5 cache migration.

Latest endpoint continuation: 24 new API 28/35 identity cases, one queued retired-
owner case, two widget unknown-connection cases and six Flutter identity client/UI
cases. Full executed gates below supersede earlier checkpoint counts. Alias
replay, v3 -> v4 cache migration, transaction rollback, archive roundtrip,
105-candidate paging and B02 preservation pass. Fixtures are synthetic only.

Warm-navigation follow-up: actual AppShell/permission/native-hint regression
reproduced Settings covering Devices before the fix. Navigator stack dismissal
makes it pass. Full Flutter 140 pass, analyzer clean; native/build gates succeed
with 222 native cases. Initial absent native fixture responses were replaced
with explicit synthetic empty history/preferences so the actual UI path could
execute. The pre-fix assertion then failed for Settings covering the destination.

| Gate | Actual result |
| --- | --- |
| Flutter full suite | 186 passed, 0 failures |
| Analyzer | Exit 0, no issues |
| Android native suite | 362 passed in 28 suites, 0 failures/errors/skips |
| Kotlin compilation | Debug and release compile pass |
| Android packaging | Debug APK build pass; artifact not published |
| Protected collector comparison | Source equality FALSE; exactly four reviewed observer lifecycle additions; strict hook-only guard passes |
| Release signing | Missing-key refusal verified; no signed release |
| Physical G / routing / telemetry / launcher | Not validated |

These are local automation results, not GitHub CI or hardware claims. The full
suite retains all original test slots, including 15 former placeholders replaced
with actual assertions. Public-review fixture sanitation must retain those gates.
Subsequent results are recorded in [Resume](CODEX_RESUME.md) and
[Implementation Ledger](PRODUCTION_IMPLEMENTATION_LEDGER.md).

Health additions: 16 API 28/35 journal cases and 16 synthetic attribution-policy
cases, plus two Flutter decoder/status cases. The interrupted-daemon file-lock
failure was resolved by a normal daemon stop and fresh single-use build; no
test fixtures/assertions were removed. These contracts do not validate hardware.

Runtime additions: 10 observer-owner cases (500 replacement model/1000-call
storm), three Android adapter API 24/28/35 models, one captured-source/durable-ack
ingress case and one Flutter hint decoder case. A missing-boot fixture initially
failed health acknowledgment; explicit synthetic boot evidence fixed the test
without weakening production refusal. Physical service/G/routing remains pending.

Owner-stop continuity: four pre-fix failures reproduced, then passed with closes
at last evidence and stale/duplicate fencing. Three history/load cases verify
1200-session complete totals/pages, internal rebuild cancellation/reopen and
version-2 cache correction/future refusal. No partial aggregates accepted.
Four API 28/35 worker lifecycle tests additionally cover blocked initialization
with nonblocking close and exactly-once resource cleanup. Physical G remains pending.

Reports/widgets/navigation: five pure native report cases cover recorded goals,
unfinished/future/partial days, disabled goals, unverified-only activity and DST.
Two API 28/35 projection cases verify persisted-goal/reopen/rebuild report parity.
Six navigation cases cover explicit intents, rejecting commands/arguments and
the actual manifest/shortcut XML, including disabling Flutter's competing URI
handler. Two widget cases verify canonical daily totals, unknown current output
and unavailable history. Three Flutter cases cover consume/disposal, malformed
report contracts and actual Wellbeing report rendering at 2x text. No assertions
were weakened. The initial analyzer style finding was corrected and rerun clean.

Native archive continuation adds 34 native cases: 27 bounded format/SQLite restore
cases (including API 28 1500 sessions/3000 observations), six API 28/35 document
picker cases and one API 28 queued-event restore-boundary integration. Seven
Flutter cases cover explicit confirmation/cancel, success counts/errors, busy
disposal, recovery pages, channel contracts and 360px/2x text. Initial JUnit
non-void method initialization failure was repaired; no test was disabled. The
large-text fixture initially tapped an off-screen/lazily built row; it now
scrolls and scales the Navigator/dialog as well as the page. Final owner-fenced
Kotlin debug/release and debug packaging pass. Phone process death, stalled
document providers and power-loss durability are not established by these models.

Public A2DP producer: 14 probe owner/failure/fresh-query cases and one durable
candidate ingress case added. Existing API 24/28/35 backend tests additionally
verify the actual integrated source contract and UNKNOWN/false eligibility.
Full 140 Flutter / 237 native, analyzer clean, debug/release Kotlin and debug APK
pass. Service guard still allows exactly four old hooks. No confirmed route/live
time is enabled. `A2DP_OBSERVATIONS.md` records source/API limits and next work.
