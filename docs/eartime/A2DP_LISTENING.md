# Bluetooth A2DP Listening Attribution (projection v6)

2026-11-05. Product decision taken under the owner's "make it fully functional for production" instruction.

## Rule
A tracked Bluetooth Classic endpoint counts as **CONFIRMED listening** while, in the same
collector sample, all of these hold:

1. `BluetoothA2dp.isA2dpPlaying(device)` reports its A2DP stream active (`STREAMING_REPORTED`).
2. `AudioManager.isMusicActive` is true (`globalMusicActive`).
3. The endpoint already has its durable endpoint UUID (alias minted by an earlier sample).
4. The sample comes from the collector owner that holds the health record (same process generation,
   collection epoch, generation and continuity epoch) and that owner is `STARTING`, or `HEALTHY`
   inside its lease.

Why this is real output evidence: the platform starts the A2DP stream (AVDTP START) to a headset only
when audio is routed to it, and suspends it when output moves to the speaker or playback stops.
Music on the phone speaker with earbuds connected therefore does not count (A6). Requiring
`isMusicActive` filters out streams kept open only for notification or system sounds.

## Interval semantics
- Route key `<collectionEpoch>:a2dp:<address>`, device = the endpoint UUID.
- An interval opens at the first qualifying sample and is extended by each later qualifying sample.
- Pause, reroute or disconnect observed in a sample ends the interval at that sample (`stopped`, timeline `PAUSED`).
- Lost ownership, expired lease, `UNKNOWN` probe state or a collection gap ends it at the **last** proving sample
  (`attribution_lost`); missing time is never bridged.
- Reads extend an open A2DP interval to "now" for the live timer, capped at the last proving sample plus
  `CollectorHealth.MAX_LEASE_MS` (15 s).
- The projection is rebuilt from the journal on upgrade (v5 to v6), so A2DP samples already journaled
  by earlier builds are attributed retroactively under the same rule.

## Still not covered
- Generic cross-app output for wired, USB and LE Audio routes (A1 remains BLOCKED_BY_PLATFORM for those).
- Sampling granularity: callbacks trigger a sample within ~250 ms, plus a 10 s poll, so starts and stops
  are accurate to roughly one sample.
- Physical acceptance on the CPH2447 + Nord Buds 3 Pro is pending.

Tests: `A2dpListeningTest` (11 cases x API 28/35).
