import 'package:flutter/foundation.dart';

/// Observational only: never a startup gate or durable event identity.
class StartupTrace {
  static final String runtimeId = DateTime.now().microsecondsSinceEpoch
      .toRadixString(16);
  static final Stopwatch _elapsed = Stopwatch()..start();

  static String format(
    String stage, {
    required int elapsedMs,
    String fields = '',
  }) {
    final bounded = fields.length <= 360
        ? fields
        : '${fields.substring(0, 360)}...';
    return '[STARTUP_TRACE:dart=$runtimeId] $stage elapsedMs=$elapsedMs $bounded';
  }

  static void mark(String stage, [String fields = '']) {
    debugPrint(
      format(stage, elapsedMs: _elapsed.elapsedMilliseconds, fields: fields),
    );
  }
}
