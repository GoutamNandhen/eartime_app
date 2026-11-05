import '../models/eartime_event.dart';
import '../models/listening_session.dart';

class SessionManager {
  static const _typeOrder = {
    'DEVICE_CONNECTED': 0,
    'PLAYBACK_STARTED': 1,
    'PLAYBACK_RESUMED': 1,
    'PLAYBACK_PAUSED': 2,
    'PLAYBACK_STOPPED': 2,
    'DEVICE_DISCONNECTED': 3,
  };

  /// Oldest first. Events sharing a millisecond are ordered connect -> play -> pause ->
  /// disconnect so a tie can never close a session before it was opened.
  static List<EarTimeEvent> sortChronologically(List<EarTimeEvent> events) {
    final sorted = List<EarTimeEvent>.of(events);
    sorted.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      if (byTime != 0) return byTime;
      return (_typeOrder[a.eventType] ?? 1).compareTo(_typeOrder[b.eventType] ?? 1);
    });
    return sorted;
  }

  /// Reconstructs sessions deterministically from an ordered list of events.
  /// Events must be ordered from oldest to newest.
  static List<ListeningSession> reconstruct(List<EarTimeEvent> unsorted) {
    final events = sortChronologically(unsorted);
    final Map<String, ListeningSession> currentSessions = {};
    final List<ListeningSession> completedSessions = [];

    for (final event in events) {
      final deviceId = event.canonicalDeviceId;
      final type = event.eventType;
      
      var session = currentSessions[deviceId];

      if (type == 'DEVICE_CONNECTED') {
        // If there was an open session for this device, complete it first
        if (session != null) {
          if (session.isPlaying) {
            final lastInterval = session.intervals.last;
            final newIntervals = List<PlaybackInterval>.from(session.intervals);
            newIntervals[newIntervals.length - 1] = lastInterval.copyWith(endTime: event.timestamp);
            session = session.copyWith(intervals: newIntervals);
          }
          completedSessions.add(session.copyWith(disconnectTime: event.timestamp, isDisconnected: true));
        }

        // Start a new session
        currentSessions[deviceId] = ListeningSession(
          id: event.id,
          canonicalDeviceId: deviceId,
          deviceName: event.deviceName,
          connectTime: event.timestamp,
          intervals: const [],
        );
      } else if (type == 'DEVICE_DISCONNECTED') {
        if (session != null) {
          if (session.isPlaying) {
            final lastInterval = session.intervals.last;
            final newIntervals = List<PlaybackInterval>.from(session.intervals);
            newIntervals[newIntervals.length - 1] = lastInterval.copyWith(endTime: event.timestamp);
            session = session.copyWith(intervals: newIntervals);
          }
          completedSessions.add(session.copyWith(
            disconnectTime: event.timestamp,
            isPlaying: false,
            isDisconnected: true,
          ));
          currentSessions.remove(deviceId);
        }
      } else if (type == 'PLAYBACK_STARTED' || type == 'PLAYBACK_RESUMED') {
        // If the process died and Android restarted it with a PLAYBACK_STARTED without a preceding CONNECTED event,
        // we recover the session gracefully.
        session ??= ListeningSession(
          id: event.id,
          canonicalDeviceId: deviceId,
          deviceName: event.deviceName,
          connectTime: event.timestamp,
          intervals: const [],
        );
        
        if (!session.isPlaying) {
          session = session.copyWith(
            isPlaying: true,
            intervals: [
              ...session.intervals,
              PlaybackInterval(startTime: event.timestamp)
            ],
          );
          currentSessions[deviceId] = session;
        }
      } else if (type == 'PLAYBACK_PAUSED' || type == 'PLAYBACK_STOPPED') {
        if (session != null && session.isPlaying) {
          final lastInterval = session.intervals.last;
          final newIntervals = List<PlaybackInterval>.from(session.intervals);
          newIntervals[newIntervals.length - 1] = lastInterval.copyWith(endTime: event.timestamp);
          session = session.copyWith(intervals: newIntervals, isPlaying: false);
          currentSessions[deviceId] = session;
        }
      }
    }

    return [...completedSessions, ...currentSessions.values];
  }
}

/// Reconciles the persisted timeline with a native SYNC_STATE snapshot.
///
/// If the app process died, the DB can contain sessions that are still "open" (connected or
/// playing) although the device is long gone, which showed a stale state on next launch.
/// This returns the synthetic events needed to bring the timeline in line with reality.
class SyncReconciler {
  const SyncReconciler._();

  static List<EarTimeEvent> reconcile({
    required List<EarTimeEvent> events,
    required List<Map<String, dynamic>> connectedDevices,
    required String? activeDeviceId,
    required bool isPlaying,
    required DateTime syncTime,
    DateTime? playbackStartedAt,
  }) {
    final sessions = SessionManager.reconstruct(events);
    final open = {
      for (final s in sessions)
        if (!s.isDisconnected) s.canonicalDeviceId: s,
    };
    final lastEventTime = <String, DateTime>{};
    for (final e in events) {
      final prev = lastEventTime[e.canonicalDeviceId];
      if (prev == null || e.timestamp.isAfter(prev)) {
        lastEventTime[e.canonicalDeviceId] = e.timestamp;
      }
    }

    final connectedIds = {
      for (final d in connectedDevices)
        if (d['id'] is String) d['id'] as String,
    };
    final result = <EarTimeEvent>[];

    EarTimeEvent synth(String deviceId, String type, DateTime at, {String? name, String? connectionType}) {
      final session = open[deviceId];
      return EarTimeEvent(
        id: '${at.millisecondsSinceEpoch}_${deviceId}_${type}_sync',
        canonicalDeviceId: deviceId,
        deviceName: name ?? session?.deviceName ?? 'Unknown Device',
        connectionType: connectionType ?? 'bluetooth',
        eventType: type,
        timestamp: at,
      );
    }

    // 1. Sessions the native side no longer knows about. We don't know when they really ended,
    //    so close them at their last recorded event instead of inventing listening time.
    for (final session in open.values) {
      if (connectedIds.contains(session.canonicalDeviceId)) continue;
      final at = lastEventTime[session.canonicalDeviceId] ?? syncTime;
      result.add(synth(session.canonicalDeviceId, 'DEVICE_DISCONNECTED', at));
    }

    // 2. Devices that are connected but have no open session. If the device is already playing,
    //    the connection must have started no later than the playback did.
    final connectTimes = <String, DateTime>{};
    for (final d in connectedDevices) {
      final id = d['id'];
      if (id is! String || open.containsKey(id)) continue;
      var at = syncTime;
      if (isPlaying && id == activeDeviceId && playbackStartedAt != null && playbackStartedAt.isBefore(at)) {
        at = playbackStartedAt;
      }
      final last = lastEventTime[id];
      if (last != null && at.isBefore(last)) at = last;
      connectTimes[id] = at;
      result.add(synth(id, 'DEVICE_CONNECTED', at,
          name: d['friendlyName'] as String?, connectionType: d['connectionType'] as String?));
    }

    // 3. Playback state of connected devices.
    for (final id in connectedIds) {
      final session = open[id];
      final sessionPlaying = session?.isPlaying ?? false;
      final shouldPlay = isPlaying && id == activeDeviceId;
      if (sessionPlaying && !shouldPlay) {
        final at = lastEventTime[id] ?? syncTime;
        result.add(synth(id, 'PLAYBACK_PAUSED', at));
      } else if (!sessionPlaying && shouldPlay) {
        var at = playbackStartedAt ?? syncTime;
        // Never start an interval before the session's own latest event or its connection.
        final floor = connectTimes[id] ?? lastEventTime[id];
        if (floor != null && at.isBefore(floor)) at = floor;
        result.add(synth(id, 'PLAYBACK_STARTED', at));
      }
    }

    return result;
  }
}
