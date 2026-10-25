import 'dart:async';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'listening_record_states_test.dart' show recordFixture;
import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/features/listening/listening_trends.dart';
import 'package:eartime_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  late StreamController<dynamic> events;
  setUp(() {
    events = StreamController<dynamic>.broadcast();
    TrackingPlatform.setRawStreamForTesting(events.stream);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readListeningProjection') {
            return recordFixture(call.arguments as Map, 'confirmed')
              ..['hourly'] = List.generate(
                24,
                (hour) => {'hour': hour, 'durationMs': hour == 9 ? 8000 : 0},
              );
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TrackingPlatform.resetForTesting();
    await events.close();
  });
  test(
    'malformed hourly bucket contracts are unavailable, not misleading charts',
    () {
      final valid = List.generate(
        24,
        (hour) => {'hour': hour, 'durationMs': hour == 9 ? 8000 : 0},
      );
      for (final hours in [
        <Map<String, int>>[],
        valid.take(23).toList(),
        valid
            .map(
              (row) => {...row, 'hour': row['hour'] == 23 ? 22 : row['hour']!},
            )
            .toList(),
        valid.reversed.toList(),
        valid
            .map((row) => {...row, 'durationMs': row['hour'] == 9 ? 9000 : 0})
            .toList(),
      ]) {
        expect(
          () => ListeningSnapshot.fromMap(
            recordFixture({'fromUtcMs': 0, 'untilUtcMs': 86400000}, 'confirmed')
              ..['hourly'] = hours,
          ),
          throwsFormatException,
        );
      }
    },
  );
  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'trend buckets preserve zero, uncertainty, paging and semantics dark=$dark scale=$scale',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final start = DateTime(2024, 3, 1);
            final map =
                recordFixture({
                    'fromUtcMs': start.millisecondsSinceEpoch,
                    'untilUtcMs': start
                        .add(const Duration(days: 30))
                        .millisecondsSinceEpoch,
                  }, 'confirmed')
                  ..['days'] = List.generate(
                    30,
                    (index) => {
                      'startUtcMs': DateTime(
                        2024,
                        3,
                        index + 1,
                      ).millisecondsSinceEpoch,
                      'confirmedMs': index == 29 ? 8000 : 0,
                      'unverifiedMs': index == 28 ? 6000 : 0,
                    },
                  )
                  ..['unverifiedMs'] = 6000
                  ..['hourly'] = List.generate(
                    24,
                    (hour) => {
                      'hour': hour,
                      'durationMs': hour == 9 ? 8000 : 0,
                    },
                  );
            tester.view.physicalSize = const Size(360, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    alwaysUse24HourFormat: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ListeningTrends(
                        snapshot: ListeningSnapshot.fromMap(map),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('1-14 of 30'), findsOneWidget);
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            expect(
              tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is IconButton &&
                          widget.tooltip == 'Previous trend buckets',
                    ),
                  )
                  .onPressed,
              isNull,
            );
            expect(find.text('Confirmed: None recorded'), findsWidgets);
            expect(
              find.text(
                'Unverified: ${formatListeningDuration(const Duration(seconds: 6))}',
              ),
              findsOneWidget,
            );
            expect(
              tester
                  .widgetList<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator),
                  )
                  .map((bar) => bar.value)
                  .where((value) => value! > 0),
              [1.0],
            );
            await tester.ensureVisible(find.byTooltip('Next trend buckets'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Next trend buckets'));
            await tester.pumpAndSettle();
            expect(find.text('15-28 of 30'), findsOneWidget);
            await tester.ensureVisible(find.byTooltip('Next trend buckets'));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Next trend buckets'));
            await tester.pumpAndSettle();
            expect(find.text('29-30 of 30'), findsOneWidget);
            expect(
              tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is IconButton &&
                          widget.tooltip == 'Next trend buckets',
                    ),
                  )
                  .onPressed,
              isNull,
            );
            await tester.ensureVisible(find.text('Hourly'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Hourly'));
            await tester.pumpAndSettle();
            expect(find.text('1-14 of 24'), findsOneWidget);
            await tester.ensureVisible(find.text('09:00'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel('09:00'))
                  .getSemanticsData()
                  .value,
              'Confirmed: ${formatListeningDuration(const Duration(seconds: 8))}',
            );
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.byTooltip('Next trend buckets'));
            await tester.pumpAndSettle();
            Focus.of(
              tester.element(find.byIcon(Icons.chevron_right)),
            ).requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.text('15-24 of 24'), findsOneWidget);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  testWidgets(
    'legacy missing hourly data is unavailable rather than fabricated zero',
    (tester) async {
      final snapshot = ListeningSnapshot.fromMap(
        recordFixture({'fromUtcMs': 0, 'untilUtcMs': 86400000}, 'empty'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListeningTrends(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hourly'));
      await tester.pumpAndSettle();
      expect(find.text('Hourly records unavailable.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('0-0 of 0'), findsOneWidget);
    },
  );
  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'actual analytics exposes accessible daily and hourly trend modes at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: ListeningWorkspace(view: ListeningView.analytics),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Hourly'), 350);
        await tester.pumpAndSettle();
        expect(find.text('Daily'), findsOneWidget);
        await tester.tap(find.text('Hourly'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Next trend buckets'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
