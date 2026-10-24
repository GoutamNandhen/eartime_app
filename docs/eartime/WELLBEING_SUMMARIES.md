# Recorded Summaries And Quiet Hours

2026-10-24. Implemented opt-in native recorded-history summaries, not live
listening reminders, acoustic exposure guidance or physical delivery proof.

## Production Path

Settings stores versioned daily/weekly, preferred minute and quiet-hour settings
in the existing native preferences. Defaults are off. Quiet intervals support
daytime/overnight boundaries; equal endpoints mean all-day quiet. Native validation
rejects future versions, wrong types and invalid minutes before any preference
commit. Display names, themes and goals are preserved. These preferences and
delivery receipts remain outside native-only journal archives (H17/H18 partial).

Native startup/preferences/status commands reconcile two bounded one-shot
inexact alarms without a Flutter engine. The private boot/time/timezone/update
receiver is manifest-disabled until explicit summary opt-in; component updates
use DONT_KILL_APP and never restart the protected collector. Disabling summaries
cancels alarms and disables the receiver. No exact-alarm permission or polling
loop is added. Android may defer alarms/jobs under idle or power restrictions.
[Official inexact-alarm semantics](https://developer.android.com/develop/background-work/services/alarms).

The alarm receiver only enqueues a permission-protected JobService. Job start/stop
remain nonblocking; canonical journal reads, configuration, delivery checks and
notification posting run on the existing journal worker. Independent per-job
ownership fences stopped/replaced jobs. Recovery is via native startup and
boot/timezone/package broadcasts, not a new history writer or Dart timer.
Every request carries a fresh UUID in JobInfo extras, preserved by JobParameters.
Late stop callbacks compare this token's value, never just a reused numeric job
ID or parcel object identity. Finishing a retired owner cannot remove its successor.
[Official JobService ownership/threading](https://developer.android.com/reference/android/app/job/JobService).
[JobParameters extras contract](https://developer.android.com/reference/android/app/job/JobParameters.html#getExtras()).

## Accounting And Delivery

Daily reports cover the preceding complete local day; Monday weekly reports
cover the preceding complete calendar week. Calendar arithmetic preserves DST
23/25-hour days/weeks and canonical fixed-offset zones without falling back from
unknown zones to GMT. Quiet deferral keeps the original report period even when
the actual preferred delivery moves into the following day. Refreshing after the
preferred time does not skip a still-pending quiet-deferred report.

The native projection provides confirmed interval union and separately recorded
unverified activity. Notifications identify the recorded period and explicitly
say totals are lower bounds with unknown time excluded. Query failures are
unavailable, never a fabricated zero. Missing/expired route evidence is not
promoted. F2/F3 continuous/break reminders remain unavailable and live eligibility
is false; the platform attribution blocker has not been bypassed.

Permission/global/channel blocking, latest configuration, quiet hours, stale
payloads and job ownership are checked before and after reads and before posting.
Quiet hours do not suppress Android's required foreground-service notification.
There are at most two summary notifications, using private lock-screen visibility
and existing whitelisted Wellbeing deep links. No device identifiers are exposed.
[Android notification permission](https://developer.android.com/develop/ui/views/notifications/notification-permission).

Durable per-kind calendar-day high-water receipts prevent duplicate/older alerts
after process replacement or clock changes. This is **at most one attempt**, not
exactly-once physical delivery: a crash/cancellation after receipt but before OS
posting can miss that summary. Delayed jobs entering quiet hours are suppressed,
not replayed as a backlog. Very stale/future/malformed windows are rejected.
OS/OEM/background/lock-screen timing and real permission recovery are physical-
pending; there is no claim that inexact delivery always occurs at the chosen time.

## Software Evidence

WellbeingSummaryTest uses actual native preferences, journal SQLite, canonical
synthetic histories, AlarmManager/NotificationManager/JobScheduler models on
API 28/35: defaults, atomic save/reopen, quiet boundaries/deferral, DST, fixed-offset
zones, opt-in/cancel, permissions/channels, actual totals, high-water/restart,
cancellation, malformed windows, source retention/query errors and optional-
preference corruption isolation. Ingress tests exercise scheduling on process
replacement without Flutter; manifest tests check private/default-disabled
receiver, BIND_JOB_SERVICE and absence of exact-alarm permission.

Eight Flutter tests cover native-channel settings persistence/save failure,
permission opt-in, malformed data, numeric time validation/cancel, normal/2x text
layout and status retry. A real stock-picker 2x overflow was reproduced; the
replacement uses a scrollable full-width numeric dialog, not font clamping or
skipped assertions. Exact final full-suite counts are in TEST_RESULTS.md.
Three RED stale-stop cases preceded the request-token fix; six final owner tests
cover replacement storms, reparceled tokens and idempotent starts. Stored settings
also reject oversized/deep/duplicate payloads through a bounded flat parser.
API 24 additionally exercises the legacy notification-builder/permission branch
and private dated output. The full suite includes all older journal/projection/
migration/replay/startup regressions; no physical G claim follows from it.
