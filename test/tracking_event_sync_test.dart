import 'package:flutter_test/flutter_test.dart';
import 'package:eartime_app/domain/models/tracking_event.dart';

void main() {
  group('TrackingEvent JSON Contract Tests (A/B Fix)', () {
    test(
      '1. SYNC_STATE with connectedDevices parses correctly inside device object',
      () {
        final json = {
          "type": "SYNC_STATE",
          "device": {
            "connectedDevices": [
              {
                "id": "00:11:22:33:44:55",
                "friendlyName": "OnePlus Nord Buds 2",
                "connectionType": "bluetooth",
                "nativeType": 8,
              },
            ],
            "isPlaying": true,
          },
          "timestamp": 1234567890,
        };

        final event = TrackingEvent.fromJson(json);

        expect(event.type, 'SYNC_STATE');
        expect(event.device, isNotNull);
        expect(event.device?['connectedDevices'], isNotEmpty);
        expect(event.device?['isPlaying'], true);

        final firstDevice = event.device!['connectedDevices'][0];
        expect(firstDevice['id'], "00:11:22:33:44:55");
        expect(firstDevice['friendlyName'], "OnePlus Nord Buds 2");
      },
    );

    test('2. SYNC_STATE with zero connected devices parses correctly', () {
      final json = {
        "type": "SYNC_STATE",
        "device": {"connectedDevices": [], "isPlaying": false},
        "timestamp": 1234567890,
      };

      final event = TrackingEvent.fromJson(json);

      expect(event.type, 'SYNC_STATE');
      expect(event.device, isNotNull);
      expect(event.device?['connectedDevices'], isEmpty);
      expect(event.device?['isPlaying'], false);
    });

    test('3. SYNC_STATE isPlaying true parses correctly', () {
      final json = {
        "type": "SYNC_STATE",
        "device": {"connectedDevices": [], "isPlaying": true},
        "timestamp": 1234567890,
      };

      final event = TrackingEvent.fromJson(json);
      expect(event.device?['isPlaying'], true);
    });

    test('4. SYNC_STATE isPlaying false parses correctly', () {
      final json = {
        "type": "SYNC_STATE",
        "device": {"connectedDevices": [], "isPlaying": false},
        "timestamp": 1234567890,
      };

      final event = TrackingEvent.fromJson(json);
      expect(event.device?['isPlaying'], false);
    });
  });
}
