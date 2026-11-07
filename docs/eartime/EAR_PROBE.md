# Ear Detection Probe (B8/B9 research)

2026-11-07. Research tool, not a feature completion.

Goal: find out whether OnePlus Nord Buds 3 Pro (or other buds) expose per-bud
in-ear state through any passive channel, so that per-ear wearing time (B9) can be built.
Android has no public per-ear API, and A2DP is one stereo stream, so per-ear *audio*
time is not measurable. Per-ear *wearing* time is possible only if the buds publish wear state.

Settings > Ear detection probe. User-started, at most 5 minutes (default 3). While running it records value
changes from:
- BLE advertisements at RSSI >= -75 (manufacturer and service data), needs BLUETOOTH_SCAN
  (neverForLocation, Android 12+);
- public broadcasts: A2DP playing/connection state, ACL connect/disconnect, platform battery level,
  HFP vendor-specific AT events (company IDs 0-2047);
- AudioManager.isMusicActive (auto-pause on removal);
- bonded audio devices' names and classic SDP service UUIDs.

The user taps guided marks (Left out, Left in, Right out, ...). EarProbe.analyse scores each
(device, field) by how many marks it explains and how many of its changes fall within 6 s after a mark.

Never connects, pairs, reads, subscribes or writes. Addresses are replaced by per-session salted
SHA-256 codes; nothing is journaled; the report leaves the app only through the user's Copy report.
Tests: EarProbeAnalysisTest (scoring/diff), ear_probe_test.dart (guided flow, permission denial).
Physical result: PENDING.
