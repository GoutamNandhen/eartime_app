import 'package:eartime_app/data/listening_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder preferences default, round-trip and reject invalid', () {
    const defaults = ListeningReminderPreferences();
    expect(ListeningReminderPreferences.fromMap(null).continuousMinutes, 60);
    final changed = defaults.copyWith(enabled: false, continuousMinutes: 90);
    final parsed = ListeningReminderPreferences.fromMap(changed.toMap());
    expect(parsed.enabled, isFalse);
    expect(parsed.continuousMinutes, 90);
    expect(parsed.repeatMinutes, 30);
    expect(
      () => ListeningReminderPreferences.fromMap({
        ...defaults.toMap(),
        'continuousMinutes': 2,
      }),
      throwsFormatException,
    );
    expect(
      () => ListeningReminderPreferences.fromMap({
        ...defaults.toMap(),
        'enabled': 'yes',
      }),
      throwsFormatException,
    );
  });
}
