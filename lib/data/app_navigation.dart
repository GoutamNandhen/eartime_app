import 'package:flutter/services.dart';

class AppNavigation {
  AppNavigation(
    this.open, {
    MethodChannel channel = const MethodChannel('com.eartime.app/navigation'),
  }) : _channel = channel;
  final void Function(int) open;
  final MethodChannel _channel;
  bool _closed = false;
  static const destinations = {
    'home': 0,
    'analytics': 1,
    'timeline': 2,
    'wellbeing': 3,
    'devices': 4,
  };

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigationAvailable') await consume();
    });
    consume();
  }

  Future<void> consume() async {
    try {
      final target = await _channel.invokeMethod<String>(
        'consumeNavigationTarget',
      );
      if (!_closed && destinations.containsKey(target)) {
        open(destinations[target]!);
      }
    } on MissingPluginException {
      // Non-Android hosts have no launcher navigation channel.
    } on PlatformException {
      // Navigation failure must not prevent the normal app from opening.
    }
  }

  void close() {
    _closed = true;
    _channel.setMethodCallHandler(null);
  }
}
