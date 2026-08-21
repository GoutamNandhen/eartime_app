import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database/database.dart';
import '../domain/logic/session_manager.dart';
import '../domain/models/listening_session.dart';
import '../domain/models/audio_device.dart';
import '../domain/models/tracking_event.dart';
import '../domain/models/connection_state.dart' as cs;
import '../domain/models/playback_state.dart' as ps;
import '../domain/models/eartime_event.dart';
import '../domain/models/analytics_data.dart';
import '../domain/models/live_session_state.dart';
import '../data/tracking_platform.dart';

// --- Database & Infrastructure ---
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final bleNotificationProvider = StreamProvider<TrackingEvent>((ref) {
  return TrackingPlatform.eventStream.where((event) => event.type == 'BLE_NOTIFICATION');
});

final bleDiagnosticStateProvider = StreamProvider<TrackingEvent>((ref) {
  return TrackingPlatform.eventStream.where((event) => event.type == 'BLE_DIAGNOSTIC_STATE');
});

// A provider that listens strictly for BLE discovery results
final bleDiscoveryResultProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return TrackingPlatform.eventStream
      .where((event) => event.type == 'BLE_DISCOVERY_RESULT')
      .map((event) => event.device ?? {});
});

// --- Live Session State ---
class LiveSessionNotifier extends Notifier<LiveSessionState> {
  @override
  LiveSessionState build() {
    return const LiveSessionState(isInitialized: false);
  }

  void updateState(LiveSessionState newState) {
    state = newState;
  }
}

final liveSessionProvider = NotifierProvider<LiveSessionNotifier, LiveSessionState>(LiveSessionNotifier.new);

// A pure side-effect provider that listens to the native stream and inserts into DB
final trackingPipelineProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  final liveNotifier = ref.read(liveSessionProvider.notifier);
  
  // Cache the last known connected device to fill in missing metadata for playback events
  String? lastKnownDeviceId;
  String lastKnownDeviceName = 'Unknown Device';
  String lastKnownConnectionType = 'bluetooth';

  String? lastPlaybackState;
  int lastPlaybackStateTime = 0;

  TrackingPlatform.eventStream.listen((event) async {
    try {
      if (event.type == 'DEVICE_CONNECTED' && event.device != null) {
        lastKnownDeviceId = event.device!['id'] as String?;
        lastKnownDeviceName = event.device!['friendlyName'] as String? ?? 'Unknown Device';
        lastKnownConnectionType = event.device!['connectionType'] as String? ?? 'bluetooth';
      }

      if (event.type == 'BLE_DISCOVERY_RESULT' || event.type == 'BLE_DIAGNOSTIC_STATE') {
        // Skip inserting this into the event stream DB directly as it's just raw diagnostics
        return;
      }

      final deviceId = event.deviceId ?? lastKnownDeviceId;
      if (deviceId == null) {
        debugPrint('[PIPELINE] Ignoring ${event.type} because no deviceId is known.');
        return;
      }

      // Deduplication for playback events
      if (event.type == 'PLAYBACK_STARTED' || event.type == 'PLAYBACK_PAUSED' || event.type == 'PLAYBACK_STOPPED' || event.type == 'PLAYBACK_RESUMED') {
          // Drop identical rapid playback states
          if (event.type == lastPlaybackState && (event.timestamp - lastPlaybackStateTime) < 2000) {
              debugPrint('[PIPELINE] Deduplicated identical playback event ${event.type}');
              return;
          }
          lastPlaybackState = event.type;
          lastPlaybackStateTime = event.timestamp;
      }

      // Live Session State Updates
      final currentLiveState = ref.read(liveSessionProvider);
      
      if (event.type == 'SYNC_STATE') {
          debugPrint('[PIPELINE] SYNC_STATE received: ${event.device}');
          final isPlaying = event.device?['isPlaying'] as bool? ?? false;
          final connectedDevices = event.device?['connectedDevices'] as List<dynamic>? ?? [];
          
          if (connectedDevices.isEmpty) {
              liveNotifier.updateState(currentLiveState.withNoDevice());
          } else {
              final firstDevice = connectedDevices.first as Map<dynamic, dynamic>;
              final syncDeviceId = firstDevice['id'] as String;
              final syncDeviceName = firstDevice['friendlyName'] as String;
              
              liveNotifier.updateState(currentLiveState.copyWith(
                  isInitialized: true,
                  activeDevice: AudioDevice(
                      canonicalDeviceId: syncDeviceId,
                      displayName: syncDeviceName,
                      deviceType: 'bluetooth',
                      connectionState: cs.ConnectionState.connected,
                      playbackState: isPlaying ? ps.PlaybackState.playing : ps.PlaybackState.paused,
                      lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
                      currentPlaybackStartTime: isPlaying ? DateTime.fromMillisecondsSinceEpoch(event.timestamp) : currentLiveState.activeDevice?.currentPlaybackStartTime,
                  ),
              ));
          }
          return; // Don't insert SYNC_STATE into DB
      } else if (event.type == 'DEVICE_CONNECTED') {
          liveNotifier.updateState(currentLiveState.copyWith(
              isInitialized: true,
              activeDevice: AudioDevice(
                  canonicalDeviceId: deviceId,
                  displayName: event.device?['friendlyName'] as String? ?? lastKnownDeviceName,
                  deviceType: 'bluetooth',
                  connectionState: cs.ConnectionState.connected,
                  playbackState: currentLiveState.activeDevice?.playbackState ?? ps.PlaybackState.stopped,
                  lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
              ),
          ));
      } else if (event.type == 'DEVICE_DISCONNECTED') {
          liveNotifier.updateState(currentLiveState.withNoDevice());
      } else if (event.type == 'PLAYBACK_STARTED' || event.type == 'PLAYBACK_RESUMED') {
          liveNotifier.updateState(currentLiveState.copyWith(
              isInitialized: true,
              activeDevice: AudioDevice(
                  canonicalDeviceId: deviceId,
                  displayName: event.device?['friendlyName'] as String? ?? lastKnownDeviceName,
                  deviceType: 'bluetooth',
                  connectionState: cs.ConnectionState.connected,
                  playbackState: ps.PlaybackState.playing,
                  lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
                  currentPlaybackStartTime: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
              ),
          ));
      } else if (event.type == 'PLAYBACK_PAUSED' || event.type == 'PLAYBACK_STOPPED') {
          liveNotifier.updateState(currentLiveState.copyWith(
              isInitialized: true,
              activeDevice: AudioDevice(
                  canonicalDeviceId: deviceId,
                  displayName: event.device?['friendlyName'] as String? ?? lastKnownDeviceName,
                  deviceType: 'bluetooth',
                  connectionState: cs.ConnectionState.connected,
                  playbackState: ps.PlaybackState.paused,
                  lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
                  currentPlaybackStartTime: currentLiveState.activeDevice?.currentPlaybackStartTime,
              ),
          ));
      }

      debugPrint('[PIPELINE] Inserting event ${event.type} for $deviceId');
      await db.insertEvent(EarTimeEventsCompanion(
        id: drift.Value('${event.timestamp}_$deviceId'), // Unique ID
        canonicalDeviceId: drift.Value(deviceId),
        deviceName: drift.Value(event.device?['friendlyName'] as String? ?? lastKnownDeviceName),
        connectionType: drift.Value(event.device?['connectionType'] as String? ?? lastKnownConnectionType),
        eventType: drift.Value(event.type),
        playbackState: drift.Value(null),
        timestamp: drift.Value(event.timestamp),
      ));
    } catch (e) {
      debugPrint('[PIPELINE] Error inserting event: $e');
    }
  });
});

// Remove MonitoringStateNotifier as tracking is now purely passive

// --- Data Streams ---
final allEventsProvider = StreamProvider<List<EarTimeEvent>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllEvents().map((entities) => entities.map((e) => EarTimeEvent(
    id: e.id,
    canonicalDeviceId: e.canonicalDeviceId,
    deviceName: e.deviceName,
    connectionType: e.connectionType,
    eventType: e.eventType,
    playbackState: e.playbackState,
    timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
  )).toList().reversed.toList()); // Reverse so chronological
});

final recentEventsProvider = Provider<AsyncValue<List<EarTimeEvent>>>((ref) {
  return ref.watch(allEventsProvider).whenData((events) => events.reversed.toList());
});

final sessionManagerProvider = Provider<AsyncValue<List<ListeningSession>>>((ref) {
  return ref.watch(allEventsProvider).whenData((events) {
    return SessionManager.reconstruct(events);
  });
});

final knownDevicesProvider = Provider<AsyncValue<List<AudioDevice>>>((ref) {
  return ref.watch(sessionManagerProvider).whenData((sessions) {
    final devices = <String, AudioDevice>{};
    for (final s in sessions) {
      if (s.isDisconnected) continue;
      devices[s.canonicalDeviceId] = AudioDevice(
        canonicalDeviceId: s.canonicalDeviceId,
        displayName: s.deviceName,
        deviceType: 'bluetooth',
        connectionState: cs.ConnectionState.connected,
        playbackState: s.isPlaying ? ps.PlaybackState.playing : ps.PlaybackState.paused,
        lastSeen: s.connectTime,
        currentPlaybackStartTime: s.currentPlaybackStartTime,
      );
    }
    return devices.values.toList();
  });
});

final analyticsDataProvider = Provider<AsyncValue<AnalyticsData?>>((ref) {
  final sessionsAsync = ref.watch(sessionManagerProvider);
  
  return sessionsAsync.whenData((sessions) {
    var totalTime = Duration.zero;

    for (final s in sessions) {
      totalTime += s.staticTotalActiveDuration;
    }

    return AnalyticsData(
      totalListenTime: totalTime,
      averageSession: Duration.zero,
      longestSession: Duration.zero,
      timeOfDayUsage: const TimeOfDayUsage(morning: Duration.zero, afternoon: Duration.zero, evening: Duration.zero, night: Duration.zero),
      deviceUsagePercentages: const <String, double>{},
    );
  });
});

final wellbeingDataProvider = FutureProvider<WellbeingData?>((ref) async {
  return null;
});
