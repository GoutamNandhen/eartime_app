import '../models/eartime_event.dart';
import '../models/listening_session.dart';

class SessionManager {
  /// Reconstructs sessions deterministically from an ordered list of events.
  /// Events must be ordered from oldest to newest.
  static List<ListeningSession> reconstruct(List<EarTimeEvent> events) {
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
