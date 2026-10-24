# Native Flutter Contract

Updated 2026-10-24. Channels are `com.eartime.app/tracking` and
`com.eartime.app/tracking_events`.

## Committed Events

The protected service sends root-level `connectedDevices` / `isPlaying` in
`SYNC_STATE`; Dart also accepts the historical nested `device` shape. A SYNC is
an observation, not an instruction to replace a durable opening timestamp.
`DEVICE_CONNECTED`, `DEVICE_DISCONNECTED`, `PLAYBACK_STARTED`, `PLAYBACK_PAUSED`
and diagnostic BLE events retain their legacy payload shape. Native publication
adds `journal` metadata after the source/projection transaction commits:

- UUID observation/source IDs and increasing source sequence;
- process/collection epoch, boot, wall and receipt-elapsed times;
- provenance, attribution confidence, payload version and commit time.

Legacy attribution is UNKNOWN. A discovered service UUID, connected endpoint
or global playback flag cannot create confirmed external listening or per-ear
telemetry. EventChannel delivery is an invalidation hint; canonical history is
replayable native data, not the volatile stream or a Flutter live reducer.

## Read And Acknowledgment RPCs

| RPC | Contract |
| --- | --- |
| `readObservationJournal` | `after` source sequence and `limit` 1..128; ordered records/source/schema/next cursor/health |
| `acknowledgeObservations` | Source-aware consumer/sequence; monotonic acknowledgment cannot exceed committed data |
| `readListeningProjection` | UTC `fromUtcMs` / `untilUtcMs`, optional IANA zone, interval offset/limit and independent optional `deviceOffset`; native clipping/union/aggregate/device snapshot |
| `readListeningPreferences` | Versioned theme, personal goal and display-name overrides |
| `updateListeningPreferences` | Validated, durable native settings update; names cannot alter source identity |

Journal schema 3 / projection version 3 are current. Additive device paging fields are `deviceOffset`,
`nextDeviceOffset`, `hasMoreDevices`; at most 100 devices per page. Old page-zero
responses remain decodable. Pages reflect current ordered state, not a frozen
multi-page snapshot. Device cursors do not affect listening totals. Reads catch up
derived state before returning. Results are bounded; oversized aggregate windows fail rather
than return incomplete totals as complete. Flutter cancellation ignores late RPC
results and cancels its deadline. Engine leases reject obsolete callbacks/sinks.

## Permissions And Limits

The manifest declares Bluetooth connection/legacy permissions, notifications and
connected-device foreground service permissions. Startup checks collection
permissions separately from optional notification capability and does not await
DB/service work before constructing the first screen. Tests model the permission
adapter; real OS/OEM permission and background behavior remain acceptance gates.

The passive observer adds `COLLECTOR_STATUS` and `OUTPUT_EVIDENCE` hints with
distinct journal source/provenance and captured elapsed time. They are not legacy
`isPlaying` or verified physical-route claims. Its generation/epoch/state health
acknowledgment follows a visible commit. The snapshot includes versioned scoped
`collectorHealth`, always `liveListeningEligible=false`. Unknown versions/scopes
are rejected; old snapshots default UNKNOWN. See `COLLECTOR_HEALTH.md`.

Legacy playback still lacks route-specific lifetime/attribution proof. Production
queries do not extrapolate from process lifetime or scoped observer health.
See [Projection](LISTENING_PROJECTION.md) and [Regression](REGRESSION.md).
