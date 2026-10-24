import 'dart:async';

import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<dynamic> input;
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    input = StreamController<dynamic>.broadcast();
    TrackingPlatform.setRawStreamForTesting(input.stream);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    container.read(trackingPipelineProvider);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    TrackingPlatform.resetForTesting();
    await input.close();
  });

  Future<void> send(String type, String id, int timestamp) async {
    input.add({
      'type': type,
      'deviceId': id,
      'device': {
        'id': id,
        'friendlyName': 'Device $id',
        'connectionType': 'bluetooth',
      },
      'timestamp': timestamp,
    });
    await pumpEventQueue();
  }

  test('disconnect B cannot clear playing A or its start timestamp', () async {
    await send('DEVICE_CONNECTED', 'B', 1000);
    await send('DEVICE_CONNECTED', 'A', 2000);
    await send('PLAYBACK_STARTED', 'A', 3000);
    await send('DEVICE_DISCONNECTED', 'B', 4000);

    final active = container.read(liveSessionProvider).activeDevice;
    expect(active?.canonicalDeviceId, 'A');
    expect(active?.playbackState, PlaybackState.playing);
    expect(
      active?.currentPlaybackStartTime,
      DateTime.fromMillisecondsSinceEpoch(3000),
    );
    final rows = await database.watchAllEvents().first;
    expect(
      rows
          .where((row) => row.eventType == 'DEVICE_DISCONNECTED')
          .single
          .canonicalDeviceId,
      'B',
    );
  });

  test('connecting B cannot inherit A playback state', () async {
    await send('DEVICE_CONNECTED', 'A', 1000);
    await send('PLAYBACK_STARTED', 'A', 2000);
    await send('DEVICE_CONNECTED', 'B', 3000);

    final active = container.read(liveSessionProvider).activeDevice;
    expect(active?.canonicalDeviceId, 'B');
    expect(active?.playbackState, PlaybackState.stopped);
    expect(active?.currentPlaybackStartTime, isNull);
  });

  test(
    'rapid same playback state on different devices is not deduplicated',
    () async {
      await send('DEVICE_CONNECTED', 'A', 1000);
      await send('PLAYBACK_STARTED', 'A', 2000);
      await send('DEVICE_CONNECTED', 'B', 2100);
      await send('PLAYBACK_STARTED', 'B', 2200);

      final rows = await database.watchAllEvents().first;
      expect(
        rows
            .where((row) => row.eventType == 'PLAYBACK_STARTED')
            .map((row) => row.canonicalDeviceId),
        unorderedEquals(['A', 'B']),
      );
      expect(
        container.read(liveSessionProvider).activeDevice?.playbackState,
        PlaybackState.playing,
      );
    },
  );

  test(
    'same-millisecond committed observations use native IDs in the read model',
    () async {
      for (var sequence = 1; sequence <= 2; sequence++) {
        input.add({
          'type': 'DEVICE_CONNECTED',
          'deviceId': 'A',
          'device': {'id': 'A', 'friendlyName': 'Device A'},
          'timestamp': 1000,
          'journal': {
            'observationId': 'native-observation-$sequence',
            'sourceId': 'native-source',
            'sequence': sequence,
            'collectionEpoch': 'collection-1',
          },
        });
        await pumpEventQueue();
      }
      final rows = await database.watchAllEvents().first;
      expect(
        rows.map((row) => row.id),
        unorderedEquals(['native-observation-1', 'native-observation-2']),
      );
    },
  );

  test(
    'repeated connection for the selected device preserves its playing timer',
    () async {
      await send('DEVICE_CONNECTED', 'A', 1000);
      await send('PLAYBACK_STARTED', 'A', 2000);
      await send('DEVICE_CONNECTED', 'A', 3000);
      final active = container.read(liveSessionProvider).activeDevice;
      expect(active?.playbackState, PlaybackState.playing);
      expect(
        active?.currentPlaybackStartTime,
        DateTime.fromMillisecondsSinceEpoch(2000),
      );
    },
  );
}
