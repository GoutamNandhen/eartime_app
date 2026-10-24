import 'package:eartime_app/data/observation_journal.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import 'package:eartime_app/features/settings/observation_journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> observation(
  int sequence, {
  String kind = 'DEVICE_CONNECTED',
}) => {
  'observationId': 'observation-$sequence',
  'sourceId': 'installation-1',
  'sequence': sequence,
  'collectionEpoch': 'collection-1',
  'kind': kind,
  'wallUtcMs': 1000,
  'elapsedMs': 100,
  'bootId': 'boot-1',
  'payloadVersion': 1,
  'confidence': 'UNKNOWN',
  'provenance': 'legacy_collector_wall_and_broker_receipt_elapsed',
  'payload': {'type': kind, 'timestamp': 1000},
};

Map<String, dynamic> page({int after = 0, bool empty = false}) => {
  'schemaVersion': 1,
  'sourceId': 'installation-1',
  'observationCount': empty ? 0 : 2,
  'lastSequence': empty ? 0 : 2,
  'gapCount': 0,
  'conflictCount': 0,
  'pendingCount': 0,
  'rejectedCount': 0,
  'failedCount': 0,
  'lastError': null,
  'nextCursor': empty ? 0 : after + 1,
  'hasMore': !empty && after == 0,
  'observations': empty ? [] : [observation(after + 1)],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  const client = ObservationJournalClient();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native committed identity is additive to the unchanged legacy event',
    () {
      final event = TrackingEvent.fromJson({
        'type': 'DEVICE_CONNECTED',
        'timestamp': 1000,
        'device': {'id': 'legacy-device', 'friendlyName': 'Buds'},
        'journal': observation(1),
      });
      expect(event.journalIdentity?.observationId, 'observation-1');
      expect(event.journalIdentity?.sequence, 1);
      expect(event.device?['id'], 'legacy-device');
      expect(
        TrackingEvent.fromJson({
          'type': 'SYNC_STATE',
          'timestamp': 0,
        }).journalIdentity,
        isNull,
      );
    },
  );

  test('unknown versions and cross-source/out-of-order pages are rejected', () {
    expect(
      () => DurableObservation.fromMap(observation(1)..['payloadVersion'] = 2),
      throwsFormatException,
    );
    expect(
      () =>
          JournalPage.fromMap(page()..['sourceId'] = 'different-installation'),
      throwsFormatException,
    );
    expect(
      () => JournalPage.fromMap(
        page()..['observations'] = [observation(2), observation(1)],
      ),
      throwsFormatException,
    );
  });

  test(
    'replay is read-only and requests bounded cursors without acknowledgement',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return page(after: (call.arguments as Map)['after'] as int);
      });
      final first = await client.read(limit: 1);
      final second = await client.read(after: first.nextCursor, limit: 1);
      expect(second.observations.single.identity.sequence, 2);
      expect(
        calls.map((call) => call.method),
        everyElement('readObservationJournal'),
      );
      await expectLater(client.read(limit: 129), throwsArgumentError);
      expect(calls, hasLength(2));
    },
  );

  test(
    'acknowledgement includes source identity and committed sequence',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'acknowledgeObservations');
        expect(call.arguments, {
          'sourceId': 'installation-1',
          'consumer': 'projection.v1',
          'sequence': 2,
        });
        return 2;
      });
      expect(
        await client.acknowledge(
          JournalIdentity.fromMap(observation(2)),
          'projection.v1',
        ),
        2,
      );
    },
  );

  test('a collection gap remains unknown rather than becoming playback', () {
    final gap = DurableObservation.fromMap(
      observation(1, kind: 'COLLECTION_GAP'),
    );
    expect(gap.isGap, isTrue);
    expect(gap.confidence, 'UNKNOWN');
  });

  testWidgets('journal empty state is visible and does not acknowledge data', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readObservationJournal');
      return page(empty: true);
    });
    await tester.pumpWidget(
      const MaterialApp(home: ObservationJournalScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('No committed observations'), findsOneWidget);
    expect(find.text('Observations: 0'), findsOneWidget);
  });

  testWidgets('journal paging and refresh are bounded, including large text', (
    tester,
  ) async {
    final cursors = <int>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final after = (call.arguments as Map)['after'] as int;
      cursors.add(after);
      return page(after: after);
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ObservationJournalScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh journal'));
    await tester.pumpAndSettle();
    expect(cursors, [0, 1, 0, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'database failure offers a working retry and preserves the error',
    (tester) async {
      var fail = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (fail) {
          throw PlatformException(
            code: 'JOURNAL_READ_FAILED',
            message: 'Storage unavailable',
          );
        }
        return page(empty: true);
      });
      await tester.pumpWidget(
        const MaterialApp(home: ObservationJournalScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Native journal unavailable'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No committed observations'), findsOneWidget);
    },
  );
}
