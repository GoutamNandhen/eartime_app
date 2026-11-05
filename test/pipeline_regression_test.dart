import 'dart:async';

import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/domain/logic/analytics_calculator.dart';
import 'package:eartime_app/domain/logic/session_manager.dart';
import 'package:eartime_app/domain/models/eartime_event.dart';
import 'package:eartime_app/domain/models/listening_session.dart';
import 'package:eartime_app/domain/models/live_session_state.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const buds = 'AA:BB:CC:DD:EE:FF';
const budsName = 'OnePlus Nord Buds 3 Pro';

Map<String, dynamic> budsDevice([String id = buds, String name = budsName]) => {
      'id': id,
      'friendlyName': name,
      'connectionType': 'bluetooth',
      'hardwareAddress': id,
    };

/// Builds events exactly the way the native side serialises them (root-level SYNC_STATE keys).
TrackingEvent ev(String type, int t, {String? deviceId, Map<String, dynamic>? device, Map<String, dynamic>? extra}) {
  return TrackingEvent.fromJson({
    'type': type,
    'timestamp': t,
    'deviceId': ?deviceId,
    'device': ?device,
    ...?extra,
  });
}

TrackingEvent connected(int t, [String id = buds]) =>
    ev('DEVICE_CONNECTED', t, deviceId: id, device: budsDevice(id));
TrackingEvent disconnected(int t, [String id = buds]) => ev('DEVICE_DISCONNECTED', t, deviceId: id);
TrackingEvent started(int t, [String id = buds]) =>
    ev('PLAYBACK_STARTED', t, deviceId: id, device: budsDevice(id));
TrackingEvent paused(int t, [String id = buds]) =>
    ev('PLAYBACK_PAUSED', t, deviceId: id, device: budsDevice(id));
TrackingEvent sync(int t, {List<Map<String, dynamic>> devices = const [], bool playing = false, int? startedAt}) =>
    ev('SYNC_STATE', t, extra: {
      'connectedDevices': devices,
      'isPlaying': playing,
      'playbackStartedAt': startedAt,
      if (devices.isNotEmpty) 'deviceId': devices.last['id'],
    });

void main() {
  late AppDatabase db;
  late StreamController<TrackingEvent> events;
  late ProviderContainer container;
  late int listenCount;
  final base = DateTime(2026, 11, 5, 9).millisecondsSinceEpoch;
  int at(int minutes) => base + minutes * 60 * 1000;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    listenCount = 0;
    events = StreamController<TrackingEvent>.broadcast(onListen: () => listenCount++);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trackingEventStreamProvider.overrideWithValue(events.stream),
      clockProvider.overrideWithValue(() => DateTime.fromMillisecondsSinceEpoch(at(120))),
    ]);
    container.read(trackingPipelineProvider);
  });

  tearDown(() async {
    container.dispose();
    await events.close();
    await db.close();
  });

  Future<void> send(List<TrackingEvent> list) async {
    for (final e in list) {
      events.add(e);
    }
    await Future<void>.delayed(Duration.zero);
    await container.read(trackingPipelineProvider).idle;
  }

  Future<List<EarTimeEvent>> stored() async {
    final rows = await db.getAllEvents();
    return rows
        .map((e) => EarTimeEvent(
              id: e.id,
              canonicalDeviceId: e.canonicalDeviceId,
              deviceName: e.deviceName,
              connectionType: e.connectionType,
              eventType: e.eventType,
              timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
            ))
        .toList();
  }

  Future<List<ListeningSession>> sessions() async => SessionManager.reconstruct(await stored());

  LiveSessionState live() => container.read(liveSessionProvider);

  group('Pipeline Regression Tests (Phase 6 Fixes)', () {
    test('1. Launch with earbuds disconnected (SYNC_STATE empty)', () async {
      await send([sync(at(0))]);
      expect(live().isInitialized, isTrue);
      expect(live().activeDevice, isNull);
    });

    test('2. Connect earbuds after launch (DEVICE_CONNECTED)', () async {
      await send([sync(at(0)), connected(at(1))]);
      expect(live().activeDevice?.canonicalDeviceId, buds);
      expect(live().activeDevice?.displayName, budsName);
      expect(live().activeDevice?.playbackState, PlaybackState.stopped);
    });

    test('3. Device remains visible when another route/device disconnects', () async {
      // Native now collapses A2DP+SCO routes; on the Dart side a disconnect for a different id
      // must never wipe the active device.
      await send([connected(at(0)), disconnected(at(1), '11:22:33:44:55:66')]);
      expect(live().activeDevice?.canonicalDeviceId, buds);
    });

    test('4. DEVICE_CONNECTED without playback has no running timer', () async {
      await send([connected(at(0))]);
      expect(live().activeDevice?.currentPlaybackStartTime, isNull);
      expect(live().isPlaying, isFalse);
    });

    test('5. PLAYBACK_STARTED after DEVICE_CONNECTED', () async {
      await send([connected(at(0)), started(at(1))]);
      expect(live().activeDevice?.playbackState, PlaybackState.playing);
      expect(live().activeDevice?.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(at(1)));
    });

    test('6. PLAYBACK_PAUSED stops live timer (sets start time to null)', () async {
      await send([connected(at(0)), started(at(1)), paused(at(5))]);
      expect(live().activeDevice?.playbackState, PlaybackState.paused);
      expect(live().activeDevice?.currentPlaybackStartTime, isNull);
    });

    test('7. PLAYBACK_PAUSED stops session accumulation', () async {
      await send([connected(at(0)), started(at(1)), paused(at(16))]);
      final s = (await sessions()).single;
      expect(s.isPlaying, isFalse);
      expect(s.intervals.single.endTime, DateTime.fromMillisecondsSinceEpoch(at(16)));
      expect(s.staticTotalActiveDuration, const Duration(minutes: 15));
    });

    test('8. PLAYBACK_RESUMED continues from accumulated duration', () async {
      await send([connected(at(0)), started(at(1)), paused(at(11)), started(at(20))]);
      expect(live().activeDevice?.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(at(20)));
      final s = (await sessions()).single;
      expect(s.intervals.length, 2);
      expect(s.staticTotalActiveDuration, const Duration(minutes: 10));
      expect(s.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(at(20)));
    });

    test('9. Repeated play/pause transitions create no duplicate intervals', () async {
      final t = at(0);
      await send([
        connected(t),
        started(t + 1000),
        started(t + 1500), // duplicate within 2s -> dropped
        paused(t + 60000),
        paused(t + 60000), // exact replay -> same id, ignored by DB
        started(t + 120000),
        paused(t + 180000),
      ]);
      final s = (await sessions()).single;
      expect(s.intervals.length, 2);
      expect(s.staticTotalActiveDuration, const Duration(seconds: 119));
    });

    test('10. No duplicate timers/subscriptions', () async {
      final a = container.read(trackingPipelineProvider);
      final b = container.read(trackingPipelineProvider);
      expect(identical(a, b), isTrue);
      expect(listenCount, 1);
      await send([connected(at(0))]);
      expect((await stored()).length, 1);
    });

    test('11. App lifecycle/reopen: stale open session is closed without inventing time', () async {
      // Previous process: connected and playing, then the process died (no further events).
      await send([connected(at(0)), started(at(1))]);
      // New process: native reports nothing connected.
      await send([sync(at(90))]);
      final s = (await sessions()).single;
      expect(s.isDisconnected, isTrue);
      expect(s.isPlaying, isFalse);
      // Closed at the last known event (minute 1), not at minute 90.
      expect(s.staticTotalActiveDuration, Duration.zero);
      expect(live().activeDevice, isNull);
    });

    test('12. SYNC_STATE with connected device (root-level payload)', () async {
      await send([sync(at(30), devices: [budsDevice()], playing: true, startedAt: at(10))]);
      expect(live().activeDevice?.canonicalDeviceId, buds);
      expect(live().activeDevice?.displayName, budsName);
      expect(live().activeDevice?.playbackState, PlaybackState.playing);
      expect(live().activeDevice?.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(at(10)));
      // The timeline gets a matching open session so Home and Timeline agree.
      final s = (await sessions()).single;
      expect(s.isDisconnected, isFalse);
      expect(s.isPlaying, isTrue);
      expect(s.currentPlaybackStartTime, DateTime.fromMillisecondsSinceEpoch(at(10)));
    });

    test('13. SYNC_STATE with no connected device clears the live state', () async {
      await send([connected(at(0)), sync(at(5))]);
      expect(live().activeDevice, isNull);
    });

    test('14. Home and Timeline consistency', () async {
      await send([connected(at(0)), started(at(10)), paused(at(40)), started(at(100))]);
      final now = DateTime.fromMillisecondsSinceEpoch(at(120));
      final closed = AnalyticsCalculator.closedListeningBetween(
          await sessions(), AnalyticsCalculator.startOfDay(now), now);
      final liveStart = live().activeDevice!.currentPlaybackStartTime!;
      final homeTotal = closed + now.difference(liveStart);

      final analytics = AnalyticsCalculator.analytics(await sessions(), AnalyticsPeriod.today, now)!;
      expect(closed, const Duration(minutes: 30));
      expect(homeTotal, const Duration(minutes: 50));
      expect(analytics.totalListenTime, homeTotal);
    });

    test('Playback without any device is not attributed to a stale device', () async {
      await send([connected(at(0)), disconnected(at(1)), ev('PLAYBACK_STARTED', at(2))]);
      expect(live().activeDevice, isNull);
      final types = (await stored()).map((e) => e.eventType).toList();
      expect(types, ['DEVICE_CONNECTED', 'DEVICE_DISCONNECTED']);
    });

    test('Events in the same millisecond are all stored', () async {
      final t = at(0);
      await send([connected(t), started(t + 1000), paused(t + 5000), disconnected(t + 5000)]);
      final types = (await stored()).map((e) => e.eventType).toSet();
      expect(types, containsAll(['PLAYBACK_PAUSED', 'DEVICE_DISCONNECTED']));
    });
  });
}
