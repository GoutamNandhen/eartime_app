import 'package:flutter_test/flutter_test.dart';
import 'package:eartime_app/domain/models/audio_device.dart';
import 'package:eartime_app/domain/models/connection_state.dart';
import 'package:eartime_app/domain/models/playback_state.dart';

void main() {
  group('AudioDevice', () {
    test('should create AudioDevice from json correctly', () {
      final json = {
        'canonicalDeviceId': 'test-123',
        'displayName': 'Test Device',
        'deviceType': 'headphones',
        'connectionState': 'connected',
        'playbackState': 'playing',
        'lastSeen': '2026-08-16T12:00:00Z',
      };

      final device = AudioDevice.fromJson(json);

      expect(device.canonicalDeviceId, 'test-123');
      expect(device.displayName, 'Test Device');
      expect(device.deviceType, 'headphones');
      expect(device.connectionState, ConnectionState.connected);
      expect(device.playbackState, PlaybackState.playing);
      expect(device.lastSeen, DateTime.parse('2026-08-16T12:00:00Z'));
    });
  });
}
