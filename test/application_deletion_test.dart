import 'package:eartime_app/features/settings/data_management_screen.dart';
import 'package:eartime_app/data/journal_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deletion client rejects absent consent and fabricated completion',
    () async {
      const channel = MethodChannel('com.eartime.app/tracking');
      var calls = 0;
      var completed = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            calls++;
            return {
              'version': 1,
              'scope': 'all_app_private_data',
              'requested': false,
              'completed': completed,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        const JournalTransferClient().requestDeletion(confirmed: false),
        throwsArgumentError,
      );
      expect(calls, 0);
      expect(
        await const JournalTransferClient().requestDeletion(confirmed: true),
        false,
      );
      completed = true;
      await expectLater(
        const JournalTransferClient().requestDeletion(confirmed: true),
        throwsFormatException,
      );
    },
  );
  testWidgets('rejected or failed deletion permits explicit retry', (
    tester,
  ) async {
    const channel = MethodChannel('com.eartime.app/tracking');
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listJournalRecoveries') {
            return {'items': [], 'hasMore': false, 'nextOffset': 0};
          }
          if (call.method == 'deleteApplicationData') {
            requests++;
            if (requests == 2) {
              throw PlatformException(code: 'SYNTHETIC_DELETION_DENIED');
            }
            return {
              'version': 1,
              'scope': 'all_app_private_data',
              'requested': false,
              'completed': false,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(const MaterialApp(home: DataManagementScreen()));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.scrollUntilVisible(find.text('Delete all local data'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete all local data'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(Checkbox),
        200,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          attempt == 0
              ? 'Android did not accept'
              : 'Deletion could not be confirmed',
        ),
        findsOneWidget,
      );
      expect(requests, attempt + 1);
      expect(tester.takeException(), isNull);
    }
  });
  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'full-data deletion requires scoped confirmation at scale $scale',
      (tester) async {
        const channel = MethodChannel('com.eartime.app/tracking');
        var deletions = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'listJournalRecoveries') {
                return {'items': [], 'hasMore': false, 'nextOffset': 0};
              }
              if (call.method == 'deleteApplicationData') {
                deletions++;
                expect((call.arguments as Map)['confirmed'], true);
                expect(call.arguments['scope'], 'all_app_private_data');
                return {
                  'version': 1,
                  'scope': 'all_app_private_data',
                  'requested': true,
                  'completed': false,
                };
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
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
            home: const DataManagementScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Delete all local data'),
          300,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete all local data'));
        await tester.pumpAndSettle();
        expect(deletions, 0);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Delete permanently'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(deletions, 0);
        await tester.tap(find.text('Delete all local data'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(Checkbox),
          200,
          scrollable: find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete permanently'));
        await tester.pumpAndSettle();
        expect(deletions, 1);
        expect(
          find.textContaining('Android accepted the deletion request'),
          findsOneWidget,
        );
        expect(find.text('Cancel transfer'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
