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

  /// SYNC_STATE only: every external device the native service currently tracks.
  final List<Map<String, dynamic>> connectedDevices;

  /// SYNC_STATE only: whether media is playing on the active device.
  final bool? isPlaying;

  /// SYNC_STATE only: epoch millis at which the current playback started, if playing.
  final int? playbackStartedAt;

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
    this.connectedDevices = const [],
    this.isPlaying,
    this.playbackStartedAt,
  });

  /// The device id carried by the event, falling back to the embedded device map.
  String? get resolvedDeviceId => deviceId ?? device?['id'] as String?;

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedDevice;
    if (json['device'] is Map) {
      parsedDevice = Map<String, dynamic>.from(json['device'] as Map);
    }

    // The contract puts SYNC_STATE fields at the root. Older builds/docs nested them inside
    // `device`, so accept both locations.
    final rawDevices = json['connectedDevices'] ?? parsedDevice?['connectedDevices'];
    final connectedDevices = <Map<String, dynamic>>[
      if (rawDevices is List)
        for (final d in rawDevices)
          if (d is Map) Map<String, dynamic>.from(d),
    ];

    return TrackingEvent(
      type: json['type'] as String,
      device: parsedDevice,
      deviceId: json['deviceId'] as String?,
      serviceUuid: json['serviceUuid'] as String?,
      characteristicUuid: json['characteristicUuid'] as String?,
      payload: json['payload'] as String?,
      state: json['state'] as String?,
      message: json['message'] as String?,
      status: (json['status'] as num?)?.toInt(),
      timestamp: (json['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      connectedDevices: connectedDevices,
      isPlaying: (json['isPlaying'] ?? parsedDevice?['isPlaying']) as bool?,
      playbackStartedAt: ((json['playbackStartedAt'] ?? parsedDevice?['playbackStartedAt']) as num?)?.toInt(),
    );
  }
}
