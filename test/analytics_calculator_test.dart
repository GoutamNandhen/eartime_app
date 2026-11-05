import 'package:eartime_app/domain/logic/analytics_calculator.dart';
import 'package:eartime_app/domain/models/listening_session.dart';
import 'package:flutter_test/flutter_test.dart';

ListeningSession session(String id, String name, List<PlaybackInterval> intervals, {bool open = false}) =>
    ListeningSession(
      id: id,
      canonicalDeviceId: id,
      deviceName: name,
      connectTime: intervals.first.startTime,
      intervals: intervals,
      isPlaying: open,
      isDisconnected: !open,
    );

void main() {
  final day = DateTime(2026, 11, 5);
  DateTime t(int h, [int m = 0]) => day.add(Duration(hours: h, minutes: m));

  test('analytics splits time of day, devices, average and longest', () {
    final sessions = [
      session('a', 'Buds', [PlaybackInterval(startTime: t(8), endTime: t(9))]), // morning 60m
      session('b', 'Headphones', [PlaybackInterval(startTime: t(16, 30), endTime: t(17, 30))]), // 30m afternoon + 30m evening
    ];
    final a = AnalyticsCalculator.analytics(sessions, AnalyticsPeriod.today, t(23))!;
    expect(a.totalListenTime, const Duration(hours: 2));
    expect(a.timeOfDayUsage.morning, const Duration(hours: 1));
    expect(a.timeOfDayUsage.afternoon, const Duration(minutes: 30));
    expect(a.timeOfDayUsage.evening, const Duration(minutes: 30));
    expect(a.averageSession, const Duration(hours: 1));
    expect(a.longestSession, const Duration(hours: 1));
    expect(a.deviceUsagePercentages['Buds'], closeTo(0.5, 1e-9));
  });

  test('today excludes yesterday\'s part of a session that crossed midnight', () {
    final s = session('a', 'Buds', [PlaybackInterval(startTime: t(-1), endTime: t(1))]);
    final a = AnalyticsCalculator.analytics([s], AnalyticsPeriod.today, t(12))!;
    expect(a.totalListenTime, const Duration(hours: 1));
  });

  test('analytics returns null without listening', () {
    expect(AnalyticsCalculator.analytics(const [], AnalyticsPeriod.week, t(12)), isNull);
  });

  test('wellbeing counts breaks and longest continuous run', () {
    final s = session('a', 'Buds', [
      PlaybackInterval(startTime: t(9), endTime: t(9, 50)),
      PlaybackInterval(startTime: t(9, 52), endTime: t(10, 30)), // 2 min gap: not a break
      PlaybackInterval(startTime: t(11), endTime: t(11, 20)), // 30 min gap: a break
    ]);
    final w = AnalyticsCalculator.wellbeing([s], t(12))!;
    expect(w.breaksCount, 1);
    expect(w.longestContinuous, const Duration(minutes: 90));
    expect(w.todayListening, const Duration(minutes: 108));
    expect(w.volumeAvgDb, isNull);
    expect(w.healthScore, inInclusiveRange(10, 100));
    expect(w.healthScore! < 100, isTrue, reason: '90 min without a break is penalised');
  });

  test('wellbeing needs a minimum amount of listening', () {
    final s = session('a', 'Buds', [PlaybackInterval(startTime: t(9), endTime: t(9, 2))]);
    expect(AnalyticsCalculator.wellbeing([s], t(12)), isNull);
  });
}
