import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:eartime_app/providers/listening_projection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eartime_app/core/theme/app_theme.dart';

Map<String, dynamic> fixture() => Map<String, dynamic>.from(
  (jsonDecode(
            File('test/fixtures/listening_continuity.json').readAsStringSync(),
          )
          as Map)['projection']
      as Map,
);

class FixtureProjectionClient extends ListeningProjectionClient {
  int calls = 0;
  Object? error;
  @override
  Future<ListeningSnapshot> read(
    ListeningWindow window, {
    ProjectionCancellation? cancellation,
  }) async {
    calls++;
    if (error != null) throw error!;
    return ListeningSnapshot.fromMap(fixture());
  }
}

Map<String, dynamic> pagedFixture(int offset) => fixture()
  ..['deviceOffset'] = offset
  ..['deviceCount'] = 101
  ..['nextDeviceOffset'] = offset == 0 ? 100 : 101
  ..['hasMoreDevices'] = offset == 0
  ..['devices'] = List.generate(
    offset == 0 ? 100 : 1,
    (index) => {
      'id': 'fixture-device-${offset + index}',
      'name': 'Fixture device ${offset + index + 1}',
      'connected': index == 0,
      'identityVerified': false,
    },
  );

class PagedFixtureProjectionClient extends ListeningProjectionClient {
  final offsets = <int>[];
  @override
  Future<ListeningSnapshot> read(
    ListeningWindow window, {
    ProjectionCancellation? cancellation,
  }) async {
    offsets.add(window.deviceOffset);
    return ListeningSnapshot.fromMap(pagedFixture(window.deviceOffset));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('projection-test');
  test(
    'observer hints are decodable without becoming legacy playing or physical identity claims',
    () {
      final sample = TrackingEvent.fromJson({
        'type': 'OUTPUT_EVIDENCE',
        'timestamp': 1000,
        'globalMusicActive': true,
        'actualOutputKnown': false,
        'confidence': 'UNKNOWN',
        'connectedInventory': [
          {'systemRouteId': 'fixture-a2dp', 'nativeType': 8},
        ],
        'predictedMediaDevices': [
          {'systemRouteId': 'fixture-speaker', 'nativeType': 2},
        ],
      });
      expect(sample.type, 'OUTPUT_EVIDENCE');
      expect(sample.isPlaying, isNull);
      expect(sample.device, isNull);
      expect(sample.deviceId, isNull);
      final status = TrackingEvent.fromJson({
        'type': 'COLLECTOR_STATUS',
        'timestamp': 1001,
        'state': 'HEALTHY',
        'scope': 'inventory_and_global_activity',
      });
      expect(status.state, 'HEALTHY');
      expect(status.isPlaying, isNull);
    },
  );
  test(
    'collector health is scoped, optional for old snapshots and fails closed',
    () {
      final old = ListeningSnapshot.fromMap(fixture());
      expect(old.collectorHealth.state, 'UNKNOWN');
      final map = fixture()
        ..['collectorHealth'] = {
          'contractVersion': 1,
          'state': 'HEALTHY',
          'scope': 'inventory_and_global_activity',
          'reason': 'sample_succeeded',
          'liveListeningEligible': false,
        };
      expect(
        ListeningSnapshot.fromMap(map).collectorHealth.label,
        'Audio inventory and activity observation available',
      );
      expect(ListeningSnapshot.fromMap(map).confirmed, Duration.zero);
      (map['collectorHealth'] as Map)['liveListeningEligible'] = true;
      expect(() => ListeningSnapshot.fromMap(map), throwsFormatException);
      (map['collectorHealth'] as Map)['liveListeningEligible'] = false;
      (map['collectorHealth'] as Map)['state'] = 'FUTURE_STATE';
      expect(() => ListeningSnapshot.fromMap(map), throwsFormatException);
    },
  );

  test('every collector failure state has explicit uncertainty text', () {
    for (final state in [
      'NOT_STARTED',
      'STARTING',
      'TEMPORARILY_UNAVAILABLE',
      'PERMISSION_BLOCKED',
      'SUSPENDED',
      'STOPPED',
      'UNKNOWN',
      'CONTINUITY_LOST',
    ]) {
      final health = ProjectedCollectorHealth({
        'contractVersion': 1,
        'state': state,
        'scope': 'inventory_and_global_activity',
        'liveListeningEligible': false,
      });
      expect(health.label, isNotEmpty);
      expect(health.label, isNot('Listening'));
    }
  });
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final window = ListeningWindow(
    DateTime.fromMillisecondsSinceEpoch(0),
    DateTime.fromMillisecondsSinceEpoch(100000),
  );
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
    'shared native B02 fixture preserves T1 and keeps unverified time out of listening',
    () {
      final snapshot = ListeningSnapshot.fromMap(fixture());
      expect(snapshot.intervals.single.start.millisecondsSinceEpoch, 1000);
      expect(snapshot.intervals.single.end.millisecondsSinceEpoch, 9000);
      expect(snapshot.unverified, const Duration(seconds: 8));
      expect(snapshot.confirmed, Duration.zero);
      expect(snapshot.intervals.single.duration, snapshot.unverified);
      expect(snapshot.days.single.unverified, snapshot.unverified);
    },
  );

  test(
    'RPC requests the bounded native window and never replays events into a live reducer',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readListeningProjection');
        expect(call.arguments, {
          'fromUtcMs': 0,
          'untilUtcMs': 100000,
          'offset': 0,
          'limit': 100,
          'deviceOffset': 0,
        });
        return fixture();
      });
      final result = await const ListeningProjectionClient(
        channel: channel,
      ).read(window);
      expect(result.sequence, 3);
      expect(result.intervals.single.start.millisecondsSinceEpoch, 1000);
    },
  );

  test(
    'projection rejects future schema and mismatched query windows',
    () async {
      expect(
        () => ListeningSnapshot.fromMap(fixture()..['projectionVersion'] = 99),
        throwsFormatException,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => fixture()..['fromUtcMs'] = 1,
      );
      await expectLater(
        const ListeningProjectionClient(channel: channel).read(window),
        throwsFormatException,
      );
      await expectLater(
        const ListeningProjectionClient(
          channel: channel,
        ).read(ListeningWindow(window.until, window.from)),
        throwsArgumentError,
      );
    },
  );

  test(
    'device paging uses an independent request and provider cache identity',
    () async {
      final next = ListeningWindow(
        window.from,
        window.until,
        deviceOffset: 100,
      );
      expect(next, isNot(window));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect((call.arguments as Map)['deviceOffset'], 100);
        expect((call.arguments as Map)['offset'], 0);
        return pagedFixture(100);
      });
      final page = await const ListeningProjectionClient(
        channel: channel,
      ).read(next);
      expect(page.devices.single.name, 'Fixture device 101');
      expect(page.nextDeviceOffset, 101);
      expect(page.hasMoreDevices, isFalse);
      expect(page.confirmed, Duration.zero);
    },
  );

  test('wrong device page and nonadvancing cursors fail visibly', () async {
    final next = ListeningWindow(window.from, window.until, deviceOffset: 100);
    messenger.setMockMethodCallHandler(channel, (_) async => pagedFixture(0));
    await expectLater(
      const ListeningProjectionClient(channel: channel).read(next),
      throwsFormatException,
    );
    expect(
      () =>
          ListeningSnapshot.fromMap(pagedFixture(0)..['nextDeviceOffset'] = 0),
      throwsFormatException,
    );
    await expectLater(
      const ListeningProjectionClient(
        channel: channel,
      ).read(ListeningWindow(window.from, window.until, deviceOffset: -1)),
      throwsArgumentError,
    );
    await expectLater(
      const ListeningProjectionClient(
        channel: channel,
      ).read(ListeningWindow(window.from, window.until, deviceOffset: 1 << 40)),
      throwsArgumentError,
    );
  });

  testWidgets(
    'Devices navigates beyond 100 rows and back without a misleading date filter',
    (tester) async {
      final client = PagedFixtureProjectionClient();
      final container = ProviderContainer(
        overrides: [
          listeningProjectionClientProvider.overrideWithValue(client),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ListeningWorkspace(view: ListeningView.devices),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1-100 of 101'), findsOneWidget);
      expect(find.byTooltip('Select dates'), findsNothing);
      await tester.tap(find.byTooltip('Next devices'));
      await tester.pump();
      await tester.pump();
      expect(find.text('101-101 of 101'), findsOneWidget);
      expect(find.text('Fixture device 101'), findsOneWidget);
      expect(client.offsets, [0, 100]);
      await tester.tap(find.byTooltip('Previous devices'));
      await tester.pump();
      await tester.pump();
      expect(find.text('1-100 of 101'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'disposing an unresolved RPC cancels its deadline and ignores late completion',
    (tester) async {
      final pending = Completer<dynamic>();
      messenger.setMockMethodCallHandler(channel, (_) => pending.future);
      final request = ProjectionCancellation();
      final result = const ListeningProjectionClient(
        channel: channel,
      ).read(window, cancellation: request);
      final assertion = expectLater(result, throwsStateError);
      request.cancel();
      await assertion;
      pending.complete(fixture());
      await tester.pump();
    },
  );

  for (final view in ListeningView.values) {
    testWidgets(
      '${view.name} uses the shared snapshot at narrow width and large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = FixtureProjectionClient();
        final container = ProviderContainer(
          overrides: [
            listeningProjectionClientProvider.overrideWithValue(client),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(body: ListeningWorkspace(view: view)),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(client.calls, 1);
        if (view != ListeningView.devices) {
          expect(find.text('0:00:00'), findsWidgets);
          expect(find.text('0:00:08'), findsWidgets);
          expect(find.text('Confirmed external listening'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'projection failures are visible and retry reads the same source',
    (tester) async {
      final client = FixtureProjectionClient()
        ..error = StateError('journal unavailable');
      final container = ProviderContainer(
        overrides: [
          listeningProjectionClientProvider.overrideWithValue(client),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ListeningWorkspace(view: ListeningView.home)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      client.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('0:00:08'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'one source is shared by duplicate consumers and cancelled on disposal',
    (tester) async {
      final client = FixtureProjectionClient();
      final container = ProviderContainer(
        overrides: [
          listeningProjectionClientProvider.overrideWithValue(client),
        ],
      );
      final first = container.listen(
        listeningProjectionProvider(window),
        (_, _) {},
      );
      final second = container.listen(
        listeningProjectionProvider(window),
        (_, _) {},
      );
      await tester.pump();
      expect(client.calls, 1);
      first.close();
      second.close();
      container.dispose();
      await tester.pump();
    },
  );

  test(
    'duration display handles subminute and multi-day values without division by zero',
    () {
      expect(formatListeningDuration(const Duration(seconds: 9)), '0:00:09');
      expect(formatListeningDuration(const Duration(hours: 25)), '25:00:00');
    },
  );

  for (final width in [360.0, 1200.0]) {
    testWidgets('Home visual layout at ${width.toInt()} pixels', (
      tester,
    ) async {
      if (const bool.fromEnvironment('EARTIME_CAPTURE_QA')) {
        await tester.runAsync(() async {
          final regular = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    const String.fromEnvironment('EARTIME_QA_FONT'),
                  ).readAsBytesSync(),
                ),
              ),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    'build/app/intermediates/flutter/debug/flutter_assets/fonts/MaterialIcons-Regular.otf',
                  ).readAsBytesSync(),
                ),
              ),
            );
          await regular.load();
          await icons.load();
        });
      }
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          listeningProjectionClientProvider.overrideWithValue(
            FixtureProjectionClient(),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RepaintBoundary(
              child: Scaffold(
                body: ListeningWorkspace(view: ListeningView.home),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EARTIME_CAPTURE_QA')) {
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('../build/qa/home-${width.toInt()}.png'),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });
  }
}
