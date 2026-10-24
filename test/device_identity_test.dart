import 'package:eartime_app/data/device_identity.dart';
import 'package:eartime_app/features/devices/device_identity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const device = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
const source = '00000000-0000-4000-8000-000000000003';
const aliasId = '00000000-0000-4000-8000-000000000004';
Map<String, Object> identityPage({bool associated = false, int offset = 0}) => {
  'version': 1,
  'deviceId': device,
  'sourceId': source,
  'aliasOffset': 0,
  'nextAliasOffset': 1,
  'hasMoreAliases': false,
  'candidateOffset': offset,
  'nextCandidateOffset': offset + 1,
  'hasMoreCandidates': offset == 0,
  'aliases': [
    {
      'id': aliasId,
      'originDeviceId': device,
      'deviceId': associated ? other : device,
      'revision': associated ? 8 : 2,
      'endpointSuffix': '44:55',
      'evidence': associated ? 'USER_CONFIRMED' : 'SAME_OBSERVED_ENDPOINT',
    },
  ],
  'candidates': [
    {
      'id': offset == 0 ? device : other,
      'name': offset == 0 ? 'Same model' : 'Other model',
    },
  ],
};

class IdentityFixture extends DeviceIdentityClient {
  bool associated = false;
  bool fail = false;
  final changes = <String?>[];
  final offsets = <int>[];
  int inspections = 0;
  @override
  Future<void> inspect({required String sourceId, required Map alias}) async {
    if (fail) throw StateError('Synthetic unavailable inspection');
    inspections++;
  }

  @override
  Future<Map<dynamic, dynamic>> read(
    String deviceId, {
    int aliasOffset = 0,
    int candidateOffset = 0,
  }) async {
    offsets.add(candidateOffset);
    return identityPage(associated: associated, offset: candidateOffset);
  }

  @override
  Future<void> change({
    required String sourceId,
    required Map alias,
    String? targetDeviceId,
  }) async {
    if (fail) throw StateError('Synthetic source revision conflict');
    changes.add(targetDeviceId);
    associated = targetDeviceId != null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('identity_fixture');
  const client = DeviceIdentityClient(channel: channel);
  test(
    'inspection carries explicit consent and alias revision, never a raw address',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'inspectDeviceEndpoint');
            expect(call.arguments, {
              'sourceId': source,
              'aliasId': aliasId,
              'expectedRevision': 2,
              'confirmed': true,
            });
            return {'queued': true};
          });
      await client.inspect(
        sourceId: source,
        alias: (identityPage()['aliases'] as List).single as Map,
      );
    },
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'native identity client validates source, identity rows and advancing cursors',
    () async {
      var page = identityPage();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => page);
      expect((await client.read(device))['sourceId'], source);
      page = {...identityPage(), 'sourceId': 'not-a-journal'};
      await expectLater(client.read(device), throwsFormatException);
      page = {...identityPage(), 'nextCandidateOffset': 0};
      await expectLater(client.read(device), throwsFormatException);
      page = {
        ...identityPage(),
        'aliases': [
          {'id': 'masked'},
        ],
      };
      await expectLater(client.read(device), throwsFormatException);
    },
  );
  test(
    'changes carry explicit confirmation and optimistic revision, reset is nullable',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {'unchanged': false};
          });
      final alias = (identityPage()['aliases'] as List).single as Map;
      await client.change(
        sourceId: source,
        alias: alias,
        targetDeviceId: other,
      );
      await client.change(sourceId: source, alias: alias);
      expect(calls.first.method, 'changeDeviceIdentity');
      expect(calls.first.arguments['confirmed'], true);
      expect(calls.first.arguments['expectedRevision'], 2);
      expect(calls.first.arguments['sourceId'], source);
      expect(calls.last.arguments['targetDeviceId'], isNull);
    },
  );
  Future<void> show(
    WidgetTester tester,
    IdentityFixture fixture, {
    bool large = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: large
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              )
            : null,
        home: DeviceIdentityScreen(
          deviceId: device,
          name: 'My device',
          client: fixture,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectTarget(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Change association'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change association'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Next identities'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next identities'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Other model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other model'));
    await tester.pumpAndSettle();
  }

  for (final fail in [false, true]) {
    testWidgets(
      'endpoint inspection requires confirmation and handles unavailable transport=$fail',
      (tester) async {
        final fixture = IdentityFixture()..fail = fail;
        await show(tester, fixture);
        await tester.tap(find.byTooltip('Inspect services (read-only)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(fixture.inspections, 0);
        await tester.tap(find.byTooltip('Inspect services (read-only)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspect services'));
        await tester.pumpAndSettle();
        expect(fixture.inspections, fail ? 0 : 1);
        expect(
          find.textContaining(
            fail
                ? 'Inspection unavailable.'
                : 'Read-only inspection requested.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('cancelled explicit association never mutates native history', (
    tester,
  ) async {
    final fixture = IdentityFixture();
    await show(tester, fixture);
    await selectTarget(tester);
    expect(find.text('Associate this endpoint?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.changes, isEmpty);
    expect(fixture.offsets, contains(1));
  });
  testWidgets('confirmed assignment and reset reload persisted associations', (
    tester,
  ) async {
    final fixture = IdentityFixture();
    await show(tester, fixture);
    await selectTarget(tester);
    await tester.tap(find.text('Confirm association'));
    await tester.pumpAndSettle();
    expect(fixture.changes, [other]);
    expect(find.text('User-associated device identity'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset association'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm association'));
    await tester.pumpAndSettle();
    expect(fixture.changes, [other, null]);
    expect(find.text('Same observed endpoint'), findsOneWidget);
  });
  testWidgets(
    'native revision conflicts show recovery without claiming a changed association',
    (tester) async {
      final fixture = IdentityFixture()..fail = true;
      await show(tester, fixture);
      await selectTarget(tester);
      await tester.tap(find.text('Confirm association'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Association could not be updated.'),
        findsOneWidget,
      );
      expect(fixture.changes, isEmpty);
      expect(find.text('Same observed endpoint'), findsOneWidget);
    },
  );
  testWidgets(
    'endpoint controls and confirmation remain usable at double text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = IdentityFixture();
      await show(tester, fixture, large: true);
      expect(tester.takeException(), isNull);
      await selectTarget(tester);
      await tester.ensureVisible(find.text('Confirm association'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm association'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fixture.changes, [other]);
    },
  );
}
