import 'package:freezed_annotation/freezed_annotation.dart';
import 'connection_state.dart';
import 'playback_state.dart';

part 'audio_device.freezed.dart';
part 'audio_device.g.dart';

@freezed
sealed class AudioDevice with _$AudioDevice {
  const factory AudioDevice({
    required String canonicalDeviceId,
    required String displayName,
    required String deviceType,
    @Default(ConnectionState.unknown) ConnectionState connectionState,
    @Default(PlaybackState.unknown) PlaybackState playbackState,
    required DateTime lastSeen,
    DateTime? currentPlaybackStartTime,
  }) = _AudioDevice;

  factory AudioDevice.fromJson(Map<String, dynamic> json) => _$AudioDeviceFromJson(json);
}
