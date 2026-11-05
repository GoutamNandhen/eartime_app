/// F2/F3 listening reminder settings, stored natively (`listeningReminders`).
class ListeningReminderPreferences {
  const ListeningReminderPreferences({
    this.enabled = true,
    this.continuousMinutes = 60,
    this.repeatMinutes = 30,
    this.breakMinutes = 5,
  });
  final bool enabled;
  final int continuousMinutes;
  final int repeatMinutes;
  final int breakMinutes;

  static const continuousChoices = [30, 45, 60, 90, 120];
  static const repeatChoices = [15, 30, 60];
  static const breakChoices = [3, 5, 10, 15];

  factory ListeningReminderPreferences.fromMap(Object? raw) {
    if (raw == null) return const ListeningReminderPreferences();
    bool inRange(Object? value, int min, int max) =>
        value is int && value >= min && value <= max;
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['enabled'] is! bool ||
        !inRange(raw['continuousMinutes'], 5, 480) ||
        !inRange(raw['repeatMinutes'], 5, 240) ||
        !inRange(raw['breakMinutes'], 1, 60)) {
      throw const FormatException('Invalid listening reminder preferences');
    }
    return ListeningReminderPreferences(
      enabled: raw['enabled'] as bool,
      continuousMinutes: raw['continuousMinutes'] as int,
      repeatMinutes: raw['repeatMinutes'] as int,
      breakMinutes: raw['breakMinutes'] as int,
    );
  }

  ListeningReminderPreferences copyWith({
    bool? enabled,
    int? continuousMinutes,
    int? repeatMinutes,
    int? breakMinutes,
  }) => ListeningReminderPreferences(
    enabled: enabled ?? this.enabled,
    continuousMinutes: continuousMinutes ?? this.continuousMinutes,
    repeatMinutes: repeatMinutes ?? this.repeatMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
  );

  Map<String, Object> toMap() => {
    'version': 1,
    'enabled': enabled,
    'continuousMinutes': continuousMinutes,
    'repeatMinutes': repeatMinutes,
    'breakMinutes': breakMinutes,
  };
}
