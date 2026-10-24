import '../../domain/models/eartime_event.dart';
import '../../domain/models/listening_session.dart';

const diagnosticEventLimit = 30;
const diagnosticDumpLineLimit = 160;

String diagnosticLabel(String value) =>
    value.length <= 100 ? value : '${value.substring(0, 100)}...';

/// Bounded inspection only. It does not change session accounting or projections.
class DiagnosticSessionPreview {
  DiagnosticSessionPreview(List<ListeningSession> all)
    : totalSessions = all.length,
      sessions = all.reversed.take(sessionLimit).toList(growable: false);

  static const sessionLimit = 12;
  static const intervalLimit = 8;
  final int totalSessions;
  final List<ListeningSession> sessions;

  int get openConnectionCount =>
      sessions.where((session) => !session.isDisconnected).length;

  int get openPlaybackCount => sessions
      .where(
        (session) =>
            !session.isDisconnected && session.currentPlaybackStartTime != null,
      )
      .length;

  List<PlaybackInterval> intervalsFor(ListeningSession session) =>
      session.intervals.reversed.take(intervalLimit).toList(growable: false);

  Duration shownClosedDuration(ListeningSession session) => intervalsFor(
    session,
  ).fold(Duration.zero, (total, interval) => total + interval.staticDuration);
}

List<String> diagnosticDumpLines(
  List<EarTimeEvent> events,
  List<ListeningSession> sessions,
) {
  final shownEvents = events.reversed
      .take(diagnosticEventLimit)
      .toList(growable: false);
  final preview = DiagnosticSessionPreview(sessions);
  return [
    'DB rows=${events.length}; showing newest ${shownEvents.length}',
    for (final event in shownEvents)
      'ts=${event.timestamp.millisecondsSinceEpoch} type=${diagnosticLabel(event.eventType)} '
          'device=${diagnosticLabel(event.canonicalDeviceId)} name=${diagnosticLabel(event.deviceName)}',
    'Event rows omitted=${events.length - shownEvents.length}',
    'Sessions=${sessions.length}; showing ${preview.sessions.length}; '
        'openConnectionsInPreview=${preview.openConnectionCount} '
        'openPlaybackInPreview=${preview.openPlaybackCount}',
    for (final session in preview.sessions) ...[
      'device=${diagnosticLabel(session.canonicalDeviceId)} disconnected=${session.isDisconnected} '
          'playingMetadata=${session.isPlaying} '
          'openPlayback=${!session.isDisconnected && session.currentPlaybackStartTime != null} '
          'closed/staticShown=${preview.shownClosedDuration(session).inSeconds}s',
      for (final interval in preview.intervalsFor(session))
        '  start=${interval.startTime} end=${interval.endTime} open=${interval.endTime == null}',
      '  Intervals omitted=${session.intervals.length - preview.intervalsFor(session).length}',
    ],
    'Sessions omitted=${sessions.length - preview.sessions.length}',
  ];
}
