// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AudioDevice _$AudioDeviceFromJson(Map<String, dynamic> json) => _AudioDevice(
  canonicalDeviceId: json['canonicalDeviceId'] as String,
  displayName: json['displayName'] as String,
  deviceType: json['deviceType'] as String,
  connectionState:
      $enumDecodeNullable(_$ConnectionStateEnumMap, json['connectionState']) ??
      ConnectionState.unknown,
  playbackState:
      $enumDecodeNullable(_$PlaybackStateEnumMap, json['playbackState']) ??
      PlaybackState.unknown,
  lastSeen: DateTime.parse(json['lastSeen'] as String),
  currentPlaybackStartTime: json['currentPlaybackStartTime'] == null
      ? null
      : DateTime.parse(json['currentPlaybackStartTime'] as String),
);

Map<String, dynamic> _$AudioDeviceToJson(_AudioDevice instance) =>
    <String, dynamic>{
      'canonicalDeviceId': instance.canonicalDeviceId,
      'displayName': instance.displayName,
      'deviceType': instance.deviceType,
      'connectionState': _$ConnectionStateEnumMap[instance.connectionState]!,
      'playbackState': _$PlaybackStateEnumMap[instance.playbackState]!,
      'lastSeen': instance.lastSeen.toIso8601String(),
      'currentPlaybackStartTime': instance.currentPlaybackStartTime
          ?.toIso8601String(),
    };

const _$ConnectionStateEnumMap = {
  ConnectionState.connected: 'connected',
  ConnectionState.disconnected: 'disconnected',
  ConnectionState.unknown: 'unknown',
};

const _$PlaybackStateEnumMap = {
  PlaybackState.playing: 'playing',
  PlaybackState.paused: 'paused',
  PlaybackState.stopped: 'stopped',
  PlaybackState.unknown: 'unknown',
};
