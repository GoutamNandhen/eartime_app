import 'journal_observation.dart';

class TrackingEvent {
  final String type;
  final Map<String, dynamic>? device;
  final String? deviceId;
  final String? serviceUuid;
  final String? characteristicUuid;
  final String? payload;
  final String? state;
  final String? message;
  final int? status;
  final int timestamp;
  final List<Map<String, dynamic>>? connectedDevices;
  final bool? isPlaying;
  final JournalIdentity? journalIdentity;

  TrackingEvent({
    required this.type,
    this.device,
    this.deviceId,
    this.serviceUuid,
    this.characteristicUuid,
    this.payload,
    this.state,
    this.message,
    this.status,
    required this.timestamp,
    this.connectedDevices,
    this.isPlaying,
    this.journalIdentity,
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedDevice;
    if (json['device'] != null) {
      parsedDevice = Map<String, dynamic>.from(json['device'] as Map);
    }

    List<Map<String, dynamic>>? parsedConnectedDevices;
    if (json['connectedDevices'] != null) {
      parsedConnectedDevices = (json['connectedDevices'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } else if (parsedDevice != null &&
        parsedDevice['connectedDevices'] != null) {
      parsedConnectedDevices = (parsedDevice['connectedDevices'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    bool? parsedIsPlaying = json['isPlaying'] as bool?;
    if (parsedIsPlaying == null &&
        parsedDevice != null &&
        parsedDevice['isPlaying'] != null) {
      parsedIsPlaying = parsedDevice['isPlaying'] as bool?;
    }

    if (parsedDevice == null &&
        (parsedConnectedDevices != null || parsedIsPlaying != null)) {
      final dev = <String, dynamic>{};
      if (parsedConnectedDevices != null) {
        dev['connectedDevices'] = parsedConnectedDevices;
      }
      if (parsedIsPlaying != null) {
        dev['isPlaying'] = parsedIsPlaying;
      }
      parsedDevice = dev;
    }

    return TrackingEvent(
      type: json['type'] as String,
      device: parsedDevice,
      deviceId: json['deviceId'] as String?,
      serviceUuid: json['serviceUuid'] as String?,
      characteristicUuid: json['characteristicUuid'] as String?,
      payload: json['payload'] as String?,
      state: json['state'] as String?,
      message: json['message'] as String?,
      status: json['status'] as int?,
      timestamp: json['timestamp'] as int,
      connectedDevices: parsedConnectedDevices,
      isPlaying: parsedIsPlaying,
      journalIdentity: json['journal'] == null
          ? null
          : JournalIdentity.fromMap(json['journal'] as Map),
    );
  }
}
