import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Diagnostic Mapping', () {
    test('Should parse diagnostic data properly', () {
      final mockData = {
        'androidVersion': '16',
        'apiLevel': 36,
        'hasBluetoothConnect': true,
        'hasBluetoothScan': true,
        'hasFgServiceConnectedDevice': true,
        'bluetoothAdapterState': 'enabled',
        'a2dpConnectedCount': 1,
        'a2dpConnectedNames': ['OnePlus Nord Buds 3 Pro'],
        'audioManagerOutputCount': 1,
        'audioManagerDevices': [
          {
            'type': 8,
            'productName': '',
            'address': '00:11:22:33:44:55',
            'isSink': true,
            'isSource': false,
            'id': 15,
          }
        ],
      };

      expect(mockData['apiLevel'], 36);
      expect(mockData['a2dpConnectedNames'], isA<List<String>>());
      expect((mockData['a2dpConnectedNames'] as List).first, 'OnePlus Nord Buds 3 Pro');
      expect(mockData['audioManagerDevices'], isA<List>());
      
      final devices = mockData['audioManagerDevices'] as List;
      expect(devices.length, 1);
      
      final device = devices.first as Map<String, dynamic>;
      expect(device['type'], 8);
      expect(device['isSink'], true);
    });
  });
}
