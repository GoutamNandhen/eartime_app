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
The legacy playback callbacks do not emit health acknowledgments. The separately
owned runtime observer now supplies them; its health never asserts that legacy
callback initialization succeeded or that another player uses an external output.

## Runtime Ownership

`SupportedAudioObserver` is owned by the foreground service, independent of
Flutter/Activity lifetimes. Registration, sampling and cleanup run on its own
HandlerThread. Four added service lines hold/start/close it; existing collector
logic is unchanged. Recoverable source-equal checkpoint: `9fd94b5`. The strict
`tools/check_collector_baseline.ps1 -AllowObserverLifecycleHooks` guard verifies
that no other collector lines changed. Source equality is explicitly FALSE.

The public API adapter records at most 128 connected routes and 128 predicted
routes per sample, global activity, and separately labeled communication/policy
information. Platform route IDs are epoch-scoped, not physical identities. No
names/MACs are merged or promoted. API 24/25 activity uses polling; API 26+ adds
a playback callback. Callback payloads are not retrospective route evidence:
the worker reads current state again. Actual output remains UNKNOWN.

Polls are 10s, leases at most 15s. Callback storms coalesce and cannot cause more
than one sample/second or more than one outstanding health acknowledgment.
Acknowledgment follows commit and checks the projected generation/epoch/state
using the current clock. Queue loss, rejection, expiry or clock discontinuity
requires fresh initialization. Commit rejection backs off 10s; API failure or
permission denial backs off 30s. Partial registration cleans up; failed cleanup
stops retries rather than silently accumulating listener owners. Stop is
idempotent/asynchronous; immediate restart can create a fresh owner.

All samples use the same ingress/process/boot epoch and store captured elapsed
time plus API-sample provenance, not later publication time. Health and evidence
rows never create listening intervals. Long-run storage/energy profiling remains
open: even unchanged successful lease renewals add durable rows. No hardware
timing, foreground-service/OEM behavior or physical G PASS is claimed.

Handler/backend/owner setup runs from `onLooperPrepared`. The service constructor
and close path never call `getLooper` or join the worker: Android documents that
[getLooper can block during initialization](https://developer.android.com/reference/android/os/HandlerThread#getLooper()).
Worker lifecycle tests hold initialization behind a latch and prove start/close
return before it is released, with no post-close registration and exactly-once
cleanup. These API 28/35 models do not validate OEM startup/splash behavior.

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

`AudioObserverOwnerTest`: 10 cases, including 500 replacements, 1000 same-clock
callbacks, failed initialization/sampling, denial, commit rejection, delayed ack,
clock/lease loss, cleanup uncertainty and capture deadlines. Adapter models pass
on API 24/28/35. Ingress integration verifies durable scoped acknowledgments,
UNKNOWN confidence and source/provenance. Flutter decodes the new hint types
without turning global activity into legacy playback or physical-device claims.

Projection v3 additionally consumes a valid current-owner stop as a listening
continuity boundary, closing at last evidence rather than the stop clock.
Retired/duplicate stops are fenced; v2 caches replay without raw data deletion.
See `HISTORY_REPLAY.md`. Collector health tests now total 20 API 28/35 cases.
