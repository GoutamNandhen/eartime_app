import 'dart:async';
import 'package:eartime_app/data/journal_transfer.dart';
import 'package:eartime_app/features/settings/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> success() => {
  'version': 1,
  'scope': 'native_observations_only',
  'count': 2,
  'sha256': '0' * 64,
};

class TransferClient extends JournalTransferClient {
  final operations = <String>[];
  final offsets = <int>[];
  int cancels = 0;
  bool fail = false;
  Completer<Map<dynamic, dynamic>>? pending;
  @override
  Future<Map<dynamic, dynamic>> transfer(
    String operation, {
    String? recoveryId,
  }) async {
    operations.add('$operation:${recoveryId ?? ''}');
    if (fail) throw StateError('Synthetic I/O failure');
    return pending == null ? success() : pending!.future;
  }

  @override
  Future<Map<dynamic, dynamic>> recoveries(int offset) async {
    offsets.add(offset);
    return {
      'items': List.generate(
        offset == 0 ? 20 : 1,
        (index) => {
          'id':
              '00000000-0000-4000-8000-${(offset + index).toString().padLeft(12, '0')}',
          'createdUtcMs': 1000 + offset + index,
          'bytes': 128,
        },
      ),
      'hasMore': offset == 0,
      'nextOffset': offset == 0 ? 20 : 21,
    };
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'large-text restore confirmation remains scrollable without clipping actions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: DataManagementScreen(client: TransferClient()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Restore native history from file'),
        250,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore native history from file'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Replace history'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'canceling restore confirmation never invokes the native restore path',
    (tester) async {
      final client = TransferClient();
      await tester.pumpWidget(
        MaterialApp(home: DataManagementScreen(client: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore native history from file'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Legacy history and preferences are not changed'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(client.operations, isEmpty);
    },
  );
  testWidgets(
    'export warns about plaintext scope and reports actual completed observation count',
    (tester) async {
      final client = TransferClient();
      await tester.pumpWidget(
        MaterialApp(home: DataManagementScreen(client: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export native history'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('It is not a full-app backup'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose destination'));
      await tester.pumpAndSettle();
      expect(client.operations, ['exportNativeJournal:']);
      expect(find.textContaining('2 observations exported'), findsOneWidget);
    },
  );
  testWidgets(
    'confirmed restore errors remain visible rather than displaying success',
    (tester) async {
      final client = TransferClient()..fail = true;
      await tester.pumpWidget(
        MaterialApp(home: DataManagementScreen(client: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore native history from file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace history'));
      await tester.pumpAndSettle();
      expect(client.operations, ['restoreNativeJournal:']);
      expect(
        find.textContaining('Transfer failed. No success is assumed.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'busy operations can request cancellation and disposed screens ignore late results',
    (tester) async {
      final client = TransferClient()
        ..pending = Completer<Map<dynamic, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(home: DataManagementScreen(client: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export native history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose destination'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancel transfer'));
      await tester.pump();
      expect(client.cancels, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      client.pending!.complete({'cancelled': true});
      await tester.pumpAndSettle();
      expect(client.cancels, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recovery pagination sends independent bounded offsets', (
    tester,
  ) async {
    final client = TransferClient();
    await tester.pumpWidget(
      MaterialApp(home: DataManagementScreen(client: client)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Next recovery archives'),
      500,
    );
    await tester.tap(find.byTooltip('Next recovery archives'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous recovery archives'));
    await tester.pumpAndSettle();
    expect(client.offsets, [0, 20, 0]);
  });
  test(
    'real channel client sends explicit restore confirmation and rejects malformed contracts',
    () async {
      const channel = MethodChannel('archive-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      Map<String, Object> response = success();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return response;
      });
      final client = JournalTransferClient(channel: channel);
      await client.transfer(
        'restoreJournalRecovery',
        recoveryId: 'synthetic-id',
      );
      expect(calls.single.arguments, {'confirmed': true, 'id': 'synthetic-id'});
      response = success()..['version'] = 2;
      await expectLater(
        client.transfer('exportNativeJournal'),
        throwsFormatException,
      );
      response = {'items': [], 'hasMore': true, 'nextOffset': 0};
      await expectLater(client.recoveries(0), throwsFormatException);
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
}
