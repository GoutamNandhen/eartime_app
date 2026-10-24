import 'dart:async';

import 'package:eartime_app/core/diagnostics/startup_trace.dart';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/features/shell/app_shell.dart';
import 'package:eartime_app/features/permissions/permission_screen.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:eartime_app/providers/listening_projection_provider.dart';
import 'package:eartime_app/providers/permission_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RapidPermissionGateway implements StartupPermissionGateway {
  int checks = 0;
  Future<bool> Function() result = () async => true;
  @override
  Future<bool> checkCollectionPermission() {
    checks++;
    return result();
  }

  @override
  Future<bool> requestCollectionPermission() => checkCollectionPermission();
  @override
  Future<NotificationCapability> checkNotificationCapability() async =>
      NotificationCapability.granted;
}

ProviderContainer startupContainer(RapidPermissionGateway gateway) =>
    ProviderContainer(
      overrides: [
        startupPermissionGatewayProvider.overrideWithValue(gateway),
        startupTimeoutsProvider.overrideWithValue(
          const StartupTimeouts(collection: Duration(milliseconds: 100)),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'D disposed startup A completes after B is ready without changing B',
    () async {
      final pendingA = Completer<bool>();
      final gatewayA = RapidPermissionGateway()..result = () => pendingA.future;
      final a = startupContainer(gatewayA);
      final b = startupContainer(RapidPermissionGateway());
      addTearDown(b.dispose);
      final oldRun = a.read(permissionProvider.notifier).checkPermissions();
      a.dispose();
      await b.read(permissionProvider.notifier).checkPermissions();
      pendingA.complete(false);
      await oldRun;
      expect(b.read(permissionProvider).status, PermissionStatusState.granted);
      expect(b.read(permissionProvider).generation, 1);
    },
  );

  testWidgets(
    'E first-frame wins then one-second fallback cannot run startup twice',
    (tester) async {
      final gateway = RapidPermissionGateway();
      final container = startupContainer(gateway);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PermissionScreen()),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(gateway.checks, 1);
      expect(container.read(permissionProvider).generation, 1);
    },
  );

  testWidgets(
    'E fallback wins before the queued frame callback, startup begins once',
    (tester) async {
      final gateway = RapidPermissionGateway();
      final container = startupContainer(gateway);
      addTearDown(container.dispose);
      container.read(permissionProvider);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(gateway.checks, 1);
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
      expect(container.read(permissionProvider).generation, 1);
    },
  );

  testWidgets(
    'F old first-frame callback after retry cannot restart a ready generation',
    (tester) async {
      final gateway = RapidPermissionGateway();
      final container = startupContainer(gateway);
      addTearDown(container.dispose);
      final notifier = container.read(permissionProvider.notifier);
      await tester.runAsync(notifier.checkPermissions);
      await tester.runAsync(notifier.checkPermissions);
      expect(container.read(permissionProvider).generation, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(gateway.checks, 2);
      expect(container.read(permissionProvider).generation, 2);
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.granted,
      );
    },
  );

  testWidgets(
    'first shell frame does not await an unresolved permission platform future',
    (tester) async {
      final pending = Completer<bool>();
      final gateway = RapidPermissionGateway()..result = () => pending.future;
      var pipelineStarted = false;
      final container = ProviderContainer(
        overrides: [
          startupPermissionGatewayProvider.overrideWithValue(gateway),
          trackingProjectionActivationProvider.overrideWith((_) {
            pipelineStarted = true;
          }),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppShell()),
        ),
      );
      expect(find.text('Tracking permission'), findsOneWidget);
      expect(
        container.read(permissionProvider).status,
        PermissionStatusState.checking,
      );
      expect(pipelineStarted, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      pending.complete(true);
      await tester.runAsync(() async => pumpEventQueue());
    },
  );

  testWidgets(
    'ready shell emits one stage marker without waiting on native tracking',
    (tester) async {
      final messages = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      var pipelineStarts = 0;
      final container = ProviderContainer(
        overrides: [
          startupPermissionGatewayProvider.overrideWithValue(
            RapidPermissionGateway(),
          ),
          trackingProjectionActivationProvider.overrideWith((_) {
            pipelineStarts++;
          }),
          analyticsDataProvider.overrideWithValue(const AsyncData(null)),
          recentEventsProvider.overrideWithValue(const AsyncData([])),
          wellbeingDataProvider.overrideWith((_) async => null),
          trackingStreamHealthProvider.overrideWith(
            (_) => Stream.value(
              const TrackingStreamHealth(status: TrackingStreamStatus.healthy),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AppShell()),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('TOTAL LISTEN TIME'), findsOneWidget);
        expect(pipelineStarts, 1);
        expect(
          messages.where((line) => line.contains('APP_SHELL_READY')).length,
          1,
        );
        expect(
          messages.any(
            (line) => line.contains('meaning=shellConstructedNotRasterized'),
          ),
          isTrue,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        debugPrint = previous;
      }
    },
  );

  test(
    'G 100 rapid startup/disposal replacements have a deterministic ready survivor',
    () async {
      final previous = debugPrint;
      debugPrint = (String? _, {int? wrapWidth}) {};
      try {
        for (var index = 0; index < 100; index++) {
          final oldResult = Completer<bool>();
          final old = startupContainer(
            RapidPermissionGateway()..result = () => oldResult.future,
          );
          final next = startupContainer(RapidPermissionGateway());
          final oldRun = old
              .read(permissionProvider.notifier)
              .checkPermissions();
          await next.read(permissionProvider.notifier).checkPermissions();
          old.dispose();
          oldResult.complete(index.isEven);
          await oldRun;
          expect(
            next.read(permissionProvider).status,
            PermissionStatusState.granted,
          );
          next.dispose();
        }
      } finally {
        debugPrint = previous;
      }
    },
  );

  test(
    'A cancellation cannot close or reset a B consumer in the same Dart runtime',
    () async {
      var rawListens = 0;
      final raw = StreamController<dynamic>.broadcast(
        onListen: () => rawListens++,
      );
      TrackingPlatform.setRawStreamForTesting(raw.stream);
      final a = TrackingPlatform.eventStream.listen((_) {});
      final receivedB = <String>[];
      final b = TrackingPlatform.eventStream.listen(
        (event) => receivedB.add(event.type),
      );
      await a.cancel();
      raw.add({'type': 'PLAYBACK_STARTED', 'timestamp': 1});
      await pumpEventQueue();
      expect(receivedB, ['PLAYBACK_STARTED']);
      expect(rawListens, 1);
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.healthy,
      );
      await b.cancel();
      TrackingPlatform.resetForTesting();
      await raw.close();
    },
  );

  test(
    'late native cancel failure from A cannot poison replacement B health',
    () async {
      const channel = MethodChannel('com.eartime.app/tracking_events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final oldCancel = Completer<dynamic>();
      var cancels = 0;
      var listens = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'listen') listens++;
        if (call.method == 'cancel' && ++cancels == 1) return oldCancel.future;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      TrackingPlatform.setRawStreamForTesting(null);
      final a = TrackingPlatform.eventStream.listen(
        (_) {},
        onError: (Object _) {},
      );
      await pumpEventQueue();
      await a.cancel();
      final received = <String>[];
      final b = TrackingPlatform.eventStream.listen(
        (event) => received.add(event.type),
        onError: (Object _) {},
      );
      await pumpEventQueue();
      ServicesBinding.instance.channelBuffers.push(
        channel.name,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'type': 'PLAYBACK_STARTED',
          'timestamp': 2,
        }),
        (_) {},
      );
      await pumpEventQueue();
      oldCancel.completeError(PlatformException(code: 'old_cancel_failed'));
      await pumpEventQueue();
      expect(received, ['PLAYBACK_STARTED']);
      expect(listens, 2);
      expect(
        TrackingPlatform.currentStreamHealth.status,
        TrackingStreamStatus.healthy,
      );
      await b.cancel();
      await pumpEventQueue();
      TrackingPlatform.resetForTesting();
    },
  );

  test('structured marker distinguishes elapsed time, runtime, and stage', () {
    final line = StartupTrace.format(
      'PERMISSION_CHECK_BEGIN',
      elapsedMs: 7,
      fields: 'generation=2',
    );
    expect(line, contains('STARTUP_TRACE:dart='));
    expect(line, contains('PERMISSION_CHECK_BEGIN elapsedMs=7'));
    expect(line, contains('generation=2'));
  });

  test(
    'structured milestone fields are bounded rather than formatting full payloads',
    () {
      final line = StartupTrace.format(
        'APP_SHELL_READY',
        elapsedMs: 10,
        fields: 'x' * 10000,
      );
      expect(line.length, lessThan(600));
      expect(line, endsWith('...'));
    },
  );

  testWidgets(
    'milestones expose one startup generation despite frame/fallback race',
    (tester) async {
      final messages = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      final container = startupContainer(RapidPermissionGateway());
      try {
        container.read(permissionProvider);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(
          messages
              .where((line) => line.contains('STARTUP_GENERATION_STARTED'))
              .length,
          1,
        );
        expect(
          messages.any((line) => line.contains('FIRST_FRAME_FALLBACK_FIRED')),
          isTrue,
        );
        expect(
          messages.any((line) => line.contains('PERMISSION_CHECK_RESULT')),
          isTrue,
        );
      } finally {
        container.dispose();
        debugPrint = previous;
      }
    },
  );
}
