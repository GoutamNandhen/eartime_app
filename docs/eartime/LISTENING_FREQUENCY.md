# Recorded Listening Frequency

2026-10-26. WIP shutdown save; query-only frequency contract 1;
source schema 3/cache 5 unchanged. E7 remains IN_PROGRESS pending final feature
acceptance review. The user has paused further implementation.

## Counting Contract

Frequency is the number of **measured confirmed canonical session groups whose
original captured opening falls inside the selected window**. It is a recorded
lower bound, not complete real-world usage. Zero-duration/unknown observations,
unverified global activity and speaker activity do not qualify. A session already
open before the window contributes duration when measured but no new start.
Repeated starts/duplicates/later SYNC never move the original T1 to a later S.

The existing native session grouper remains authoritative. Overlapping routes in
the same evidenced domain can form one group; per-device counts are scoped and
must not be added to recreate global frequency. Pause/resume and uncertainty
boundaries retain distinct observed groups. Clock rollback can produce distinct
source starts at the same wall timestamp; do not deduplicate by display time.

Native frequency is independent of visible session pagination. Original starts
are filtered to [from, until), sorted once, then assigned to daily calendar bounds
with one forward cursor and to native local-hour buckets. This is not N-times-day
rescanning. Midnight does not invent a start; repeated DST hours share the same
local-hour bucket while retaining distinct measured source starts.

## Integrated Presentation

The existing native snapshot includes frequencyContractVersion 1 and
measuredSessionStarts globally and per day/hour. Flutter validates supported
version, required measured-session metadata, nonnegative counts, bounds and day/
hour reconciliation. Legacy metadata without frequency remains unavailable, not
zero. Analytics and Wellbeing display native starts; existing trend semantic rows
and daily/hourly values include available native counts. No Dart timer, new writer,
collection lease, attribution upgrade or proprietary device operation is added.

## Evidence In Progress

Five native tests (ten API 28/35 executions) and three Flutter tests were RED on
the missing implementation. Focused all-projection tests and Flutter frequency/
trend tests subsequently pass. Coverage includes original/clipped T1 vs later
sample/SYNC, UUID duplicate, unverified/speaker/zero points, overlap/per-device
scope, gap/clock rollback, midnight/repeated DST hour, pagination and replay/
reopen; malformed contracts and actual Analytics/Wellbeing/trend presentation.
Complete actual gates passed: 247 Flutter tests, analyzer clean, 468 native tests
in 32 suites with zero failures/errors/skips, debug/release Kotlin and debug APK.
The final native rerun compiled the last SYNC assertion. Final feature acceptance
review/documentation remains unfinished; passing gates do not promote E7 alone.
Synthetic confirmed observations are software proof only: there is still no real
cross-app confirmed-route producer or physical G/telemetry/release validation.
