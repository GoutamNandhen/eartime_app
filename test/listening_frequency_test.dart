import 'dart:async';
import 'dart:convert';
import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'listening_record_states_test.dart' show recordFixture;

Map<String, dynamic> frequencyFixture(Map args) {
  final value = Map<String, dynamic>.from(recordFixture(args, 'confirmed'));
  final at = args['fromUtcMs'] as int;
  value['intervals'] = List.generate(
    2,
    (index) => {
      'id': 'synthetic-frequency-$index',
      'deviceId': null,
      'attribution': 'CONFIRMED',
      'startUtcMs': at + index * 5000,
      'endUtcMs': at + index * 5000 + 4000,
      'durationMs': 4000,
      'open': false,
      'live': false,
      'closeReason': 'stopped',
    },
  );
  value['intervalCount'] = 2;
  value['nextOffset'] = 2;
  value['frequencyContractVersion'] = 1;
  value['measuredSessionStarts'] = 2;
  value['sessionContractVersion'] = 1;
  value['sessions'] = List.generate(
    2,
    (index) => {
      'id': 'synthetic-frequency-$index',
      'attribution': 'CONFIRMED',
      'startUtcMs': at + index * 5000,
      'endUtcMs': at + index * 5000 + 4000,
      'durationMs': 4000,
      'segmentCount': 1,
      'deviceCount': 0,
      'incomplete': false,
      'clipped': false,
    },
  );
  value['sessionCount'] = 2;
  value['nextSessionOffset'] = 2;
  value['hasMoreSessions'] = false;
  value['measuredSessionCount'] = 2;
  value['longestSessionMs'] = 4000;
  value['averageSessionMs'] = 4000;
  (value['days'] as List).single['measuredSessionStarts'] = 2;
  value['hourly'] = List.generate(
    24,
    (hour) => {
      'hour': hour,
      'durationMs': hour == 0 ? 8000 : 0,
      'measuredSessionStarts': hour == 0 ? 2 : 0,
    },
  );
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  late StreamController<dynamic> events;
  setUp(() {
    events = StreamController<dynamic>.broadcast();
    TrackingPlatform.setRawStreamForTesting(events.stream);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TrackingPlatform.resetForTesting();
    await events.close();
  });
  test(
    'frequency contracts reject missing, negative, unsupported and non-reconciling counts',
    () {
      final original = frequencyFixture({
        'fromUtcMs': 0,
        'untilUtcMs': 86400000,
      });
      expect(ListeningSnapshot.fromMap(original).measuredSessionStarts, 2);
      expect(
        ListeningSnapshot.fromMap(
          recordFixture({'fromUtcMs': 0, 'untilUtcMs': 86400000}, 'empty'),
        ).measuredSessionStarts,
        isNull,
      );
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (map) => map.remove('sessionContractVersion'),
        (map) => map['frequencyContractVersion'] = 2,
        (map) => map['measuredSessionStarts'] = -1,
        (map) => map.remove('measuredSessionStarts'),
        (map) => (map['days'] as List).single.remove('measuredSessionStarts'),
        (map) => (map['hourly'] as List).first['measuredSessionStarts'] = 3,
        (map) {
          map['measuredSessionStarts'] = 3;
          (map['days'] as List).single['measuredSessionStarts'] = 3;
          (map['hourly'] as List).first['measuredSessionStarts'] = 3;
        },
      ]) {
        final map = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(original)) as Map,
        );
        mutate(map);
        expect(() => ListeningSnapshot.fromMap(map), throwsFormatException);
      }
    },
  );
  for (final view in [ListeningView.analytics, ListeningView.wellbeing]) {
    testWidgets(
      'actual ${view.name} shows native measured-start frequency without a new timer',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (call) async => call.method == 'readListeningProjection'
                  ? frequencyFixture(call.arguments as Map)
                  : null,
            );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: ListeningWorkspace(view: view)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('2 measured session starts in this period'),
          300,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('2 measured session starts in this period'),
          findsOneWidget,
        );
        if (view == ListeningView.analytics) {
          await tester.scrollUntilVisible(find.text('Measured starts: 2'), 300);
          await tester.pumpAndSettle();
          expect(find.text('Measured starts: 2'), findsOneWidget);
          await tester.ensureVisible(find.text('Hourly'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hourly'));
          await tester.pumpAndSettle();
          expect(find.text('Measured starts: 2'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
