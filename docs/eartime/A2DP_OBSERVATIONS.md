# Public A2DP Stream Observations

2026-10-24. Implemented passive native acquisition, not completed listening
attribution/live accounting. Current production confirmed duration still excludes
these candidate samples. No service-file edits, routing writes, pairing, GATT,
reflection, codec changes or vendor commands. Physical behavior remains pending.

## Supported Evidence

Android's public BluetoothA2dp.isA2dpPlaying queries a specific remote device's
transport streaming state. That is different from connected inventory, global
music activity, communication routing or a predicted media route. AOSP consults
the per-device A2DP state machine. Its public client and service can also return
false on unavailable/error paths, so false is deliberately not proven silence,
a known pause, a confirmed disconnection or a healthy observation lease.

Sources:
- [Public BluetoothA2dp API](https://developer.android.com/reference/android/bluetooth/BluetoothA2dp#isA2dpPlaying(android.bluetooth.BluetoothDevice))
- [Public proxy lifecycle/main-looper callbacks](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#getProfileProxy(android.content.Context,%20android.bluetooth.BluetoothProfile.ServiceListener,%20int))
- [AOSP client fallback](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/framework/java/android/bluetooth/BluetoothA2dp.java)
- [AOSP per-device service query](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/android/app/src/com/android/bluetooth/a2dp/A2dpService.java)

## Integrated Producer

AndroidAudioObservationBackend now owns AndroidA2dpProfileConnector and
A2dpStreamProbe alongside its existing AudioManager registration. All API
registration, connected-device queries and streaming reads occur on the existing
observer worker. Broadcasts only request a rate-limited fresh query: extras are
not accepted as current route state. Public profile callbacks on the Android
main looper only exchange guarded references and request sampling. Late proxy
closure is dispatched to one bounded cleanup worker, never queried on main.

OUTPUT_EVIDENCE contains an `a2dpTransport` contract: probe owner UUID/request
generation, API source, captured wall/elapsed clocks, normalized endpoint address,
per-device observed clocks and STREAMING_REPORTED or
NOT_STREAMING_OR_API_UNAVAILABLE. A positive candidate requires a valid endpoint
and connected-state reports both before and after the streaming query. Duplicate
endpoints, excessive inventory, clock/deadline/owner loss or permission/query
failure discard candidates. Empty lists retain their API-failure ambiguity.

The existing native ingress snapshots and commits these samples before hint
publication. Nested addresses are private native observations and included in
explicit private journal exports, never public repository fixtures. No raw
address is promoted to a physical UUID, no global boolean proves a route, and
no new timer/reducer/database or profile-specific CONFIRMED publisher exists.
Both confidence and liveListeningEligible remain UNKNOWN/false. Inventory health
still has inventory/global-activity scope, not A2DP route-health scope.

## Ownership And Bounds

One request per probe generation; one proxy identity is expected from the public
request. Reconnect retains that proxy but does not assert duration continuity.
Retired/refused-generation/unexpected-handle callbacks cannot resurrect a source.
Pending proxy reservations are capped at eight per process; cleanup has one
worker/eight queued tasks. Successful disposal releases the reservation. An
unresolved request exception or failed cleanup conservatively retains it rather
than repeatedly allocating unknown handles. If callbacks never resolve, capacity
may remain unavailable until process restart; this is an explicit limitation,
not a successful recovery claim. Refused requests back off for 30 seconds.

At most 16 endpoints and a one-second capture window. Existing callback sample
coalescing/rate limit and ten-second worker poll remain. The sample carries
captured clocks, not a receipt-time rewrite of delayed broadcast state. No hard
Binder deadline/cancellation is claimed. Profile/service/OEM latency, silent
stream semantics, screen-off behavior, battery and actual G remain unvalidated.

## Automated Evidence And Next Work

14 native probe cases cover positive/false/empty data, fresh query after delayed
hint, two-device separation, invalid/masked identity, permission loss, late
callbacks, exactly-once off-callback cleanup, reconnect, refused-request backoff,
bounded pending pressure, slow/clock/owner loss, replacement/refused generations
and duplicate endpoints. API 24/28/35 backend tests verify actual producer wiring
and UNKNOWN eligibility. An API 28 ingress case verifies durable nested candidate
payloads with no confirmed listening or implicit physical identity. Existing
blocked-worker tests continue to prove nonblocking start/close software behavior.

Next: durable endpoint/physical-ID association and reversible aliases; normalize
sample/transition timestamps and failures; prove route-specific continuity and
expiry, profile-loss and restore/replay fencing; integrate the same canonical
projection with honest current/unknown UI. Do not enable live time merely because
a raw positive sample exists. LE/SCO/wired/USB/owned-player attribution remain
separate capabilities. No feature row is marked complete by this producer alone.
