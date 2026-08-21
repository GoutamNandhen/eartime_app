import '../models/analytics_data.dart';

abstract class AnalyticsRepository {
  Future<Duration> getTotalListeningTime(DateTime start, DateTime end);
  Future<Duration> getDeviceListeningTime(String canonicalDeviceId, DateTime start, DateTime end);
  Future<AnalyticsData?> getAnalyticsData();
  Future<WellbeingData?> getWellbeingData();
}

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  @override
  Future<Duration> getTotalListeningTime(DateTime start, DateTime end) async => Duration.zero;

  @override
  Future<Duration> getDeviceListeningTime(String canonicalDeviceId, DateTime start, DateTime end) async => Duration.zero;

  @override
  Future<AnalyticsData?> getAnalyticsData() async => null;

  @override
  Future<WellbeingData?> getWellbeingData() async => null;
}
