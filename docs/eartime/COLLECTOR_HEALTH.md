# Collector Health And Output Evidence

2026-10-24. Contract implementation; hardware acceptance PHYSICAL_PENDING.

## Durable Health Contract

`COLLECTOR_STATUS` from `supported_audio_observer` folds into the existing
listening projection in the same transaction as its journal observation. It is
not a second event store or a Dart timer. Contract version 1 distinguishes
NOT_STARTED, STARTING, HEALTHY, TEMPORARILY_UNAVAILABLE, PERMISSION_BLOCKED,
SUSPENDED, STOPPED, UNKNOWN and CONTINUITY_LOST.

A collector owner has a monotonically increasing generation within the process,
a new continuity epoch per generation, the journal process/collection epoch,
boot identity and captured wall/elapsed timestamps. Only STARTING can establish
an owner; retired-generation callbacks cannot revoke or renew a newer one.
HEALTHY requires successful initialization/sample evidence, registered inventory
observation and activity-observation readiness. A bounded lease is at most 15s.
Renewal after expiry is rejected; a new generation/epoch must acknowledge fresh
initialization. Stops, gaps and clock discontinuities revoke eligibility.

Snapshot expiry is read-only, derived using a current comparable boot/monotonic
clock; the next expired renewal records lost continuity durably. Without a
current clock, HEALTHY becomes UNKNOWN. Journal reopen/rebuild, duplicate IDs
and rollback retain the same recorded health evidence. Process restart journals
a gap before new publication. The health-query clock is deliberately separate
from the projection's gated live-extrapolation clock.

The scope is explicitly `inventory_and_global_activity`, never actual output or
continuous listening. `liveListeningEligible` is always false. No lease in this
contract enables confirmed playback accounting, reminders or Dart ticking.
The protected legacy collector does not emit health acknowledgments. A runtime
observer requires separately tested ownership/cleanup integration.

## Supported API Boundaries

- `AudioManager.getDevices` is connected inventory; `getCommunicationDevice`
  describes communication use. Neither establishes another player's media output.
  API 33 `getAudioDevicesForAttributes` predicts devices for a hypothetical track;
  concurrent/player-specific routing can differ. See the official
  [AudioManager reference](https://developer.android.com/reference/android/media/AudioManager).
- `AudioPlaybackConfiguration.getAudioDeviceInfo` was deprecated in API 36;
  its documentation says the information was never populated. Do not build a
  cross-app route collector on it. See the official
  [playback configuration reference](https://developer.android.com/reference/android/media/AudioPlaybackConfiguration#getAudioDeviceInfo()).
- `AudioRouting.getRoutedDevice` identifies the route of that AudioTrack/AudioRecord
  while playing, not arbitrary other applications. Preferred devices are not
  actual routing. See the official
  [AudioRouting reference](https://developer.android.com/reference/android/media/AudioRouting#getRoutedDevice()).

`OutputAttribution` therefore rejects inventory/global activity, communication
and predicted-policy inputs. The pure policy permits confirmation only for a
current, app-owned playing media object with a matching external route/device,
owner generation, epoch, boot and fresh timestamp. No current EarTime runtime
collector supplies such an owned-player input. This policy is not evidence of
Spotify/other-player attribution support. No hidden APIs, permissions bypass,
audio capture or vendor writes were added.

## Automated Evidence And Limits

`CollectorHealthTest` models initialization, stale callbacks, expiry, failed
registration, oversized leases, permission/suspension/stopping, clock/boot changes,
new generations, duplicate/rollback/reopen/rebuild and process gaps on API 28/35.
`OutputAttributionTest` has 16 labeled synthetic policy cases covering speaker,
earbuds, disconnect, multiple devices, switches, SCO coexistence, LE, wired/USB,
pause, unknown, restart, Flutter reopen and delayed route callbacks. These are
policy checks, not complete real-platform route-transition integration tests.
Flutter decoding/status tests keep old snapshots compatible and reject unsafe
health-version/scope/eligibility claims. Full gates are in `TEST_RESULTS.md`.
