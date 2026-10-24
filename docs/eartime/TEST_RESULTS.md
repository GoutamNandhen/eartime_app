# Automated Results

Last verified implementation baseline: 2026-10-24.

| Gate | Actual result |
| --- | --- |
| Flutter full suite | 128 passed, 0 failures |
| Analyzer | Exit 0, no issues |
| Android native suite | 148 passed, 0 failures/errors/skips |
| Kotlin compilation | Debug and release compile pass |
| Android packaging | Debug APK build pass; artifact not published |
| Protected service | Empty diff against `0a8be43` |
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
