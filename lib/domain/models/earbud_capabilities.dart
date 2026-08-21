import 'package:freezed_annotation/freezed_annotation.dart';

part 'earbud_capabilities.freezed.dart';
part 'earbud_capabilities.g.dart';

enum CapabilityStatus {
  supported,
  unsupported,
  unknown,
}

@freezed
sealed class EarbudCapabilities with _$EarbudCapabilities {
  const factory EarbudCapabilities({
    @Default(CapabilityStatus.unknown) CapabilityStatus bleAvailable,
    @Default(CapabilityStatus.unknown) CapabilityStatus gattAvailable,
    @Default(CapabilityStatus.unknown) CapabilityStatus leAudioAvailable,
    @Default(CapabilityStatus.unknown) CapabilityStatus pacsAvailable,
    @Default(CapabilityStatus.unknown) CapabilityStatus individualBudIdentity,
    @Default(CapabilityStatus.unknown) CapabilityStatus leftRightIdentity,
    @Default(CapabilityStatus.unknown) CapabilityStatus leftRightConnectionState,
    @Default(CapabilityStatus.unknown) CapabilityStatus inEarDetection,
    @Default(CapabilityStatus.unknown) CapabilityStatus perEarExposure,
    @Default('Unknown') String providerName,
  }) = _EarbudCapabilities;

  factory EarbudCapabilities.fromJson(Map<String, dynamic> json) => _$EarbudCapabilitiesFromJson(json);
}
