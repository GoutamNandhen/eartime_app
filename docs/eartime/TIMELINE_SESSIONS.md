# Canonical Recorded Sessions

2026-10-25. Query contract 1 extends the existing native projection. Raw journal
schema 3 and disposable projection 5 are unchanged. No collector, observation,
duration writer, confidence promotion or Dart accounting clock was added.

## Definition

A recorded listening session is a continuous union of overlapping measured
segments with the same attribution and comparable captured clock domain. A pause
ends a session unless another overlapping segment maintains observed playback.
Resume starts a new session. Merely touching intervals are not automatically
joined. Zero-duration observations remain separate, unmeasured sessions.

Grouping requires the same collection epoch and non-null boot/monotonic anchor;
anchor disagreement beyond the projection's 2000ms tolerance prevents joining.
Explicit journal gaps/unsupported payloads and uncertain interval-close sequences
fence groups. Lost-continuity segments are isolated conservatively. No distance or
arbitrary silence threshold joins disjoint playback. Missing observations never
establish a break, idle duration or a new confirmed route.

Sessions sort by their first source sequence, descending. This preserves capture
order when wall clocks move backward. IDs derive from the original first interval,
not a Flutter SYNC timestamp. Reopen/rebuild does not replace these openings.
Dates and durations are clipped to the selected native window before grouping.
Both timestamps, local UTC offset, clipped/incomplete status, contributor and
device counts are visible. Unverified sessions remain separate from confirmed
listening. Open sessions end at durable evidence, not the display clock.

## Accounting And Paging

Within a group every added measured segment overlaps its continuous union, so
duration is exactly its clipped union, not the sum of overlapping routes. The
native longest/average recorded-session metrics exclude unmeasured points and
unverified playback. Original continuous-run metrics remain available separately.

Period totals still use the established global calendar union. Sessions from
different epochs, clock discontinuities or conservative uncertainty boundaries
can overlap on that calendar; their displayed durations must NOT simply be added
as a replacement total. Home, Analytics, widgets and reports retain that source.
The UI discloses overlapping-session union and recorded lower bounds.

Session pages and separately queried contributor pages each contain at most 100
rows. Device filtering is applied in SQLite before grouping. Details retain the
same window/device scope and use the existing worker, cancellation, timeout and
foreground-refresh ownership. Missing/changed IDs fail instead of returning an
unrelated session. Observed pause, disconnect, non-external-output transition,
last evidence and continuity loss are distinguished using raw close observations.
Connection-only events are NOT yet a complete event timeline (D5 remains open).

Grouping sorts bounded window data; maintained endpoints avoid a quadratic scan
of overlapping contributors. Existing 100000-interval work limit remains explicit;
gap boundary results are separately capped at 100000. Over-limit queries fail,
never silently truncate accounting. Live offset pages are not a frozen multi-page
snapshot, and no phone performance/energy SLA is claimed. D11 remains partial.

## Executed Evidence

Starting checkpoint revalidated: 217 Flutter / 366 native, analyzer clean, both
Kotlin variants/debug APK pass. Six new API 28/35 RED executions reproduced absent
session output before implementation. Five native cases (10 executions) now cover
overlap/multiple devices, pause/resume, explicit gaps/clock rollback, unverified/
open points, means, 105 sessions/105 contributors, scope rejection, transitions,
clipping and source-preserving reopen/replay. Existing B02/migration/load tests
remain in the full gate. All data is synthetic/Robolectric, not physical evidence.

Five Flutter cases cover strict metadata/detail pages, missing identity rejection,
actual Timeline -> details/back/paging at 1x/3x with both pause contributors.
Initial tests reproduced the absent screen. Later fixture fixes await scrolled
layout, target lazy-list items independently and distinguish retained parent-route
refresh calls; no assertions or production duration logic were suppressed.
One analyzer block-style finding was corrected without an ignore.

D1/D2/D3/E5/E6 software acceptance is complete. D5/D6/D11 and H5 retain their
remaining connection/identity/telemetry/performance gates. Actual output attribution,
live leases, physical G, OEM clock/lifecycle acceptance and release certification
remain pending or platform-blocked as documented elsewhere.
