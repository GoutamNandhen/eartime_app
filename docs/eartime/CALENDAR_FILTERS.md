# Calendar Filters And Totals

2026-10-25. D7/E1 software acceptance. Actual output attribution, physical clocks,
live collection, grouped-session semantics and charts retain their separate gates.

Home, Timeline, Analytics and Wellbeing use one calendar-window constructor. Today
ends at the following local midnight; week starts Monday, month/year start at the
calendar boundary, through today. Custom end dates are inclusive in the UI and
become exclusive next-local-midnight bounds in the existing native query. No
24-hour arithmetic is used to advance local dates. UTC calendar components count
the maximum 366 selected dates so DST elapsed-hour changes cannot reject a valid
calendar range. Canonical native clipping/union, not Dart summation, owns totals.

Custom dates support preserved history back to 1970, replacing an arbitrary
ten-year picker cutoff. Future dates, reversed inputs and oversized ranges are
rejected without changing the previous query. Cancellation preserves selection.
A backward clock adjustment invalidates only the editor's initial value, not
previously selected history. Date summaries include the year. Both page offsets
reset when a filter changes; device UUID scope remains intact. Device-offset
reset is defensive state hygiene, not a claimed physical regression reproduction.

Real tests exposed stock date-range header overflow on 360px at 1x/2x. The
replacement is a scrollable, naturally sized date form using Flutter's localized
InputDatePickerFormField parsing/validation and Material date labels. It does not
clamp font scale, parse dates with ad hoc regex, create a listening timer or add
another journal/projection. Calendar-now injection controls only date selection
in tests, not listening duration. Device inventory remains date-independent.

Thirteen Flutter cases cover leap days, Monday/year boundaries, inclusive custom
ends, 366-day/future/pre-epoch rejection, actual 100-row paging and global/scoped
Timeline/Analytics controls, invalid/cancel/oversized edits, clock rollback and
360px layouts at 1x/2x/3x. Four API 28/35 native executions add actual SQLite union
reconciliation across leap-day midnight, day/week/month/year/custom bounds,
overlapping devices, offset pages, reopen and cache replay. Raw observations and
consumer cursor are retained; invalid queries cannot mutate or expose all history.
All fixtures are synthetic, not a real output-route producer.

Full gates: 186 Flutter, 362 native in 28 suites, zero failures/errors/skips;
analyzer clean; debug/release Kotlin, debug APK, version and protected four-hook
checks pass. Source schema 3/projection 5 are unchanged. No user database was
restored/deleted and no device/physical G/release validation is claimed.
