import 'package:eartime_app/data/app_build_information.dart';
import 'package:eartime_app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<Object?, Object?> buildInfo() => {
  'version': 1,
  'packageName': 'com.eartime.eartime_app',
  'versionName': '1.1.0-dev.1',
  'versionCode': 2,
  'debuggable': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('metadata is strict and does not assert release readiness', () {
    expect(AppBuildInformation.fromMap(buildInfo()).versionCode, 2);
    for (final patch in [
      {'version': 2},
      {'packageName': 'another.app'},
      {'versionName': ''},
      {'versionName': 'line\nbreak'},
      {'versionName': 'x' * 129},
      {'versionCode': 0},
      {'versionCode': 2.0},
      {'debuggable': null},
    ]) {
      expect(
        () => AppBuildInformation.fromMap({...buildInfo(), ...patch}),
        throwsFormatException,
      );
    }
    expect(
      AppBuildInformation.fromMap({
        ...buildInfo(),
        'versionCode': 4294967305,
      }).versionCode,
      4294967305,
    );
  });
  test(
    'client reads installed native metadata and rejects missing data',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readAppBuildInformation');
        return buildInfo();
      });
      expect(
        (await const AppBuildInformationClient().read()).versionName,
        '1.1.0-dev.1',
      );
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await expectLater(
        const AppBuildInformationClient().read(),
        throwsFormatException,
      );
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Settings About retries and displays actual package at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var fail = true;
        var requests = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readListeningPreferences') {
            return {'version': 1, 'themeMode': 'system', 'dailyGoalMinutes': 0};
          }
          if (call.method == 'readAppBuildInformation') {
            requests++;
            if (fail) throw PlatformException(code: 'SYNTHETIC_UNAVAILABLE');
            return buildInfo();
          }
          return null;
        });
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests, 0);
        await tester.scrollUntilVisible(
          find.text('About EarTime'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('About EarTime'));
        await tester.pumpAndSettle();
        expect(find.text('Installed version unavailable'), findsOneWidget);
        fail = false;
        await tester.tap(find.byTooltip('Retry version information'));
        await tester.pumpAndSettle();
        expect(find.text('1.1.0-dev.1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Release ready'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Open-source licenses'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Open-source licenses'));
        await tester.pumpAndSettle();
        expect(find.byType(LicensePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
