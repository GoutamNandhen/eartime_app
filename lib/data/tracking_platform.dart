import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';

class TrackingPlatform {
  static const MethodChannel _methodChannel = MethodChannel('com.eartime.app/tracking');
  static const EventChannel _eventChannel = EventChannel('com.eartime.app/tracking_events');

  static Future<void> startMonitoring() async {
    await _methodChannel.invokeMethod('startMonitoring');
  }

  static Future<void> stopMonitoring() async {
    await _methodChannel.invokeMethod('stopMonitoring');
  }

  static Future<Map<String, dynamic>> getAudioDiagnostics() async {
    final result = await _methodChannel.invokeMethod('getAudioDiagnostics');
    return Map<String, dynamic>.from(result);
  }

  static Future<void> startBleDiagnostic(String hardwareAddress) async {
    await _methodChannel.invokeMethod('startBleDiagnostic', {'address': hardwareAddress});
  }

  static Stream<TrackingEvent> get eventStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event);
      final type = map['type'] as String? ?? 'UNKNOWN';
      debugPrint('[DART_EVENT]\n$type received');
      if (type == 'BLE_DISCOVERY_RESULT') {
        debugPrint('[FLUTTER BLE] BLE_DISCOVERY_RESULT received');
        debugPrint('[FLUTTER BLE] Map structure: $map');
      }
      try {
        final parsed = TrackingEvent.fromJson(map);
        return parsed;
      } catch (e, stack) {
        debugPrint('[EARTRACE-ERROR] Parsing failed: $e\n$stack\nRaw event: $map');
        rethrow;
      }
    });
  }
}
