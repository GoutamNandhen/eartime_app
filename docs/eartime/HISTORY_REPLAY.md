# History Replay And Owner-Stop Continuity

2026-10-24. Native journal schema 3; disposable listening projection version 3.

## Proven Stop Mechanism

On the published observer checkpoint `53277be`, health STOPPED did not close
listening routes. New API 28/35 regressions failed before the reducer edit:
an opening at T1=1000, SYNC=5000 and service stop=9000 remained open, so a later
SYNC could bridge known downtime. This is separate from the unproven physical G
splash regression.

A valid current-owner `STOPPED` with reason `observer_owner_stopped` now closes
routes at their last durable evidence (5000), never at the stop clock (9000).
A later SYNC=12000 and pause=16000 yields 4000+4000=8000 of unverified activity,
not 15000. Confirmed time stays zero for the legacy collector. Retired-generation
and repeated stops cannot close newer work or multiply gap counts. Ordinary
observer sampling failure is not proof that legacy callbacks stopped, so it
does not assert a service stop. Terminal stop requires owner identity, not a
healthy lease; it never grants playback duration or health without boot proof.

The projection's gap count includes known owner-stop transitions. Raw journal
stats count `COLLECTION_GAP` rows only; the counts have different scopes.

## Cache Upgrade And Cancellation

Projection version 2 caches are automatically cleared/replayed as version 3 on
the journal worker. Only disposable interval/device/state tables are cleared in
a transaction. Raw rows, observation IDs, source identity, consumer cursors and
legacy Drift data are retained. Unknown future projection versions refuse
access without deleting caches or source data. No SQLite source-layout migration
or destructive user-data migration is needed.

`rebuildListeningProjection(cancelled)` checks cancellation before resetting a
cache and before each 128-row replay transaction. Cancellation raises an explicit
error, preserving the last fully committed projection cursor. Reopen/next read
finishes replay before returning totals; partial aggregates are never returned
as complete. This is an internal rebuild cancellation boundary, not a new
Flutter RPC cancellation feature or a claim that normal startup replay yields
fairly to queued work. Production scheduling/cancellation integration remains open.

## Executed Synthetic Load

`ListeningHistoryLoadTest` (API 28) covers:

- 1200 confirmed synthetic sessions / 2400 observations; full union totals,
  longest/average/frequency, all 12 pages, no duplicate IDs or truncated totals.
- Cancellation after three committed batches (cursor 384), source/ack retention,
  process-owner reopen and exact full snapshot parity; pre-cancellation is a no-op.
- Observation insertion between known-device pages, explicit source sequence
  change and complete restart of a 206-device scan. Offset pages remain live:
  insertion can reorder them; a frozen multi-page view is not implemented.
- Version 2 stale-cache correction of owner-stop history and refusal of future
  cache version 99, preserving original source rows and consumer acknowledgment.

Focused run: seed 9071ms, total 9945ms, SQLite file 1466368 bytes for 1200 sessions.
These are one Windows/Robolectric model run, not phone latency, battery or a
performance SLA. Hardware profiling, longer histories, cooperative startup
fairness and cross-layer cancellation remain required. Full gates are recorded
in `TEST_RESULTS.md` and the implementation ledger.
