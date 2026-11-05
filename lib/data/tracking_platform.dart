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
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<void> startBleDiagnostic(String hardwareAddress) async {
    await _methodChannel.invokeMethod('startBleDiagnostic', {'address': hardwareAddress});
  }

  /// The single shared stream of native tracking events.
  ///
  /// [EventChannel.receiveBroadcastStream] must only be called once per channel: every call
  /// installs a new platform message handler for the channel name, so a second subscriber
  /// (e.g. a BLE diagnostics provider) silently stole all events from the pipeline, and its
  /// cancellation tore down the native sink for everyone. All consumers share this stream.
  static final Stream<TrackingEvent> eventStream = _eventChannel
      .receiveBroadcastStream()
      // On platforms without the native side (iOS/desktop/tests) the channel errors with
      // MissingPluginException; log it instead of surfacing an unhandled stream error.
      .handleError((Object e) => debugPrint('[EARTRACE-ERROR] Event channel error: $e'))
      .expand<TrackingEvent>(_parse)
      .asBroadcastStream();

  static Iterable<TrackingEvent> _parse(dynamic event) {
    if (event is! Map) {
      debugPrint('[EARTRACE-ERROR] Ignoring non-map event: $event');
      return const [];
    }
    final map = Map<String, dynamic>.from(event);
    try {
      return [TrackingEvent.fromJson(map)];
    } catch (e, stack) {
      // A malformed event must not become a stream error that kills listeners.
      debugPrint('[EARTRACE-ERROR] Parsing failed: $e\n$stack\nRaw event: $map');
      return const [];
    }
  }
}
