# Reports, Widgets And Navigation

Implemented 2026-10-24. Software evidence only; launcher/OEM and physical G
acceptance remain pending. No new source observations or collector changes.

## Recorded Reports

`ListeningReport` consumes the canonical native snapshot's clipped daily
buckets. ObservationJournal adds the report to the same read transaction used
by Home, Timeline, Analytics, Devices, Wellbeing and widgets. The persisted
personal goal is read natively; Dart does not reconstruct durations or streaks.

Reports contain recorded active days, average per active day, goal days, ending
and best recorded streak within the selected window, a duration-based insight
and personal-goal guidance. Days use actual adjacent calendar bucket endpoints,
not 24-hour arithmetic. A partial custom-date bucket cannot establish a full
day goal hit/miss. An unfinished current day does not erase yesterday's streak;
future buckets are excluded. Disabling goals produces no goal streaks.

All reports are recorded lower bounds. Gaps/unverified activity stay excluded
from confirmed listening. No missing record is called a break, no exposure or
medical recommendation is inferred, and no all-time streak is claimed from a
bounded window. Break recommendations and scheduled report notifications remain
unfinished separate features. Reports regenerate automatically on native reads,
including after journal reopen/rebuild; no report database or competing clock.

## Widgets

Three native providers: existing dark two-column devices, compact last-observed
activity, and daily confirmed/unverified totals. All use one canonical daily
query without a Flutter engine. Event-coalesced refresh, platform periodic
updates and resize callbacks cover all installed variants. A missing history
renders `--`, not a claim of zero listening. Unknown output/continuity is explicit;
there is no live timer or fabricated battery level. Current activity uses the
aggregate open-interval count, not the limited timeline page. The current
collector cannot establish current output; the activity widget says last-observed.

Native resource/render tests do not establish launcher layout or refresh timing.
The existing device widget's connection labels still lack validated freshness;
do not treat old connected inventory as proof of a current route.

## Navigation

Static shortcuts: Today, Timeline, Analytics, Devices. Widget taps open Devices,
Home or Analytics as appropriate. Explicit component intents and immutable
PendingIntents distinguish destinations. `eartime://open/<destination>` accepts
only five presentation destinations, no query/fragment/user/port/extra path.
No external URI can delete, restore, start BLE diagnostics or submit observations.

MainActivity queues one pending destination before Flutter engine setup, consumes
it once through a separate method channel, and notifies on new warm intents.
Saved pending state avoids replaying the original launch intent on recreation.
Engine cleanup is owner-fenced; Dart disposal ignores late navigation results.
The permission gate remains in front of the selected screen.
Warm hints dismiss covering Settings/detail routes before selecting the view.
`app_navigation_shell_test.dart` proves the actual requested screen is visible;
it failed with the earlier tab-only implementation.
Flutter's default URI route handler is explicitly disabled to avoid competing
with this channel and sending unvalidated URI strings to Navigator.

Official API references:
- [Android shortcuts](https://developer.android.com/develop/ui/compose/system/shortcuts/creating-shortcuts)
- [Widget layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts)
- [Flutter default deep-link handling](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change)
- [Candidate A2DP stream API](https://developer.android.com/reference/android/bluetooth/BluetoothA2dp#isA2dpPlaying(android.bluetooth.BluetoothDevice))
- [AOSP API failure fallback](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/framework/java/android/bluetooth/BluetoothA2dp.java)
- [AOSP per-device service state](https://android.googlesource.com/platform/packages/modules/Bluetooth/+/refs/heads/main/android/app/src/com/android/bluetooth/a2dp/A2dpService.java)

Tests: ListeningReportTest (5), native projection persisted-goal/reopen/replay
(2 API 28/35), NavigationTargetTest (6 API 28/35), summary-widget render (2 API
28/35), Flutter navigation (1), report contract and large-text product UI (2).
