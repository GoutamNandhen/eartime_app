import 'dart:async';
import 'package:flutter/services.dart';

/// Serializes direct legacy reads with restore in this engine. Native owns accounting/recovery.
class ApplicationDataAccess {
  ApplicationDataAccess({
    MethodChannel channel = const MethodChannel('com.eartime.app/tracking'),
  }) : _channel = channel;
  final MethodChannel _channel;
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final released = Completer<void>();
    final previous = _tail;
    _tail = released.future;
    return (() async {
      await previous;
      try {
        final ready = await _channel.invokeMapMethod<String, dynamic>(
          'awaitApplicationDataReady',
        );
        if (ready?['ready'] != true) {
          throw const FormatException('Application recovery is not ready');
        }
        return await operation();
      } finally {
        released.complete();
      }
    })();
  }
}

final applicationDataAccess = ApplicationDataAccess();
