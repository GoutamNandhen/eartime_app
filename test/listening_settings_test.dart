import 'package:eartime_app/features/settings/settings_screen.dart';
import 'package:eartime_app/providers/listening_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPreferencesClient extends ListeningPreferencesClient {
  Map<String, Object> values = {
    'version': 1,
    'themeMode': 'system',
    'dailyGoalMinutes': 0,
  };
  bool fail = false;
  @override
  Future<ListeningPreferences> read() async =>
      ListeningPreferences.fromMap(values);
  @override
  Future<ListeningPreferences> update(Map<String, Object> updates) async {
    if (fail) throw StateError('Storage unavailable');
    values = {...values, ...updates};
    return ListeningPreferences.fromMap(values);
  }
}

void main() {
  test(
    'preferences reject unsupported versions and invalid personal goals',
    () {
      expect(
        () => ListeningPreferences.fromMap({
          'version': 2,
          'themeMode': 'system',
          'dailyGoalMinutes': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => ListeningPreferences.fromMap({
          'version': 1,
          'themeMode': 'dark',
          'dailyGoalMinutes': -1,
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'theme and goal are read again after Flutter owner replacement',
    () async {
      final client = MemoryPreferencesClient();
      var container = ProviderContainer(
        overrides: [
          listeningPreferencesClientProvider.overrideWithValue(client),
        ],
      );
      await client.update({'themeMode': 'dark', 'dailyGoalMinutes': 45});
      await container.read(listeningPreferencesProvider.future);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      container.dispose();
      container = ProviderContainer(
        overrides: [
          listeningPreferencesClientProvider.overrideWithValue(client),
        ],
      );
      expect(
        (await container.read(
          listeningPreferencesProvider.future,
        )).dailyGoalMinutes,
        45,
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
      container.dispose();
    },
  );

  testWidgets(
    'goal validates input, persists and can be disabled without a dangling timer',
    (tester) async {
      final client = MemoryPreferencesClient();
      final container = ProviderContainer(
        overrides: [
          listeningPreferencesClientProvider.overrideWithValue(client),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit daily goal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter 1 to 1440 minutes'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '45');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(client.values['dailyGoalMinutes'], 45);
      expect(find.text('45 minutes'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit daily goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      expect(client.values['dailyGoalMinutes'], 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'save errors are visible and do not pretend preferences were persisted',
    (tester) async {
      final client = MemoryPreferencesClient()..fail = true;
      final container = ProviderContainer(
        overrides: [
          listeningPreferencesClientProvider.overrideWithValue(client),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit daily goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Settings could not be saved.'), findsOneWidget);
      expect(client.values['dailyGoalMinutes'], 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}
