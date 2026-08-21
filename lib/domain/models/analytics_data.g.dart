// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnalyticsData _$AnalyticsDataFromJson(Map<String, dynamic> json) =>
    _AnalyticsData(
      totalListenTime: Duration(
        microseconds: (json['totalListenTime'] as num).toInt(),
      ),
      averageSession: Duration(
        microseconds: (json['averageSession'] as num).toInt(),
      ),
      longestSession: Duration(
        microseconds: (json['longestSession'] as num).toInt(),
      ),
      timeOfDayUsage: TimeOfDayUsage.fromJson(
        json['timeOfDayUsage'] as Map<String, dynamic>,
      ),
      deviceUsagePercentages:
          (json['deviceUsagePercentages'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ),
    );

Map<String, dynamic> _$AnalyticsDataToJson(_AnalyticsData instance) =>
    <String, dynamic>{
      'totalListenTime': instance.totalListenTime.inMicroseconds,
      'averageSession': instance.averageSession.inMicroseconds,
      'longestSession': instance.longestSession.inMicroseconds,
      'timeOfDayUsage': instance.timeOfDayUsage,
      'deviceUsagePercentages': instance.deviceUsagePercentages,
    };

_TimeOfDayUsage _$TimeOfDayUsageFromJson(Map<String, dynamic> json) =>
    _TimeOfDayUsage(
      morning: Duration(microseconds: (json['morning'] as num).toInt()),
      afternoon: Duration(microseconds: (json['afternoon'] as num).toInt()),
      evening: Duration(microseconds: (json['evening'] as num).toInt()),
      night: Duration(microseconds: (json['night'] as num).toInt()),
    );

Map<String, dynamic> _$TimeOfDayUsageToJson(_TimeOfDayUsage instance) =>
    <String, dynamic>{
      'morning': instance.morning.inMicroseconds,
      'afternoon': instance.afternoon.inMicroseconds,
      'evening': instance.evening.inMicroseconds,
      'night': instance.night.inMicroseconds,
    };

_WellbeingData _$WellbeingDataFromJson(Map<String, dynamic> json) =>
    _WellbeingData(
      healthScore: (json['healthScore'] as num?)?.toInt(),
      volumeAvgDb: (json['volumeAvgDb'] as num).toInt(),
      volumePeakDb: (json['volumePeakDb'] as num).toInt(),
      breaksCount: (json['breaksCount'] as num).toInt(),
      recommendation: json['recommendation'] as String?,
    );

Map<String, dynamic> _$WellbeingDataToJson(_WellbeingData instance) =>
    <String, dynamic>{
      'healthScore': instance.healthScore,
      'volumeAvgDb': instance.volumeAvgDb,
      'volumePeakDb': instance.volumePeakDb,
      'breaksCount': instance.breaksCount,
      'recommendation': instance.recommendation,
    };
