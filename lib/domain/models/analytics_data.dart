import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_data.freezed.dart';
part 'analytics_data.g.dart';

@freezed
sealed class AnalyticsData with _$AnalyticsData {
  const factory AnalyticsData({
    required Duration totalListenTime,
    required Duration averageSession,
    required Duration longestSession,
    required TimeOfDayUsage timeOfDayUsage,
    required Map<String, double> deviceUsagePercentages,
  }) = _AnalyticsData;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) => _$AnalyticsDataFromJson(json);
}

@freezed
sealed class TimeOfDayUsage with _$TimeOfDayUsage {
  const factory TimeOfDayUsage({
    required Duration morning,
    required Duration afternoon,
    required Duration evening,
    required Duration night,
  }) = _TimeOfDayUsage;

  factory TimeOfDayUsage.fromJson(Map<String, dynamic> json) => _$TimeOfDayUsageFromJson(json);
}

@freezed
sealed class WellbeingData with _$WellbeingData {
  const factory WellbeingData({
    required int? healthScore,
    required int volumeAvgDb,
    required int volumePeakDb,
    required int breaksCount,
    required String? recommendation,
  }) = _WellbeingData;

  factory WellbeingData.fromJson(Map<String, dynamic> json) => _$WellbeingDataFromJson(json);
}
