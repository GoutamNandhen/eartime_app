# Privacy And Permission Disclosures

2026-10-24. H28 is the integrated disclosure path, not a completed security audit
or store-policy certification. H15/H17/H18/H19/H20/H21 retain their own gates.

`PrivacyScreen` is available offline from both Settings and the ungranted startup
gate. It has no platform, database, permission, Bluetooth, network or account
dependency. Opening/reading it never grants permission, starts optional inspection
or changes data. Nine headed sections cover actual data categories and habits,
unverified output and telemetry, runtime Bluetooth access, optional notifications/
required service status, short-lived diagnostic consent, developer networking,
document-provider destinations, native-only archives, retained legacy data,
missing whole-app deletion and possible private collector logs. It does not claim
encryption, anonymity, whole-app backup, no developer internet permission or
completed log sanitation. These limitations are visible, not hidden in a report.

Source checks: main/debug manifests, permission_provider.dart, BleDiscoveryManager,
native journal/archive/preferences paths, legacy storage, backup_rules.xml and
data_extraction_rules.xml. Four API 28/35 native executions inspect merged
permissions/allowBackup and every root/database/sharedpref/file/external exclusion
for legacy cloud backup, modern cloud backup and device transfer. Configuration
tests are not OEM backup-behavior evidence. Debug APK permission inspection retains
INTERNET for Flutter development tooling; no audio recording/location/scanning/
exact-alarm permission is added by this work.

The former fixed-height startup column reproduced 1084px overflow at 2x text and
3032px at 3x on 360x640. It now uses a safe-area scroll view, naturally sized
buttons, inherited Material theme and semantic heading/status. No font clamp,
decorative orb, permission algorithm, ownership generation, platform timeout,
first-frame scheduler or collector edit is introduced. Existing grant/retry/
system-settings commands retain their conditions and timeout/error handling.

Six Flutter cases verify both RED-to-GREEN overflow scenarios plus all disclosure
sections/navigation/back at 1x/3x from Settings and denied setup. Native failures
are explicit fixtures; disclosure navigation adds no native request or permission
prompt. Tests wait for/render lazy-list targets rather than ignoring missed taps.
The full suite retains rapid-reopen, first-frame and retired-owner assertions.
No real device, accessibility-service, OS backup or physical G verdict follows.
