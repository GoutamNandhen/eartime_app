// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earbud_capabilities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EarbudCapabilities _$EarbudCapabilitiesFromJson(
  Map<String, dynamic> json,
) => _EarbudCapabilities(
  bleAvailable:
      $enumDecodeNullable(_$CapabilityStatusEnumMap, json['bleAvailable']) ??
      CapabilityStatus.unknown,
  gattAvailable:
      $enumDecodeNullable(_$CapabilityStatusEnumMap, json['gattAvailable']) ??
      CapabilityStatus.unknown,
  leAudioAvailable:
      $enumDecodeNullable(
        _$CapabilityStatusEnumMap,
        json['leAudioAvailable'],
      ) ??
      CapabilityStatus.unknown,
  pacsAvailable:
      $enumDecodeNullable(_$CapabilityStatusEnumMap, json['pacsAvailable']) ??
      CapabilityStatus.unknown,
  individualBudIdentity:
      $enumDecodeNullable(
        _$CapabilityStatusEnumMap,
        json['individualBudIdentity'],
      ) ??
      CapabilityStatus.unknown,
  leftRightIdentity:
      $enumDecodeNullable(
        _$CapabilityStatusEnumMap,
        json['leftRightIdentity'],
      ) ??
      CapabilityStatus.unknown,
  leftRightConnectionState:
      $enumDecodeNullable(
        _$CapabilityStatusEnumMap,
        json['leftRightConnectionState'],
      ) ??
      CapabilityStatus.unknown,
  inEarDetection:
      $enumDecodeNullable(_$CapabilityStatusEnumMap, json['inEarDetection']) ??
      CapabilityStatus.unknown,
  perEarExposure:
      $enumDecodeNullable(_$CapabilityStatusEnumMap, json['perEarExposure']) ??
      CapabilityStatus.unknown,
  providerName: json['providerName'] as String? ?? 'Unknown',
);

Map<String, dynamic> _$EarbudCapabilitiesToJson(
  _EarbudCapabilities instance,
) => <String, dynamic>{
  'bleAvailable': _$CapabilityStatusEnumMap[instance.bleAvailable]!,
  'gattAvailable': _$CapabilityStatusEnumMap[instance.gattAvailable]!,
  'leAudioAvailable': _$CapabilityStatusEnumMap[instance.leAudioAvailable]!,
  'pacsAvailable': _$CapabilityStatusEnumMap[instance.pacsAvailable]!,
  'individualBudIdentity':
      _$CapabilityStatusEnumMap[instance.individualBudIdentity]!,
  'leftRightIdentity': _$CapabilityStatusEnumMap[instance.leftRightIdentity]!,
  'leftRightConnectionState':
      _$CapabilityStatusEnumMap[instance.leftRightConnectionState]!,
  'inEarDetection': _$CapabilityStatusEnumMap[instance.inEarDetection]!,
  'perEarExposure': _$CapabilityStatusEnumMap[instance.perEarExposure]!,
  'providerName': instance.providerName,
};

const _$CapabilityStatusEnumMap = {
  CapabilityStatus.supported: 'supported',
  CapabilityStatus.unsupported: 'unsupported',
  CapabilityStatus.unknown: 'unknown',
};
