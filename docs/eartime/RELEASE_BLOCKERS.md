# Release Blockers

Updated 2026-10-24. Verdict: NOT RELEASE_READY.
Feature-level implementation and acceptance gaps are in `FEATURE_MATRIX.md`.

| Blocker | Current evidence | Required resolution |
| --- | --- | --- |
| Physical G / immediate reopen | Historical failure; source/model ownership tests pass; no new device evidence | Correlated OnePlus rapid-reopen trace and final acceptance; preserve `0a8be43` reference |
| Production live continuity | B02 opening retained; FGS-owned scoped inventory/activity observer with durable leases/cleanup/recovery | Actual route-specific continuity before extrapolation/reminders; physical acceptance; scoped health is not legacy callback health |
| Output attribution | All real protected-collector playback remains UNVERIFIED; confirmed route inputs exist only in modeled fixtures | Permitted verified route-scoped collector/evidence; never promote global playback or connected state |
| Identity | Typed random IDs/alias contracts exist; legacy name fallback remains | Persistent evidence-backed identity normalization and alias migration |
| Migration/replay integration | Schema 3 migrations/rebuild/native consumer cutover pass; legacy Drift preserved read-only | Deliberate legacy import policy, export/restore conflict/rollback tests and physical migration acceptance |
| Memory/history size | Bounded results, 1200-session/2400-row model, internal rebuild cancellation, live paging insertion tests | Realistic phone/storage/energy profiling, normal startup fairness, cross-layer cancellation and frozen multi-page consistency |
| Telemetry/privacy | Experimental automatic BLE discovery is inherited; proprietary capabilities unverified | Explicit optional gating, real capability/freshness evidence, privacy/offline/backup review |
| Missing product scope | Most remaining analytics, wellbeing, widgets and data-control features are incomplete | Implement/test the remaining approved feature matrix |
| Static/test integration | Analyzer clean, 129 Flutter / 173 native pass; 15 placeholders replaced | Actual FlutterEngine/OS fault tests, broader performance/accessibility/locale matrix |
| Release/signing | Debug APK/debug+release Kotlin compile pass; production signing env gate rejects missing keys, no debug fallback | Authorized keys, signed release packaging, hashes and final release/privacy gates |
| Physical integration | No Android device/AVD available this session | Final background/process/restart/routing/widget/battery acceptance on supported devices |

The debug artifact proves packaging only. It was not installed, published or
treated as a release. The original source checkpoint and staged work remain
recoverable; no destructive database migration was performed.

OS cloud backup/device transfer are now excluded; explicit local export/restore
is not yet implemented. Do not uninstall or clear data as a migration strategy.
The widget implements the native dark two-column layout with unknown battery
states, but actual launcher timing/resize/refresh and battery telemetry are not
validated. Production interval reads stop at durable evidence; a living process
alone never enables a ticking listening timer. `LISTENING_PROJECTION.md` records
these deliberate correctness limits and the exact automated evidence.
