import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/providers/data_providers.dart';

void main() {
  group('EarTime Phase 2A — Shared EventChannel Ownership Tests', () {
    late StreamController<dynamic> rawController;

    setUp(() {
      rawController = StreamController<dynamic>.broadcast();
      TrackingPlatform.setRawStreamForTesting(rawController.stream);
    });

    tearDown(() async {
      TrackingPlatform.resetForTesting();
      await rawController.close();
    });

    test('Requirement A: Multiple consumers can subscribe simultaneously', () async {
      expect(identical(TrackingPlatform.eventStream, TrackingPlatform.eventStream), isTrue,
          reason: 'Repeated access to eventStream must return the identical broadcast stream');

      final events1 = <TrackingEvent>[];
      final events2 = <TrackingEvent>[];
      final events3 = <TrackingEvent>[];

      final sub1 = TrackingPlatform.eventStream.listen(events1.add);
      final sub2 = TrackingPlatform.eventStream.listen(events2.add);
      final sub3 = TrackingPlatform.eventStream.listen(events3.add);

      expect(TrackingPlatform.hasActiveListeners, isTrue);

      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'dev_test_mac_1',
        'device': {'friendlyName': 'Test Pods'},
        'timestamp': 1700000000000,
      });

      await pumpEventQueue();

      expect(events1.length, 1);
      expect(events1.first.type, 'DEVICE_CONNECTED');
      expect(events1.first.deviceId, 'dev_test_mac_1');

      expect(events2.length, 1);
      expect(events2.first.type, 'DEVICE_CONNECTED');
      expect(events2.first.deviceId, 'dev_test_mac_1');

      expect(events3.length, 1);
      expect(events3.first.type, 'DEVICE_CONNECTED');
      expect(events3.first.deviceId, 'dev_test_mac_1');

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();

      expect(TrackingPlatform.hasActiveListeners, isFalse);
    });

    test('Requirement B: Pipeline + BLE consumers all receive their relevant events', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Activate pipeline
      container.read(trackingPipelineProvider);

      // Listen to BLE providers
      final bleNotifications = <TrackingEvent>[];
      container.listen<AsyncValue<TrackingEvent>>(bleNotificationProvider, (_, next) {
        if (next.hasValue && next.value != null) {
          bleNotifications.add(next.value!);
        }
      });

      final bleDiagnostics = <TrackingEvent>[];
      container.listen<AsyncValue<TrackingEvent>>(bleDiagnosticStateProvider, (_, next) {
        if (next.hasValue && next.value != null) {
          bleDiagnostics.add(next.value!);
        }
      });

      final bleDiscoveries = <Map<String, dynamic>>[];
      container.listen<AsyncValue<Map<String, dynamic>>>(bleDiscoveryResultProvider, (_, next) {
        if (next.hasValue && next.value != null) {
          bleDiscoveries.add(next.value!);
        }
      });

      // 1. Emit BLE_NOTIFICATION
      rawController.add({
        'type': 'BLE_NOTIFICATION',
        'payload': 'AABBCCDDEEFF',
        'timestamp': 1700000000010,
      });
      await pumpEventQueue();

      expect(bleNotifications.length, 1);
      expect(bleNotifications.first.payload, 'AABBCCDDEEFF');
      expect(bleDiagnostics.isEmpty, isTrue);
      expect(bleDiscoveries.isEmpty, isTrue);

      // 2. Emit BLE_DIAGNOSTIC_STATE
      rawController.add({
        'type': 'BLE_DIAGNOSTIC_STATE',
        'state': 'CONNECTED',
        'message': 'GATT connection active',
        'timestamp': 1700000000020,
      });
      await pumpEventQueue();

      expect(bleDiagnostics.length, 1);
      expect(bleDiagnostics.first.state, 'CONNECTED');
      expect(bleDiagnostics.first.message, 'GATT connection active');

      // 3. Emit BLE_DISCOVERY_RESULT
      rawController.add({
        'type': 'BLE_DISCOVERY_RESULT',
        'device': {
          'name': 'Earbuds V2',
          'address': '11:22:33:44:55:66',
        },
        'timestamp': 1700000000030,
      });
      await pumpEventQueue();

      expect(bleDiscoveries.length, 1);
      expect(bleDiscoveries.first['name'], 'Earbuds V2');
      expect(bleDiscoveries.first['address'], '11:22:33:44:55:66');

      // 4. Emit DEVICE_CONNECTED and verify tracking pipeline processes it
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': '11:22:33:44:55:66',
        'device': {
          'id': '11:22:33:44:55:66',
          'friendlyName': 'Earbuds V2',
          'connectionType': 'bluetooth',
        },
        'timestamp': 1700000000040,
      });
      await pumpEventQueue();

      final liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNotNull);
      expect(liveState.activeDevice!.canonicalDeviceId, '11:22:33:44:55:66');
      expect(liveState.activeDevice!.displayName, 'Earbuds V2');

      // Verify event was inserted into drift database
      final events = await db.watchAllEvents().first;
      expect(events.any((e) => e.eventType == 'DEVICE_CONNECTED' && e.canonicalDeviceId == '11:22:33:44:55:66'), isTrue);

      // 5. Emit PLAYBACK_STARTED and verify playback state updates
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'deviceId': '11:22:33:44:55:66',
        'timestamp': 1700000000050,
      });
      await pumpEventQueue();

      final playingState = container.read(liveSessionProvider);
      expect(playingState.activeDevice!.playbackState, PlaybackState.playing);
      expect(playingState.activeDevice!.currentPlaybackStartTime, isNotNull);

      // 6. Emit PLAYBACK_PAUSED and verify timer pause
      rawController.add({
        'type': 'PLAYBACK_PAUSED',
        'deviceId': '11:22:33:44:55:66',
        'timestamp': 1700000003000,
      });
      await pumpEventQueue();

      final pausedState = container.read(liveSessionProvider);
      expect(pausedState.activeDevice!.playbackState, PlaybackState.paused);
      expect(pausedState.activeDevice!.currentPlaybackStartTime, isNull);
    });

    test('Requirement C: Cancelling one consumer does not interrupt the others', () async {
      final eventsA = <TrackingEvent>[];
      final eventsB = <TrackingEvent>[];
      final eventsC = <TrackingEvent>[];

      final subA = TrackingPlatform.eventStream.listen(eventsA.add);
      final subB = TrackingPlatform.eventStream.listen(eventsB.add);
      final subC = TrackingPlatform.eventStream.listen(eventsC.add);

      // Event 1 to all
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'dev_common',
        'timestamp': 1700000000000,
      });
      await pumpEventQueue();

      expect(eventsA.length, 1);
      expect(eventsB.length, 1);
      expect(eventsC.length, 1);

      // Cancel B
      await subB.cancel();
      expect(TrackingPlatform.hasActiveListeners, isTrue,
          reason: 'StreamController should still have active listeners A and C');

      // Event 2 to remaining
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'deviceId': 'dev_common',
        'timestamp': 1700000000100,
      });
      await pumpEventQueue();

      expect(eventsA.length, 2);
      expect(eventsB.length, 1, reason: 'Consumer B was cancelled and must receive no further events');
      expect(eventsC.length, 2);

      // Cancel A
      await subA.cancel();
      expect(TrackingPlatform.hasActiveListeners, isTrue,
          reason: 'StreamController should still have active listener C');

      // Event 3 to C
      rawController.add({
        'type': 'PLAYBACK_PAUSED',
        'deviceId': 'dev_common',
        'timestamp': 1700000000200,
      });
      await pumpEventQueue();

      expect(eventsA.length, 2);
      expect(eventsB.length, 1);
      expect(eventsC.length, 3);

      // Cancel C
      await subC.cancel();
      expect(TrackingPlatform.hasActiveListeners, isFalse,
          reason: 'All consumers cancelled, no active listeners remain');
    });

    test('Requirement D: Provider disposal cancels the pipeline\'s own subscription', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);

      expect(TrackingPlatform.hasActiveListeners, isFalse);

      // Reading trackingPipelineProvider attaches the pipeline subscription
      container.read(trackingPipelineProvider);
      expect(TrackingPlatform.hasActiveListeners, isTrue,
          reason: 'trackingPipelineProvider should establish a listener on TrackingPlatform.eventStream');

      // Emit event through pipeline to confirm it is active
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'dev_lifecycle_test',
        'device': {'id': 'dev_lifecycle_test', 'friendlyName': 'Lifecycle Buds'},
        'timestamp': 1700000000000,
      });
      await pumpEventQueue();

      final stateBefore = container.read(liveSessionProvider);
      expect(stateBefore.activeDevice?.canonicalDeviceId, 'dev_lifecycle_test');

      // Disposing container triggers ref.onDispose on trackingPipelineProvider
      container.dispose();
      await db.close();
      await pumpEventQueue();

      expect(TrackingPlatform.hasActiveListeners, isFalse,
          reason: 'Disposing trackingPipelineProvider must cancel its StreamSubscription');
    });

    test('Requirement E: End-to-end SYNC_STATE payload parsing through shared stream', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      container.read(trackingPipelineProvider);

      // Feed root-level SYNC_STATE payload over the shared stream
      rawController.add({
        'type': 'SYNC_STATE',
        'connectedDevices': [
          {
            'id': '02:11:22:33:44:55',
            'friendlyName': 'OnePlus Nord Buds 3 Pro',
            'connectionType': 'bluetooth',
            'nativeType': 8,
          }
        ],
        'isPlaying': true,
        'timestamp': 1700000000000,
      });
      await pumpEventQueue();

      final state = container.read(liveSessionProvider);
      expect(state.isInitialized, isTrue);
      expect(state.activeDevice, isNotNull);
      expect(state.activeDevice!.canonicalDeviceId, '02:11:22:33:44:55');
      expect(state.activeDevice!.displayName, 'OnePlus Nord Buds 3 Pro');
      expect(state.activeDevice!.playbackState, PlaybackState.playing);
      expect(state.activeDevice!.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });
  });
}
