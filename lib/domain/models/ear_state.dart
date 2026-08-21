import 'package:freezed_annotation/freezed_annotation.dart';

part 'ear_state.freezed.dart';
part 'ear_state.g.dart';

enum EarSide {
  left,
  right,
  both,
  unknown,
}

@freezed
sealed class EarState with _$EarState {
  const factory EarState({
    bool? leftAvailable,
    bool? rightAvailable,
    bool? leftInEar,
    bool? rightInEar,
    @Default(EarSide.unknown) EarSide earSide,
    @Default('unknown') String confidence,
    @Default('fallback') String source,
    required DateTime timestamp,
  }) = _EarState;

  factory EarState.fromJson(Map<String, dynamic> json) => _$EarStateFromJson(json);
}
