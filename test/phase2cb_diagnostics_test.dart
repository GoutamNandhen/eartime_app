import 'package:eartime_app/domain/models/eartime_event.dart';
import 'package:eartime_app/domain/models/listening_session.dart';
import 'package:eartime_app/features/settings/tracking_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 7, 10);

  test('K completed stale playing session is not counted as open', () {
    final closed = ListeningSession(
      id: 'closed',
      canonicalDeviceId: 'A',
      deviceName: 'A',
      connectTime: start,
      disconnectTime: start.add(const Duration(minutes: 1)),
      isPlaying: true,
      isDisconnected: true,
      intervals: [
        PlaybackInterval(
          startTime: start,
          endTime: start.add(const Duration(minutes: 1)),
        ),
      ],
    );
    final connected = ListeningSession(
      id: 'connected',
      canonicalDeviceId: 'A',
      deviceName: 'A',
      connectTime: start,
      intervals: const [],
    );
    final preview = DiagnosticSessionPreview([closed, connected]);
    expect(preview.openConnectionCount, 1);
    expect(preview.openPlaybackCount, 0);
  });

  test('history and interval inspection have explicit finite limits', () {
    final sessions = List.generate(
      1000,
      (index) => ListeningSession(
        id: '$index',
        canonicalDeviceId: 'A',
        deviceName: 'A',
        connectTime: start,
        intervals: List.generate(
          50,
          (i) => PlaybackInterval(
            startTime: start,
            endTime: start.add(const Duration(seconds: 1)),
          ),
        ),
      ),
    );
    final preview = DiagnosticSessionPreview(sessions);
    expect(preview.sessions.length, DiagnosticSessionPreview.sessionLimit);
    expect(preview.totalSessions, 1000);
    expect(
      preview.intervalsFor(preview.sessions.first).length,
      DiagnosticSessionPreview.intervalLimit,
    );
  });

  test(
    'log dump is bounded and distinguishes closed duration from open state',
    () {
      final events = List.generate(
        1000,
        (i) => EarTimeEvent(
          id: '$i',
          canonicalDeviceId: 'A',
          deviceName: 'A',
          connectionType: 'bluetooth',
          eventType: 'PLAYBACK_STARTED',
          timestamp: start,
        ),
      );
      final sessions = List.generate(
        1000,
        (i) => ListeningSession(
          id: '$i',
          canonicalDeviceId: 'A',
          deviceName: 'A',
          connectTime: start,
          isPlaying: true,
          intervals: [PlaybackInterval(startTime: start)],
        ),
      );
      final lines = diagnosticDumpLines(events, sessions);
      expect(lines.length, lessThanOrEqualTo(diagnosticDumpLineLimit));
      expect(lines.join('\n'), contains('closed/static'));
      expect(lines.join('\n'), contains('openPlayback=true'));
      expect(lines.join('\n'), contains('omitted'));
    },
  );
}
