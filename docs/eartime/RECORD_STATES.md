# Recorded History States

2026-10-25. E12 covers product record/uncertainty/error presentation, not proof of
physical audio output, complete observation coverage or a live listening lease.

Home, Timeline, Analytics and Wellbeing distinguish an empty selected history,
unverified-only playback, zero-duration observations and confirmed recorded
intervals. Missing duration is displayed as `None recorded`, never as proof of
zero actual listening. Numerical native totals are unchanged. Positive durations
remain canonical native unions; no Dart duration reducer, extrapolation, new
writer, lease or source-confidence promotion is introduced. Inventory keeps its
separate device/connection state presentation.

Every duration view identifies recorded totals as lower bounds with unknown time
excluded. Native gap/error/pending/failed metadata adds an explicit incomplete
coverage notice. These are conservative source-wide diagnostics, not a new claim
that observation coverage is complete elsewhere. Query errors remain unavailable;
they never become an empty snapshot, fabricated zero or retained success total.
Manual retry queries the same canonical source. Live eligibility stays gated.

Strict decoding rejects negative loss/pending/failure counters, run counts and
longest/average/day/hour/device durations, invalid hour indices, and an interval
duration greater than its actual span. Corrupt metadata is an error, not silently
clamped into valid-looking statistics. Existing supported snapshot versions are
retained. An explicit record-state enum classifies native metadata for display;
it does not calculate listening time.

Two initial RED tests reproduced negative gap acceptance and missing Home empty
state. Broader tests then exposed competing default Riverpod provider retries:
native read failures caused stream-owner replacement/backoff timers alongside the
existing coalesced foreground refresh loop. The isolated provider now disables
only framework retries; error publication, bounded polling, manual retry, event
hints, foreground recovery and disposal remain active. Other providers and native
collector lifecycle are unchanged. This is not an error suppression.
[Riverpod per-provider retry contract](https://riverpod.dev/docs/concepts2/retry).

The zero-duration interval label initially exhausted ListTile trailing width at
3x text. Its duration now flows below interval details without font clamping.
Actual-shaped native daily buckets also reproduced a remaining numeric-zero cell
on unverified-only days. Daily/device detail durations now use the same recorded-
only wording, and daily labels flow below the date rather than consuming trailing
width. The fixtures retain these buckets instead of omitting the failing path.
The repeated failing render run was interrupted, the layout fixed and the same
assertions rerun. A lifecycle fixture initially skipped required intermediate
states; it was corrected to inactive/hidden/paused and the reverse sequence, not
by changing production lifecycle or suppressing framework assertions. Four new
analyzer findings were corrected with blocks, not ignored.

31 Flutter cases cover malformed metadata, 28 actual view/state combinations at
360px/3x, native error/corruption retry, unknown duration, retained numeric totals,
single foreground refresh ownership, paused inactivity and cancellation on
disposal. The previous shared-view zero assertion now explicitly requires `None
recorded`; its positive-duration/native-source checks remain intact. Two API 28/35
native executions independently verify distinct empty/open/unverified/gap states,
nonnegative zero metrics, no confirmed promotion and SQLite reopen/replay parity.
Two further API 28/35 RED executions proved a native average bug: one measured
4000ms run plus an unmeasured open observation returned 2000ms. Aggregate run
spans now exclude zero lengths, matching the existing positive run-count rule.
Raw and displayed interval rows, including the open zero-duration observation,
remain intact. No source/cache migration or route attribution promotion is needed.
No physical G, output attribution, acoustic exposure or release claim follows.

Final gates: 217 Flutter / 366 native in 28 suites, no failures/errors/skips,
clean analyzer, debug/release Kotlin and final debug packaging. APK metadata is
1.1.0-dev.1/build 2, debuggable; artifact is ignored, not installed/published.
Protected comparison still permits exactly the four prior lifecycle additions;
no service-file change in this phase. Approved 119 IDs/titles were compared with
2d7195524a4de4bda28d2ea8d3ca083b1d137a5f without deletion or renaming.
