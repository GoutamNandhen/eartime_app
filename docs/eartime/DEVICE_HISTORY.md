# Device-Scoped Listening History

2026-10-24. Native query integration; physical route validation remains pending.

Devices -> details -> Device history, and Analytics -> device totals, open the
existing Timeline workspace with a recorded device UUID. Date ranges and
100-interval paging retain that scope. There is no second history reducer, Dart
duration summation or independent live clock.

The optional deviceId passes through the MethodChannel, native runtime and
journal to ListeningProjection. SQL filters before paging or aggregation, not
after reading one global page. The same clipping, interval union, daily/hourly
buckets and per-device totals apply. Overlapping routes of one identity count
once; other identities and unattributed global playback do not leak in. Global
queries/widgets are unchanged. Personal global-goal reports are disabled for a
device-only query rather than being mislabeled as device goals.

Derived projection version 5 adds a device/window index. Versions 2/3/4 replay
from unchanged source schema 3, retaining source IDs, raw observations, immutable
endpoint associations and consumer acknowledgments. Future versions still fail
closed. Unknown UUIDs return empty scoped results, never global fallback. Invalid
UUIDs are rejected. Flutter checks echoed scope and all returned interval/device/
per-device IDs; provider cache identity includes the device UUID.

This view follows the identity recorded on each interval. Reversible endpoint
association does not rewrite old history. No history is assigned using names,
timing or a connected/global-playback assumption. An empty endpoint history is
not evidence that no physical listening happened. The current real collector
still lacks a confirmed route-duration producer; nonzero confirmed fixtures are
synthetic software evidence only.

Four API 28/35 native cases cover device union/clipping/reconciliation, exclusion
of global activity, 105 scoped intervals interleaved with another device, replay/
reopen, invalid/unknown IDs and v4-index migration with retained raw rows/cursors.
Five Flutter cases exercise channel scope validation/provider identity and the
actual Devices-details-history-navigation/paging/date-control path at normal and
double text size, plus display-name cancel/save/error/owner recreation. Full gate
counts are recorded in TEST_RESULTS.md. B3 is software-complete; physical-device
identity/route attribution are separate unresolved requirements, not renamed
or silently satisfied by an editable display name.
