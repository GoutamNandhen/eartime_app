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
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedDevice;
    if (json['device'] != null) {
      parsedDevice = Map<String, dynamic>.from(json['device'] as Map);
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
    );
  }
}
