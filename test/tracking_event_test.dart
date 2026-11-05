import 'package:flutter_test/flutter_test.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';

void main() {
  group('TrackingEvent mapping', () {
    test('Should map DEVICE_CONNECTED correctly', () {
      final json = {
        'type': 'DEVICE_CONNECTED',
        'device': {
          'id': '123',
          'friendlyName': 'My Earbuds',
          'connectionType': 'bluetooth',
        },
        'timestamp': 1600000000000,
      };

      final event = TrackingEvent.fromJson(json);

      expect(event.type, 'DEVICE_CONNECTED');
      expect(event.device?['id'], '123');
      expect(event.device?['friendlyName'], 'My Earbuds');
      expect(event.device?['connectionType'], 'bluetooth');
      expect(event.timestamp, 1600000000000);
    });

    test('Should map PLAYBACK_STARTED correctly', () {
      final json = {
        'type': 'PLAYBACK_STARTED',
        'timestamp': 1600000000000,
      };

      final event = TrackingEvent.fromJson(json);

      expect(event.type, 'PLAYBACK_STARTED');
      expect(event.device, null);
      expect(event.timestamp, 1600000000000);
    });
  });

  group('SYNC_STATE contract', () {
    test('reads root-level connectedDevices / isPlaying / playbackStartedAt (native format)', () {
      final event = TrackingEvent.fromJson({
        'type': 'SYNC_STATE',
        'timestamp': 1700000000000,
        'deviceId': 'AA:BB',
        'connectedDevices': [
          {'id': 'AA:BB', 'friendlyName': 'Buds'}
        ],
        'isPlaying': true,
        'playbackStartedAt': 1699999990000,
      });
      expect(event.connectedDevices.single['friendlyName'], 'Buds');
      expect(event.isPlaying, isTrue);
      expect(event.playbackStartedAt, 1699999990000);
      expect(event.resolvedDeviceId, 'AA:BB');
    });

    test('still accepts the legacy nested format', () {
      final event = TrackingEvent.fromJson({
        'type': 'SYNC_STATE',
        'timestamp': 1700000000000,
        'device': {
          'connectedDevices': [
            {'id': 'AA:BB', 'friendlyName': 'Buds'}
          ],
          'isPlaying': false,
        },
      });
      expect(event.connectedDevices.length, 1);
      expect(event.isPlaying, isFalse);
    });
  });
}
