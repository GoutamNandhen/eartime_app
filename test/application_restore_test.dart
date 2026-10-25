import 'dart:async';
import 'package:eartime_app/data/application_data_access.dart';
import 'package:eartime_app/data/journal_transfer.dart';
import 'package:eartime_app/features/settings/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:eartime_app/data/database/database.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:eartime_app/providers/listening_preferences_provider.dart';
import 'package:eartime_app/features/settings/settings_screen.dart';
import 'package:eartime_app/features/settings/legacy_history_screen.dart';
import 'application_transfer_test.dart' show ApplicationClient;
import 'listening_settings_test.dart' show MemoryPreferencesClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'legacy reads cannot enter while restore owns access and each entry waits for recovery',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'awaitApplicationDataReady');
            calls.add('ready');
            return {'ready': true};
          });
      final access = ApplicationDataAccess();
      final entered = Completer<void>();
      final released = Completer<void>();
      final restore = access.run(() async {
        calls.add('restore');
        entered.complete();
        await released.future;
      });
      await entered.future;
      final legacy = access.run(() async {
        calls.add('legacy');
        return 42;
      });
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['ready', 'restore']);
      released.complete();
      await restore;
      expect(await legacy, 42);
      expect(calls, ['ready', 'restore', 'ready', 'legacy']);
    },
  );
  test(
    'actual legacy provider waits for restore and operation-owned invalidation refreshes preferences',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => {'ready': true});
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final preferences = MemoryPreferencesClient();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          listeningPreferencesClientProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      expect(
        (await container.read(listeningPreferencesProvider.future)).themeMode,
        'system',
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final restore = container.read(applicationRestoreOperationProvider)(
        () async {
          await database.customStatement(
            "INSERT INTO ear_time_events VALUES ('synthetic','synthetic-device','Synthetic device','bluetooth','PLAYBACK_STARTED',NULL,1000)",
          );
          preferences.values['themeMode'] = 'dark';
          entered.complete();
          await release.future;
          return {'unchanged': false};
        },
      );
      await entered.future;
      final subscription = container.listen(
        legacyHistoryPageProvider(0),
        (_, _) {},
      );
      final page = container.read(legacyHistoryPageProvider(0).future);
      var completed = false;
      final observed = page.then((value) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, false);
      release.complete();
      await restore;
      await observed;
      expect(
        (await container.read(legacyHistoryPageProvider(0).future)).single.id,
        'synthetic',
      );
      expect(
        (await container.read(listeningPreferencesProvider.future)).themeMode,
        'dark',
      );
      subscription.close();
    },
  );
  test(
    'failed recovery blocks data access and releases the queue for explicit retry',
    () async {
      var ready = false;
      var entered = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => {'ready': ready});
      final access = ApplicationDataAccess();
      await expectLater(
        access.run(() async {
          entered = true;
        }),
        throwsFormatException,
      );
      expect(entered, false);
      ready = true;
      await access.run(() async {
        entered = true;
      });
      expect(entered, true);
    },
  );
  test('operation failure never strands subsequent legacy requests', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'ready': true});
    final access = ApplicationDataAccess();
    await expectLater(
      access.run(() async => throw StateError('Synthetic restore failure')),
      throwsStateError,
    );
    expect(await access.run(() async => 'legacy'), 'legacy');
  });
  test(
    'application restore validates scope and receipt bounds and explicit confirmation',
    () async {
      var wrong = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'restoreApplicationData');
            expect((call.arguments as Map)['confirmed'], true);
            return {
              'version': 1,
              'scope': wrong ? 'native_observations_only' : 'application_data',
              'componentCount': 5,
              'count': 2,
              'legacyCount': 3,
              'sha256': '0' * 64,
            };
          });
      expect(
        (await const JournalTransferClient().transfer(
          'restoreApplicationData',
        ))['legacyCount'],
        3,
      );
      wrong = true;
      await expectLater(
        const JournalTransferClient().transfer('restoreApplicationData'),
        throwsFormatException,
      );
    },
  );
  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'application restore waits for preparation and requires separate destructive consent at scale $scale',
      (tester) async {
        final client = ApplicationClient();
        var prepared = 0;
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: DataManagementScreen(
              client: client,
              runApplicationRestore: (operation) async {
                prepared++;
                expect(client.operations, isEmpty);
                return operation();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Restore application data'),
          250,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restore application data'));
        await tester.pumpAndSettle();
        expect(find.text('Replace application data?'), findsOneWidget);
        expect(prepared, 0);
        expect(client.operations, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(client.operations, isEmpty);
        await tester.tap(find.text('Restore application data'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Replace application data'),
        );
        await tester.pumpAndSettle();
        expect(prepared, 1);
        expect(client.operations, ['restoreApplicationData:']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
