# Whole-App Restore Contract

2026-10-25. H14/H18 IMPLEMENTED / AUTOMATED_PASS / PHYSICAL_PENDING.
Prior published baseline: b149a6b37fcc0d58ac5821da5d4a54d2ba3ebfb1 (40/119).
Current full gates: 236 Flutter / 458 native (32 suites), no failures/errors/skips,
analyzer clean, both Kotlin variants/debug APK/strict four-hook guard pass. Counts
42 IMPLEMENTED / 62 IN_PROGRESS / 14 NOT_STARTED / 1 BLOCKED_BY_PLATFORM =119.
This is bounded software acceptance, not all-feature or production certification.

## Failure Mechanism

Native-only restore correctly owns one SQLite transaction. A whole-app restore
cannot add independent legacy SQLite and SharedPreferences commits and retain
that guarantee. The new preference failure model actually commits the first
store, interrupts before the second, and observes mixed old/new settings. Applying
the verified prior preference payload restores both exactly. That proves the need
for durable recovery before mutation, not a regression in the published native
archive feature. No real user preferences were changed in these tests.

## Recoverable Commit Design

ATTACH is not the production strategy. API 28/35 Robolectric defaults reported
WAL/memory respectively, not physical/OEM evidence. SQLite cross-database atomicity
does not apply with WAL. The retained ATTACH research guard is TEST ONLY; its
positive tests explicitly use DELETE-mode fixtures and its WAL tests refuse them.
Production uses a native outer transaction as the FINAL commit record, with
durable compensation of independently committed legacy rows and preferences.
Both SQLite targets must use supported disk journal modes and FULL synchronization;
WAL is supported without switching journal modes. Memory/off modes are refused.
[SQLite ATTACH contract](https://sqlite.org/lang_attach.html),
[SQLite super-journal prerequisites](https://www.sqlite.org/tempfiles.html).

Prepare any absent legacy schema through the existing Drift owner before starting
restore. Native restore must refuse an unprepared/mismatched target, not create a
second normal-launch legacy writer. Capture and verify a private application
recovery archive before changing source or settings. Then persist/read-back a
bounded prepared intent bound to the target store, recovery archive, operation
UUID and input checksum. The old typed preferences come from that verified copy.

Within the native outer transaction, stage native rows/projection, commit legacy
rows in their own transaction, then synchronously apply settings. Commit a native
operation/hash marker LAST in the outer transaction. Before this final commit,
SQLite rolls back native rows and the verified prior application archive restores
legacy rows/preferences. After it, all prior commits completed. On restart the
prepared intent and native marker distinguish compensation from completed state.
Recovery precedes worker collection/query/preferences publication, including an
already-running owner. Keep recovery archives; remove only completed transient
intent/staging files. This is recoverable application atomicity, NOT one physical
transaction spanning all files; power-loss/fsync behavior remains physical-pending.
[Synchronous preference commit](https://developer.android.com/reference/android/content/SharedPreferences.Editor#commit()),
[AtomicFile finish contract](https://developer.android.com/reference/android/util/AtomicFile#finishWrite(java.io.FileOutputStream)).

Explicit file/directory sync and read-back verification are required; do not treat void
AtomicFile completion as a sufficient application-level receipt after I/O errors.
If rollback cannot persist, retain the intent/recovery copy and report recovery
required, not successful cancellation or empty data. The existing explicit
Android-managed deletion command must remain available without a readable journal.

## Implemented Prerequisites

ApplicationArchive stages only its five fixed validated components into generated
private cache directories. Original byte digests are retained for revalidation;
late footer corruption/cancellation removes only generated files. Strict bounded
typed preferences retain int/long/float/set distinctions, validate active settings,
and permit exact raw prior-state rollback without silently defaulting bad values.
The coordinator includes generated bounded prepared intents, final native markers,
legacy replacement, exact old-preference compensation, fault union/conflict checks,
cursor bounds, semantic duplicate detection and collection gaps. Notification
attempt high-water marks never regress and imported delivery results never become
local delivery proof. Input-native matching prefixes retain newer local source.
There is no new listening reducer or source schema. Initial coordinator tests found
and corrected nullable legacy JSON conversion before any write; retain that evidence.

## Integrated Application Path

Settings' separate destructive disclosure calls the application document format,
not native-only import. The existing Drift owner initializes absent legacy schema
before native restore; a per-engine operation queue serializes direct legacy reads
with restore. Each entry waits for native recovery. The operation provider outlives
Settings navigation and invalidates preferences, projections and legacy pages.
New engines also wait behind the serialized native worker. Filesystem-only native/
application recovery pages remain available without opening a damaged journal.

Success is returned only after final commit/recovery resolution. Cancellation is
cooperative between chunks/rows/commit boundaries; a blocked Android document
provider cannot promise immediate cancellation. Committed state wins late cancel.
Recovery-required failures are never disguised as successful cancellation. Source
schema 3/cache 5 and all original collector lines remain unchanged.

Focused prerequisite tests passed 37 executions, then coordinator/file-transfer
tests passed with the Windows directory syscall model. Full Flutter passes 236;
analyzer clean. The first complete native run found a shared-sandbox class-cast
conflict when switching Linux shadows between classes (458 executions/22 errors).
The test-only syscall configuration is now consistent suite-wide; the subsequent
full 458-execution run passed. No tests/rollback assertions were removed or skipped.

The Windows model cannot open Linux directories (ShadowLinux returns EIO), so a
test-only shadow records directory open/fsync/close and injects fsync failure.
Other file operations use the existing framework/host behavior. Production still
uses public Android Os.open/fsync/close and fails before mutation on sync failure.
This fixture proves ordering/error handling, NOT real storage durability.
The WAL test also caught a real read-write-open flag regression: legacy WAL was
changed to DELETE. The writer now reads the mode read-only, opens with matching
WAL flags and verifies unchanged mode. Nullable legacy JSON conversion was fixed
without weakening original null/rollback assertions.

No physical erasure, power-loss durability, generic route evidence, vendor support
or physical G follows from these synthetic SQLite/Robolectric models. Do not
apply a native-only archive to preferences/legacy. Actual OS durability, provider
stall/cancellation and private recovery accessibility remain physical-pending.
