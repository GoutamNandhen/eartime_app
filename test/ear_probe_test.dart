import 'package:eartime_app/features/settings/ear_probe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('probe starts, marks guided steps and shows copyable report', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'earProbeStart' => {'scan': 'scanning', 'bonded': [], 'durationMs': 180000},
        'earProbeStop' => {
          'eventCount': 4,
          'marks': [
            {'atMs': 1000, 'label': 'Left out'},
          ],
          'candidates': [
            {'device': 'dev-1', 'field': 'mfr:079a'},
          ],
          'report': 'EarTime ear probe v1',
        },
        _ => null,
      };
    });
    await tester.pumpWidget(
      MaterialApp(home: EarProbeScreen(requestPermissions: () async => true)),
    );
    await tester.tap(find.text('Start probe'));
    await tester.pump();
    expect(find.text('Next: Left out'), findsOneWidget);
    await tester.tap(find.text('Done: Left out'));
    await tester.pump();
    expect(find.text('Next: Left in'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(find.text('1 possible in-ear signal(s) found.'), findsOneWidget);
    expect(find.text('Copy report'), findsOneWidget);
    expect(calls.map((c) => c.method), [
      'earProbeStart',
      'earProbeMark',
      'earProbeStop',
    ]);
    expect(calls[1].arguments, {'label': 'Left out'});
  });

  testWidgets('denied permission never starts the probe', (tester) async {
    var started = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      started = true;
      return null;
    });
    await tester.pumpWidget(
      MaterialApp(home: EarProbeScreen(requestPermissions: () async => false)),
    );
    await tester.tap(find.text('Start probe'));
    await tester.pump();
    expect(started, isFalse);
    expect(find.text('Nearby devices permission is needed.'), findsOneWidget);
  });
}
