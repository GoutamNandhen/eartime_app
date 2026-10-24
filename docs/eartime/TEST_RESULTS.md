# Automated Results

Last verified implementation baseline: 2026-10-24.

| Gate | Actual result |
| --- | --- |
| Flutter full suite | 129 passed, 0 failures |
| Analyzer | Exit 0, no issues |
| Android native suite | 173 passed, 0 failures/errors/skips |
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
