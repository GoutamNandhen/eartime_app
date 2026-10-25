import 'package:eartime_app/data/listening_calendar.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:eartime_app/features/listening/listening_dates_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> calendarReply(Map args) => {
  'projectionVersion': 5,
  'sourceId': 'synthetic-calendar',
  'sequence': 1,
  'fromUtcMs': args['fromUtcMs'],
  'untilUtcMs': args['untilUtcMs'],
  'filterDeviceId': args['deviceId'],
  'confirmedMs': 1010,
  'unverifiedMs': 0,
  'gapCount': 0,
  'intervalCount': 101,
  'nextOffset': args['offset'] == 0 ? 100 : 101,
  'hasMore': args['offset'] == 0,
  'deviceOffset': args['deviceOffset'],
  'deviceCount': 1,
  'nextDeviceOffset': 1,
  'hasMoreDevices': false,
  'devices': [
    {
      'id': '00000000-0000-4000-8000-000000000001',
      'name': 'Synthetic calendar device',
      'connected': false,
      'identityVerified': false,
    },
  ],
  'intervals': List.generate(
    args['offset'] == 0 ? 100 : 1,
    (index) => {
      'id': 'synthetic-${(args['offset'] as int) + index}',
      'deviceId': '00000000-0000-4000-8000-000000000001',
      'attribution': 'CONFIRMED',
      'startUtcMs':
          (args['fromUtcMs'] as int) + ((args['offset'] as int) + index) * 100,
      'endUtcMs':
          (args['fromUtcMs'] as int) +
          ((args['offset'] as int) + index) * 100 +
          10,
      'durationMs': 10,
      'open': false,
      'live': false,
      'closeReason': 'synthetic_stop',
    },
  ),
  'days': [
    {'startUtcMs': args['fromUtcMs'], 'confirmedMs': 1010, 'unverifiedMs': 0},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in [
    (
      ListeningRange.today,
      DateTime(2024, 2, 29),
      DateTime(2024, 2, 29),
      DateTime(2024, 3),
    ),
    (
      ListeningRange.week,
      DateTime(2023, 1, 1),
      DateTime(2022, 12, 26),
      DateTime(2023, 1, 2),
    ),
    (
      ListeningRange.month,
      DateTime(2024, 3, 1),
      DateTime(2024, 3),
      DateTime(2024, 3, 2),
    ),
    (
      ListeningRange.year,
      DateTime(2024, 12, 31),
      DateTime(2024),
      DateTime(2025),
    ),
  ]) {
    test(
      'calendar ${entry.$1.name} preserves local boundaries at ${entry.$2}',
      () {
        final window = ListeningCalendar.window(
          entry.$1,
          entry.$2,
          offset: 100,
          deviceOffset: 100,
          deviceId: 'synthetic-id',
        );
        expect(window.from, entry.$3);
        expect(window.until, entry.$4);
        expect(window.offset, 100);
        expect(window.deviceOffset, 100);
        expect(window.deviceId, 'synthetic-id');
      },
    );
  }
  test(
    'custom includes entire last calendar date and supports preserved old history',
    () {
      final custom = DateTimeRange(
        start: DateTime(1999, 12, 31, 15),
        end: DateTime(2000, 1, 1, 16),
      );
      expect(ListeningCalendar.validCustom(custom, DateTime(2026)), true);
      final window = ListeningCalendar.window(
        ListeningRange.custom,
        DateTime(2026),
        custom: custom,
      );
      expect(window.from, DateTime(1999, 12, 31));
      expect(window.until, DateTime(2000, 1, 2));
    },
  );
  test(
    'custom 366-day bound rejects future, oversized and pre-epoch ranges',
    () {
      final now = DateTime(2026, 10, 24);
      expect(
        ListeningCalendar.validCustom(
          DateTimeRange(start: DateTime(2024), end: DateTime(2024, 12, 31)),
          now,
        ),
        true,
      );
      for (final invalid in [
        DateTimeRange(start: DateTime(2024), end: DateTime(2025)),
        DateTimeRange(
          start: DateTime(2026, 10, 24),
          end: DateTime(2026, 10, 25),
        ),
        DateTimeRange(start: DateTime(1969, 12, 31), end: DateTime(1970)),
      ]) {
        expect(ListeningCalendar.validCustom(invalid, now), false);
      }
    },
  );
  test(
    'clock rollback discards only invalid picker initial value, not saved selection',
    () {
      final custom = DateTimeRange(
        start: DateTime(2026, 10, 10),
        end: DateTime(2026, 10, 11),
      );
      expect(
        ListeningCalendar.pickerInitial(custom, DateTime(2026, 10, 24)),
        custom,
      );
      expect(
        ListeningCalendar.pickerInitial(custom, DateTime(2026, 10, 1)),
        isNull,
      );
      expect(
        ListeningCalendar.window(
          ListeningRange.custom,
          DateTime(2026, 10, 1),
          custom: custom,
        ).from,
        custom.start,
      );
    },
  );

  const channel = MethodChannel('com.eartime.app/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final view in [ListeningView.timeline, ListeningView.analytics]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        '${view.name} calendar/custom filters, cancellation and clock rollback at scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var now = DateTime(2026, 10, 24, 12);
          final queries = <Map>[];
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'readListeningPreferences') {
              return {
                'version': 1,
                'themeMode': 'system',
                'dailyGoalMinutes': 0,
              };
            }
            if (call.method == 'readListeningProjection') {
              final args = Map.of(call.arguments as Map);
              queries.add(args);
              return calendarReply(args);
            }
            return null;
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                listeningCalendarNowProvider.overrideWithValue(() => now),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ListeningWorkspace(
                    view: view,
                    deviceId: view == ListeningView.timeline
                        ? '00000000-0000-4000-8000-000000000001'
                        : null,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            queries.last['fromUtcMs'],
            DateTime(2026, 10, 24).millisecondsSinceEpoch,
          );
          if (view == ListeningView.timeline) {
            await tester.scrollUntilVisible(
              find.byTooltip('Next intervals'),
              400,
              maxScrolls: 300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(find.byTooltip('Next intervals'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Next intervals'));
            await tester.pumpAndSettle();
            expect(queries.last['offset'], 100);
          }
          for (final item in [
            ('This week', DateTime(2026, 10, 19)),
            ('This month', DateTime(2026, 10)),
            ('This year', DateTime(2026)),
          ]) {
            await tester.ensureVisible(
              find.byType(DropdownButton<ListeningRange>),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byType(DropdownButton<ListeningRange>));
            await tester.pumpAndSettle();
            await tester.tap(find.text(item.$1).last);
            await tester.pumpAndSettle();
            expect(queries.last['fromUtcMs'], item.$2.millisecondsSinceEpoch);
            expect(
              queries.last['untilUtcMs'],
              DateTime(2026, 10, 25).millisecondsSinceEpoch,
            );
            expect(queries.last['offset'], 0);
            expect(queries.last['deviceOffset'], 0);
            expect(
              queries.last['deviceId'],
              view == ListeningView.timeline
                  ? '00000000-0000-4000-8000-000000000001'
                  : null,
            );
          }
          Future<void> openInput() async {
            await tester.ensureVisible(find.byTooltip('Select dates'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Select dates'));
            await tester.pumpAndSettle();
          }

          await openInput();
          await tester.enterText(find.byType(TextField).at(0), '10/10/2026');
          await tester.enterText(find.byType(TextField).at(1), '10/11/2026');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(
            queries.last['fromUtcMs'],
            DateTime(2026, 10, 10).millisecondsSinceEpoch,
          );
          expect(
            queries.last['untilUtcMs'],
            DateTime(2026, 10, 12).millisecondsSinceEpoch,
          );
          final before = Map.of(queries.last);
          expect(find.text('Oct 10, 2026 to Oct 11, 2026'), findsOneWidget);
          await openInput();
          await tester.enterText(find.byType(TextField).at(0), '1/1/2024');
          await tester.enterText(find.byType(TextField).at(1), '1/1/2025');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Choose at most 366'), findsOneWidget);
          expect(queries.last, before);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await openInput();
          await tester.enterText(find.byType(TextField).at(0), 'invalid');
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(find.byType(ListeningDatesDialog), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(queries.last, before);
          now = DateTime(2026, 10, 1);
          await tester.tap(find.byTooltip('Select dates'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ListeningDatesDialog>(find.byType(ListeningDatesDialog))
                .initial,
            isNull,
          );
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
