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
  debugPrint('[GFLOW] databaseProvider initialization START');
  final db = AppDatabase();
  ref.onDispose(db.close);
  debugPrint('[GFLOW] databaseProvider initialization END');
  return db;
});

final bleNotificationProvider = StreamProvider<TrackingEvent>((ref) {
  return TrackingPlatform.eventStream.where((event) => event.type == 'BLE_NOTIFICATION');
});

final trackingStreamHealthProvider = StreamProvider<TrackingStreamHealth>((ref) {
  return TrackingPlatform.healthStream;
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
    debugPrint('[GFLOW] liveSessionProvider START/END');
    return const LiveSessionState(isInitialized: false);
  }

  void updateState(LiveSessionState newState) {
    state = newState;
  }
}

final liveSessionProvider = NotifierProvider<LiveSessionNotifier, LiveSessionState>(LiveSessionNotifier.new);

/// Selects the best device from a SYNC_STATE connectedDevices list.
/// Priority:
/// 1. nativeType == 8 (Bluetooth A2DP)
/// 2. otherwise valid hardwareAddress
/// 3. otherwise first device
Map<dynamic, dynamic>? selectSyncDevice(List<dynamic> connectedDevices) {
  if (connectedDevices.isEmpty) return null;

  // 1. nativeType == 8 (A2DP)
  for (final d in connectedDevices) {
    if (d is Map && d['nativeType'] == 8) {
      return d;
    }
  }

  // 2. otherwise valid hardwareAddress
  for (final d in connectedDevices) {
    if (d is Map &&
        d['hardwareAddress'] != null &&
        d['hardwareAddress'].toString().trim().isNotEmpty) {
      return d;
    }
  }

  // 3. otherwise first device
  final first = connectedDevices.first;
  return first is Map ? first : null;
}

// Legacy compatibility adapter for preserved regressions/tools, not product accounting.
// AppShell uses trackingProjectionActivationProvider; do not resume this legacy writer.
final trackingPipelineProvider = Provider<void>((ref) {
  debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] DART_PIPELINE_STARTED');
  debugPrint('[GFLOW] trackingPipelineProvider initialization START');
  final db = ref.watch(databaseProvider);
  final liveNotifier = ref.read(liveSessionProvider.notifier);
  
  // Historical last-known device metadata (retained for display/fallback names when valid)
  String historicalDeviceName = 'Unknown Device';
  String historicalConnectionType = 'bluetooth';

  // Currently attributable external audio device (valid only while actively connected)
  String? currentAttributableDeviceId;
  String? currentAttributableDeviceName;
  String? currentAttributableConnectionType;

  final lastPlaybackByDevice = <String, (String, int)>{};

  Future<void> insertDbRow(String eventType, String devId, String name, String connType, int ts,
      {String? observationId}) async {
    final rowId = observationId ?? '${ts}_$devId';
    debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] DB_INSERT_ATTEMPT type=$eventType id=$rowId ts=$ts devId=$devId');
    try {
      await db.insertEvent(EarTimeEventsCompanion(
        id: drift.Value(rowId),
        canonicalDeviceId: drift.Value(devId),
        deviceName: drift.Value(name),
        connectionType: drift.Value(connType),
        eventType: drift.Value(eventType),
        playbackState: const drift.Value(null),
        timestamp: drift.Value(ts),
      ));
      debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] DB_INSERT_SUCCESS type=$eventType id=$rowId');
    } catch (e) {
      debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] DB_INSERT_FAILURE type=$eventType id=$rowId error=$e');
      rethrow;
    }
  }

  debugPrint('[GFLOW] trackingPipelineProvider EventChannel.listen setup');
  final subscription = TrackingPlatform.eventStream.listen((event) async {
    try {
      if (event.type == 'BLE_DISCOVERY_RESULT' || event.type == 'BLE_DIAGNOSTIC_STATE') {
        // Skip inserting this into the event stream DB directly as it's just raw diagnostics
        return;
      }

      // Live Session State Updates
      final currentLiveState = ref.read(liveSessionProvider);
      
      if (event.type == 'SYNC_STATE') {
          debugPrint('[PIPELINE] SYNC_STATE received: connectedDevices=${event.connectedDevices}, isPlaying=${event.isPlaying}');
          final isPlaying = event.isPlaying ?? (event.device?['isPlaying'] as bool? ?? false);
          final connectedDevices = event.connectedDevices ?? (event.device?['connectedDevices'] as List<dynamic>? ?? []);
          
          final chosenDevice = selectSyncDevice(connectedDevices);
          if (chosenDevice == null) {
              // Invalidate current attributable external device context
              currentAttributableDeviceId = null;
              currentAttributableDeviceName = null;
              currentAttributableConnectionType = null;
              liveNotifier.updateState(currentLiveState.withNoDevice());
              debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] SYNC_REDUCER_APPLIED device=none isPlaying=false');
          } else {
              final syncDeviceId = chosenDevice['id']?.toString() ?? 'unknown_device';
              final syncDeviceName = chosenDevice['friendlyName']?.toString() ?? 'Bluetooth Device';
              final syncConnectionType = chosenDevice['connectionType']?.toString() ?? 'bluetooth';
              
              currentAttributableDeviceId = syncDeviceId;
              currentAttributableDeviceName = syncDeviceName;
              currentAttributableConnectionType = syncConnectionType;

              historicalDeviceName = syncDeviceName;
              historicalConnectionType = syncConnectionType;

              final isSameDevice = currentLiveState.activeDevice?.canonicalDeviceId == syncDeviceId;
              final wasPlaying = currentLiveState.activeDevice?.playbackState == ps.PlaybackState.playing;
              final existingStartTime = (isSameDevice && wasPlaying)
                  ? currentLiveState.activeDevice?.currentPlaybackStartTime
                  : null;
              final playbackStartTime = isPlaying
                  ? (existingStartTime ?? DateTime.fromMillisecondsSinceEpoch(event.timestamp))
                  : null;

              if (isPlaying && playbackStartTime != null) {
                final source = existingStartTime != null ? 'existing live state' : 'sync snapshot';
                debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] LIVE_PLAYBACK_START_SELECTED ts=${playbackStartTime.millisecondsSinceEpoch} source=$source');
              }
              debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] SYNC_REDUCER_APPLIED device=$syncDeviceId isPlaying=$isPlaying playbackStart=${playbackStartTime?.millisecondsSinceEpoch}');

              liveNotifier.updateState(currentLiveState.copyWith(
                  isInitialized: true,
                  activeDevice: AudioDevice(
                      canonicalDeviceId: syncDeviceId,
                      displayName: syncDeviceName,
                      deviceType: syncConnectionType,
                      connectionState: cs.ConnectionState.connected,
                      playbackState: isPlaying ? ps.PlaybackState.playing : ps.PlaybackState.paused,
                      lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
                      currentPlaybackStartTime: playbackStartTime,
                  ),
              ));
          }
          return; // Don't insert SYNC_STATE into DB
      }

      if (event.type == 'DEVICE_CONNECTED') {
          final connectedId = event.deviceId ?? (event.device?['id'] as String?);
          if (connectedId == null) {
            debugPrint('[PIPELINE] Ignoring DEVICE_CONNECTED because no deviceId is known.');
            return;
          }
          final connectedName = event.device?['friendlyName'] as String? ?? historicalDeviceName;
          final connType = event.device?['connectionType'] as String? ?? 'bluetooth';

          currentAttributableDeviceId = connectedId;
          currentAttributableDeviceName = connectedName;
          currentAttributableConnectionType = connType;

          historicalDeviceName = connectedName;
          historicalConnectionType = connType;

          liveNotifier.updateState(currentLiveState.copyWith(
              isInitialized: true,
              activeDevice: AudioDevice(
                  canonicalDeviceId: connectedId,
                  displayName: connectedName,
                  deviceType: connType,
                  connectionState: cs.ConnectionState.connected,
                  playbackState: currentLiveState.activeDevice?.canonicalDeviceId == connectedId
                      ? currentLiveState.activeDevice!.playbackState
                      : ps.PlaybackState.stopped,
                  currentPlaybackStartTime: currentLiveState.activeDevice?.canonicalDeviceId == connectedId
                      ? currentLiveState.activeDevice?.currentPlaybackStartTime
                      : null,
                  lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
              ),
          ));

          debugPrint('[PIPELINE] Inserting event ${event.type} for $connectedId');
          await insertDbRow(event.type, connectedId, connectedName, connType, event.timestamp,
              observationId: event.journalIdentity?.observationId);
          return;
      }

      if (event.type == 'DEVICE_DISCONNECTED') {
          final disconnectedId = event.deviceId ?? (event.device?['id'] as String?) ?? currentAttributableDeviceId;
          final disconnectedName = event.device?['friendlyName'] as String? ?? currentAttributableDeviceName ?? historicalDeviceName;
          final disconnectedConnType = event.device?['connectionType'] as String? ?? currentAttributableConnectionType ?? historicalConnectionType;

          if (disconnectedId == null || disconnectedId == currentAttributableDeviceId) {
            currentAttributableDeviceId = null;
            currentAttributableDeviceName = null;
            currentAttributableConnectionType = null;
          }

          lastPlaybackByDevice.remove(disconnectedId);
          if (disconnectedId == null ||
              disconnectedId == currentLiveState.activeDevice?.canonicalDeviceId) {
            liveNotifier.updateState(currentLiveState.withNoDevice());
          }

          if (disconnectedId != null) {
            debugPrint('[PIPELINE] Inserting event ${event.type} for $disconnectedId');
            await insertDbRow(event.type, disconnectedId, disconnectedName, disconnectedConnType, event.timestamp,
                observationId: event.journalIdentity?.observationId);
          }
          return;
      }

      if (event.type == 'PLAYBACK_STARTED' ||
          event.type == 'PLAYBACK_PAUSED' ||
          event.type == 'PLAYBACK_STOPPED' ||
          event.type == 'PLAYBACK_RESUMED') {

          final targetDeviceId = event.deviceId ?? currentAttributableDeviceId;
          if (targetDeviceId == null) {
            debugPrint('[PIPELINE] Ignoring device-less ${event.type}: no attributable external device connected.');
            return;
          }

          if (event.deviceId != null && currentAttributableDeviceId == null) {
            currentAttributableDeviceId = event.deviceId;
            currentAttributableDeviceName = event.device?['friendlyName'] as String? ?? historicalDeviceName;
            currentAttributableConnectionType = event.device?['connectionType'] as String? ?? 'bluetooth';
            historicalDeviceName = currentAttributableDeviceName!;
            historicalConnectionType = currentAttributableConnectionType!;
          }

          final deviceName = event.device?['friendlyName'] as String? ?? currentAttributableDeviceName ?? historicalDeviceName;
          final connType = event.device?['connectionType'] as String? ?? currentAttributableConnectionType ?? 'bluetooth';

          // Deduplication for playback events
          final previousPlayback = lastPlaybackByDevice[targetDeviceId];
          final elapsed = previousPlayback == null
              ? null
              : event.timestamp - previousPlayback.$2;
          if (previousPlayback?.$1 == event.type &&
              elapsed != null && elapsed >= 0 && elapsed < 2000) {
              debugPrint('[PIPELINE] Deduplicated identical playback event ${event.type}');
              return;
          }
          lastPlaybackByDevice[targetDeviceId] = (event.type, event.timestamp);

          if (event.type == 'PLAYBACK_STARTED' || event.type == 'PLAYBACK_RESUMED') {
              final selectedTime = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
              debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] LIVE_PLAYBACK_START_SELECTED ts=${event.timestamp} source=native transition');
              liveNotifier.updateState(currentLiveState.copyWith(
                  isInitialized: true,
                  activeDevice: AudioDevice(
                      canonicalDeviceId: targetDeviceId,
                      displayName: deviceName,
                      deviceType: connType,
                      connectionState: cs.ConnectionState.connected,
                      playbackState: ps.PlaybackState.playing,
                      lastSeen: selectedTime,
                      currentPlaybackStartTime: selectedTime,
                  ),
              ));
          } else {
              liveNotifier.updateState(currentLiveState.copyWith(
                  isInitialized: true,
                  activeDevice: AudioDevice(
                      canonicalDeviceId: targetDeviceId,
                      displayName: deviceName,
                      deviceType: connType,
                      connectionState: cs.ConnectionState.connected,
                      playbackState: ps.PlaybackState.paused,
                      lastSeen: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
                      currentPlaybackStartTime: null,
                  ),
              ));
          }

          debugPrint('[PIPELINE] Inserting event ${event.type} for $targetDeviceId');
          await insertDbRow(event.type, targetDeviceId, deviceName, connType, event.timestamp,
              observationId: event.journalIdentity?.observationId);
          return;
      }

      final fallbackDeviceId = event.deviceId ?? currentAttributableDeviceId;
      if (fallbackDeviceId == null) {
        debugPrint('[PIPELINE] Ignoring ${event.type} because no deviceId is known.');
        return;
      }

      debugPrint('[PIPELINE] Inserting event ${event.type} for $fallbackDeviceId');
      await insertDbRow(
        event.type,
        fallbackDeviceId,
        event.device?['friendlyName'] as String? ?? currentAttributableDeviceName ?? historicalDeviceName,
        event.device?['connectionType'] as String? ?? currentAttributableConnectionType ?? historicalConnectionType,
        event.timestamp,
        observationId: event.journalIdentity?.observationId,
      );
    } catch (e) {
      debugPrint('[PIPELINE] Error inserting event: $e');
    }
  }, onError: (Object error, StackTrace stack) {
    // Health is published by the shared platform stream; do not change session
    // accounting or recreate a subscription in response to transport errors.
    debugPrint('[STREAM_HEALTH:dart=${TrackingPlatform.dartRuntimeId}] '
        'pipeline observed error=$error');
    debugPrintStack(stackTrace: stack, maxFrames: 8);
  }, onDone: () {
    debugPrint('[STREAM_HEALTH:dart=${TrackingPlatform.dartRuntimeId}] '
        'pipeline stream closed; live state may be stale');
  });

  ref.onDispose(() {
    debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] DART_PIPELINE_DISPOSED');
    debugPrint('[GFLOW] trackingPipelineProvider disposing: cancelling subscription');
    subscription.cancel();
  });

  debugPrint('[GFLOW] trackingPipelineProvider initialization END');
});

// Remove MonitoringStateNotifier as tracking is now purely passive

// --- Data Streams ---
final allEventsProvider = StreamProvider<List<EarTimeEvent>>((ref) {
  debugPrint('[GFLOW] allEventsProvider initialization START');
  final db = ref.watch(databaseProvider);
  debugPrint('[GFLOW] allEventsProvider watchAllEvents START');
  final stream = db.watchAllEvents().map((entities) {
    debugPrint('[LIFECYCLE:dart=${TrackingPlatform.dartRuntimeId}] DB_STATE_SUMMARY rowCount=${entities.length}');
    debugPrint('[GFLOW] allEventsProvider watchAllEvents database query returned: ${entities.length} events');
    return entities.map((e) => EarTimeEvent(
      id: e.id,
      canonicalDeviceId: e.canonicalDeviceId,
      deviceName: e.deviceName,
      connectionType: e.connectionType,
      eventType: e.eventType,
      playbackState: e.playbackState,
      timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
    )).toList().reversed.toList();
  }); // Reverse so chronological
  debugPrint('[GFLOW] allEventsProvider initialization END');
  return stream;
});

final recentEventsProvider = Provider<AsyncValue<List<EarTimeEvent>>>((ref) {
  debugPrint('[GFLOW] recentEventsProvider START/END');
  return ref.watch(allEventsProvider).whenData((events) => events.reversed.toList());
});

final sessionManagerProvider = Provider<AsyncValue<List<ListeningSession>>>((ref) {
  return ref.watch(allEventsProvider).whenData((events) {
    debugPrint('[GFLOW] SessionManager.reconstruct START. Number of events: ${events.length}');
    final startTime = DateTime.now();
    final sessions = SessionManager.reconstruct(events);
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    debugPrint('[GFLOW] SessionManager.reconstruct END. Duration: ${duration}ms');
    return sessions;
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
  debugPrint('[GFLOW] analyticsDataProvider START');
  final sessionsAsync = ref.watch(sessionManagerProvider);
  
  final result = sessionsAsync.whenData((sessions) {
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
  debugPrint('[GFLOW] analyticsDataProvider END');
  return result;
});

final wellbeingDataProvider = FutureProvider<WellbeingData?>((ref) async {
  debugPrint('[GFLOW] wellbeingDataProvider START/END');
  return null;
});
