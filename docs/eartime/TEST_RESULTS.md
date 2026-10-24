# Automated Results

Last verified implementation baseline: 2026-10-24.

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
| Flutter full suite | 151 passed, 0 failures |
| Analyzer | Exit 0, no issues |
| Android native suite | 272 passed in 22 suites, 0 failures/errors/skips |
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
