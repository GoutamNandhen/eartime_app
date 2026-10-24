import 'package:eartime_app/data/wellbeing_notifications.dart';
import 'package:eartime_app/features/settings/settings_screen.dart';
import 'package:eartime_app/features/settings/wellbeing_notification_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> notificationStatus({bool permission = true}) => {
  'version': 1,
  'permissionGranted': permission,
  'schedulingAvailable': true,
  'liveRemindersEligible': false,
  'dailyUtcMs': null,
  'weeklyUtcMs': null,
  'delivery': 'NOT_DELIVERED',
};

class StatusFixture extends WellbeingNotificationClient {
  bool allowed = false;
  bool fail = false;
  int calls = 0;
  @override
  Future<WellbeingNotificationStatus> status() async {
    calls++;
    if (fail) throw StateError('Synthetic unavailable notification status');
    return WellbeingNotificationStatus.fromMap(
      notificationStatus(permission: allowed),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'preferences default off and reject corrupt schema, types and minute bounds',
    () {
      final defaults = WellbeingNotificationPreferences.fromMap(null);
      expect(defaults.daily, false);
      expect(defaults.weekly, false);
      expect(defaults.quiet, true);
      for (final invalid in [
        {...defaults.toMap(), 'version': 2},
        {...defaults.toMap(), 'daily': 'true'},
        {...defaults.toMap(), 'quietEnd': 1440},
        {...defaults.toMap(), 'quietStart': -1},
      ]) {
        expect(
          () => WellbeingNotificationPreferences.fromMap(invalid),
          throwsFormatException,
        );
      }
      expect(
        () => WellbeingNotificationStatus.fromMap({
          ...notificationStatus(),
          'liveRemindersEligible': true,
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'status reads native scheduling evidence, never starts an accounting timer',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readWellbeingNotificationStatus');
        return notificationStatus();
      });
      final result = await const WellbeingNotificationClient().status();
      expect(result.schedulingAvailable, true);
      expect(result.daily, isNull);
    },
  );
  for (final fail in [false, true]) {
    testWidgets(
      'Settings summary toggles persist native configuration and show save failure=$fail',
      (tester) async {
        var saved = const WellbeingNotificationPreferences();
        var updates = 0;
        Map<String, Object?> preferences() => {
          'version': 1,
          'themeMode': 'system',
          'dailyGoalMinutes': 0,
          'wellbeingNotifications': saved.toMap(),
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readListeningPreferences') return preferences();
          if (call.method == 'readWellbeingNotificationStatus') {
            return notificationStatus();
          }
          if (call.method == 'updateListeningPreferences') {
            updates++;
            if (fail) throw PlatformException(code: 'SYNTHETIC_SAVE_FAILURE');
            saved = WellbeingNotificationPreferences.fromMap(
              call.arguments['wellbeingNotifications'],
            );
            return preferences();
          }
          return null;
        });
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SettingsScreen())),
        );
        await tester.pumpAndSettle();
        final daily = find.widgetWithText(SwitchListTile, 'Daily summary');
        await tester.ensureVisible(daily);
        await tester.pumpAndSettle();
        await tester.tap(daily);
        await tester.pumpAndSettle();
        expect(updates, 1);
        expect(saved.daily, !fail);
        expect(tester.widget<SwitchListTile>(daily).value, !fail);
        if (fail) {
          expect(find.text('Settings could not be saved.'), findsOneWidget);
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            const ProviderScope(child: MaterialApp(home: SettingsScreen())),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SwitchListTile>(
                  find.widgetWithText(SwitchListTile, 'Daily summary'),
                )
                .value,
            true,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'permission is requested only on explicit action and does not implicitly enable summaries',
    (tester) async {
      final client = StatusFixture();
      var requests = 0;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WellbeingNotificationControls(
                value: const WellbeingNotificationPreferences(),
                client: client,
                onSave: (_) async {
                  saves++;
                },
                requestPermission: () async {
                  requests++;
                  client.allowed = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.ensureVisible(find.text('Enable notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable notifications'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(saves, 0);
      expect(find.text('Enable notifications'), findsNothing);
    },
  );
  testWidgets(
    'time entry rejects invalid values and cancellation preserves the preference',
    (tester) async {
      final client = StatusFixture()..allowed = true;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WellbeingNotificationControls(
                value: const WellbeingNotificationPreferences(),
                client: client,
                onSave: (_) async {
                  saves++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Summary time'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '25');
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 0-23 hours and 0-59 minutes.'), findsOneWidget);
      expect(saves, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.text('Time'), findsNothing);
    },
  );
  for (final large in [false, true]) {
    testWidgets(
      'quiet-hours controls, time picker and retry work at large text=$large',
      (tester) async {
        tester.view.physicalSize = const Size(380, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var saved = const WellbeingNotificationPreferences();
        final client = StatusFixture()..allowed = true;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(large ? 2 : 1),
                alwaysUse24HourFormat: true,
              ),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SingleChildScrollView(
                  child: WellbeingNotificationControls(
                    value: saved,
                    client: client,
                    onSave: (value) async {
                      setState(() => saved = value);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final edit = find.byTooltip('Edit Quiet hours start');
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        await tester.tap(edit);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '21');
        await tester.enterText(find.byType(TextField).at(1), '30');
        await tester.ensureVisible(find.text('Save time'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save time'));
        await tester.pumpAndSettle();
        expect(saved.quietStart, 1290);
        expect(tester.takeException(), isNull);
        client.fail = true;
        await tester.ensureVisible(
          find.byTooltip('Refresh notification status'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Refresh notification status'));
        await tester.pumpAndSettle();
        expect(find.text('Notification status unavailable.'), findsOneWidget);
        client.fail = false;
        await tester.ensureVisible(
          find.byTooltip('Refresh notification status'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Refresh notification status'));
        await tester.pumpAndSettle();
        expect(find.text('Notification status unavailable.'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
