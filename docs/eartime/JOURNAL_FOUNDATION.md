# Native Journal Foundation

Date: 2026-10-24. Implementation checkpoint, not release readiness.

Historical foundation checkpoint. `LISTENING_PROJECTION.md` / `CODEX_RESUME.md`
supersede schema, product consumer, unbounded-buffer and pending-projection
statements below. Current schema is 3, projection version 3; product history is
native and delivery hints are bounded. Legacy Drift remains read-only/preserved.

## Delivered

The application now owns a native observation journal independently of a live
Flutter engine. `EarTimeApplication` creates one ingress worker, asynchronously.
The protected service still calls the same broker API with the same payloads.
The broker submits a bounded immutable snapshot to the worker; SQLite commit
completes before the original payload plus additive `journal` metadata is
published. Engine leases and rejection of obsolete sink attachments remain.

`eartime_observations.sqlite` is owned only by `ObservationJournal`; Flutter has
no direct writer to that file. The built-in `SQLiteOpenHelper` is used rather
than introducing Room/code generation or a second runtime database package.
This keeps transaction ownership explicit and adds no production dependency.
The pinned Robolectric 4.16.1 dependency is test-only (Apache-2.0), using Java 17
and modeled API 28/35. See [Robolectric setup](https://robolectric.org/getting-started/)
and [compatibility](https://robolectric.org/compatibility_table/).

The separate legacy Drift database is retained without schema changes or data
deletion. Its history/live pipeline is a compatibility path, not the new
canonical observation store. It now uses native observation IDs where supplied,
avoiding new same-millisecond/device row collisions. Legacy rows retain their
old IDs. Automatic journal-to-history reconciliation and a unified interval
projection are NOT delivered by this checkpoint; B02 remains open.

## Source and time contract

- A persistent random source UUID is stored in the native database.
- Observation UUIDs are allocated once at ingress; source sequences are assigned
  transactionally by SQLite. Identical wall milliseconds remain distinct.
- The input and its stable structured-JSON fingerprint are checked by ID inside
  the append transaction. An identical replay returns the existing row;
  conflicting reuse raises a consistency fault and retains a durable fault row.
- Each row records collector, process generation, collection epoch, boot count
  when available, payload version, UTC wall timestamp, receipt elapsed time,
  commit timestamp, provenance and confidence.
- Existing collector timestamps are wall-clock observations. New monotonic
  values describe BROKER RECEIPT, not a retroactively invented collector time.
- Every legacy event has UNKNOWN route-attribution confidence. A legacy MAC/name
  claim is not promoted to physical-device identity or confirmed output routing.
- Opening a new process on an existing journal records an explicit unobserved
  collection gap. It does not extend listening across that gap.

Typed native contracts distinguish random physical IDs, endpoint/transport,
profile, collection-scoped route ID, mutable observed/user names, alias evidence,
confidence, optional capability freshness and observation time. Exact endpoint
normalization rejects masked addresses. The pure route reducer never starts
listening from global or candidate playback. This reducer is contract groundwork;
the legacy collector and live pipeline have NOT been converted to it yet.

## Transactions, limits and recovery

SQLite uses FULL synchronization. ID check, row insert and sequence allocation
share a transaction. The injected pre-commit crash test verifies rollback of both
row and sequence. A second database connection verifies commit visibility before
publication. Source identity, rows and cursors survive closing/reopening the store.

Ingress holds at most 256 observations. After saturation, later offers are
rejected until earlier accepted observations drain; one ordered gap then records
the lost count and receipt bounds. There is no silent unbounded in-memory retry.
Writes yield after 32 entries. Read/RPC work has a separate 32-request executor
queue. Payloads are limited to 64 KiB, nesting to 12 and structure to 4096 nodes.
The inherited main-looper/volatile delivery cache remains unbounded in total,
with its existing 32-event flush batches. A finite eviction limit was rejected
during review because automatic canonical replay is not yet integrated: it
would leave the legacy UI history incomplete even though source rows survived.
Switch this cache to bounded journal cursors with the phase-4 consumer migration.
Do not claim that total application buffering is bounded at this checkpoint.

Read pages are bounded to 128 rows (UI requests 32), ordered by source sequence.
Cursor acknowledgements are monotonic, source-checked and cannot exceed a
committed sequence. Acknowledging does not delete source observations. The
diagnostics screen reads only and never acknowledges. Future consumers must
commit their own derived state before acknowledging.

Journal failures reach native logs, EventChannel errors and journal diagnostics.
Commit failures are not published as successful observations. A later successful
commit records the prior loss as a collection gap. Corruption and unsupported
schema upgrades/downgrades fail visibly while retaining the database; there is
no automatic destructive recovery. Disk exhaustion followed by immediate process
death cannot preserve an exact lost count: the next process records a conservative
gap. No implementation can claim a durable write while storage rejects it.

## Dart and product integration

`ObservationJournalClient` exposes bounded reads and source-aware acknowledgement
RPCs with five-second timeouts. Typed decoding rejects unsupported schemas,
payload versions, mixed sources, invalid cursors and unordered pages. Journal
replies from retired engines are ignored by their existing owner lease.

Settings -> Observation Journal shows committed counts, collection gaps,
conflicts, queue state, last failure, and paged observations. Empty/error/retry,
next/previous and refresh states are implemented. Large text at 360 px is tested.
The UI reports legacy attribution as unverified.

The legacy Dart reducer separately repairs three proven defects: B disconnect
clearing A; B inheriting A's playing flag; and A's two-second duplicate suppression
discarding B's playback. Repeated same-device connection retains its current
timer rather than preserving playing metadata with a missing start timestamp.
These fixes do not establish reliable Android route evidence.

## Verification

Initial baseline: 90 Flutter tests; 15 JVM tests. The three scoped-device tests
were executed before the repair and failed with the expected incorrect state.
The final scoped target also covers native-ID collisions and timer continuity.

The native suite has 46 passing tests: 15 inherited owner/buffer tests, seven
typed-contract tests, three queue/compatibility tests, 20 SQLite tests (ten at each of API 28
and 35), and one native ingress/reopen integration test. The future-schema
downgrade test verifies that incompatible existing data is retained. All new SQLite tests
exercise the production helper on a worker, not a handwritten mock repository.
Robolectric models Android; it is not physical service/process-kill evidence.

Commands and final artifact hashes/results are in `CODEX_RESUME.md`.
Inherited Flutter placeholder tests are explicitly excluded from meaningful
coverage claims: 14 empty tests in `pipeline_regression_test.dart` and the
`expect(true, true)` widget placeholder remain test debt.

## Next implementation boundary

Before switching Home/Timeline/Analytics to native state, implement versioned
normalization and transactional interval projections, including exact unions,
gaps, boot/clock changes and deterministic rebuild. Define an idempotent legacy
import/read-model policy first. Do not replay an arbitrary old journal page into
the current live reducer; it would resurrect stale connections and timers.

Physical G remains PENDING PHYSICAL VALIDATION. The service bytes and Git blob
remain identical to `0a8be43`; other application code has changed. Source equality
of one file is not evidence that the new whole application passes G. Preserve
the original checkpoint and collect the existing correlated startup markers at
the user's final physical acceptance stage. No A/B regression fix is claimed.
