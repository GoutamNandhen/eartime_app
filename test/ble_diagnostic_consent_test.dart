import 'dart:async';
import 'package:eartime_app/data/tracking_platform.dart';
import 'package:eartime_app/domain/models/audio_device.dart';
import 'package:eartime_app/domain/models/live_session_state.dart';
import 'package:eartime_app/features/settings/developer_diagnostics_screen.dart';
import 'package:eartime_app/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class DiagnosticLiveFixture extends LiveSessionNotifier {
  @override
  LiveSessionState build() => LiveSessionState(
    isInitialized: true,
    activeDevice: AudioDevice(
      canonicalDeviceId: '02:11:22:33:44:55',
      displayName: 'Synthetic device',
      deviceType: 'bluetooth',
      lastSeen: DateTime(2026),
    ),
  );
}

void main() {
  testWidgets(
    'opening diagnostics with a device does not interact until explicit confirmation',
    (tester) async {
      final events = StreamController<dynamic>.broadcast();
      TrackingPlatform.setRawStreamForTesting(events.stream);
      const channel = MethodChannel('com.eartime.app/tracking');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {'queued': true};
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        TrackingPlatform.resetForTesting();
        await events.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allEventsProvider.overrideWith((_) => Stream.value(const [])),
            liveSessionProvider.overrideWith(DiagnosticLiveFixture.new),
          ],
          child: const MaterialApp(home: DeveloperDiagnosticsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'startBleDiagnostic'),
        isEmpty,
      );
      await tester.tap(find.text('Refresh Diagnostic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'startBleDiagnostic'),
        isEmpty,
      );
      await tester.tap(find.text('Refresh Diagnostic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect services'));
      await tester.pumpAndSettle();
      final request = calls.singleWhere(
        (call) => call.method == 'startBleDiagnostic',
      );
      expect(request.arguments['confirmed'], true);
      expect(request.arguments['address'], '02:11:22:33:44:55');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
