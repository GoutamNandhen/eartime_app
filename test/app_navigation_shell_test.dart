import 'dart:async';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/features/shell/app_shell.dart';
import 'package:eartime_app/features/settings/settings_screen.dart';
import 'package:eartime_app/features/devices/devices_screen.dart';
import 'package:eartime_app/providers/permission_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class GrantedGateway implements StartupPermissionGateway {
  @override
  Future<bool> checkCollectionPermission() async => true;
  @override
  Future<bool> requestCollectionPermission() async => true;
  @override
  Future<NotificationCapability> checkNotificationCapability() async =>
      NotificationCapability.denied;
}

void main() {
  testWidgets(
    'warm widget navigation dismisses Settings and opens the selected actual screen',
    (tester) async {
      const channel = MethodChannel('com.eartime.app/navigation');
      const tracking = MethodChannel('com.eartime.app/tracking');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      String? pending;
      messenger.setMockMethodCallHandler(channel, (_) async {
        final result = pending;
        pending = null;
        return result;
      });
      messenger.setMockMethodCallHandler(tracking, (call) async {
        if (call.method == 'readListeningPreferences') {
          return {'version': 1, 'themeMode': 'system', 'dailyGoalMinutes': 0};
        }
        if (call.method == 'readListeningProjection') {
          return {
            'projectionVersion': 3,
            'sourceId': 'synthetic-empty-history',
            'sequence': 0,
            'fromUtcMs': (call.arguments as Map)['fromUtcMs'],
            'untilUtcMs': (call.arguments as Map)['untilUtcMs'],
            'confirmedMs': 0,
            'unverifiedMs': 0,
            'gapCount': 0,
            'intervalCount': 0,
            'nextOffset': 0,
            'hasMore': false,
            'intervals': <Object>[],
            'devices': <Object>[],
            'days': <Object>[],
          };
        }
        throw PlatformException(code: 'UNEXPECTED_TEST_RPC');
      });
      final events = StreamController<dynamic>.broadcast();
      TrackingPlatform.setRawStreamForTesting(events.stream);
      final container = ProviderContainer(
        overrides: [
          startupPermissionGatewayProvider.overrideWithValue(GrantedGateway()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      pending = 'devices';
      final handled = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('navigationAvailable'),
        ),
        (_) => handled.complete(),
      );
      await tester.pumpAndSettle();
      await handled.future;
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(DevicesScreen), findsOneWidget);
      expect(pending, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(tracking, null);
      TrackingPlatform.resetForTesting();
      await events.close();
    },
  );
}
