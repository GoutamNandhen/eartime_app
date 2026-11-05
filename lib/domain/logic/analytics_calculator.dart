import '../models/analytics_data.dart';
import '../models/listening_session.dart';

enum AnalyticsPeriod { today, week, month, year }

/// A concrete span of listening, already clipped to a time window.
class _Span {
  final String sessionId;
  final String deviceName;
  final DateTime start;
  final DateTime end;
  const _Span(this.sessionId, this.deviceName, this.start, this.end);
  Duration get duration => end.difference(start);
}

/// Pure analytics over reconstructed sessions. Everything takes `now` so it is testable.
class AnalyticsCalculator {
  const AnalyticsCalculator._();

  /// WHO "safe listening" reference: 40 hours a week at 80 dB, i.e. ~5h43m a day.
  static const dailyExposureGuideline = Duration(minutes: 343);

  /// Gaps shorter than this don't count as a break; a run longer than this needs one.
  static const minBreak = Duration(minutes: 5);
  static const recommendedMaxContinuous = Duration(minutes: 60);

  static DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime periodStart(AnalyticsPeriod period, DateTime now) {
    final today = startOfDay(now);
    switch (period) {
      case AnalyticsPeriod.today:
        return today;
      case AnalyticsPeriod.week:
        return today.subtract(const Duration(days: 6));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month, 1);
      case AnalyticsPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }

  /// Completed listening inside [from, to). Excludes the currently open interval, which the
  /// Home live timer adds itself; including it here as well double counted it.
  static Duration closedListeningBetween(List<ListeningSession> sessions, DateTime from, DateTime to) {
    return sessions.fold(Duration.zero, (t, s) => t + s.staticDurationWithin(from, to));
  }

  static List<_Span> _spans(List<ListeningSession> sessions, DateTime from, DateTime to,
      {required bool includeOpen}) {
    final spans = <_Span>[];
    for (final s in sessions) {
      for (final i in s.intervals) {
        final rawEnd = i.endTime ?? (includeOpen ? to : null);
        if (rawEnd == null) continue;
        final start = i.startTime.isBefore(from) ? from : i.startTime;
        final end = rawEnd.isAfter(to) ? to : rawEnd;
        if (end.isAfter(start)) spans.add(_Span(s.id, s.deviceName, start, end));
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  static AnalyticsData? analytics(List<ListeningSession> sessions, AnalyticsPeriod period, DateTime now) {
    final from = periodStart(period, now);
    final spans = _spans(sessions, from, now, includeOpen: true);
    if (spans.isEmpty) return null;

    var total = Duration.zero;
    final perSession = <String, Duration>{};
    final perDevice = <String, Duration>{};
    var morning = Duration.zero, afternoon = Duration.zero, evening = Duration.zero, night = Duration.zero;

    for (final span in spans) {
      total += span.duration;
      perSession[span.sessionId] = (perSession[span.sessionId] ?? Duration.zero) + span.duration;
      perDevice[span.deviceName] = (perDevice[span.deviceName] ?? Duration.zero) + span.duration;

      // Split the span on hour boundaries and bucket each piece by time of day.
      var cursor = span.start;
      while (cursor.isBefore(span.end)) {
        final nextHour = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
        final pieceEnd = nextHour.isBefore(span.end) ? nextHour : span.end;
        final piece = pieceEnd.difference(cursor);
        final h = cursor.hour;
        if (h >= 5 && h < 12) {
          morning += piece;
        } else if (h >= 12 && h < 17) {
          afternoon += piece;
        } else if (h >= 17 && h < 21) {
          evening += piece;
        } else {
          night += piece;
        }
        cursor = pieceEnd;
      }
    }

    final longest = perSession.values.fold(Duration.zero, (a, b) => b > a ? b : a);
    final average = Duration(microseconds: total.inMicroseconds ~/ perSession.length);
    final totalUs = total.inMicroseconds;

    return AnalyticsData(
      totalListenTime: total,
      averageSession: average,
      longestSession: longest,
      timeOfDayUsage: TimeOfDayUsage(morning: morning, afternoon: afternoon, evening: evening, night: night),
      deviceUsagePercentages: {
        for (final e in perDevice.entries)
          e.key: totalUs == 0 ? 0.0 : e.value.inMicroseconds / totalUs,
      },
    );
  }

  /// Duration-based wellbeing for today. Volume cannot be measured with public Android APIs,
  /// so the dB fields stay null instead of showing invented numbers.
  static WellbeingData? wellbeing(List<ListeningSession> sessions, DateTime now) {
    final spans = _spans(sessions, startOfDay(now), now, includeOpen: true);
    final total = spans.fold(Duration.zero, (t, s) => t + s.duration);
    if (total < minBreak) return null;

    // Merge spans separated by less than a real break into continuous runs.
    var breaks = 0;
    var longestRun = Duration.zero;
    DateTime runStart = spans.first.start;
    DateTime runEnd = spans.first.end;
    for (final span in spans.skip(1)) {
      if (span.start.difference(runEnd) >= minBreak) {
        breaks++;
        final run = runEnd.difference(runStart);
        if (run > longestRun) longestRun = run;
        runStart = span.start;
      }
      if (span.end.isAfter(runEnd)) runEnd = span.end;
    }
    final lastRun = runEnd.difference(runStart);
    if (lastRun > longestRun) longestRun = lastRun;

    final ratio = total.inSeconds / dailyExposureGuideline.inSeconds;
    final exposurePenalty = ((ratio - 0.5) * 80).clamp(0, 60);
    final continuityPenalty =
        ((longestRun.inMinutes - recommendedMaxContinuous.inMinutes) / 2).clamp(0, 30);
    final score = (100 - exposurePenalty - continuityPenalty).round().clamp(10, 100);

    String recommendation;
    if (ratio >= 1) {
      recommendation = 'You have passed the daily listening guideline. Give your ears a long rest today.';
    } else if (longestRun > recommendedMaxContinuous) {
      recommendation = 'Take a 5–10 minute break for every hour of continuous listening.';
    } else if (ratio >= 0.75) {
      recommendation = 'You are close to the daily listening guideline. Keep the volume low for the rest of the day.';
    } else {
      recommendation = 'Your listening today is well within the guideline. Keep taking regular breaks.';
    }

    return WellbeingData(
      healthScore: score,
      volumeAvgDb: null,
      volumePeakDb: null,
      breaksCount: breaks,
      recommendation: recommendation,
      todayListening: total,
      longestContinuous: longestRun,
    );
  }
}
