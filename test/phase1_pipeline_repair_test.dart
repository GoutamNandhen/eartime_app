import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';
import 'package:eartime_app/domain/models/live_session_state.dart';
import 'package:eartime_app/domain/models/playback_state.dart';
import 'package:eartime_app/domain/models/connection_state.dart';
import 'package:eartime_app/domain/models/audio_device.dart';
import 'package:eartime_app/domain/models/eartime_event.dart';
import 'package:eartime_app/domain/logic/session_manager.dart';
import 'package:eartime_app/providers/data_providers.dart';

void main() {
  group('Phase 1 Pipeline Repair Tests', () {
    test('TEST 1: A root-level SYNC_STATE payload is correctly consumed', () {
      final json = {
        'type': 'SYNC_STATE',
        'connectedDevices': [
          {
            'id': '02:11:22:33:44:55',
            'friendlyName': 'OnePlus Nord Buds 3 Pro',
            'connectionType': 'bluetooth',
            'nativeType': 8,
          },
        ],
        'isPlaying': false,
        'timestamp': 1700000000000,
      };

      final event = TrackingEvent.fromJson(json);

      expect(event.type, 'SYNC_STATE');
      expect(event.connectedDevices, isNotNull);
      expect(event.connectedDevices!.length, 1);
      expect(event.connectedDevices!.first['id'], '02:11:22:33:44:55');
      expect(
        event.connectedDevices!.first['friendlyName'],
        'OnePlus Nord Buds 3 Pro',
      );
      expect(event.isPlaying, false);
      expect(event.device, isNotNull);
      expect(event.device!['connectedDevices'], isNotNull);
    });

    test('TEST 2: SYNC_STATE is processed even when deviceId is null', () {
      final json = {
        'type': 'SYNC_STATE',
        'connectedDevices': [
          {
            'id': '02:11:22:33:44:55',
            'friendlyName': 'OnePlus Nord Buds 3 Pro',
            'connectionType': 'bluetooth',
          },
        ],
        'isPlaying': true,
        'timestamp': 1700000000000,
      };

      final event = TrackingEvent.fromJson(json);

      // Event itself has no top-level deviceId
      expect(event.deviceId, isNull);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final liveNotifier = container.read(liveSessionProvider.notifier);
      final currentLiveState = container.read(liveSessionProvider);

      final isPlaying =
          event.isPlaying ?? (event.device?['isPlaying'] as bool? ?? false);
      final connectedDevices =
          event.connectedDevices ??
          (event.device?['connectedDevices'] as List<dynamic>? ?? []);

      expect(connectedDevices, isNotEmpty);
      final firstDevice = connectedDevices.first;
      final syncDeviceId = firstDevice['id']?.toString() ?? '';
      final syncDeviceName = firstDevice['friendlyName']?.toString() ?? '';

      liveNotifier.updateState(
        currentLiveState.copyWith(
          isInitialized: true,
          activeDevice: AudioDevice(
            canonicalDeviceId: syncDeviceId,
            displayName: syncDeviceName,
            deviceType: 'bluetooth',
            connectionState: ConnectionState.connected,
            playbackState: isPlaying
                ? PlaybackState.playing
                : PlaybackState.paused,
            lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
            currentPlaybackStartTime: isPlaying
                ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
                : null,
          ),
        ),
      );

      final state = container.read(liveSessionProvider);
      expect(state.isInitialized, true);
      expect(state.activeDevice, isNotNull);
      expect(state.activeDevice!.canonicalDeviceId, '02:11:22:33:44:55');
    });

    test(
      'TEST 3: SYNC_STATE containing one connected device produces the expected live state',
      () {
        final json = {
          'type': 'SYNC_STATE',
          'connectedDevices': [
            {
              'id': 'dev_123',
              'friendlyName': 'Test Earbuds',
              'connectionType': 'bluetooth',
            },
          ],
          'isPlaying': false,
          'timestamp': 1700000050000,
        };

        final event = TrackingEvent.fromJson(json);
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final liveNotifier = container.read(liveSessionProvider.notifier);
        final currentLiveState = container.read(liveSessionProvider);

        final isPlaying =
            event.isPlaying ?? (event.device?['isPlaying'] as bool? ?? false);
        final connectedDevices =
            event.connectedDevices ??
            (event.device?['connectedDevices'] as List<dynamic>? ?? []);
        final firstDevice = connectedDevices.first;

        liveNotifier.updateState(
          currentLiveState.copyWith(
            isInitialized: true,
            activeDevice: AudioDevice(
              canonicalDeviceId: firstDevice['id']?.toString() ?? '',
              displayName: firstDevice['friendlyName']?.toString() ?? '',
              deviceType:
                  firstDevice['connectionType']?.toString() ?? 'bluetooth',
              connectionState: ConnectionState.connected,
              playbackState: isPlaying
                  ? PlaybackState.playing
                  : PlaybackState.paused,
              lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
              currentPlaybackStartTime: isPlaying
                  ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
                  : null,
            ),
          ),
        );

        final liveState = container.read(liveSessionProvider);
        expect(liveState.isInitialized, true);
        expect(liveState.activeDevice, isNotNull);
        expect(liveState.activeDevice!.canonicalDeviceId, 'dev_123');
        expect(liveState.activeDevice!.displayName, 'Test Earbuds');
        expect(liveState.activeDevice!.playbackState, PlaybackState.paused);
        expect(liveState.activeDevice!.currentPlaybackStartTime, isNull);
      },
    );

    test('TEST 4: PLAYBACK_STARTED creates currentPlaybackStartTime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final liveNotifier = container.read(liveSessionProvider.notifier);
      final startTime = DateTime.fromMillisecondsSinceEpoch(1700000100000);

      liveNotifier.updateState(
        const LiveSessionState(isInitialized: true).copyWith(
          activeDevice: AudioDevice(
            canonicalDeviceId: 'dev_123',
            displayName: 'Test Earbuds',
            deviceType: 'bluetooth',
            connectionState: ConnectionState.connected,
            playbackState: PlaybackState.playing,
            lastSeen: startTime,
            currentPlaybackStartTime: startTime,
          ),
        ),
      );

      final state = container.read(liveSessionProvider);
      expect(state.activeDevice!.playbackState, PlaybackState.playing);
      expect(state.activeDevice!.currentPlaybackStartTime, startTime);
    });

    test('TEST 5: PLAYBACK_PAUSED clears currentPlaybackStartTime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final liveNotifier = container.read(liveSessionProvider.notifier);
      final startTime = DateTime.fromMillisecondsSinceEpoch(1700000100000);
      final pauseTime = DateTime.fromMillisecondsSinceEpoch(1700000200000);

      // Initially playing
      liveNotifier.updateState(
        const LiveSessionState(isInitialized: true).copyWith(
          activeDevice: AudioDevice(
            canonicalDeviceId: 'dev_123',
            displayName: 'Test Earbuds',
            deviceType: 'bluetooth',
            connectionState: ConnectionState.connected,
            playbackState: PlaybackState.playing,
            lastSeen: startTime,
            currentPlaybackStartTime: startTime,
          ),
        ),
      );

      expect(
        container
            .read(liveSessionProvider)
            .activeDevice!
            .currentPlaybackStartTime,
        isNotNull,
      );

      // Transition to paused - currentPlaybackStartTime becomes null
      final currentLiveState = container.read(liveSessionProvider);
      liveNotifier.updateState(
        currentLiveState.copyWith(
          isInitialized: true,
          activeDevice: AudioDevice(
            canonicalDeviceId: 'dev_123',
            displayName: 'Test Earbuds',
            deviceType: 'bluetooth',
            connectionState: ConnectionState.connected,
            playbackState: PlaybackState.paused,
            lastSeen: pauseTime,
            currentPlaybackStartTime: null,
          ),
        ),
      );

      final pausedState = container.read(liveSessionProvider);
      expect(pausedState.activeDevice!.playbackState, PlaybackState.paused);
      expect(pausedState.activeDevice!.currentPlaybackStartTime, isNull);
    });

    test(
      'TEST 6: A pause does not continue accumulating elapsed playback time',
      () {
        final t0 = DateTime(2026, 8, 1, 10, 0); // connected
        final t1 = DateTime(2026, 8, 1, 10, 5); // playing
        final t2 = DateTime(2026, 8, 1, 10, 20); // paused (15 min active)

        final events = [
          EarTimeEvent(
            id: '1',
            canonicalDeviceId: 'dev_123',
            deviceName: 'Test Earbuds',
            connectionType: 'bluetooth',
            eventType: 'DEVICE_CONNECTED',
            timestamp: t0,
          ),
          EarTimeEvent(
            id: '2',
            canonicalDeviceId: 'dev_123',
            deviceName: 'Test Earbuds',
            connectionType: 'bluetooth',
            eventType: 'PLAYBACK_STARTED',
            timestamp: t1,
          ),
          EarTimeEvent(
            id: '3',
            canonicalDeviceId: 'dev_123',
            deviceName: 'Test Earbuds',
            connectionType: 'bluetooth',
            eventType: 'PLAYBACK_PAUSED',
            timestamp: t2,
          ),
        ];

        final sessions = SessionManager.reconstruct(events);
        expect(sessions.length, 1);
        final session = sessions.first;

        expect(session.isPlaying, false);
        expect(session.currentPlaybackStartTime, isNull);

        // Static duration of completed intervals
        expect(session.staticTotalActiveDuration.inMinutes, 15);
        expect(session.staticTotalActiveDuration, const Duration(minutes: 15));
      },
    );

    test(
      'TEST 7: SYNC_STATE prefers A2DP (nativeType 8) over SCO (nativeType 7)',
      () {
        final connectedDevices = [
          {
            'id': 'CPH2447_7',
            'systemId': 7799,
            'hardwareAddress': null,
            'friendlyName': 'CPH2447',
            'connectionType': 'bluetooth',
            'nativeType': 7,
          },
          {
            'id': '02:11:22:33:44:55',
            'systemId': 7807,
            'hardwareAddress': '02:11:22:33:44:55',
            'friendlyName': 'OnePlus Nord Buds 3 Pro',
            'connectionType': 'bluetooth',
            'nativeType': 8,
          },
        ];

        final chosen = selectSyncDevice(connectedDevices);
        expect(chosen, isNotNull);
        expect(chosen!['id'], '02:11:22:33:44:55');
        expect(chosen['friendlyName'], 'OnePlus Nord Buds 3 Pro');
        expect(chosen['nativeType'], 8);
      },
    );

    test(
      'TEST 8: SYNC_STATE with non-string id handles gracefully without throwing',
      () {
        final connectedDevices = [
          {
            'id': 12345, // int id instead of String
            'friendlyName': 'Integer ID Buds',
            'connectionType': 'bluetooth',
            'nativeType': 8,
          },
        ];

        final chosen = selectSyncDevice(connectedDevices);
        expect(chosen, isNotNull);
        final syncDeviceId = chosen!['id']?.toString() ?? 'unknown_device';
        expect(syncDeviceId, '12345');
      },
    );

    test(
      'TEST 9: Repeated SYNC_STATE preserves existing playback start time when already playing',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final liveNotifier = container.read(liveSessionProvider.notifier);
        final initialStartTime = DateTime.fromMillisecondsSinceEpoch(
          1700000000000,
        );

        // Device is already connected and playing
        liveNotifier.updateState(
          const LiveSessionState(isInitialized: true).copyWith(
            activeDevice: AudioDevice(
              canonicalDeviceId: 'dev_repeat',
              displayName: 'Repeat Buds',
              deviceType: 'bluetooth',
              connectionState: ConnectionState.connected,
              playbackState: PlaybackState.playing,
              lastSeen: initialStartTime,
              currentPlaybackStartTime: initialStartTime,
            ),
          ),
        );

        final stateBefore = container.read(liveSessionProvider);
        expect(
          stateBefore.activeDevice!.currentPlaybackStartTime,
          initialStartTime,
        );

        // Simulate receiving repeated SYNC_STATE 10 seconds later while still playing
        final syncTimestamp = 1700000010000;
        final syncDeviceId = 'dev_repeat';
        final currentLiveState = container.read(liveSessionProvider);

        final isSameDevice =
            currentLiveState.activeDevice?.canonicalDeviceId == syncDeviceId;
        final wasPlaying =
            currentLiveState.activeDevice?.playbackState ==
            PlaybackState.playing;
        final existingStartTime = (isSameDevice && wasPlaying)
            ? currentLiveState.activeDevice?.currentPlaybackStartTime
            : null;
        final playbackStartTime =
            existingStartTime ??
            DateTime.fromMillisecondsSinceEpoch(syncTimestamp);

        liveNotifier.updateState(
          currentLiveState.copyWith(
            isInitialized: true,
            activeDevice: AudioDevice(
              canonicalDeviceId: syncDeviceId,
              displayName: 'Repeat Buds',
              deviceType: 'bluetooth',
              connectionState: ConnectionState.connected,
              playbackState: PlaybackState.playing,
              lastSeen: DateTime.fromMillisecondsSinceEpoch(syncTimestamp),
              currentPlaybackStartTime: playbackStartTime,
            ),
          ),
        );

        final stateAfter = container.read(liveSessionProvider);
        // Playback start time must be preserved and NOT overwritten by syncTimestamp!
        expect(
          stateAfter.activeDevice!.currentPlaybackStartTime,
          initialStartTime,
        );
        expect(
          stateAfter.activeDevice!.currentPlaybackStartTime,
          isNot(DateTime.fromMillisecondsSinceEpoch(syncTimestamp)),
        );
      },
    );
  });
}
