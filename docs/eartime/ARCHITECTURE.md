# Architecture

Updated 2026-10-24. Development checkpoint, not a production-ready release.
This replaces historical notes that described an in-memory source of truth or
asserted physical G without corresponding evidence.

## Authoritative Path

`Android callbacks -> protected AudioTrackingService/BLE broker emissions ->
NativeJournalRuntime -> ObservationJournal + ListeningProjection transaction ->
committed EventChannel invalidation hints`.

`EarTimeApplication` initializes the native worker without awaiting Flutter.
Journal schema 3 owns raw source observations, source identity, sequence and
replay/ack cursors. Projection version 2 owns disposable interval/device rows and
its transactional replay cursor. A separate SQLite reader verifies both source
and projection commit visibility before publication. Flutter never writes this DB.

Home, Timeline, Analytics, Devices, Wellbeing and the Android launcher widget
read `readListeningProjection`. Clipping, union and calendar bucket calculations
run in native code. Flutter formats values and sends bounded queries; events
invalidate data rather than reconstructing product history. Native-backed
preferences hold display names, themes and personal duration goals.

The old Drift schema/data are retained. The shell does not activate its writer.
Settings exposes paged read-only legacy observations, separate from confirmed
listening. Compatibility reducers remain for regression tests, not product totals.

## Correctness Boundaries

- `AudioTrackingService.kt` remains byte-identical to `0a8be43`.
- Real legacy playback is UNKNOWN attribution, projected as UNVERIFIED activity.
  Connected devices and a global playback boolean do not prove the playing output.
- Only explicitly confirmed, identified native route inputs contribute confirmed
  listening. Current nonzero confirmed fixtures are synthetic, not hardware proof.
- Production queries do not extrapolate from process lifetime. A validated
  collector health/continuity lease is still required for live ticking/reminders.
- Restart/loss gaps close at last durable evidence, not at the later restart time.
  Unmarked same-process service recreation still requires a collector-generation hook.
- Identity from legacy names/MAC fallbacks is provisional and epoch-scoped;
  user display-name overrides cannot alter observations or physical identity.
- Ingress and live hints are bounded; known-device results are paged at 100;
  interval pages at 100 and aggregate scans at 100,000 with explicit refusal.
  Long-history replay fairness/performance remains unfinished.

Read [Listening Projection](LISTENING_PROJECTION.md), [Native Contract](NATIVE_FLUTTER_CONTRACT.md),
[Collector Health](COLLECTOR_HEALTH.md),
[Feature Matrix](FEATURE_MATRIX.md), [Regression Gates](REGRESSION.md) and
[Resume Checkpoint](CODEX_RESUME.md). Raw logs, device identifiers and local
research are not part of the public checkpoint. Published rollback uses `git revert`.
