import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'listening_calendar_test.dart' show calendarReply;

Map<String, Object?> session(int index, int start) => {
  'id': 'synthetic-session-$index',
  'attribution': 'CONFIRMED',
  'startUtcMs': start,
  'endUtcMs': start + 5000,
  'durationMs': 5000,
  'segmentCount': 2,
  'deviceCount': 1,
  'incomplete': false,
  'clipped': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  test('session metadata rejects fabricated union lengths and counters', () {
    final value = session(0, 1000);
    expect(ProjectedSession(value).duration, const Duration(seconds: 5));
    for (final invalid in [
      {...value, 'durationMs': 6000},
      {...value, 'durationMs': -1},
      {...value, 'segmentCount': 0},
      {...value, 'deviceCount': 3},
      {...value, 'attribution': 'UNKNOWN'},
      {...value, 'endUtcMs': 0},
    ]) {
      expect(() => ProjectedSession(invalid), throwsFormatException);
    }
  });
  test('session detail rejects mismatched pagination and confidence', () {
    final part = {
      'id': 'synthetic-part',
      'deviceId': null,
      'attribution': 'CONFIRMED',
      'startUtcMs': 1000,
      'endUtcMs': 6000,
      'durationMs': 5000,
      'open': false,
      'live': false,
      'closeReason': 'stopped',
    };
    final value = {
      ...session(0, 1000),
      'offset': 0,
      'nextOffset': 1,
      'hasMore': true,
      'intervals': [part],
    };
    expect(ProjectedSessionDetail(value).nextOffset, 1);
    for (final invalid in [
      {...value, 'nextOffset': 2},
      {...value, 'hasMore': false},
      {...value, 'offset': -1},
      {
        ...value,
        'intervals': [
          {...part, 'attribution': 'UNVERIFIED'},
        ],
      },
    ]) {
      expect(() => ProjectedSessionDetail(invalid), throwsFormatException);
    }
  });
  test('client refuses a mismatched or missing session identity', () async {
    final window = ListeningWindow(
      DateTime(2026, 10, 25),
      DateTime(2026, 10, 26),
      sessionId: 'synthetic-session-0',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final reply = calendarReply(call.arguments as Map);
          reply['sessionDetail'] = null;
          return reply;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await expectLater(
      const ListeningProjectionClient().read(window),
      throwsFormatException,
    );
  });
  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'Timeline opens native grouped detail and pages at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method != 'readListeningProjection') return null;
              final args = call.arguments as Map;
              calls.add(args);
              final start = args['fromUtcMs'] as int;
              final offset = args['offset'] as int;
              final reply = calendarReply(args);
              reply.addAll({
                'sessionContractVersion': 1,
                'sessionCount': 101,
                'measuredSessionCount': 101,
                'longestSessionMs': 5000,
                'averageSessionMs': 5000,
                'sessions': List.generate(
                  offset == 0 ? 100 : 1,
                  (i) => session(i + offset, start + (i + offset) * 10000),
                ),
                'nextSessionOffset': offset == 0 ? 100 : 101,
                'hasMoreSessions': offset == 0,
                'sessionDetail': args['sessionId'] == null
                    ? null
                    : {
                        ...session(0, start),
                        'offset': offset,
                        'nextOffset': 2,
                        'hasMore': false,
                        'intervals': [
                          for (var i = 0; i < 2; i++)
                            {
                              'id': 'synthetic-part-$i',
                              'deviceId':
                                  '00000000-0000-4000-8000-000000000001',
                              'attribution': 'CONFIRMED',
                              'startUtcMs': start + i * 1000,
                              'endUtcMs': start + 5000,
                              'durationMs': 5000 - i * 1000,
                              'open': false,
                              'live': false,
                              'closeReason': 'stopped',
                              'transition': 'PAUSED',
                            },
                        ],
                      },
              });
              return reply;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              listeningCalendarNowProvider.overrideWithValue(
                () => DateTime(2026, 10, 25),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: ListeningWorkspace(view: ListeningView.timeline),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Sessions'), 300);
        expect(find.text('Sessions'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Recorded duration: 0:00:05').first,
          300,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Recorded duration: 0:00:05').first);
        await tester.pumpAndSettle();
        expect(find.text('Session details'), findsOneWidget);
        for (var i = 0; i < 2; i++) {
          final part = find.byKey(ValueKey('session-part-synthetic-part-$i'));
          await tester.scrollUntilVisible(part, 300, maxScrolls: 50);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: part, matching: find.text('Pause observed')),
            findsOneWidget,
          );
        }
        final detailCalls = calls
            .where((call) => call['sessionId'] != null)
            .toList();
        expect(detailCalls, isNotEmpty);
        expect(
          detailCalls.every(
            (call) =>
                call['sessionId'] == 'synthetic-session-0' &&
                call['offset'] == 0,
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byTooltip('Next sessions'),
          2000,
          maxScrolls: 500,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next sessions'));
        await tester.pumpAndSettle();
        expect(calls.last['offset'], 100);
        expect(calls.last['sessionId'], isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
