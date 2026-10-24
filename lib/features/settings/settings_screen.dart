import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/listening_preferences_provider.dart';
import 'audio_diagnostics_screen.dart';
import 'developer_diagnostics_screen.dart';
import 'observation_journal_screen.dart';
import 'legacy_history_screen.dart';
import 'data_management_screen.dart';
import 'wellbeing_notification_controls.dart';
import 'about_screen.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(listeningPreferencesProvider).asData?.value.themeMode;
  return ThemeMode.values.firstWhere(
    (value) => value.name == mode,
    orElse: () => ThemeMode.system,
  );
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;
  Future<void> save(Map<String, Object> values) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(listeningPreferencesClientProvider).update(values);
      if (mounted) ref.invalidate(listeningPreferencesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> goal(int current) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(current),
    );
    if (result != null && mounted) await save({'dailyGoalMinutes': result});
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(listeningPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_saving) const LinearProgressIndicator(),
          preferences.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => ListTile(
              title: const Text('Settings unavailable'),
              trailing: IconButton(
                tooltip: 'Retry settings',
                onPressed: () => ref.invalidate(listeningPreferencesProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: ThemeMode.values.firstWhere(
                    (mode) => mode.name == value.themeMode,
                  ),
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: ThemeMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(switch (mode) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (mode) {
                          if (mode != null) save({'themeMode': mode.name});
                        },
                ),
                const SizedBox(height: 24),
                Text(
                  'Wellbeing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily listening goal'),
                  subtitle: Text(
                    value.dailyGoalMinutes == 0
                        ? 'Disabled'
                        : '${value.dailyGoalMinutes} minutes',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit daily goal',
                    onPressed: _saving
                        ? null
                        : () => goal(value.dailyGoalMinutes),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
                const Text(
                  'A personal duration goal, not a safe sound-exposure limit. Automatic listening reminders are unavailable until output attribution is verified.',
                ),
                WellbeingNotificationControls(
                  value: value.notifications,
                  saving: _saving,
                  onSave: (preferences) =>
                      save({'wellbeingNotifications': preferences.toMap()}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Data and diagnostics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _link(
            'Local data',
            Icons.folder_outlined,
            const DataManagementScreen(),
          ),
          _link(
            'Observation Journal',
            Icons.receipt_long_outlined,
            const ObservationJournalScreen(),
          ),
          _link(
            'Preserved legacy history',
            Icons.history,
            const LegacyHistoryScreen(),
          ),
          _link(
            'Audio diagnostics',
            Icons.monitor_heart_outlined,
            const AudioDiagnosticsScreen(),
          ),
          _link(
            'Experimental earbud diagnostics',
            Icons.science_outlined,
            const DeveloperDiagnosticsScreen(),
          ),
          const SizedBox(height: 16),
          _link('About EarTime', Icons.info_outline, const AboutScreen()),
          const Text(
            'EarTime stores observations on this device. Vendor earbud telemetry is unverified. Battery, case and wearing values remain unknown without validated observations.',
          ),
        ],
      ),
    );
  }

  Widget _link(String title, IconData icon, Widget screen) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen)),
  );
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog(this.current);
  final int current;
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final controller = TextEditingController(
    text: '${widget.current == 0 ? 60 : widget.current}',
  );
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Daily goal'),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: 'Minutes', errorText: error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, 0),
        child: const Text('Disable'),
      ),
      FilledButton(
        onPressed: () {
          final minutes = int.tryParse(controller.text);
          if (minutes == null || minutes < 1 || minutes > 1440) {
            setState(() => error = 'Enter 1 to 1440 minutes');
            return;
          }
          Navigator.pop(context, minutes);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
