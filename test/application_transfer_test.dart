import 'package:eartime_app/data/journal_transfer.dart';
import 'package:eartime_app/features/settings/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'journal_transfer_test.dart' show TransferClient;

class ApplicationClient extends TransferClient {
  @override
  Future<Map<dynamic, dynamic>> transfer(
    String operation, {
    String? recoveryId,
  }) async => {
    ...await super.transfer(operation, recoveryId: recoveryId),
    'scope': 'application_data',
    'componentCount': 5,
    'legacyCount': 3,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('application export validates its distinct scope and counts', () async {
    const channel = MethodChannel('com.eartime.app/tracking');
    var invalid = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'exportApplicationData');
          expect((call.arguments as Map)['confirmed'], true);
          return {
            'version': 1,
            'scope': 'application_data',
            'componentCount': 5,
            'count': 2,
            'legacyCount': invalid ? -1 : 3,
            'sha256': '0' * 64,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(
      (await const JournalTransferClient().transfer(
        'exportApplicationData',
      ))['legacyCount'],
      3,
    );
    invalid = true;
    await expectLater(
      const JournalTransferClient().transfer('exportApplicationData'),
      throwsFormatException,
    );
  });
  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'application export requires disclosure confirmation at scale $scale',
      (tester) async {
        final client = ApplicationClient();
        tester.view.physicalSize = const Size(360, 740);
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
            home: DataManagementScreen(client: client),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Export application data'),
          250,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export application data'));
        await tester.pumpAndSettle();
        expect(find.text('Export private application data?'), findsOneWidget);
        expect(client.operations, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(client.operations, isEmpty);
        await tester.tap(find.text('Export application data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose destination'));
        await tester.pumpAndSettle();
        expect(client.operations, ['exportApplicationData:']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
