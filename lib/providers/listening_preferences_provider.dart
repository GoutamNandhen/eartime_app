import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListeningPreferences {
  ListeningPreferences.fromMap(Map<dynamic, dynamic> map)
    : themeMode = map['themeMode'] as String,
      dailyGoalMinutes = map['dailyGoalMinutes'] as int {
    if (map['version'] != 1 ||
        !['system', 'light', 'dark'].contains(themeMode) ||
        dailyGoalMinutes < 0 ||
        dailyGoalMinutes > 1440) {
      throw const FormatException('Invalid listening preferences');
    }
  }
  final String themeMode;
  final int dailyGoalMinutes;
}

class ListeningPreferencesClient {
  const ListeningPreferencesClient();
  static const _channel = MethodChannel('com.eartime.app/tracking');
  Future<ListeningPreferences> read() async => ListeningPreferences.fromMap(
    (await _channel.invokeMapMethod<dynamic, dynamic>(
      'readListeningPreferences',
    ))!,
  );
  Future<ListeningPreferences> update(Map<String, Object> values) async =>
      ListeningPreferences.fromMap(
        (await _channel.invokeMapMethod<dynamic, dynamic>(
          'updateListeningPreferences',
          values,
        ))!,
      );
}

final listeningPreferencesClientProvider = Provider(
  (ref) => const ListeningPreferencesClient(),
);
final listeningPreferencesProvider = FutureProvider<ListeningPreferences>(
  (ref) => ref.read(listeningPreferencesClientProvider).read(),
);
