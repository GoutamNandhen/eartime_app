import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../../domain/models/audio_device.dart';
import 'method_channel_tracking.dart';

abstract class TrackingPlatform extends PlatformInterface {
  TrackingPlatform() : super(token: _token);

  static final Object _token = Object();
  static TrackingPlatform _instance = MethodChannelTracking();

  static TrackingPlatform get instance => _instance;

  static set instance(TrackingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> startTracking() {
    throw UnimplementedError('startTracking() has not been implemented.');
  }

  Future<void> stopTracking() {
    throw UnimplementedError('stopTracking() has not been implemented.');
  }

  Future<void> startBleDiagnostic(String hardwareAddress) {
    throw UnimplementedError('startBleDiagnostic() has not been implemented.');
  }

  Stream<AudioDevice> get deviceEvents {
    throw UnimplementedError('deviceEvents has not been implemented.');
  }
}
