# Architecture

Updated 2026-10-24. Development checkpoint, not a production-ready release.
This replaces historical notes that described an in-memory source of truth or
asserted physical G without corresponding evidence.

## Authoritative Path

Record-state UI classifies native metadata without calculating time. Errors stay
unavailable; missing duration is None recorded, and totals are explicit lower
bounds. The owned foreground refresh is the sole stream recovery mechanism, not
a second framework retry owner. Zero-length interval rows remain available but
cannot dilute positive-run means. RECORD_STATES.md records RED/GREEN evidence.

Calendar filters share local-date window construction and localized validated
entry; selected end days become exclusive next-midnight native bounds. Calendar
clock injection is selection-only, not a duration reducer/lease. CALENDAR_FILTERS.md
records tested UI/pagination/SQLite reconciliation and physical limitations.

About reads installed PackageManager metadata only on explicit navigation via
the bounded worker and owner-fenced channel. Tracked version/Gradle preBuild
consistency and Git comparison gates are documented in VERSIONING.md; no
version/debug flag is treated as signing or readiness evidence.

Recorded-summary opt-in/time/quiet preferences use existing native settings.
Inexact alarms feed a private permission-protected JobService; ownership-fenced
canonical reads/receipts/notifications run on the journal worker without Flutter.
No live extrapolation is enabled. See WELLBEING_SUMMARIES.md for calendar and
at-most-one-attempt semantics; physical delivery is not proven by model tests.

Optional Bluetooth diagnostics are now consent-only bounded service catalogs,
not automatic inventory-triggered connections or vendor CCCD subscriptions. Their
dedicated source/clock provenance commits through the same journal and broker.
See READ_ONLY_DIAGNOSTICS.md; no telemetry or listening confidence is promoted.
PLATFORM_ATTRIBUTION_LIMITS.md records the generic cross-app route blocker.

Passive public per-device A2DP queries now add nested transport observations to
the same OUTPUT_EVIDENCE journal path. This is acquisition, not a route-duration
producer: addresses are not promoted to verified physical IDs, false/empty API fallbacks
remain ambiguous, and confidence/live eligibility are UNKNOWN/false. No second
writer/projection or service-file edit. See `A2DP_OBSERVATIONS.md`.

Fresh supported A2DP endpoint evidence now atomically adds raw random-UUID
association observations and derived alias rows. Explicit confirmed/reset edits
are source/revision/engine-owner fenced and never rewrite earlier identity.
Names remain display-only; physical identity stays unverified. Connection loss
of evidence is UNKNOWN, not disconnection. See `ENDPOINT_IDENTITY.md`.

Explicit native journal archives use bounded versioned JSON lines with source/
sequence cutoff and an integrity footer. Document I/O has its own worker; source
pages still belong to the journal owner. Restore retains a private recovery file
before an atomic source/projection/cursor replacement and gap. Pre-restore queued
events get a separate epoch. Preferences and preserved legacy history are not
replaced or promoted. See `JOURNAL_ARCHIVES.md`: not yet whole-app backup/restore,
and no schema 3 migration or new competing projection was added.

`Android callbacks -> protected AudioTrackingService/BLE broker emissions ->
NativeJournalRuntime -> ObservationJournal + ListeningProjection transaction ->
committed EventChannel invalidation hints`.

`EarTimeApplication` initializes the native worker without awaiting Flutter.
Journal schema 3 owns raw source observations, source identity, sequence and
replay/ack cursors. Projection version 5 owns disposable interval/device/alias rows and
its transactional replay cursor. A separate SQLite reader verifies both source
and projection commit visibility before publication. Flutter never writes this DB.

Home, Timeline, Analytics, Devices, Wellbeing and the Android launcher widget
read `readListeningProjection`. Clipping, union and calendar bucket calculations
run in native code. Flutter formats values and sends bounded queries; events
invalidate data rather than reconstructing product history. Native-backed
preferences hold display names, themes and personal duration goals.

Optional device UUID scope uses indexed SQL before canonical aggregation and
paging. Devices/details and Analytics link to the same Timeline workspace;
unattributed playback cannot enter a device history by name matching. Global
goals are not applied to device-only totals. See `DEVICE_HISTORY.md`.

Native ListeningReport derives selected-window recorded goal streaks and duration
insights from those same daily buckets. It is not a second reducer or persisted
history system. Three widget variants consume the canonical query without Flutter.
Whitelisted navigation uses an independent consume-once channel, with Flutter's
default URI handler disabled. See `REPORTS_AND_NAVIGATION.md` for contracts/tests.

The old Drift schema/data are retained. The shell does not activate its writer.
Settings exposes paged read-only legacy observations, separate from confirmed
listening. Compatibility reducers remain for regression tests, not product totals.

## Correctness Boundaries

- `AudioTrackingService.kt` differs from `0a8be43` by exactly four reviewed passive
  observer lifecycle additions. All prior collector lines match; the hook-only
  guard checks this. Source equality is FALSE; physical G remains pending.
- Real legacy playback is UNKNOWN attribution, projected as UNVERIFIED activity.
  Connected devices and a global playback boolean do not prove the playing output.
- Only explicitly confirmed, identified native route inputs contribute confirmed
  listening. Current nonzero confirmed fixtures are synthetic, not hardware proof.
- Production queries do not extrapolate from process lifetime. A validated
  route-specific health/continuity lease is still required for live ticking/reminders.
  The native observer's durable inventory/global-activity lease cannot grant that.
- Restart/loss gaps close at last durable evidence, not at the later restart time.
  The separate observer journals owner generations/epochs and stops; it does not
  retrospectively validate the legacy collector's same-process gaps.
  A valid current service-owner stop closes intervals at last evidence; stale
  and duplicate owner stops do not close newer work. V2 caches replay as V3.
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
