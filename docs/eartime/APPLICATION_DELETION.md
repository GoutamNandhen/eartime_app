# Explicit Full-Data Deletion

2026-10-25. H19 delegates complete private-data erasure to Android, not to partial
table/file deletion loops. This code was tested only with synthetic API models.
No real EarTime data was cleared, device action performed or physical G claimed.

## Contract

Settings -> Local data -> Delete all local data opens a scrollable destructive-
action disclosure. A separate unchecked acknowledgement must be selected before
Delete permanently becomes available. Cancel/back before submission sends no
command. The dialog names native/legacy history, names/associations, preferences,
goals, notification settings, diagnostics and private recovery archives. It warns
that collection/transfers stop, permissions are revoked, the app may close and
there is no undo/cancel after sending. Whole-app restore remains unavailable.

The scoped method requires confirmation in both Dart and native code and accepts
only `all_app_private_data`. Existing engine/navigation ownership is checked at
receipt; the existing serialized journal worker checks ownership again before
and after obtaining ActivityManager. A queued retired owner cannot erase data.
The operation does not require a healthy readable journal, create a second data
writer or edit protected collector callbacks. The helper is created lazily.

The public `ActivityManager.clearApplicationUserData()` API erases the calling
app's private and app-private external data, clears notifications/URI grants and
revokes runtime permissions. It retains the installed application. The method's
boolean reports only whether the request was accepted, not completed deletion.
[Official Android contract](https://developer.android.com/reference/android/app/ActivityManager#clearApplicationUserData()).

The native response always has `completed: false`; Dart rejects an invented
completion receipt. Accepted requests are not automatically retried or sent
twice by the same helper. A refused/failed request permits another explicitly
confirmed attempt. No application-side timeout silently cancels a queued
irreversible operation. Once acknowledged, the UI stops its request spinner and
continues to say completion is unproven; it offers no false Cancel transfer.
Engine retirement can prevent a still-queued request, not undo one sent to Android.

Android owns package-wide erasure/termination; this is not a multi-table SQLite
transaction, reversible import or secure/forensic flash-wipe guarantee. There is
no hidden retained private recovery archive after full deletion. User-exported
documents outside private app storage are not deleted. Never interpret in-memory
request state as evidence that persistent data is already gone.

## Evidence And Limits

Two actual RED Flutter cases established the absent deletion control. Four
Flutter cases now cover default-off acknowledgement, disabled action/cancel,
strict consent/protocol decoding, refusal/error retry and 1x/3x actual settings
flows. The first dialog fixture needed its own scroll owner. An accepted request
also exposed an indefinitely animating progress indicator; the production UI
now stops that request animation after acknowledgement without claiming erasure.
Four analyzer findings were corrected with blocks, not suppressions.

Nineteen native executions: API 24/28/35 supported public call, request-only
response, missing consent/wrong scope/retired owners, post-service-lookup owner
replacement, unavailable service, platform exception, refusal/retry and accepted
idempotence; plus an actual ingress queue blocked behind publication then retired
before deletion. The latter fixture was corrected to expect the command wrapper's
exact exception prefix; the Android-not-called assertion remains intact.

Robolectric acknowledges a request without deleting its fixture file or killing
the test process. That is explicitly asserted, not represented as physical wipe
proof. Full gates are recorded separately in TEST_RESULTS.md. H19 software path
is implemented/automated-pass; OS/OEM erasure, permission reset, process/service
termination and fresh-source behavior remain PHYSICAL_PENDING. Any future wipe
acceptance must use disposable test data/profile after backup/restore testing,
not the user's personal listening history. No intermediate hardware test is
requested here. All-feature completion and release readiness remain unachieved.
