# Unified Listening Projection

2026-10-24. This document supersedes the foundation-only accounting state.

## Ownership And Commit Boundary

`EarTimeApplication -> NativeJournalRuntime -> ObservationJournal` owns the
native SQLite file. `ListeningProjection` writes only disposable derived tables
inside the journal transaction. The source row and projection sequence are
visible to a separate SQLite connection before EventChannel publication.
The integration test checks both, not just an in-memory callback.

Raw observation IDs are UUIDs, sequences are assigned by SQLite, source identity
persists, fingerprints detect conflicting ID reuse, and consumer acknowledgments
cannot advance past committed rows or move backward. Projection sequence is a
separate transactional checkpoint. Identical duplicate source rows do not apply
twice. Duplicate logical start events preserve the opening; repeated pauses do
not create negative or duplicate listening.

All seven protected-service emission sites and BLE emissions found by source
audit call `TrackingEventBroker.sendEvent`. Direct diagnostic RPC replies are
snapshots, not historical collector observations. Remaining volatile paths are
collector state/dedup before emission, the bounded 256-entry pre-commit ingress,
and post-commit delivery hints. Death before ingress commit can lose those
unpublished observations; restart records uncertainty, not invented duration.

Overflow and invalid input become ordered durable loss markers. Commit failure
prevents publication and requires a durable gap before the next accepted record.
Delivery failure after commit does not falsely create collection loss. The live
hint cache is capped at 256 and flushes 32 per turn; it is not canonical history.

## Migration And Recovery

- Schema 1 -> 3: additive derived tables only, retaining journal/source/cursors.
- Schema 2 -> 3: add indexed known-device rows and clear only disposable caches.
- Replay runs in 128-row transactions, each committing its own state/cursor.
  Every public projection read catches up before returning a snapshot.
- Rebuilding from observations produces equivalent IDs/totals/state. A crash
  before commit rolls back source and projection together. Reopen retains the
  checkpoint; a new process appends a gap before new collector publication.
- Future DB versions fail closed without corruption deletion or raw-data loss.
- Derived projection v2/v3 caches replay as v4 to apply owner-stop closure and
  durable endpoint associations. Alias observations remain in the same raw journal;
  source schema remains 3. Internal rebuild cancellation preserves completed
  128-row transactions and cannot return partial totals. See `HISTORY_REPLAY.md`.
- Legacy Drift remains schema 1, untouched. It is not imported, upcast or added
  to confirmed totals. Product activation no longer writes it; Settings exposes
  paged read-only historical observations with an uncertainty label.

## Continuity And B02

The old Dart compatibility reducer holds an opening only in memory. On a new
Dart owner, a playing SYNC falls back to its timestamp S, losing T1. This was the
specific live/history mechanism; it is separate from the unproven physical G
splash cause. Native state now persists the interval ID, opening, monotonic
anchor, epoch, boot and source sequence. A valid same-epoch SYNC/repeated start
updates last evidence without replacing T1. Tests replay start=1000,
SYNC=5000, pause=9000 and assert 8000, not 4000, for unverified activity.

Confirmed synthetic route fixtures prove the same native opening survives
Flutter snapshot and DB owner replacement. An actual process restart is NOT
continuity: the last durable evidence closes the old interval; a later new
observation starts a new one. No time is credited between those points.

Pause/resume partitions time. Route disconnect only closes its route; two routes
of one physical device retain connection until both disappear. Missing/changed
identity, built-in speaker, unknown attribution, monotonic rollback, changed boot
or epoch and wall-clock jumps cannot extend a previously confirmed route.
Wall-clock discontinuities close at last valid evidence rather than inventing
calendar duration. Global totals union overlapping routes; per-device totals
union that device's own routes and may overlap other devices intentionally.

Calendar windows are clipped centrally. Calendar day advancement handles 23/25
hour DST days; repeated autumn hours accumulate into the same hourly bucket.
Day/hour sums, longest/average runs and global totals have native reconciliation
tests. Flutter performs formatting/progress normalization, not interval math.

## Truthful Production Semantics

The existing legacy playback logic emits a global playback boolean and fallback
device IDs. It does NOT prove the playing output or physical identity. All its
real observations remain UNKNOWN; their playback projection is UNVERIFIED and
device identity is provisional/epoch-scoped. Only explicitly CONFIRMED typed
native route inputs can create confirmed listening. There is currently no real
collector that emits those inputs. Tests are not hardware support evidence.

There is no route-specific listening lease: the separate service-owned observer
has durable inventory/activity health, not actual-output proof or a guarantee
that legacy initialization succeeded. Consequently production RPCs
never extend open intervals to the query clock. Last evidence, not a Flutter
timer or mere process lifetime, is authoritative. The explicit live-lease reducer
path is model-tested for future verified collectors. A fresh legacy SYNC cannot
retrospectively prove continuous collection across an unmarked same-process
service recreation; its unverified duration is never confirmed listening credit.
That lifetime/generation hook remains required. Live ticking/reminders are
not declared implemented. User-requested stop journals a gap.

Home/Timeline/Analytics/Devices/Wellbeing read the same versioned native snapshot.
The native widget calls the same query, not Flutter/Drift. Date ranges and
interval pages are real queries. Native names are display overrides only, not
physical aliases. Known devices use independent `deviceOffset` pages of at most
100 rows, returning `nextDeviceOffset` and `hasMoreDevices`. The Devices view
offers next/previous controls; Home/widgets keep page zero. Connected rows sort
first, then descending last evidence and identity. Pages are live offset queries,
not a frozen multi-page snapshot: source changes can reorder rows between reads.
Device paging never changes interval totals or the independent interval cursor.
A 100,000 interval scan ceiling fails explicitly rather
than truncating totals. Realistic storage/performance profiling remains open.

## Evidence

`ListeningProjectionTest`: 48 modeled API 28/35 cases. `ListeningWidgetTest`: 6.
`ListeningPreferencesTest`: 12. Existing SQLite cases: 20. Ingress integration:
3. Durable delivery/loss tests: 2 plus original queue cases. The JSON fixture
`test/fixtures/listening_continuity.json` is consumed by the real native reducer
and Dart decoding/RPC/widget tests. This is cross-layer contract evidence,
not a real FlutterEngine/device end-to-end test.

Flutter projection/RPC/layout/paging/health suite: 20 cases. Device tests traverse 205
synthetic identities, preserve totals/reopen results and reject invalid cursors.
Full final gates: 129 Flutter, 173 native, zero failures/skips, analyzer clean,
debug/release Kotlin compilation and debug APK packaging successful. Signing
check correctly refuses missing keys. Strict four-hook collector guard verified;
plain service equality is now FALSE. See `COLLECTOR_HEALTH.md` for necessity/checkpoint.
Physical process killing, OnePlus G, route attribution, BLE hardware and launcher
refresh/battery/resize acceptance are still pending. See `CODEX_RESUME.md`.

The additive `collectorHealth` snapshot is folded from journaled acknowledgments,
not inferred from uptime/EventChannel attachment. Production supplies a clock
only for health freshness, not duration extrapolation. Scope is inventory/global
activity and `liveListeningEligible` remains false. See `COLLECTOR_HEALTH.md`.
