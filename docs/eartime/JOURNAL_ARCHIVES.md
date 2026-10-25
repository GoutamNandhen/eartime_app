# Native Journal Archives

Development implementation, 2026-10-24. Native observations only, **not a full-app
backup**. H17 now separately exports application state including preferences and
legacy history (APPLICATION_EXPORTS.md). H18 whole-app restoration remains
IN_PROGRESS; H19 deletion is not implemented. The native format below is retained.

## Integrated Path

Settings -> Local data exposes export, explicitly confirmed replacement from a
file, paged local recovery archives and explicitly confirmed recovery restore.
Android's Storage Access Framework chooses the document. No broad storage
permission, external URI command, vendor interaction or automatic restore.
Activity/engine destruction cannot deliver success to a retired Flutter owner.
The transfer helper is lazy: normal launch/reopen/teardown does not instantiate
an archive worker or call document-picker cleanup when no transfer exists.

Exports are plaintext private user data: captured times, device identifiers and
raw payloads. The UI warns before opening the destination picker. Users must
choose an appropriate private/local provider; Android may also offer remote
document providers. EarTime does not select/upload to one automatically. Never
publish an archive, recovery copy or staging file in the public Git repository.

## Format And Integrity

Version 1, `eartime.native_journal`, source schema 3, LF-delimited UTF-8 JSON.
Header: source UUID, sequence cutoff, explicit native-only scope/version.
Observation rows preserve UUIDs, source sequence, provenance/confidence, original
captured clocks/process/collection epoch, payload version and commit timestamp.
Footer: record count, final sequence and SHA-256 over preceding exact bytes.
Checksum detects corruption, **not authenticity or physical route verification**.
Only restore trusted user-selected archives; confidence is retained, never promoted.

Bounds: 128 MiB, 200000 observations, 524288 characters per line, JSON depth 16,
16384 nodes per record, existing 65536-byte payload bound. Strict UTF-8, duplicate
JSON keys, invalid ordering, bad IDs/integer fields, unknown format/version,
truncation, missing/footer mismatch and trailing content fail closed. A streaming
JsonReader bounds nesting before JSONObject parses untrusted content. Oversized
history fails explicitly; no totals or archive rows are silently truncated.

Document-provider I/O runs on a separate worker. Export requests immutable source
pages (128 rows) from the sole journal owner up to a captured source/sequence cut;
later appends do not enter that export. A source replacement during export fails
rather than mixing journals. The destination is not a database path. Partial or
canceled exports without a valid footer are not accepted on restore.

## Replacement And Recovery

Selected input is copied with a byte bound into private cache, validated before
replacement and read/verified again inside the SQLite replacement transaction.
Before any mutation, the current native observation history is exported to a
private recovery file, flushed, file-descriptor synced, validated and renamed.
Recovery files have generated UUID names and are never automatically pruned.
The paged UI permits restoring one; recovery inputs are path/UUID restricted.
Backup failure prevents replacement. Power-loss/filesystem/provider durability
still requires physical validation; model tests do not establish that gate.

Matching same-source prefixes are idempotent: older/repeated archives do not
erase newer observations or add gaps/recovery copies. A conflicting same-source
observation/order is rejected. Explicit different-source replacement retains the
previous history in the recovery archive. Source rows/identity, derived reset/
replay, consumer cursor reset and the new restoration gap commit atomically.
Fault evidence and preferences are retained; faults are not exported/restored.
Unknown future journal/projection versions are not destructively reset.

The restoration gap closes imported open intervals at their last evidence, not
at current time. Production live extrapolation remains disabled. Pending native
observations captured before the restore boundary receive a separate collection
epoch; they cannot bridge into subsequent observations. Publication/widgets are
invalidated only after commit. A rolled-back transaction retains the original
source rows, source ID, projection and cursors. Journal schema stays 3; no
automatic data migration, legacy import or confidence promotion was added.

Cancellation is cooperative at bounded row/line/commit boundaries. A commit
that wins the cancellation race is reported as committed, not undone. Provider
calls can block independently; no hard cancellation/deadline for stalled provider
I/O is claimed. A process death can leave a private cache partial file, never a
committed partial replacement. Physical OS-death/provider/permission tests and
storage/energy profiling remain pending. Long restores own the journal worker
during the transaction; existing overflow loss markers remain required.

## Acceptance Evidence

`JournalArchiveTest`: round trip; trusted provenance retention; active-interval
gap close; recovery restore/reopen; repeated restore; precommit crash rollback;
mid-import cancellation rollback; corruption/truncation/future/trailing rejection;
same-source conflict; fixed-cut concurrent append; oversized/invalid UTF-8/deep/
ambiguous JSON; preferences retained; path traversal refusal; future projection
refusal; 1500-session/3000-row archive with every page counted (API 28).
Other archive cases run API 28/35. These are SQLite/Robolectric models, not phone
process-death proof. The ingress integration case blocks its worker to establish
restore-before-drain ordering and verifies queued/future epoch separation.
Picker tests verify actual CREATE/OPEN_DOCUMENT intent ownership, cancellation,
rejecting non-content URIs, duplicate results and retired Activity callbacks.
Flutter tests exercise confirmation/no-op cancel, actual success counts, errors,
pending cancellation/disposal, paged recoveries, channel contracts and 2x text.

Official reference: [Android document access](https://developer.android.com/training/data-storage/shared/documents-files).

Next data work: full-app/legacy/preferences export and transactional restoration,
confirmed deletion including retained copies, recovery export, provider timeout/
process-death handling, cross-layer cancellation and performance profiling. Do
not describe the current native-only archive as all of H17/H18 implemented.
