import 'package:eartime_app/data/listening_projection.dart';
import 'package:eartime_app/features/listening/listening_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const deviceId = '00000000-0000-4000-8000-000000000001';
const otherId = '00000000-0000-4000-8000-000000000002';
Map<String, Object?> history(Map args, {bool scoped = true}) => {
  'projectionVersion': 5,
  'sourceId': 'synthetic-source',
  'sequence': 20,
  'fromUtcMs': args['fromUtcMs'],
  'untilUtcMs': args['untilUtcMs'],
  'filterDeviceId': scoped ? args['deviceId'] : null,
  'confirmedMs': 5000,
  'unverifiedMs': 0,
  'gapCount': 0,
  'intervalCount': 101,
  'nextOffset': args['offset'] == 100 ? 101 : 100,
  'hasMore': args['offset'] != 100,
  'deviceOffset': 0,
  'deviceCount': 1,
  'nextDeviceOffset': 1,
  'hasMoreDevices': false,
  'devices': [
    {
      'id': deviceId,
      'name': 'My listening device',
      'connected': true,
      'identityVerified': false,
      'identityKind': 'ENDPOINT_ASSOCIATED',
      'connectionState': 'CONNECTED_REPORTED',
    },
  ],
  'days': <Object>[],
  'perDevice': [
    {'deviceId': deviceId, 'durationMs': 5000},
  ],
  'intervals': args['deviceId'] == null
      ? <Object>[]
      : [
          {
            'id': 'interval-${args['offset']}',
            'deviceId': deviceId,
            'attribution': 'CONFIRMED',
            'startUtcMs': args['fromUtcMs'],
            'endUtcMs': (args['fromUtcMs'] as int) + 5000,
            'durationMs': 5000,
            'open': false,
            'live': false,
            'closeReason': 'stopped',
          },
        ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.eartime.app/tracking');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'device scope changes provider identity and is validated against native replies',
    () async {
      final from = DateTime.fromMillisecondsSinceEpoch(0);
      final until = DateTime.fromMillisecondsSinceEpoch(100000);
      final window = ListeningWindow(from, until, deviceId: deviceId);
      expect(window, isNot(ListeningWindow(from, until)));
      expect(window, isNot(ListeningWindow(from, until, deviceId: otherId)));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments['deviceId'], deviceId);
        return history(call.arguments as Map);
      });
      expect(
        (await const ListeningProjectionClient().read(
          window,
        )).confirmed.inMilliseconds,
        5000,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => history(call.arguments as Map, scoped: false),
      );
      await expectLater(
        const ListeningProjectionClient().read(window),
        throwsFormatException,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => history(call.arguments as Map)
          ..['devices'] = [
            {
              'id': otherId,
              'name': 'Other identity',
              'connected': false,
              'identityVerified': false,
            },
          ],
      );
      await expectLater(
        const ListeningProjectionClient().read(window),
        throwsFormatException,
      );
      await expectLater(
        const ListeningProjectionClient().read(
          ListeningWindow(from, until, deviceId: 'Same name'),
        ),
        throwsArgumentError,
      );
    },
  );
  for (final large in [false, true]) {
    testWidgets(
      'Devices opens native-scoped history with paging and date filters, large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final queries = <Map>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readListeningPreferences') {
            return {'version': 1, 'themeMode': 'system', 'dailyGoalMinutes': 0};
          }
          if (call.method != 'readListeningProjection') return null;
          final args = Map.of(call.arguments as Map);
          queries.add(args);
          return history(args);
        });
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                child: child!,
              ),
              home: const Scaffold(
                body: ListeningWorkspace(view: ListeningView.devices),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Device details'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Device details'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Device history'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Device history'));
        await tester.pumpAndSettle();
        expect(find.text('Device timeline'), findsOneWidget);
        expect(queries.last['deviceId'], deviceId);
        expect(find.byTooltip('Select dates'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Next intervals'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next intervals'));
        await tester.pumpAndSettle();
        expect(queries.last['offset'], 100);
        expect(queries.last['deviceId'], deviceId);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final fail in [false, true]) {
    testWidgets(
      'device rename uses the stable UUID and handles storage failure=$fail',
      (tester) async {
        var displayName = 'My listening device';
        var updates = 0;
        Map<String, Object> preferences() => {
          'version': 1,
          'themeMode': 'system',
          'dailyGoalMinutes': 0,
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readListeningPreferences') return preferences();
          if (call.method == 'updateListeningPreferences') {
            updates++;
            expect(call.arguments['deviceNames'], {deviceId: 'My custom name'});
            if (fail) {
              throw PlatformException(code: 'SYNTHETIC_STORAGE_FAILURE');
            }
            displayName = 'My custom name';
            return preferences();
          }
          if (call.method == 'readListeningProjection') {
            final page = history(call.arguments as Map);
            ((page['devices'] as List).single as Map)['name'] = displayName;
            return page;
          }
          return null;
        });
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListeningWorkspace(view: ListeningView.devices),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Device details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'My custom name');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(updates, 0);
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'My custom name');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(updates, 1);
        if (fail) {
          expect(displayName, 'My listening device');
          expect(find.text('Device name could not be saved.'), findsOneWidget);
        } else {
          expect(find.text('My custom name'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: ListeningWorkspace(view: ListeningView.devices),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('My custom name'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
