// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'earbud_capabilities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EarbudCapabilities {

 CapabilityStatus get bleAvailable; CapabilityStatus get gattAvailable; CapabilityStatus get leAudioAvailable; CapabilityStatus get pacsAvailable; CapabilityStatus get individualBudIdentity; CapabilityStatus get leftRightIdentity; CapabilityStatus get leftRightConnectionState; CapabilityStatus get inEarDetection; CapabilityStatus get perEarExposure; String get providerName;
/// Create a copy of EarbudCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EarbudCapabilitiesCopyWith<EarbudCapabilities> get copyWith => _$EarbudCapabilitiesCopyWithImpl<EarbudCapabilities>(this as EarbudCapabilities, _$identity);

  /// Serializes this EarbudCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EarbudCapabilities&&(identical(other.bleAvailable, bleAvailable) || other.bleAvailable == bleAvailable)&&(identical(other.gattAvailable, gattAvailable) || other.gattAvailable == gattAvailable)&&(identical(other.leAudioAvailable, leAudioAvailable) || other.leAudioAvailable == leAudioAvailable)&&(identical(other.pacsAvailable, pacsAvailable) || other.pacsAvailable == pacsAvailable)&&(identical(other.individualBudIdentity, individualBudIdentity) || other.individualBudIdentity == individualBudIdentity)&&(identical(other.leftRightIdentity, leftRightIdentity) || other.leftRightIdentity == leftRightIdentity)&&(identical(other.leftRightConnectionState, leftRightConnectionState) || other.leftRightConnectionState == leftRightConnectionState)&&(identical(other.inEarDetection, inEarDetection) || other.inEarDetection == inEarDetection)&&(identical(other.perEarExposure, perEarExposure) || other.perEarExposure == perEarExposure)&&(identical(other.providerName, providerName) || other.providerName == providerName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bleAvailable,gattAvailable,leAudioAvailable,pacsAvailable,individualBudIdentity,leftRightIdentity,leftRightConnectionState,inEarDetection,perEarExposure,providerName);

@override
String toString() {
  return 'EarbudCapabilities(bleAvailable: $bleAvailable, gattAvailable: $gattAvailable, leAudioAvailable: $leAudioAvailable, pacsAvailable: $pacsAvailable, individualBudIdentity: $individualBudIdentity, leftRightIdentity: $leftRightIdentity, leftRightConnectionState: $leftRightConnectionState, inEarDetection: $inEarDetection, perEarExposure: $perEarExposure, providerName: $providerName)';
}


}

/// @nodoc
abstract mixin class $EarbudCapabilitiesCopyWith<$Res>  {
  factory $EarbudCapabilitiesCopyWith(EarbudCapabilities value, $Res Function(EarbudCapabilities) _then) = _$EarbudCapabilitiesCopyWithImpl;
@useResult
$Res call({
 CapabilityStatus bleAvailable, CapabilityStatus gattAvailable, CapabilityStatus leAudioAvailable, CapabilityStatus pacsAvailable, CapabilityStatus individualBudIdentity, CapabilityStatus leftRightIdentity, CapabilityStatus leftRightConnectionState, CapabilityStatus inEarDetection, CapabilityStatus perEarExposure, String providerName
});




}
/// @nodoc
class _$EarbudCapabilitiesCopyWithImpl<$Res>
    implements $EarbudCapabilitiesCopyWith<$Res> {
  _$EarbudCapabilitiesCopyWithImpl(this._self, this._then);

  final EarbudCapabilities _self;
  final $Res Function(EarbudCapabilities) _then;

/// Create a copy of EarbudCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bleAvailable = null,Object? gattAvailable = null,Object? leAudioAvailable = null,Object? pacsAvailable = null,Object? individualBudIdentity = null,Object? leftRightIdentity = null,Object? leftRightConnectionState = null,Object? inEarDetection = null,Object? perEarExposure = null,Object? providerName = null,}) {
  return _then(_self.copyWith(
bleAvailable: null == bleAvailable ? _self.bleAvailable : bleAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,gattAvailable: null == gattAvailable ? _self.gattAvailable : gattAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,leAudioAvailable: null == leAudioAvailable ? _self.leAudioAvailable : leAudioAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,pacsAvailable: null == pacsAvailable ? _self.pacsAvailable : pacsAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,individualBudIdentity: null == individualBudIdentity ? _self.individualBudIdentity : individualBudIdentity // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,leftRightIdentity: null == leftRightIdentity ? _self.leftRightIdentity : leftRightIdentity // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,leftRightConnectionState: null == leftRightConnectionState ? _self.leftRightConnectionState : leftRightConnectionState // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,inEarDetection: null == inEarDetection ? _self.inEarDetection : inEarDetection // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,perEarExposure: null == perEarExposure ? _self.perEarExposure : perEarExposure // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [EarbudCapabilities].
extension EarbudCapabilitiesPatterns on EarbudCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EarbudCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EarbudCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EarbudCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _EarbudCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EarbudCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _EarbudCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CapabilityStatus bleAvailable,  CapabilityStatus gattAvailable,  CapabilityStatus leAudioAvailable,  CapabilityStatus pacsAvailable,  CapabilityStatus individualBudIdentity,  CapabilityStatus leftRightIdentity,  CapabilityStatus leftRightConnectionState,  CapabilityStatus inEarDetection,  CapabilityStatus perEarExposure,  String providerName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EarbudCapabilities() when $default != null:
return $default(_that.bleAvailable,_that.gattAvailable,_that.leAudioAvailable,_that.pacsAvailable,_that.individualBudIdentity,_that.leftRightIdentity,_that.leftRightConnectionState,_that.inEarDetection,_that.perEarExposure,_that.providerName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CapabilityStatus bleAvailable,  CapabilityStatus gattAvailable,  CapabilityStatus leAudioAvailable,  CapabilityStatus pacsAvailable,  CapabilityStatus individualBudIdentity,  CapabilityStatus leftRightIdentity,  CapabilityStatus leftRightConnectionState,  CapabilityStatus inEarDetection,  CapabilityStatus perEarExposure,  String providerName)  $default,) {final _that = this;
switch (_that) {
case _EarbudCapabilities():
return $default(_that.bleAvailable,_that.gattAvailable,_that.leAudioAvailable,_that.pacsAvailable,_that.individualBudIdentity,_that.leftRightIdentity,_that.leftRightConnectionState,_that.inEarDetection,_that.perEarExposure,_that.providerName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CapabilityStatus bleAvailable,  CapabilityStatus gattAvailable,  CapabilityStatus leAudioAvailable,  CapabilityStatus pacsAvailable,  CapabilityStatus individualBudIdentity,  CapabilityStatus leftRightIdentity,  CapabilityStatus leftRightConnectionState,  CapabilityStatus inEarDetection,  CapabilityStatus perEarExposure,  String providerName)?  $default,) {final _that = this;
switch (_that) {
case _EarbudCapabilities() when $default != null:
return $default(_that.bleAvailable,_that.gattAvailable,_that.leAudioAvailable,_that.pacsAvailable,_that.individualBudIdentity,_that.leftRightIdentity,_that.leftRightConnectionState,_that.inEarDetection,_that.perEarExposure,_that.providerName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EarbudCapabilities implements EarbudCapabilities {
  const _EarbudCapabilities({this.bleAvailable = CapabilityStatus.unknown, this.gattAvailable = CapabilityStatus.unknown, this.leAudioAvailable = CapabilityStatus.unknown, this.pacsAvailable = CapabilityStatus.unknown, this.individualBudIdentity = CapabilityStatus.unknown, this.leftRightIdentity = CapabilityStatus.unknown, this.leftRightConnectionState = CapabilityStatus.unknown, this.inEarDetection = CapabilityStatus.unknown, this.perEarExposure = CapabilityStatus.unknown, this.providerName = 'Unknown'});
  factory _EarbudCapabilities.fromJson(Map<String, dynamic> json) => _$EarbudCapabilitiesFromJson(json);

@override@JsonKey() final  CapabilityStatus bleAvailable;
@override@JsonKey() final  CapabilityStatus gattAvailable;
@override@JsonKey() final  CapabilityStatus leAudioAvailable;
@override@JsonKey() final  CapabilityStatus pacsAvailable;
@override@JsonKey() final  CapabilityStatus individualBudIdentity;
@override@JsonKey() final  CapabilityStatus leftRightIdentity;
@override@JsonKey() final  CapabilityStatus leftRightConnectionState;
@override@JsonKey() final  CapabilityStatus inEarDetection;
@override@JsonKey() final  CapabilityStatus perEarExposure;
@override@JsonKey() final  String providerName;

/// Create a copy of EarbudCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EarbudCapabilitiesCopyWith<_EarbudCapabilities> get copyWith => __$EarbudCapabilitiesCopyWithImpl<_EarbudCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EarbudCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EarbudCapabilities&&(identical(other.bleAvailable, bleAvailable) || other.bleAvailable == bleAvailable)&&(identical(other.gattAvailable, gattAvailable) || other.gattAvailable == gattAvailable)&&(identical(other.leAudioAvailable, leAudioAvailable) || other.leAudioAvailable == leAudioAvailable)&&(identical(other.pacsAvailable, pacsAvailable) || other.pacsAvailable == pacsAvailable)&&(identical(other.individualBudIdentity, individualBudIdentity) || other.individualBudIdentity == individualBudIdentity)&&(identical(other.leftRightIdentity, leftRightIdentity) || other.leftRightIdentity == leftRightIdentity)&&(identical(other.leftRightConnectionState, leftRightConnectionState) || other.leftRightConnectionState == leftRightConnectionState)&&(identical(other.inEarDetection, inEarDetection) || other.inEarDetection == inEarDetection)&&(identical(other.perEarExposure, perEarExposure) || other.perEarExposure == perEarExposure)&&(identical(other.providerName, providerName) || other.providerName == providerName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bleAvailable,gattAvailable,leAudioAvailable,pacsAvailable,individualBudIdentity,leftRightIdentity,leftRightConnectionState,inEarDetection,perEarExposure,providerName);

@override
String toString() {
  return 'EarbudCapabilities(bleAvailable: $bleAvailable, gattAvailable: $gattAvailable, leAudioAvailable: $leAudioAvailable, pacsAvailable: $pacsAvailable, individualBudIdentity: $individualBudIdentity, leftRightIdentity: $leftRightIdentity, leftRightConnectionState: $leftRightConnectionState, inEarDetection: $inEarDetection, perEarExposure: $perEarExposure, providerName: $providerName)';
}


}

/// @nodoc
abstract mixin class _$EarbudCapabilitiesCopyWith<$Res> implements $EarbudCapabilitiesCopyWith<$Res> {
  factory _$EarbudCapabilitiesCopyWith(_EarbudCapabilities value, $Res Function(_EarbudCapabilities) _then) = __$EarbudCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
 CapabilityStatus bleAvailable, CapabilityStatus gattAvailable, CapabilityStatus leAudioAvailable, CapabilityStatus pacsAvailable, CapabilityStatus individualBudIdentity, CapabilityStatus leftRightIdentity, CapabilityStatus leftRightConnectionState, CapabilityStatus inEarDetection, CapabilityStatus perEarExposure, String providerName
});




}
/// @nodoc
class __$EarbudCapabilitiesCopyWithImpl<$Res>
    implements _$EarbudCapabilitiesCopyWith<$Res> {
  __$EarbudCapabilitiesCopyWithImpl(this._self, this._then);

  final _EarbudCapabilities _self;
  final $Res Function(_EarbudCapabilities) _then;

/// Create a copy of EarbudCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bleAvailable = null,Object? gattAvailable = null,Object? leAudioAvailable = null,Object? pacsAvailable = null,Object? individualBudIdentity = null,Object? leftRightIdentity = null,Object? leftRightConnectionState = null,Object? inEarDetection = null,Object? perEarExposure = null,Object? providerName = null,}) {
  return _then(_EarbudCapabilities(
bleAvailable: null == bleAvailable ? _self.bleAvailable : bleAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,gattAvailable: null == gattAvailable ? _self.gattAvailable : gattAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,leAudioAvailable: null == leAudioAvailable ? _self.leAudioAvailable : leAudioAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,pacsAvailable: null == pacsAvailable ? _self.pacsAvailable : pacsAvailable // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,individualBudIdentity: null == individualBudIdentity ? _self.individualBudIdentity : individualBudIdentity // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,leftRightIdentity: null == leftRightIdentity ? _self.leftRightIdentity : leftRightIdentity // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,leftRightConnectionState: null == leftRightConnectionState ? _self.leftRightConnectionState : leftRightConnectionState // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,inEarDetection: null == inEarDetection ? _self.inEarDetection : inEarDetection // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,perEarExposure: null == perEarExposure ? _self.perEarExposure : perEarExposure // ignore: cast_nullable_to_non_nullable
as CapabilityStatus,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
