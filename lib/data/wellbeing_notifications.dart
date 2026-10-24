import 'package:flutter/services.dart';

class WellbeingNotificationPreferences {
  const WellbeingNotificationPreferences({
    this.daily = false,
    this.weekly = false,
    this.quiet = true,
    this.quietStart = 1320,
    this.quietEnd = 420,
    this.deliveryMinute = 540,
  });
  final bool daily;
  final bool weekly;
  final bool quiet;
  final int quietStart;
  final int quietEnd;
  final int deliveryMinute;
  factory WellbeingNotificationPreferences.fromMap(Object? raw) {
    if (raw == null) return const WellbeingNotificationPreferences();
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['daily'] is! bool ||
        raw['weekly'] is! bool ||
        raw['quiet'] is! bool ||
        !['quietStart', 'quietEnd', 'deliveryMinute'].every(
          (key) =>
              raw[key] is int &&
              (raw[key] as int) >= 0 &&
              (raw[key] as int) < 1440,
        )) {
      throw const FormatException('Invalid wellbeing notification preferences');
    }
    return WellbeingNotificationPreferences(
      daily: raw['daily'] as bool,
      weekly: raw['weekly'] as bool,
      quiet: raw['quiet'] as bool,
      quietStart: raw['quietStart'] as int,
      quietEnd: raw['quietEnd'] as int,
      deliveryMinute: raw['deliveryMinute'] as int,
    );
  }
  WellbeingNotificationPreferences copyWith({
    bool? daily,
    bool? weekly,
    bool? quiet,
    int? quietStart,
    int? quietEnd,
    int? deliveryMinute,
  }) => WellbeingNotificationPreferences(
    daily: daily ?? this.daily,
    weekly: weekly ?? this.weekly,
    quiet: quiet ?? this.quiet,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    deliveryMinute: deliveryMinute ?? this.deliveryMinute,
  );
  Map<String, Object> toMap() => {
    'version': 1,
    'daily': daily,
    'weekly': weekly,
    'quiet': quiet,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'deliveryMinute': deliveryMinute,
  };
}

class WellbeingNotificationStatus {
  WellbeingNotificationStatus.fromMap(Map raw)
    : permissionGranted = raw['permissionGranted'] as bool?,
      schedulingAvailable = raw['schedulingAvailable'] == true,
      daily = raw['dailyUtcMs'] as int?,
      weekly = raw['weeklyUtcMs'] as int?,
      delivery = raw['delivery'] as String {
    if (raw['version'] != 1 ||
        (raw['permissionGranted'] != null && raw['permissionGranted'] is! bool) ||
        raw['schedulingAvailable'] is! bool ||
        raw['liveRemindersEligible'] != false ||
        (daily != null && daily! < 0) ||
        (weekly != null && weekly! < 0)) {
      throw const FormatException('Invalid wellbeing notification status');
    }
  }
  final bool? permissionGranted;
  final bool schedulingAvailable;
  final int? daily;
  final int? weekly;
  final String delivery;
}

class WellbeingNotificationClient {
  const WellbeingNotificationClient();
  static const _channel = MethodChannel('com.eartime.app/tracking');
  Future<WellbeingNotificationStatus> status() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'readWellbeingNotificationStatus',
    );
    if (raw == null) {
      throw const FormatException('Missing wellbeing notification status');
    }
    return WellbeingNotificationStatus.fromMap(raw);
  }
}
