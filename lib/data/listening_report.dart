class ListeningReport {
  ListeningReport.fromMap(Map<dynamic, dynamic> map)
    : activeDays = map['activeDays'] as int,
      goalMinutes = map['goalMinutes'] as int,
      goalDays = map['goalDays'] as int,
      completedDays = map['completedCalendarDays'] as int,
      currentStreak = map['currentRecordedStreak'] as int,
      bestStreak = map['bestRecordedStreak'] as int,
      averageActiveDay = Duration(
        milliseconds: map['averageActiveDayMs'] as int,
      ),
      hasUncertainty = map['hasUncertainty'] as bool,
      insight = map['insight'] as String,
      guidance = map['guidance'] as String {
    if (map['version'] != 1 ||
        map['scope'] != 'selected_window_recorded_lower_bound' ||
        activeDays < 0 ||
        goalMinutes < 0 ||
        goalMinutes > 1440 ||
        goalDays < 0 ||
        completedDays < 0 ||
        currentStreak < 0 ||
        bestStreak < currentStreak ||
        averageActiveDay.isNegative ||
        insight.length > 512 ||
        guidance.length > 512) {
      throw const FormatException('Invalid listening report');
    }
  }
  final int activeDays;
  final int goalMinutes;
  final int goalDays;
  final int completedDays;
  final int currentStreak;
  final int bestStreak;
  final Duration averageActiveDay;
  final bool hasUncertainty;
  final String insight;
  final String guidance;
}
