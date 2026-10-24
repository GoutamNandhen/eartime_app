import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/domain/models/connection_state.dart';
import 'package:eartime_app/providers/data_providers.dart';

void main() {
  group('EarTime Phase 2B — Stale Device Attribution & Disconnect Correctness Tests', () {
    late StreamController<dynamic> rawController;
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      rawController = StreamController<dynamic>.broadcast();
      TrackingPlatform.setRawStreamForTesting(rawController.stream);
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);
      // Activate the tracking pipeline
      container.read(trackingPipelineProvider);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      TrackingPlatform.resetForTesting();
      await rawController.close();
    });

    test('Scenario A: Connect A -> Play -> Disconnect A -> Device-less Playback (Speaker)', () async {
      // 1. Connect Earbuds A
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:01',
        'device': {
          'id': 'AA:BB:CC:DD:EE:01',
          'friendlyName': 'Earbuds A',
          'connectionType': 'bluetooth',
        },
        'timestamp': 1000000,
      });
      await pumpEventQueue();

      var liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNotNull);
      expect(liveState.activeDevice!.canonicalDeviceId, 'AA:BB:CC:DD:EE:01');
      expect(liveState.activeDevice!.displayName, 'Earbuds A');

      // 2. Playback starts on Earbuds A
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'deviceId': 'AA:BB:CC:DD:EE:01',
        'timestamp': 1001000,
      });
      await pumpEventQueue();

      liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice!.playbackState, PlaybackState.playing);
      expect(liveState.activeDevice!.currentPlaybackStartTime, isNotNull);

      // Verify DB has 2 events so far
      var dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 2);

      // 3. Disconnect Earbuds A
      rawController.add({
        'type': 'DEVICE_DISCONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:01',
        'device': {
          'id': 'AA:BB:CC:DD:EE:01',
          'friendlyName': 'Earbuds A',
        },
        'timestamp': 1002000,
      });
      await pumpEventQueue();

      liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNull,
          reason: 'activeDevice must be cleared upon disconnect');

      dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 3);
      expect(dbEvents.any((e) => e.eventType == 'DEVICE_DISCONNECTED' && e.canonicalDeviceId == 'AA:BB:CC:DD:EE:01'), isTrue);

      // 4. Device-less playback starts (phone speaker audio)
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        // deviceId is explicitly omitted/null from native
        'timestamp': 1005000,
      });
      await pumpEventQueue();

      // UI/Notifier assertion: Earbuds A must NOT be resurrected
      liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNull,
          reason: 'Speaker playback after disconnect must NEVER resurrect disconnected Earbuds A');

      // Persistence assertion: Drift database must NOT contain any new playback events
      dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 3,
          reason: 'No new event should be inserted into the database for speaker playback');

      final earbudPlaybackEvents = dbEvents.where(
        (e) => e.canonicalDeviceId == 'AA:BB:CC:DD:EE:01' && (e.eventType == 'PLAYBACK_STARTED' || e.eventType == 'PLAYBACK_RESUMED'),
      ).toList();
      expect(earbudPlaybackEvents.length, 1,
          reason: 'Only the initial connected playback event should exist in history');
      expect(earbudPlaybackEvents.first.timestamp, 1001000);

      final eventsAfterDisconnect = dbEvents.where((e) => e.timestamp > 1002000).toList();
      expect(eventsAfterDisconnect, isEmpty,
          reason: 'Zero events should be persisted with timestamps after disconnection');
    });

    test('Scenario B: Connect A -> Disconnect A -> Device-less Playback Paused', () async {
      // 1. Connect Earbuds A
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:02',
        'device': {
          'id': 'AA:BB:CC:DD:EE:02',
          'friendlyName': 'Earbuds A',
        },
        'timestamp': 2000000,
      });
      await pumpEventQueue();

      // 2. Disconnect Earbuds A
      rawController.add({
        'type': 'DEVICE_DISCONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:02',
        'timestamp': 2001000,
      });
      await pumpEventQueue();

      var liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNull);

      // 3. Device-less PLAYBACK_PAUSED arrives
      rawController.add({
        'type': 'PLAYBACK_PAUSED',
        'timestamp': 2002000,
      });
      await pumpEventQueue();

      // Assert device is not recreated as connected or paused
      liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNull,
          reason: 'Device-less PLAYBACK_PAUSED must not recreate disconnected device');

      final dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 2,
          reason: 'Only CONNECTED and DISCONNECTED events should exist');
      expect(dbEvents.any((e) => e.eventType == 'PLAYBACK_PAUSED'), isFalse);
    });

    test('Scenario C: Connect A -> Native device-less PLAYBACK_STARTED while A is connected', () async {
      // 1. Connect Earbuds A
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:03',
        'device': {
          'id': 'AA:BB:CC:DD:EE:03',
          'friendlyName': 'Earbuds Active',
          'connectionType': 'bluetooth',
        },
        'timestamp': 3000000,
      });
      await pumpEventQueue();

      // 2. Native emits PLAYBACK_STARTED without deviceId while A is legitimately connected
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'timestamp': 3001000,
      });
      await pumpEventQueue();

      final liveState = container.read(liveSessionProvider);
      expect(liveState.activeDevice, isNotNull);
      expect(liveState.activeDevice!.canonicalDeviceId, 'AA:BB:CC:DD:EE:03');
      expect(liveState.activeDevice!.displayName, 'Earbuds Active');
      expect(liveState.activeDevice!.connectionState, ConnectionState.connected);
      expect(liveState.activeDevice!.playbackState, PlaybackState.playing);
      expect(liveState.activeDevice!.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(3001000));

      final dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 2);
      expect(dbEvents.any((e) => e.eventType == 'PLAYBACK_STARTED' && e.canonicalDeviceId == 'AA:BB:CC:DD:EE:03'), isTrue);

      // 3. Native emits device-less PLAYBACK_PAUSED while A is still connected
      rawController.add({
        'type': 'PLAYBACK_PAUSED',
        'timestamp': 3004000,
      });
      await pumpEventQueue();

      final pausedState = container.read(liveSessionProvider);
      expect(pausedState.activeDevice!.playbackState, PlaybackState.paused);
      expect(pausedState.activeDevice!.currentPlaybackStartTime, isNull);

      final dbEventsPaused = await db.watchAllEvents().first;
      expect(dbEventsPaused.length, 3);
      expect(dbEventsPaused.any((e) => e.eventType == 'PLAYBACK_PAUSED' && e.canonicalDeviceId == 'AA:BB:CC:DD:EE:03'), isTrue);
    });

    test('Scenario D: Connect A -> SYNC_STATE with zero connected devices -> Device-less playback', () async {
      // 1. Connect Earbuds A
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:04',
        'device': {
          'id': 'AA:BB:CC:DD:EE:04',
          'friendlyName': 'Earbuds Sync Test',
        },
        'timestamp': 4000000,
      });
      await pumpEventQueue();

      expect(container.read(liveSessionProvider).activeDevice, isNotNull);

      // 2. SYNC_STATE with empty connectedDevices list
      rawController.add({
        'type': 'SYNC_STATE',
        'connectedDevices': [],
        'isPlaying': false,
        'timestamp': 4001000,
      });
      await pumpEventQueue();

      expect(container.read(liveSessionProvider).activeDevice, isNull,
          reason: 'SYNC_STATE with no devices must clear activeDevice and invalidate attribution');

      // 3. Device-less playback starts
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'timestamp': 4002000,
      });
      await pumpEventQueue();

      expect(container.read(liveSessionProvider).activeDevice, isNull,
          reason: 'Earbuds A must not be resurrected after SYNC_STATE invalidated attribution');

      final dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 1,
          reason: 'Only the initial DEVICE_CONNECTED event should be persisted');
      expect(dbEvents.any((e) => e.eventType == 'PLAYBACK_STARTED'), isFalse);
    });

    test('Scenario E: Reconnect A legitimately -> Playback attributed to A again', () async {
      // 1. Connect Earbuds A
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:05',
        'device': {
          'id': 'AA:BB:CC:DD:EE:05',
          'friendlyName': 'Earbuds Reconnect',
          'connectionType': 'bluetooth',
        },
        'timestamp': 5000000,
      });
      await pumpEventQueue();

      // 2. Disconnect Earbuds A
      rawController.add({
        'type': 'DEVICE_DISCONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:05',
        'timestamp': 5001000,
      });
      await pumpEventQueue();

      expect(container.read(liveSessionProvider).activeDevice, isNull);

      // 3. Speaker playback during disconnection (must be ignored)
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'timestamp': 5002000,
      });
      await pumpEventQueue();

      expect(container.read(liveSessionProvider).activeDevice, isNull);

      // 4. Legitimate reconnection of Earbuds A
      rawController.add({
        'type': 'DEVICE_CONNECTED',
        'deviceId': 'AA:BB:CC:DD:EE:05',
        'device': {
          'id': 'AA:BB:CC:DD:EE:05',
          'friendlyName': 'Earbuds Reconnect',
          'connectionType': 'bluetooth',
        },
        'timestamp': 5003000,
      });
      await pumpEventQueue();

      expect(container.read(liveSessionProvider).activeDevice, isNotNull);
      expect(container.read(liveSessionProvider).activeDevice!.canonicalDeviceId, 'AA:BB:CC:DD:EE:05');

      // 5. Subsequent playback starts while Earbuds A is reconnected
      rawController.add({
        'type': 'PLAYBACK_STARTED',
        'timestamp': 5004000,
      });
      await pumpEventQueue();

      final reconnectedPlayingState = container.read(liveSessionProvider);
      expect(reconnectedPlayingState.activeDevice!.playbackState, PlaybackState.playing);
      expect(reconnectedPlayingState.activeDevice!.currentPlaybackStartTime, isNotNull);

      // Verify Drift DB persistence
      final dbEvents = await db.watchAllEvents().first;
      expect(dbEvents.length, 4,
          reason: 'Expected 4 events: CONNECTED -> DISCONNECTED -> CONNECTED -> PLAYBACK_STARTED');
      expect(dbEvents.where((e) => e.eventType == 'PLAYBACK_STARTED').length, 1);
      expect(dbEvents.firstWhere((e) => e.eventType == 'PLAYBACK_STARTED').timestamp, 5004000);
      expect(dbEvents.firstWhere((e) => e.eventType == 'PLAYBACK_STARTED').canonicalDeviceId, 'AA:BB:CC:DD:EE:05');
    });
  });
}
