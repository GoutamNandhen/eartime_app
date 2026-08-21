// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ear_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EarState {

 bool? get leftAvailable; bool? get rightAvailable; bool? get leftInEar; bool? get rightInEar; EarSide get earSide; String get confidence; String get source; DateTime get timestamp;
/// Create a copy of EarState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EarStateCopyWith<EarState> get copyWith => _$EarStateCopyWithImpl<EarState>(this as EarState, _$identity);

  /// Serializes this EarState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EarState&&(identical(other.leftAvailable, leftAvailable) || other.leftAvailable == leftAvailable)&&(identical(other.rightAvailable, rightAvailable) || other.rightAvailable == rightAvailable)&&(identical(other.leftInEar, leftInEar) || other.leftInEar == leftInEar)&&(identical(other.rightInEar, rightInEar) || other.rightInEar == rightInEar)&&(identical(other.earSide, earSide) || other.earSide == earSide)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.source, source) || other.source == source)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,leftAvailable,rightAvailable,leftInEar,rightInEar,earSide,confidence,source,timestamp);

@override
String toString() {
  return 'EarState(leftAvailable: $leftAvailable, rightAvailable: $rightAvailable, leftInEar: $leftInEar, rightInEar: $rightInEar, earSide: $earSide, confidence: $confidence, source: $source, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $EarStateCopyWith<$Res>  {
  factory $EarStateCopyWith(EarState value, $Res Function(EarState) _then) = _$EarStateCopyWithImpl;
@useResult
$Res call({
 bool? leftAvailable, bool? rightAvailable, bool? leftInEar, bool? rightInEar, EarSide earSide, String confidence, String source, DateTime timestamp
});




}
/// @nodoc
class _$EarStateCopyWithImpl<$Res>
    implements $EarStateCopyWith<$Res> {
  _$EarStateCopyWithImpl(this._self, this._then);

  final EarState _self;
  final $Res Function(EarState) _then;

/// Create a copy of EarState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? leftAvailable = freezed,Object? rightAvailable = freezed,Object? leftInEar = freezed,Object? rightInEar = freezed,Object? earSide = null,Object? confidence = null,Object? source = null,Object? timestamp = null,}) {
  return _then(_self.copyWith(
leftAvailable: freezed == leftAvailable ? _self.leftAvailable : leftAvailable // ignore: cast_nullable_to_non_nullable
as bool?,rightAvailable: freezed == rightAvailable ? _self.rightAvailable : rightAvailable // ignore: cast_nullable_to_non_nullable
as bool?,leftInEar: freezed == leftInEar ? _self.leftInEar : leftInEar // ignore: cast_nullable_to_non_nullable
as bool?,rightInEar: freezed == rightInEar ? _self.rightInEar : rightInEar // ignore: cast_nullable_to_non_nullable
as bool?,earSide: null == earSide ? _self.earSide : earSide // ignore: cast_nullable_to_non_nullable
as EarSide,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EarState].
extension EarStatePatterns on EarState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EarState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EarState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EarState value)  $default,){
final _that = this;
switch (_that) {
case _EarState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EarState value)?  $default,){
final _that = this;
switch (_that) {
case _EarState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool? leftAvailable,  bool? rightAvailable,  bool? leftInEar,  bool? rightInEar,  EarSide earSide,  String confidence,  String source,  DateTime timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EarState() when $default != null:
return $default(_that.leftAvailable,_that.rightAvailable,_that.leftInEar,_that.rightInEar,_that.earSide,_that.confidence,_that.source,_that.timestamp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool? leftAvailable,  bool? rightAvailable,  bool? leftInEar,  bool? rightInEar,  EarSide earSide,  String confidence,  String source,  DateTime timestamp)  $default,) {final _that = this;
switch (_that) {
case _EarState():
return $default(_that.leftAvailable,_that.rightAvailable,_that.leftInEar,_that.rightInEar,_that.earSide,_that.confidence,_that.source,_that.timestamp);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool? leftAvailable,  bool? rightAvailable,  bool? leftInEar,  bool? rightInEar,  EarSide earSide,  String confidence,  String source,  DateTime timestamp)?  $default,) {final _that = this;
switch (_that) {
case _EarState() when $default != null:
return $default(_that.leftAvailable,_that.rightAvailable,_that.leftInEar,_that.rightInEar,_that.earSide,_that.confidence,_that.source,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EarState implements EarState {
  const _EarState({this.leftAvailable, this.rightAvailable, this.leftInEar, this.rightInEar, this.earSide = EarSide.unknown, this.confidence = 'unknown', this.source = 'fallback', required this.timestamp});
  factory _EarState.fromJson(Map<String, dynamic> json) => _$EarStateFromJson(json);

@override final  bool? leftAvailable;
@override final  bool? rightAvailable;
@override final  bool? leftInEar;
@override final  bool? rightInEar;
@override@JsonKey() final  EarSide earSide;
@override@JsonKey() final  String confidence;
@override@JsonKey() final  String source;
@override final  DateTime timestamp;

/// Create a copy of EarState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EarStateCopyWith<_EarState> get copyWith => __$EarStateCopyWithImpl<_EarState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EarStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EarState&&(identical(other.leftAvailable, leftAvailable) || other.leftAvailable == leftAvailable)&&(identical(other.rightAvailable, rightAvailable) || other.rightAvailable == rightAvailable)&&(identical(other.leftInEar, leftInEar) || other.leftInEar == leftInEar)&&(identical(other.rightInEar, rightInEar) || other.rightInEar == rightInEar)&&(identical(other.earSide, earSide) || other.earSide == earSide)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.source, source) || other.source == source)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,leftAvailable,rightAvailable,leftInEar,rightInEar,earSide,confidence,source,timestamp);

@override
String toString() {
  return 'EarState(leftAvailable: $leftAvailable, rightAvailable: $rightAvailable, leftInEar: $leftInEar, rightInEar: $rightInEar, earSide: $earSide, confidence: $confidence, source: $source, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$EarStateCopyWith<$Res> implements $EarStateCopyWith<$Res> {
  factory _$EarStateCopyWith(_EarState value, $Res Function(_EarState) _then) = __$EarStateCopyWithImpl;
@override @useResult
$Res call({
 bool? leftAvailable, bool? rightAvailable, bool? leftInEar, bool? rightInEar, EarSide earSide, String confidence, String source, DateTime timestamp
});




}
/// @nodoc
class __$EarStateCopyWithImpl<$Res>
    implements _$EarStateCopyWith<$Res> {
  __$EarStateCopyWithImpl(this._self, this._then);

  final _EarState _self;
  final $Res Function(_EarState) _then;

/// Create a copy of EarState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? leftAvailable = freezed,Object? rightAvailable = freezed,Object? leftInEar = freezed,Object? rightInEar = freezed,Object? earSide = null,Object? confidence = null,Object? source = null,Object? timestamp = null,}) {
  return _then(_EarState(
leftAvailable: freezed == leftAvailable ? _self.leftAvailable : leftAvailable // ignore: cast_nullable_to_non_nullable
as bool?,rightAvailable: freezed == rightAvailable ? _self.rightAvailable : rightAvailable // ignore: cast_nullable_to_non_nullable
as bool?,leftInEar: freezed == leftInEar ? _self.leftInEar : leftInEar // ignore: cast_nullable_to_non_nullable
as bool?,rightInEar: freezed == rightInEar ? _self.rightInEar : rightInEar // ignore: cast_nullable_to_non_nullable
as bool?,earSide: null == earSide ? _self.earSide : earSide // ignore: cast_nullable_to_non_nullable
as EarSide,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
