import 'dart:async';
import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StreamController<dynamic> input;
  late ProviderContainer container;
  final device = {
    'id': 'A',
    'friendlyName': 'Buds',
    'connectionType': 'bluetooth',
    'nativeType': 8,
  };
  setUp(() {
    input = StreamController<dynamic>.broadcast();
    TrackingPlatform.setRawStreamForTesting(input.stream);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.read(trackingPipelineProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    TrackingPlatform.resetForTesting();
    await input.close();
  });
  Future<void> send(
    String type,
    int time, {
    Map<String, dynamic>? extra,
  }) async {
    input.add({
      'type': type,
      'timestamp': time,
      'deviceId': 'A',
      'device': device,
      ...?extra,
    });
    await pumpEventQueue();
  }

  test('1. empty SYNC does not invent a connection', () async {
    await send(
      'SYNC_STATE',
      0,
      extra: {'connectedDevices': [], 'isPlaying': false},
    );
    expect(container.read(liveSessionProvider).activeDevice, isNull);
  });
  test('2. connection establishes stopped device', () async {
    await send('DEVICE_CONNECTED', 0);
    expect(
      container.read(liveSessionProvider).activeDevice?.canonicalDeviceId,
      'A',
    );
    expect(
      container.read(liveSessionProvider).activeDevice?.playbackState,
      PlaybackState.stopped,
    );
  });
  test(
    '3. removing another profile does not wipe the selected device',
    () async {
      await send('DEVICE_CONNECTED', 0);
      await send('DEVICE_DISCONNECTED', 1000, extra: {'deviceId': 'SCO-B'});
      expect(
        container.read(liveSessionProvider).activeDevice?.canonicalDeviceId,
        'A',
      );
    },
  );
  test('4. connection alone has no playback opening', () async {
    await send('DEVICE_CONNECTED', 0);
    expect(
      container
          .read(liveSessionProvider)
          .activeDevice
          ?.currentPlaybackStartTime,
      isNull,
    );
  });
  test('5. playback uses the observed opening timestamp', () async {
    await send('DEVICE_CONNECTED', 0);
    await send('PLAYBACK_STARTED', 1000);
    expect(
      container
          .read(liveSessionProvider)
          .activeDevice
          ?.currentPlaybackStartTime
          ?.millisecondsSinceEpoch,
      1000,
    );
  });
  test('6. pause clears live opening without disconnecting', () async {
    await send('DEVICE_CONNECTED', 0);
    await send('PLAYBACK_STARTED', 1000);
    await send('PLAYBACK_PAUSED', 3000);
    expect(
      container
          .read(liveSessionProvider)
          .activeDevice
          ?.currentPlaybackStartTime,
      isNull,
    );
    expect(
      container.read(liveSessionProvider).activeDevice?.canonicalDeviceId,
      'A',
    );
  });
  test('7. pause is durably represented in legacy history', () async {
    await send('DEVICE_CONNECTED', 0);
    await send('PLAYBACK_STARTED', 1000);
    await send('PLAYBACK_PAUSED', 3000);
    final rows = await db.watchAllEvents().first;
    expect(
      rows.singleWhere((r) => r.eventType == 'PLAYBACK_PAUSED').timestamp,
      3000,
    );
  });
  test('8. resume opens a new interval after pause', () async {
    await send('DEVICE_CONNECTED', 0);
    await send('PLAYBACK_STARTED', 1000);
    await send('PLAYBACK_PAUSED', 3000);
    await send('PLAYBACK_STARTED', 6000);
    expect(
      container
          .read(liveSessionProvider)
          .activeDevice
          ?.currentPlaybackStartTime
          ?.millisecondsSinceEpoch,
      6000,
    );
  });
  test('9. repeated transitions retain each distinct state change', () async {
    await send('DEVICE_CONNECTED', 0);
    await send('PLAYBACK_STARTED', 1000);
    await send('PLAYBACK_PAUSED', 2000);
    await send('PLAYBACK_STARTED', 3000);
    await send('PLAYBACK_PAUSED', 4000);
    expect((await db.watchAllEvents().first).length, 5);
  });
  test('10. repeated provider reads do not create duplicate writers', () async {
    container.read(trackingPipelineProvider);
    container.read(trackingPipelineProvider);
    await send('DEVICE_CONNECTED', 0);
    expect((await db.watchAllEvents().first).length, 1);
  });
  test(
    '11. replacing Dart owner cannot preserve stale in-memory context',
    () async {
      await send('DEVICE_CONNECTED', 0);
      await send('PLAYBACK_STARTED', 1000);
      container.dispose();
      await pumpEventQueue();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      container.read(trackingPipelineProvider);
      expect(container.read(liveSessionProvider).activeDevice, isNull);
      // Canonical continuity comes from native projection, not this compatibility cache.
    },
  );
  test('12. SYNC uses observed device metadata', () async {
    await send(
      'SYNC_STATE',
      1000,
      extra: {
        'connectedDevices': [device],
        'isPlaying': true,
      },
    );
    expect(
      container.read(liveSessionProvider).activeDevice?.displayName,
      'Buds',
    );
  });
  test('13. empty snapshot clears previous connection', () async {
    await send('DEVICE_CONNECTED', 0);
    await send(
      'SYNC_STATE',
      1000,
      extra: {'connectedDevices': [], 'isPlaying': false},
    );
    expect(container.read(liveSessionProvider).activeDevice, isNull);
  });
  test(
    '14. repeated snapshot retains existing compatibility opening',
    () async {
      await send('DEVICE_CONNECTED', 0);
      await send('PLAYBACK_STARTED', 1000);
      await send(
        'SYNC_STATE',
        9000,
        extra: {
          'connectedDevices': [device],
          'isPlaying': true,
        },
      );
      expect(
        container
            .read(liveSessionProvider)
            .activeDevice
            ?.currentPlaybackStartTime
            ?.millisecondsSinceEpoch,
        1000,
      );
    },
  );
}
