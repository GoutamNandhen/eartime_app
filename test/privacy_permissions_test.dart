import 'package:eartime_app/features/permissions/permission_screen.dart';
import 'package:eartime_app/features/settings/privacy_screen.dart';
import 'package:eartime_app/features/settings/settings_screen.dart';
import 'package:eartime_app/providers/permission_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class DisclosureGateway implements StartupPermissionGateway {
  int requests = 0;
  @override
  Future<bool> checkCollectionPermission() async => false;
  @override
  Future<bool> requestCollectionPermission() async {
    requests++;
    return false;
  }

  @override
  Future<NotificationCapability> checkNotificationCapability() async =>
      NotificationCapability.denied;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scale in [2.0, 3.0]) {
    testWidgets('permission gate fits 360px at scale $scale without clamping', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = DisclosureGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupPermissionGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const PermissionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final grant = find.text('Grant tracking permission');
      await tester.ensureVisible(grant);
      await tester.pumpAndSettle();
      await tester.tap(grant);
      await tester.pumpAndSettle();
      expect(gateway.requests, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final settings in [false, true]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'offline disclosures reachable from settings=$settings at scale $scale without requests',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final gateway = DisclosureGateway();
          const channel = MethodChannel('com.eartime.app/tracking');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          var nativeCalls = 0;
          messenger.setMockMethodCallHandler(channel, (_) async {
            nativeCalls++;
            throw PlatformException(code: 'SYNTHETIC_PLATFORM_OFFLINE');
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                startupPermissionGatewayProvider.overrideWithValue(gateway),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: settings
                    ? const SettingsScreen()
                    : const PermissionScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final before = nativeCalls;
          await tester.scrollUntilVisible(
            find.text('Privacy and permissions'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(find.text('Privacy and permissions'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Privacy and permissions'));
          await tester.pumpAndSettle();
          expect(find.byType(PrivacyScreen), findsOneWidget);
          expect(gateway.requests, 0);
          expect(nativeCalls, before);
          for (final (heading, body) in PrivacyScreen.sections) {
            await tester.scrollUntilVisible(
              find.text(heading),
              250,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 150,
            );
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text(body),
              250,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 150,
            );
            await tester.pumpAndSettle();
            expect(find.text(body), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(PrivacyScreen), findsNothing);
          expect(gateway.requests, 0);
        },
      );
    }
  }
}
