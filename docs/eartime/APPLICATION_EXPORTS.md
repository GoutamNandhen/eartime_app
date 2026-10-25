# Versioned Application Exports

2026-10-25. This extends, not replaces, native-only archives. Whole-app restore
and deletion remain unfinished. No automatic migration or user-data deletion is
performed by export. No hardware, physical durability or release claim follows.

Subsequent H19 continuation implements explicitly confirmed Android-managed full
private-data deletion (APPLICATION_DELETION.md), with actual OS erasure pending.
The export-checkpoint evidence below is historical. Subsequent H14/H18 continuation
adds application restore/recovery: APPLICATION_RESTORE_CONTRACT.md. Current full
gates are 236 Flutter/458 native, not physical storage/durability certification.

## Production Path

Settings -> Local data -> Export application data requires the plaintext/private-
data disclosure before Android's user-selected create-document picker. Native
engine/navigation ownership and confirmation are checked. Capture runs on the
existing serialized journal worker in a read-only-in-effect SQLite transaction;
document-provider I/O remains on the separate archive worker. UI/source changes
cannot interleave native journal/preferences commands during capture. Existing
ingress bounds/loss markers still apply if a large optional export delays commits.

Five components:

- `manifest.json`: application format 1, native logical schema 3, disposable
  projection rebuild version 5 and legacy schema 1.
- `native.jsonl`: original observation/source IDs, source cutoff, captured clocks,
  provenance/confidence, identity/alias observations and existing native checksum.
- `preferences.json`: typed raw user settings/names/goals/notification preferences
  plus summary-delivery state. Absent preferences preserve version-1 defaults.
- `legacy.jsonl`: all preserved Drift v1 event fields, exact integer timestamps,
  nullable playback state and explicit absent-vs-present metadata. Legacy records
  remain legacy; they are never added to confirmed listening.
- `journal_state.jsonl`: consumer cursors and durable conflict evidence.

This is a logical data export, not a copy of live SQLite/WAL files or an image of
all private storage. Derived caches/indexes are rebuilt from source. Temporary
files, diagnostic logs and older private native recovery archives are excluded;
those remain on the device. External user-selected exports are not recopied.

The legacy path is the same Flutter `PathUtils.getDataDirectory` documents location
used by the installed path_provider Android implementation, with the existing
`eartime_db.sqlite` name. A missing file is recorded explicitly, never created.
Only known schema/columns and the event table are accepted. The known one-column
Android locale metadata table may exist; it is regenerable platform metadata, not
listening history. Unknown tables (including sqlite-like names) fail explicitly.
[AOSP locale-table implementation](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/database/sqlite/SQLiteConnection.java).

Legacy access is read-only with an explicit non-deleting corruption handler.
Android's default handler can remove corrupt databases, so it is not used here.
[AOSP default corruption handler](https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/database/DefaultDatabaseErrorHandler.java).
The current production legacy writer remains disabled. Arbitrary concurrent
external/compatibility writes are not a validated multi-store snapshot guarantee.

## Format And Bounds

ASCII magic `EARTIME_APPLICATION_ARCHIVE_1`, followed by the five fixed ordered
components. Each has an exact ASCII name, byte length, SHA-256 and raw payload.
The final SHA-256 covers the preceding entire container. No compression,
user-provided paths, archive extraction or arbitrary component names are involved.
Checksums detect damage, not authenticity or correct physical route attribution.

256 MiB container, 128 MiB per component, 200000 rows per history/state component;
4096-byte manifest, 524288-byte preferences/record limits, existing bounded JSON
depth/nodes/strings and strict UTF-8. Unknown versions, missing/reordered parts,
bad lengths/count types, duplicate keys, bad hashes, truncation or trailing bytes
fail closed. No source data or totals are truncated to fit an archive.
Integer, long, finite float, boolean, string and string-set preference types are
retained explicitly. Legacy identifier ordering uses UTF-8 byte order, matching
SQLite BINARY order for the current schema rather than Java UTF-16 ordering.

Generated private staging files are bounded, flushed/synced and fully read back
through the integrity validator before provider copying. Cooperative cancellation
checks run through rows and I/O chunks; failure removes only this operation's
generated cache files. A killed process can leave private cache partials. No
provider/OS hard deadline, power-loss durability or automatic cache-pruning claim
is made. A stalled provider remains a release-hardening item. A copied partial
without the valid container footer is rejected. Do not publish archives or logs.

## Evidence And Open Work

Two API 28/35 RED picker cases and three Flutter RED client/UI cases established
the missing path. New native tests use real journal/SQLite/preferences/legacy
files and ingress ownership, not mocked accounting. They cover byte-identical
repeat exports, raw/source/preference/legacy preservation, unknown schema/table
refusal, corrupt-file retention, cancellation cleanup, malformed/recomputed
containers, Unicode IDs and 1001 native/1203 legacy rows beyond all source pages.
Two additional RED executions exposed SQL LIKE's underscore wildcard hiding
`sqliteXhistory`; literal-prefix GLOB fixes it without allowing unknown tables.

Fixture-only failures: JUnit requires a void return from the hostile-length case;
short DB names avoid the Windows native SQLite path limit. Android's actual
locale table is accepted only with its expected column, not by weakening the
unknown-table assertion. No failed tests or fixtures were deleted.

Flutter tests cover strict distinct result scope/counts, confirmation/cancel before
any action and actual data-settings navigation at 1x/3x. Existing native-only
export/restore/recovery and privacy tests remain in the complete gate.
The final synthetic document-provider case runs the actual transfer helper,
process-scoped runtime, serialized native writer and output validation end to end.
Only fixture worker retirement uses reflection; capture/I/O/accounting is not
mocked. Final gates: 225 Flutter / 401 native in 29 suites, no failures/errors/
skips, analyzer clean, both Kotlin variants and debug APK pass. Strict four-hook
collector and version checks/17 version self-tests pass. H17 is implemented;
H18/H19 remain incomplete. No real document provider, physical G or OS power-loss
proof is inferred from Robolectric.

Remaining: whole-app transactional restore across native SQLite, SharedPreferences
and legacy Drift; durable crash-intent recovery, rollback/idempotence/conflict
policy, cancellation and user-confirmed deletion. Existing native-only replacement
must not be applied to the new format. No raw SQLite file replacement, implicit
legacy import or confidence promotion is allowed. Continue these paths before
calling the data-management phase complete or preparing consolidated manual tests.
