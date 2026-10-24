import 'dart:async';

import 'package:eartime_app/features/permissions/permission_screen.dart';
import 'package:eartime_app/features/widgets/tracking_health_notice.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/providers/permission_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePermissionGateway implements StartupPermissionGateway {
  Future<bool> Function() collectionCheck = () async => true;
  Future<bool> Function() collectionRequest = () async => true;
  Future<NotificationCapability> Function() notificationCheck = () async =>
      NotificationCapability.granted;

  @override
  Future<bool> checkCollectionPermission() => collectionCheck();

  @override
  Future<bool> requestCollectionPermission() => collectionRequest();

  @override
  Future<NotificationCapability> checkNotificationCapability() =>
      notificationCheck();
}

const testTimeouts = StartupTimeouts(
  collection: Duration(milliseconds: 30),
  request: Duration(milliseconds: 30),
  notification: Duration(milliseconds: 30),
  firstFrameFallback: Duration(seconds: 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePermissionGateway gateway;
  late ProviderContainer container;

  setUp(() {
    gateway = FakePermissionGateway();
    container = ProviderContainer(
      overrides: [
        startupPermissionGatewayProvider.overrideWithValue(gateway),
        startupTimeoutsProvider.overrideWithValue(testTimeouts),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('Android production permission adapter', () {
    const tracking = MethodChannel('com.eartime.app/tracking');
    const permissions = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> permissionCalls;
    var sdk = 33;

    setUp(() {
      sdk = 33;
      permissionCalls = [];
      messenger.setMockMethodCallHandler(tracking, (_) async => sdk);
      messenger.setMockMethodCallHandler(permissions, (call) async {
        permissionCalls.add(call);
        if (call.method == 'requestPermissions') {
          return {
            for (final int permission in call.arguments as List) permission: 1,
          };
        }
        return call.arguments == Permission.notification.value ? 0 : 1;
      });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(tracking, null);
      messenger.setMockMethodCallHandler(permissions, null);
    });

    test('Android 12+ checks only bluetoothConnect for collection', () async {
      final adapter = PlatformStartupPermissionGateway.forTesting(
        isAndroid: true,
      );
      expect(await adapter.checkCollectionPermission(), isTrue);
      expect(
        permissionCalls.single.arguments,
        Permission.bluetoothConnect.value,
      );
      expect(
        await adapter.checkNotificationCapability(),
        NotificationCapability.denied,
      );
    });

    test('older Android checks the legacy Bluetooth prerequisite', () async {
      sdk = 30;
      final adapter = PlatformStartupPermissionGateway.forTesting(
        isAndroid: true,
      );
      expect(await adapter.checkCollectionPermission(), isTrue);
      expect(permissionCalls.single.arguments, Permission.bluetooth.value);
    });

    test('request does not bundle optional notification permission', () async {
      final adapter = PlatformStartupPermissionGateway.forTesting(
        isAndroid: true,
      );
      expect(await adapter.requestCollectionPermission(), isTrue);
      expect(permissionCalls.single.method, 'requestPermissions');
      expect(permissionCalls.single.arguments, [
        Permission.bluetoothConnect.value,
      ]);
    });

    test('missing SDK response reaches recoverable startup error', () async {
      messenger.setMockMethodCallHandler(tracking, (_) async => null);
      final androidContainer = ProviderContainer(
        overrides: [
          startupPermissionGatewayProvider.overrideWithValue(
            PlatformStartupPermissionGateway.forTesting(isAndroid: true),
          ),
        ],
      );
      addTearDown(androidContainer.dispose);
      await androidContainer
          .read(permissionProvider.notifier)
          .checkPermissions();
      expect(
        androidContainer.read(permissionProvider).status,
        PermissionStatusState.error,
      );
      expect(
        androidContainer.read(permissionProvider).message,
        contains('SDK response was absent'),
      );
      expect(permissionCalls, isEmpty);
    });
  });

  test('A collection permission success makes startup usable', () async {
    await container.read(permissionProvider.notifier).checkPermissions();
    expect(
      container.read(permissionProvider).status,
      PermissionStatusState.granted,
    );
    expect(container.read(permissionProvider).generation, 1);
  });

  test('B denied collection permission becomes permission required', () async {
    gateway.collectionCheck = () async => false;
    await container.read(permissionProvider.notifier).checkPermissions();
    expect(
      container.read(permissionProvider).status,
      PermissionStatusState.denied,
    );
    expect(
      container.read(permissionProvider).stage,
      StartupStage.permissionRequired,
    );
  });

  test(
    'C permission exception exits checking and retains diagnostic',
    () async {
      gateway.collectionCheck = () async => throw StateError('platform failed');
      await container.read(permissionProvider.notifier).checkPermissions();
      final startup = container.read(permissionProvider);
      expect(startup.status, PermissionStatusState.error);
      expect(startup.message, contains('platform failed'));
    },
  );

  test('D a never completing permission check has a finite outcome', () async {
    gateway.collectionCheck = () => Completer<bool>().future;
    await container.read(permissionProvider.notifier).checkPermissions();
    expect(
      container.read(permissionProvider).status,
      PermissionStatusState.error,
    );
    expect(container.read(permissionProvider).message, contains('timed out'));
  });

  test(
    'E timeout retry succeeds and obsolete completion cannot overwrite it',
    () async {
      final oldCheck = Completer<bool>();
      gateway.collectionCheck = () => oldCheck.future;
      final notifier = container.read(permissionProvider.notifier);
      await notifier.checkPermissions();
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.error,
      );

      gateway.collectionCheck = () async => true;
      await notifier.checkPermissions();
      oldCheck.complete(false);
      await pumpEventQueue();
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
      expect(container.read(permissionProvider).generation, 2);
    },
  );

  test('a response from a superseded still-running check is ignored', () async {
    final oldCheck = Completer<bool>();
    gateway.collectionCheck = () => oldCheck.future;
    final notifier = container.read(permissionProvider.notifier);
    final oldRun = notifier.checkPermissions();
    gateway.collectionCheck = () async => true;
    await notifier.checkPermissions();
    oldCheck.complete(false);
    await oldRun;
    expect(
      container.read(permissionProvider).status,
      PermissionStatusState.granted,
    );
    expect(container.read(permissionProvider).generation, 2);
  });

  test(
    'optional notifications neither deny nor indefinitely block startup',
    () async {
      gateway.notificationCheck = () =>
          Completer<NotificationCapability>().future;
      await container.read(permissionProvider.notifier).checkPermissions();
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(permissionProvider).notifications,
        NotificationCapability.unavailable,
      );
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
    },
  );

  test(
    'notification denial remains distinct from collection permission',
    () async {
      gateway.notificationCheck = () async => NotificationCapability.denied;
      await container.read(permissionProvider.notifier).checkPermissions();
      await pumpEventQueue();
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
      expect(
        container.read(permissionProvider).notifications,
        NotificationCapability.denied,
      );
    },
  );

  test('permission request failure is bounded and recoverable', () async {
    gateway.collectionRequest = () => Completer<bool>().future;
    final granted = await container
        .read(permissionProvider.notifier)
        .requestPermissions();
    expect(granted, isFalse);
    expect(
      container.read(permissionProvider).status,
      PermissionStatusState.error,
    );
  });

  test(
    'completion after provider disposal does not touch disposed state',
    () async {
      final pending = Completer<bool>();
      gateway.collectionCheck = () => pending.future;
      final run = container
          .read(permissionProvider.notifier)
          .checkPermissions();
      container.dispose();
      pending.complete(true);
      await run;
    },
  );

  test(
    'first-frame fallback starts checking even without a rendered frame',
    () async {
      final fallbackContainer = ProviderContainer(
        overrides: [
          startupPermissionGatewayProvider.overrideWithValue(gateway),
          startupTimeoutsProvider.overrideWithValue(
            const StartupTimeouts(
              firstFrameFallback: Duration(milliseconds: 5),
            ),
          ),
        ],
      );
      addTearDown(fallbackContainer.dispose);
      expect(
        fallbackContainer.read(permissionProvider).stage,
        StartupStage.awaitingFirstFrame,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        fallbackContainer.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
      expect(fallbackContainer.read(permissionProvider).generation, 1);
    },
  );

  test(
    'late optional response and old command error cannot replace fresh state',
    () async {
      final oldNotifications = Completer<NotificationCapability>();
      gateway.notificationCheck = () => oldNotifications.future;
      final notifier = container.read(permissionProvider.notifier);
      await notifier.checkPermissions();
      gateway.notificationCheck = () async => NotificationCapability.granted;
      await notifier.checkPermissions();
      oldNotifications.complete(NotificationCapability.denied);
      notifier.recordPlatformError(1, StateError('obsolete command'));
      await pumpEventQueue();
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
      expect(
        container.read(permissionProvider).notifications,
        NotificationCapability.granted,
      );
      expect(container.read(permissionProvider).generation, 2);
    },
  );

  testWidgets(
    'stream failure renders a stale-state warning without a second subscription',
    (tester) async {
      var listens = 0;
      final raw = StreamController<dynamic>.broadcast(
        onListen: () => listens++,
      );
      TrackingPlatform.setRawStreamForTesting(raw.stream);
      final sub = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object _) {},
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TrackingHealthNotice()),
          ),
        ),
      );
      raw.addError(StateError('native failed'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Live status may be stale'), findsOneWidget);
      expect(listens, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await sub.cancel();
        TrackingPlatform.resetForTesting();
        await raw.close();
      });
    },
  );

  testWidgets('permission error UI exposes a working check retry', (
    tester,
  ) async {
    gateway.collectionCheck = () async => throw StateError('platform failed');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PermissionScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('platform failed'), findsOneWidget);
    gateway.collectionCheck = () async => true;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(
      container.read(permissionProvider).status,
      PermissionStatusState.granted,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('permission-required UI exposes a grant action', (tester) async {
    gateway.collectionCheck = () async => false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PermissionScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Grant tracking permission'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
