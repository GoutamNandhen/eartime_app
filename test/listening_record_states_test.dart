import 'dart:async';
import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:eartime_app/providers/listening_projection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> recordFixture(Map args, String state) {
  final confirmed = state == 'confirmed' || state == 'incomplete';
  final zero = state == 'open';
  final count = state == 'empty' ? 0 : 1;
  final at = args['fromUtcMs'] as int;
  return {
    'projectionVersion': 5,
    'sourceId': 'synthetic-record-state',
    'sequence': 1,
    'fromUtcMs': at,
    'untilUtcMs': args['untilUtcMs'],
    'filterDeviceId': args['deviceId'],
    'confirmedMs': confirmed ? 8000 : 0,
    'unverifiedMs': !confirmed && count > 0 && !zero ? 8000 : 0,
    'longestMs': confirmed ? 8000 : 0,
    'averageMs': confirmed ? 8000 : 0,
    'listeningRuns': confirmed ? 1 : 0,
    'gapCount': state == 'incomplete' ? 1 : 0,
    'failedCount': state == 'incomplete' ? 1 : 0,
    'pendingCount': state == 'incomplete' ? 1 : 0,
    'intervalCount': count,
    'nextOffset': count,
    'hasMore': false,
    'deviceOffset': 0,
    'deviceCount': 0,
    'nextDeviceOffset': 0,
    'hasMoreDevices': false,
    'devices': <Object>[],
    'days': [
      {
        'startUtcMs': at,
        'confirmedMs': confirmed ? 8000 : 0,
        'unverifiedMs': !confirmed && count > 0 && !zero ? 8000 : 0,
      },
    ],
    'intervals': [
      if (count > 0)
        {
          'id': 'synthetic-interval',
          'deviceId': null,
          'attribution': confirmed ? 'CONFIRMED' : 'UNVERIFIED',
          'startUtcMs': at,
          'endUtcMs': at + (zero ? 0 : 8000),
          'durationMs': zero ? 0 : 8000,
          'open': zero,
          'live': false,
          'closeReason': zero ? null : 'stopped',
        },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StreamController<dynamic> events;
  setUp(() {
    events = StreamController<dynamic>.broadcast();
    TrackingPlatform.setRawStreamForTesting(events.stream);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    TrackingPlatform.resetForTesting();
    await events.close();
  });

  test(
    'negative counters are unavailable, not accepted as empty or complete history',
    () {
      final args = {'fromUtcMs': 0, 'untilUtcMs': 100000};
      for (final key in [
        'gapCount',
        'pendingCount',
        'failedCount',
        'longestMs',
        'averageMs',
        'listeningRuns',
      ]) {
        expect(
          () => ListeningSnapshot.fromMap(
            recordFixture(args, 'empty')..[key] = -1,
          ),
          throwsFormatException,
          reason: key,
        );
      }
    },
  );
  test(
    'negative chart values and impossible interval durations fail closed',
    () {
      expect(
        () => ProjectedDay({
          'startUtcMs': 0,
          'confirmedMs': -1,
          'unverifiedMs': 0,
        }),
        throwsFormatException,
      );
      for (final hour in [-1, 24]) {
        expect(
          () => ProjectedHour({'hour': hour, 'durationMs': 0}),
          throwsFormatException,
        );
      }
      expect(
        () => ProjectedHour({'hour': 0, 'durationMs': -1}),
        throwsFormatException,
      );
      expect(
        () => ProjectedDeviceTotal({'deviceId': 'synthetic', 'durationMs': -1}),
        throwsFormatException,
      );
      final interval =
          (recordFixture({
                        'fromUtcMs': 0,
                        'untilUtcMs': 100000,
                      }, 'confirmed')['intervals']
                      as List)
                  .single
              as Map;
      expect(
        () => ProjectedInterval({...interval, 'durationMs': 8001}),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'failed history retains one foreground refresh owner and cancels on disposal',
    (tester) async {
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'readListeningProjection') {
          reads++;
          throw PlatformException(code: 'SYNTHETIC_HISTORY_UNAVAILABLE');
        }
        return null;
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final container = ProviderContainer();
      final subscription = container.listen(
        listeningProjectionProvider(
          ListeningWindow(DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
        ),
        (_, _) {},
      );
      await tester.pump();
      await tester.pump();
      expect(reads, 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(reads, 2);
      subscription.close();
      container.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final view in [
    ListeningView.home,
    ListeningView.timeline,
    ListeningView.analytics,
    ListeningView.wellbeing,
  ]) {
    for (final state in [
      'empty',
      'unverified',
      'open',
      'confirmed',
      'incomplete',
      'failure',
      'corrupt',
    ]) {
      testWidgets(
        '${view.name} distinguishes $state history without estimated zero at 3x text',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var failing = state == 'failure' || state == 'corrupt';
          var reads = 0;
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'readListeningPreferences') {
              return {
                'version': 1,
                'themeMode': 'system',
                'dailyGoalMinutes': 0,
              };
            }
            if (call.method == 'readListeningProjection') {
              reads++;
              if (failing && state == 'failure') {
                throw PlatformException(code: 'SYNTHETIC_HISTORY_UNAVAILABLE');
              }
              return recordFixture(Map.of(call.arguments as Map), state)
                ..['gapCount'] = failing ? -1 : (state == 'incomplete' ? 1 : 0);
            }
            return null;
          });
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(3)),
                  child: child!,
                ),
                home: Scaffold(body: ListeningWorkspace(view: view)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (failing) {
            expect(reads, 1);
            expect(
              find.text(
                'Listening history is unavailable. No listening time has been estimated.',
              ),
              findsOneWidget,
            );
            expect(find.text('None recorded'), findsNothing);
            final before = reads;
            failing = false;
            await tester.ensureVisible(find.text('Retry'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Retry'));
            await tester.pumpAndSettle();
            expect(reads, greaterThan(before));
            expect(
              find.text(
                'Listening history is unavailable. No listening time has been estimated.',
              ),
              findsNothing,
            );
          } else {
            final title = switch (state) {
              'empty' => 'No playback records in this period.',
              'unverified' => 'Only unverified playback recorded.',
              'open' => 'Playback observed; duration unknown.',
              _ => 'Confirmed listening recorded.',
            };
            expect(find.text(title), findsOneWidget);
            if (state == 'incomplete') {
              expect(
                find.text(
                  'History coverage is incomplete. Recorded totals are lower bounds.',
                ),
                findsOneWidget,
              );
            }
            await tester.scrollUntilVisible(
              find.text('Confirmed external listening'),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            if (state == 'confirmed' || state == 'incomplete') {
              expect(find.text('0:00:08'), findsWidgets);
            } else {
              expect(find.text('None recorded'), findsWidgets);
              expect(find.text('0:00:00'), findsNothing);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
