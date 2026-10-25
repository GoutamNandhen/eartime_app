# Release Blockers

Updated 2026-10-25. Verdict: NOT RELEASE_READY.
Feature-level implementation and acceptance gaps are in `FEATURE_MATRIX.md`.

Latest application-restore gates: 236 Flutter / 458 native, analyzer clean, both
Kotlin variants/debug APK pass. Native-only export/confirmed restore/recovery are
integrated. H17 application-state export now includes legacy/preferences and
integrity validation; APPLICATION_EXPORTS.md. H19's confirmed self-data-clear path
is implemented, not physically erased/validated (APPLICATION_DELETION.md). H14/H18
application restore/recovery is integrated with commit-last compensation and
read barriers; APPLICATION_RESTORE_CONTRACT.md. Actual OS power-loss durability,
provider stalls/cancellation timing and recovery accessibility remain pending.
No new hardware or release evidence.

| Blocker | Current evidence | Required resolution |
| --- | --- | --- |
| Physical G / immediate reopen | Historical failure; source/model ownership tests pass; no new device evidence | Correlated OnePlus rapid-reopen trace and final acceptance; preserve `0a8be43` reference |
| Production live continuity | B02 opening retained; FGS-owned scoped inventory/activity observer with durable leases/cleanup/recovery | Actual route-specific continuity before extrapolation/reminders; physical acceptance; scoped health is not legacy callback health |
| Output attribution / A1 BLOCKED_BY_PLATFORM | Generic configuration-route field documented as never populated; all real collector playback still UNVERIFIED; narrower A2DP candidates acquired | PLATFORM_ATTRIBUTION_LIMITS.md; supported scoped proof/continuity or approved cooperative source, not a physical-test waiver/global or inventory promotion |
| Identity | Durable random endpoint IDs and explicit reversible associations integrated; replay/reopen/restore tested | Verified physical/cross-profile identity; LE/wired/USB normalization; legacy provisional records stay separate |
| Migration/replay integration | Schema 3 migrations/rebuild/native consumer cutover pass; legacy Drift preserved read-only | Deliberate legacy import policy, export/restore conflict/rollback tests and physical migration acceptance |
| Memory/history size | Bounded results, 1200-session/2400-row model, internal rebuild cancellation, live paging insertion tests | Realistic phone/storage/energy profiling, normal startup fairness, cross-layer cancellation and frozen multi-page consistency |
| Telemetry/privacy | Automatic GATT/vendor CCCD writes removed; explicit one-shot bounded read-only catalog, own-source durability tested | Actual standard/vendor values/roles/freshness; protected collector log audit, offline/backup/privacy review |
| Missing product scope | Most remaining analytics, wellbeing, widgets and data-control features are incomplete | Implement/test the remaining approved feature matrix |
| Static/test integration | Analyzer clean, 236 Flutter / 458 native pass; 15 placeholders replaced | Actual FlutterEngine/OS fault tests, broader performance/accessibility/locale matrix; Windows directory syscalls explicitly modeled, not physical evidence |
| Release/signing | Version 1.1.0-dev.1+2 metadata inspected; monotonic/source consistency gates; debug APK/debug+release Kotlin pass; signing rejects missing keys, no debug fallback | Authorized keys, signed release packaging, hashes and final release/privacy gates |
| Physical integration | No hardware actions performed; current attachment availability not checked | Final background/process/restart/routing/widget/battery/deletion acceptance on supported devices |

The debug artifact proves packaging only. It was not installed, published or
treated as a release. The original source checkpoint and staged work remain
recoverable; no destructive database migration was performed.

OS cloud backup/device transfer are excluded. Explicit versioned application backup/
restore covers native, legacy and preferences with recoverable commit boundaries;
physical durability remains pending. Do not uninstall or clear data as a migration
strategy; explicit full deletion remains irreversible and removes private recovery.
The widget implements the native dark two-column layout with unknown battery
states, but actual launcher timing/resize/refresh and battery telemetry are not
validated. Production interval reads stop at durable evidence; a living process
alone never enables a ticking listening timer. `LISTENING_PROJECTION.md` records
these deliberate correctness limits and the exact automated evidence.

Reports, recorded goal streaks, widget variants, shortcut/deep links and opt-in
recorded daily/weekly notifications/quiet controls have production software paths.
Live listening/break reminders and observed-break guidance remain unfinished.
Data controls' physical storage/provider/erasure gates and summary OS/OEM timing
and permission behavior are PHYSICAL_PENDING;
these additions do not close tracking, hardware, privacy or release blockers.
