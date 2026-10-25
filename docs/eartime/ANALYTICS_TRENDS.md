# Recorded Daily And Hourly Trends

2026-10-25. Native source/cache versions remain 3/5. No collector change.

Analytics now presents canonical daily/hour-of-day buckets through one integrated
trend view. Segmented modes, 14-bucket pages, explicit missing records, localized
dates and 12/24-hour labels replace a positive-only hourly list. All day buckets
remain available, including no-duration records; unverified daily duration stays
separate. Legacy snapshots missing hourly data show unavailable, not 24 fake zeros.
Window/source keys reset selection state and bucket paging; page bounds clamp when
a refreshed dataset shrinks. Display normalization uses the maximum native bucket
across the selected period, not page-local totals or a second duration reducer.

Hour-of-day totals combine the selected calendar period. Native DST-aware buckets
and interval unions remain authoritative; no unobserved time, gap, connection or
unverified playback becomes confirmed listening. Explicit hourly payloads must
contain exactly 24 ordered unique hours and reconcile with the native period total.
Malformed duplicates, missing/empty sets, reordering or incorrect sums are rejected.
Absent hourly fields remain backward-compatible, explicitly unavailable in charts.

## Accessibility Evidence

One semantic container exposes each date/hour, confirmed duration and available
unverified duration. Decorative normalized progress bars are excluded from that
semantic subtree; they are not independent accounting values or misleading progress
percentages. The original hourly progress value used a duration string, which
Flutter's progress semantics requires to be numeric. Two actual Analytics tests
reproduced that failure before replacement. A strict malformed-hourly test also
failed before decoder correction.

Eight new Flutter cases cover actual Analytics navigation at 1x/3x, 30-day paging,
zero/unverified states, raw bar values, mode/page reset, legacy absence, exact
semantic duration, keyboard activation, and both real app themes at 1x/3x. Labeled
tap targets, Android minimum target size and text-contrast guidelines are executed.
The selected light-theme control initially failed contrast (3.08 versus 4.5).
Explicit theme primary/on-primary styling fixes it without changing global theme.
Tooltip-wrapper and semantics-handle cleanup fixture corrections retain every
behavior assertion. Physical TalkBack/OEM/font rendering remains PHYSICAL_PENDING.

Full actual gates: 244 Flutter /458 native in 32 suites (native task explicitly
rerun), zero failures/errors/skips, analyzer clean, both Kotlin variants/debug APK
pass. E3/E13 software complete; 44/119 features implemented, not release ready.
