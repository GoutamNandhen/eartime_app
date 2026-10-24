# Generic Cross-App Output Limit

Verified against public Android documentation on 2026-10-24. This is a platform
boundary, not a claim that all Bluetooth evidence or future APIs are impossible.

- AudioPlaybackConfiguration.getAudioDeviceInfo was added in API 31 and is
  deprecated in API 36. Android explicitly documents that its device information
  was never populated. It is not an available general cross-app output producer.
  [Official configuration reference](https://developer.android.com/reference/android/media/AudioPlaybackConfiguration#getAudioDeviceInfo()).
- AudioManager.getActivePlaybackConfigurations exposes playback configurations,
  not a substitute populated output-device field. getAudioDevicesForAttributes
  describes anticipated routing for attributes; routing may change independently.
  [Official AudioManager reference](https://developer.android.com/reference/android/media/AudioManager#getAudioDevicesForAttributes(android.media.AudioAttributes)).
- AudioRouting.getRoutedDevice/getRoutedDevices describe the particular playing
  AudioTrack/AudioRecord object. EarTime does not own other apps' player objects.
  A preferred device is not guaranteed to be the actual route.
  [Official routing reference](https://developer.android.com/reference/android/media/AudioRouting#getRoutedDevice()).

Engineering conclusion: A1's full generic third-party playback duration across
Classic/LE/wired/USB/speaker output cannot currently meet the approved proof
requirement with EarTime's ordinary-app supported APIs. A1 is BLOCKED_BY_PLATFORM,
not implemented. The canonical journal/accounting implementation remains real;
synthetic confirmed intervals do not resolve its missing production evidence.

Public per-device A2DP streaming samples are a narrower, real candidate source
and remain under development (A7). This limitation does not forbid that work or
independent product, data, wellbeing and release hardening. See A2DP_OBSERVATIONS.md.
Physical validation can test supported candidates and OEM behavior, but cannot
turn the documented unpopulated configuration field into a generic route API.

Do not use global activity plus connected inventory, communication/SCO routing,
predictions or an empty/failing query as confirmed listening. Do not use hidden
APIs, privileged permission workarounds, root or unrelated capture/accessibility
permissions to hide this limitation. A valid approved cooperative/per-output
source would require fresh technical evidence and scoped acceptance before this
blocker can be removed. Live extrapolation and live-dependent reminders remain
gated; no listening is fabricated across unknown collection intervals.
