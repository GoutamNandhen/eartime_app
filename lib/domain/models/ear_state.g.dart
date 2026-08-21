// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ear_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EarState _$EarStateFromJson(Map<String, dynamic> json) => _EarState(
  leftAvailable: json['leftAvailable'] as bool?,
  rightAvailable: json['rightAvailable'] as bool?,
  leftInEar: json['leftInEar'] as bool?,
  rightInEar: json['rightInEar'] as bool?,
  earSide:
      $enumDecodeNullable(_$EarSideEnumMap, json['earSide']) ?? EarSide.unknown,
  confidence: json['confidence'] as String? ?? 'unknown',
  source: json['source'] as String? ?? 'fallback',
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$EarStateToJson(_EarState instance) => <String, dynamic>{
  'leftAvailable': instance.leftAvailable,
  'rightAvailable': instance.rightAvailable,
  'leftInEar': instance.leftInEar,
  'rightInEar': instance.rightInEar,
  'earSide': _$EarSideEnumMap[instance.earSide]!,
  'confidence': instance.confidence,
  'source': instance.source,
  'timestamp': instance.timestamp.toIso8601String(),
};

const _$EarSideEnumMap = {
  EarSide.left: 'left',
  EarSide.right: 'right',
  EarSide.both: 'both',
  EarSide.unknown: 'unknown',
};
