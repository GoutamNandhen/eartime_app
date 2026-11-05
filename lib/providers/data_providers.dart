import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database/database.dart';
import '../domain/logic/analytics_calculator.dart';
import '../domain/logic/live_session_reducer.dart';
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

/// The one shared stream of native events. Overridden in tests.
final trackingEventStreamProvider = Provider<Stream<TrackingEvent>>((ref) {
  return TrackingPlatform.eventStream;
});

/// Wall clock, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final bleNotificationProvider = StreamProvider<TrackingEvent>((ref) {
  return ref.watch(trackingEventStreamProvider).where((event) => event.type == 'BLE_NOTIFICATION');
});

final bleDiagnosticStateProvider = StreamProvider<TrackingEvent>((ref) {
  return ref.watch(trackingEventStreamProvider).where((event) => event.type == 'BLE_DIAGNOSTIC_STATE');
});

// A provider that listens strictly for BLE discovery results
final bleDiscoveryResultProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref
      .watch(trackingEventStreamProvider)
      .where((event) => event.type == 'BLE_DISCOVERY_RESULT')
      .map((event) => event.device ?? <String, dynamic>{});
});

// --- Live Session State ---
class LiveSessionNotifier extends Notifier<LiveSessionState> {
  @override
  LiveSessionState build() {
    return const LiveSessionState(isInitialized: false);
  }

  void apply(TrackingEvent event) {
    state = LiveSessionReducer.reduce(state, event);
  }

  void updateState(LiveSessionState newState) {
    state = newState;
  }
}

final liveSessionProvider = NotifierProvider<LiveSessionNotifier, LiveSessionState>(LiveSessionNotifier.new);

/// Listens to the native stream, updates the live session and persists the timeline.
///
/// Events are processed strictly one at a time (each handler awaits its DB work before the
/// next starts), so a SYNC_STATE reconciliation can never interleave with a live event.
class TrackingPipeline {
  TrackingPipeline(this._ref);

  final Ref _ref;
  StreamSubscription<TrackingEvent>? _subscription;
  Future<void> _queue = Future.value();

  String? _lastPlaybackKey;
  int _lastPlaybackTime = 0;

  /// Completes once every event received so far has been fully handled. Used by tests.
  Future<void> get idle => _queue;

  void start() {
    _subscription = _ref.read(trackingEventStreamProvider).listen((event) {
      _queue = _queue.then((_) => _handle(event)).catchError((Object e, StackTrace st) {
        debugPrint('[PIPELINE] Error handling ${event.type}: $e\n$st');
      });
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  AppDatabase get _db => _ref.read(databaseProvider);

  Future<void> _handle(TrackingEvent event) async {
    if (event.type == 'SYNC_STATE') {
      await _handleSync(event);
      return;
    }
    if (!persistedEventTypes.contains(event.type)) return; // BLE/diagnostic traffic.

    final liveNotifier = _ref.read(liveSessionProvider.notifier);
    final before = _ref.read(liveSessionProvider);
    final deviceId = LiveSessionReducer.attributedDeviceId(before, event);
    if (deviceId == null) {
      debugPrint('[PIPELINE] Ignoring ${event.type}: no device to attribute it to.');
      return;
    }

    // Drop identical rapid playback states for the same device.
    if (playbackStartTypes.contains(event.type) || playbackStopTypes.contains(event.type)) {
      final key = '${event.type}|$deviceId';
      if (key == _lastPlaybackKey && (event.timestamp - _lastPlaybackTime) < 2000) {
        debugPrint('[PIPELINE] Deduplicated identical playback event ${event.type}');
        return;
      }
      _lastPlaybackKey = key;
      _lastPlaybackTime = event.timestamp;
    }

    liveNotifier.apply(event);

    final knownDevice = before.activeDevice?.canonicalDeviceId == deviceId ? before.activeDevice : null;
    await _insert(EarTimeEvent(
      id: '${event.timestamp}_${deviceId}_${event.type}',
      canonicalDeviceId: deviceId,
      deviceName: event.device?['friendlyName'] as String? ?? knownDevice?.displayName ?? 'Unknown Device',
      connectionType: event.device?['connectionType'] as String? ?? knownDevice?.deviceType ?? 'bluetooth',
      eventType: event.type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    ));
  }

  Future<void> _handleSync(TrackingEvent event) async {
    debugPrint('[PIPELINE] SYNC_STATE received: ${event.connectedDevices} playing=${event.isPlaying}');
    final liveNotifier = _ref.read(liveSessionProvider.notifier);
    liveNotifier.apply(event);

    // Bring the persisted timeline in line with the native snapshot (stale sessions after
    // process death, connections that happened while nobody was listening, ...).
    final entities = await _db.getAllEvents();
    final synthetic = SyncReconciler.reconcile(
      events: entities.map(_toModel).toList(),
      connectedDevices: event.connectedDevices,
      activeDeviceId: _ref.read(liveSessionProvider).activeDevice?.canonicalDeviceId,
      isPlaying: event.isPlaying ?? false,
      syncTime: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
      playbackStartedAt: event.playbackStartedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(event.playbackStartedAt!)
          : null,
    );
    for (final e in synthetic) {
      debugPrint('[PIPELINE] Reconciling timeline: ${e.eventType} for ${e.canonicalDeviceId}');
      await _insert(e);
    }
  }

  Future<void> _insert(EarTimeEvent e) {
    return _db.insertEvent(EarTimeEventsCompanion(
      id: drift.Value(e.id),
      canonicalDeviceId: drift.Value(e.canonicalDeviceId),
      deviceName: drift.Value(e.deviceName),
      connectionType: drift.Value(e.connectionType),
      eventType: drift.Value(e.eventType),
      playbackState: const drift.Value(null),
      timestamp: drift.Value(e.timestamp.millisecondsSinceEpoch),
    ));
  }
}

EarTimeEvent _toModel(EarTimeEventEntity e) => EarTimeEvent(
      id: e.id,
      canonicalDeviceId: e.canonicalDeviceId,
      deviceName: e.deviceName,
      connectionType: e.connectionType,
      eventType: e.eventType,
      playbackState: e.playbackState,
      timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
    );

/// Starts the pipeline once and tears its subscription down with the provider.
final trackingPipelineProvider = Provider<TrackingPipeline>((ref) {
  final pipeline = TrackingPipeline(ref)..start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

// --- Data Streams ---

/// All persisted events, oldest first.
final allEventsProvider = StreamProvider<List<EarTimeEvent>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .watchAllEvents()
      .map((entities) => SessionManager.sortChronologically(entities.map(_toModel).toList()));
});

/// Persisted events, newest first.
final recentEventsProvider = Provider<AsyncValue<List<EarTimeEvent>>>((ref) {
  return ref.watch(allEventsProvider).whenData((events) => events.reversed.toList());
});

final sessionManagerProvider = Provider<AsyncValue<List<ListeningSession>>>((ref) {
  return ref.watch(allEventsProvider).whenData(SessionManager.reconstruct);
});

/// Every device seen in the timeline, most recently seen first. Devices with an open session
/// are reported as connected.
final knownDevicesProvider = Provider<AsyncValue<List<AudioDevice>>>((ref) {
  return ref.watch(sessionManagerProvider).whenData((sessions) {
    final devices = <String, AudioDevice>{};
    // Later sessions of the same device overwrite earlier ones.
    final ordered = List<ListeningSession>.of(sessions)..sort((a, b) => a.connectTime.compareTo(b.connectTime));
    for (final s in ordered) {
      devices[s.canonicalDeviceId] = AudioDevice(
        canonicalDeviceId: s.canonicalDeviceId,
        displayName: s.deviceName,
        deviceType: 'bluetooth',
        connectionState: s.isDisconnected ? cs.ConnectionState.disconnected : cs.ConnectionState.connected,
        playbackState: s.isPlaying
            ? ps.PlaybackState.playing
            : (s.isDisconnected ? ps.PlaybackState.stopped : ps.PlaybackState.paused),
        lastSeen: s.disconnectTime ?? s.connectTime,
        currentPlaybackStartTime: s.currentPlaybackStartTime,
      );
    }
    final list = devices.values.toList()..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  });
});

/// Completed listening time today (closed intervals only). Home adds the live interval on
/// top of this, so the open interval is never counted twice.
final todayClosedListeningProvider = Provider<AsyncValue<Duration>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref.watch(sessionManagerProvider).whenData((sessions) {
    final start = AnalyticsCalculator.startOfDay(now);
    return AnalyticsCalculator.closedListeningBetween(sessions, start, start.add(const Duration(days: 1)));
  });
});

final analyticsForPeriodProvider =
    Provider.family<AsyncValue<AnalyticsData?>, AnalyticsPeriod>((ref, period) {
  final now = ref.watch(clockProvider)();
  return ref.watch(sessionManagerProvider).whenData(
        (sessions) => AnalyticsCalculator.analytics(sessions, period, now),
      );
});

/// Today's analytics.
final analyticsDataProvider = Provider<AsyncValue<AnalyticsData?>>((ref) {
  return ref.watch(analyticsForPeriodProvider(AnalyticsPeriod.today));
});

final wellbeingDataProvider = Provider<AsyncValue<WellbeingData?>>((ref) {
  final now = ref.watch(clockProvider)();
  return ref.watch(sessionManagerProvider).whenData(
        (sessions) => AnalyticsCalculator.wellbeing(sessions, now),
      );
});

/// Total recorded listening per device id (open intervals counted up to now).
final deviceListeningTotalsProvider = Provider<AsyncValue<Map<String, Duration>>>((ref) {
  return ref.watch(sessionManagerProvider).whenData((sessions) {
    final totals = <String, Duration>{};
    for (final s in sessions) {
      totals[s.canonicalDeviceId] = (totals[s.canonicalDeviceId] ?? Duration.zero) + s.totalActiveDuration;
    }
    return totals;
  });
});
