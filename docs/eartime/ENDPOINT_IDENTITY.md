# Durable Endpoint Associations

2026-10-24. Software evidence, not physical-device or output-route validation.

## Production Path

The existing passive A2DP sample now captures bounded display names and a
connection report before/after its query. Valid same-capture Classic endpoints
receive random device and alias UUIDs. The source observation, association
observation and projection checkpoint commit in one journal transaction, before
publication. A duplicate observation does not mint another ID. Names are never
matching keys; distinct endpoints with identical names remain distinct.

Only supported-source/version samples with a valid owner/request generation,
normalized non-masked endpoint, explicit connection evidence and bounded captured
wall/monotonic age qualify. Unknown boot identity does not prevent storing a
transport association, but cannot establish playback continuity. Old samples
without these fields are not retroactively promoted.

Associations are raw ENDPOINT_IDENTITY journal observations, not another source
database. Derived projection version 4 adds an indexed disposable alias cache;
v2/v3 caches replay, source schema stays 3. Reopening, rebuilding and native
archive restore retain the exact UUIDs. Future cache versions still fail closed.
The later device-history query uses derived version 5, preserving these same
source associations and adding a device/window lookup index; see DEVICE_HISTORY.md.

## Explicit Changes

Devices expose a paged association screen with endpoint suffixes, independently
paged identity candidates, explicit confirmation and reset to the immutable
original association. Commands require current engine ownership, journal source
identity and the expected alias revision. Ownership is checked again when queued
work executes. A stale edit cannot overwrite a newer association.

A user association affects subsequent endpoint observations, not earlier device
history. Affected route intervals close at their last durable evidence; unrelated
routes and the legacy B02 T1 opening are preserved. Reset is another auditable
observation. Display-name overrides remain separate and persist across reconnect,
process recreation and projection replay.

No association is hardware-verified, including user-confirmed associations.
Classic endpoint reuse, address changes, LE identity, wired/USB identity and
physical cross-profile matching remain unresolved. Legacy provisional records
are retained separately; record counts are not physical-device counts.

## Uncertainty And Evidence

Empty/failed samples, collection gaps and incomplete synchronization produce
connection UNKNOWN, not a fabricated disconnection. Screens/widgets show last
observed connection wording; there is no live connection freshness guarantee.
Raw A2DP streaming candidates still cannot grant CONFIRMED duration, route
continuity, wearing/battery telemetry or a live ticking timer.

EndpointIdentityTest runs on API 28/35: atomic rollback, duplicate IDs, reconnect/
rename/reopen, same-name isolation, invalid/stale evidence, nullable boot identity,
assignment/reset/conflicts, B02 preservation, v3-cache migration, archive roundtrip,
105-candidate paging and device-scoped route closure. Native ingress tests cover
retired queued command ownership; widget tests cover unknown connection states.
Six Flutter tests cover strict channel decoding, confirmation/revision arguments,
cancel/assignment/reset/conflict, candidate paging and double-text-scale layout.
These fixtures are synthetic. No device interaction or physical G test occurred.

Initial validation exposed unformatted code/lints, scroll-frame assumptions in
the large-font test and a Windows Robolectric database-path failure. Lints were
fixed without suppression; scroll tests await layout and use real hit-tested
controls; fixture database names follow existing short-name conventions. The
screen uses full-width endpoint labels with separate controls for large text.
