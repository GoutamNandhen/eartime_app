import '../models/audio_device.dart';

abstract class DeviceRepository {
  Future<void> saveDevice(AudioDevice device);
  Future<AudioDevice?> getDevice(String canonicalDeviceId);
  Future<List<AudioDevice>> getAllDevices();
  Future<void> updateDeviceLastSeen(String canonicalDeviceId, DateTime lastSeen);
  
  /// Returns a stream of the currently active/connected audio device.
  Stream<AudioDevice?> getActiveDevice();
}

class DeviceRepositoryImpl implements DeviceRepository {
  @override
  Future<void> saveDevice(AudioDevice device) async {}

  @override
  Future<AudioDevice?> getDevice(String canonicalDeviceId) async => null;

  @override
  Future<List<AudioDevice>> getAllDevices() async => [];

  @override
  Future<void> updateDeviceLastSeen(String canonicalDeviceId, DateTime lastSeen) async {}

  @override
  Stream<AudioDevice?> getActiveDevice() => Stream.value(null);
}
