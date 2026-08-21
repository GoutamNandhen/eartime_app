import 'package:flutter/services.dart';
import '../../domain/models/audio_device.dart';
import 'tracking_platform.dart';

class MethodChannelTracking extends TrackingPlatform {
  final methodChannel = const MethodChannel('com.eartime/tracking');
  final eventChannel = const EventChannel('com.eartime/tracking_events');

  @override
  Future<void> startTracking() async {
    await methodChannel.invokeMethod<void>('startTracking');
  }

  @override
  Future<void> stopTracking() async {
    await methodChannel.invokeMethod<void>('stopTracking');
  }

  @override
  Future<void> stopMonitoring() async {
    await methodChannel.invokeMethod<void>('stopMonitoring');
  }

  @override
  Future<void> startBleDiagnostic(String hardwareAddress) async {
    await methodChannel.invokeMethod<void>('startBleDiagnostic', {'address': hardwareAddress});
  }

  @override
  Stream<AudioDevice> get deviceEvents {
    return eventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event);
      return AudioDevice.fromJson(map);
    });
  }
}
