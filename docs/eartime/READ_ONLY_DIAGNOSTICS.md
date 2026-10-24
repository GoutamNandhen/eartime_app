# Consent-Only Bluetooth Inspection

2026-10-24. Privacy hardening, not vendor telemetry completion or physical proof.

## Proven Unsafe Path And Change

The inherited service called BleDiscoveryManager.discover during ordinary device
inventory. That manager connected GATT and subscribed to a vendor characteristic
with a CCCD descriptor write; opening DeveloperDiagnosticsScreen also requested
discovery automatically. These source paths contradicted the approved no-automatic-
vendor-interaction rule. Recoverable remote checkpoint before replacement:
`00a0e17eafb8996cf83b5049df8d4060d50245ab`.

AudioTrackingService.kt is not edited. Its ordinary discover calls now return
before reading the endpoint or scheduling work. Forced diagnostic requests need
an explicit process-local one-shot authorization bound to a normalized endpoint,
valid for at most 15 elapsed seconds. Authorization is never persisted or inferred
from connection state, names, a vendor UUID, screen opening or process restart.

The current engine must confirm the request. Endpoint-association UI supplies
source/alias/revision, not raw addresses; the journal owner resolves the private
endpoint, and the main-thread command rechecks current ownership before granting
authorization and dispatching the service action. Legacy explicit diagnostics
also require confirmation and a valid explicit address; there is no fallback
selection. Opening diagnostics and cancelling confirmation perform no interaction.

The full suite initially exposed a real error-label defect on API 28 and 35:
an oversized catalog threw, but a finally block closed it as finished before
the outer error handler could report failure. No partial catalog escaped and the
handle closed; nevertheless the reason was wrong. Success closure now occurs
only after successful catalog handling, and errors close as inspection_unavailable.
The original failing bounds assertions were retained and rerun successfully.

## Read-Only Boundaries

The replacement manager inspects service/characteristic UUIDs and property flags
only. It does not read characteristic values, subscribe, write descriptors or
characteristics, pair, authenticate, change ANC/EQ/firmware or decode vendor data.
WRITE/NOTIFY in a catalog is descriptive metadata, never permission to operate.
Android's public [discoverServices API](https://developer.android.com/reference/android/bluetooth/BluetoothGatt#discoverServices())
and catalog access provide discovery, not supported physical telemetry evidence.

Only explicit user requests create work. Native connect/discovery/catalog tasks
and cleanup are off-main on bounded process pools (two connection workers/8
queued tasks, two cleanup workers/2 queued tasks, two outstanding handles).
Owner/handle/closed checks fence late callbacks; catalog publication and closure
are serialized. Duplicate connected callbacks cannot start repeated discovery.
A 10-second scheduled deadline requests closure. A blocked platform Binder call
can delay cleanup; this is not a hard physical disconnect guarantee. Capacity is
retained until cleanup succeeds; a failed/blocked close cannot spawn unbounded
replacement connections and may leave diagnostics unavailable until restart.

Catalogs allow at most 32 services, 64 characteristics per service and 256 total.
Oversized results fail explicitly, not as a truncated complete catalog. Names are
sanitized/bounded, raw notification payload logging/forwarding is removed, and
the result carries readOnly=true/telemetryVerified=false. Dedicated collector
optional_read_only_gatt_catalog retains captured wall/elapsed provenance through
the existing durable journal and committed broker, not the legacy audio-service
source or another telemetry database. Connection is a
historical observation at capture, not live route or collector health evidence.
The request closes after inspection or deadline; no reconnect loop exists.

## Evidence And Remaining Work

BleDiagnosticSafetyTest uses synthetic Robolectric API 28/35 devices only:
one-shot/expiry/revocation, 500 ordinary inventory calls without connection,
asynchronous authorized requests, deadline before/during connect and late handles,
catalog-only/no reads-or-writes/closure, worker/cleanup/callback refusal, duplicate
cleanup and malformed/oversized catalogs. EndpointIdentityTest validates private
resolution against source/alias revision without mutating raw history. Flutter
tests cover native consent arguments, endpoint confirmation/cancel/error and the
actual legacy diagnostic screen not connecting on open.

No real device was contacted. Standard battery-value acquisition, freshness,
per-ear/case roles, wearing state and optional OnePlus compatibility remain
unfinished/PHYSICAL_PENDING. This does not complete B5-B12 or H15; protected
collector logging and broader privacy/offline/data-control review remain open.
