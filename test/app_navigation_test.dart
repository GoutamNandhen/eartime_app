import 'package:eartime_app/data/app_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('navigation-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'cold start and warm widget navigation consume only known destinations',
    () async {
      final opened = <int>[];
      String? pending = 'timeline';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'consumeNavigationTarget');
        final result = pending;
        pending = null;
        return result;
      });
      final navigation = AppNavigation(opened.add, channel: channel);
      await navigation.consume();
      await navigation.consume();
      pending = 'devices';
      await navigation.consume();
      pending = 'delete';
      await navigation.consume();
      expect(opened, [2, 4]);
      navigation.close();
      pending = 'home';
      await navigation.consume();
      expect(opened, [2, 4]);
    },
  );
}
