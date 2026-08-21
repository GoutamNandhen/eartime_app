// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioDevice {

 String get canonicalDeviceId; String get displayName; String get deviceType; ConnectionState get connectionState; PlaybackState get playbackState; DateTime get lastSeen; DateTime? get currentPlaybackStartTime;
/// Create a copy of AudioDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioDeviceCopyWith<AudioDevice> get copyWith => _$AudioDeviceCopyWithImpl<AudioDevice>(this as AudioDevice, _$identity);

  /// Serializes this AudioDevice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioDevice&&(identical(other.canonicalDeviceId, canonicalDeviceId) || other.canonicalDeviceId == canonicalDeviceId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.deviceType, deviceType) || other.deviceType == deviceType)&&(identical(other.connectionState, connectionState) || other.connectionState == connectionState)&&(identical(other.playbackState, playbackState) || other.playbackState == playbackState)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.currentPlaybackStartTime, currentPlaybackStartTime) || other.currentPlaybackStartTime == currentPlaybackStartTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,canonicalDeviceId,displayName,deviceType,connectionState,playbackState,lastSeen,currentPlaybackStartTime);

@override
String toString() {
  return 'AudioDevice(canonicalDeviceId: $canonicalDeviceId, displayName: $displayName, deviceType: $deviceType, connectionState: $connectionState, playbackState: $playbackState, lastSeen: $lastSeen, currentPlaybackStartTime: $currentPlaybackStartTime)';
}


}

/// @nodoc
abstract mixin class $AudioDeviceCopyWith<$Res>  {
  factory $AudioDeviceCopyWith(AudioDevice value, $Res Function(AudioDevice) _then) = _$AudioDeviceCopyWithImpl;
@useResult
$Res call({
 String canonicalDeviceId, String displayName, String deviceType, ConnectionState connectionState, PlaybackState playbackState, DateTime lastSeen, DateTime? currentPlaybackStartTime
});




}
/// @nodoc
class _$AudioDeviceCopyWithImpl<$Res>
    implements $AudioDeviceCopyWith<$Res> {
  _$AudioDeviceCopyWithImpl(this._self, this._then);

  final AudioDevice _self;
  final $Res Function(AudioDevice) _then;

/// Create a copy of AudioDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? canonicalDeviceId = null,Object? displayName = null,Object? deviceType = null,Object? connectionState = null,Object? playbackState = null,Object? lastSeen = null,Object? currentPlaybackStartTime = freezed,}) {
  return _then(_self.copyWith(
canonicalDeviceId: null == canonicalDeviceId ? _self.canonicalDeviceId : canonicalDeviceId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,deviceType: null == deviceType ? _self.deviceType : deviceType // ignore: cast_nullable_to_non_nullable
as String,connectionState: null == connectionState ? _self.connectionState : connectionState // ignore: cast_nullable_to_non_nullable
as ConnectionState,playbackState: null == playbackState ? _self.playbackState : playbackState // ignore: cast_nullable_to_non_nullable
as PlaybackState,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,currentPlaybackStartTime: freezed == currentPlaybackStartTime ? _self.currentPlaybackStartTime : currentPlaybackStartTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioDevice].
extension AudioDevicePatterns on AudioDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioDevice value)  $default,){
final _that = this;
switch (_that) {
case _AudioDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioDevice value)?  $default,){
final _that = this;
switch (_that) {
case _AudioDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String canonicalDeviceId,  String displayName,  String deviceType,  ConnectionState connectionState,  PlaybackState playbackState,  DateTime lastSeen,  DateTime? currentPlaybackStartTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioDevice() when $default != null:
return $default(_that.canonicalDeviceId,_that.displayName,_that.deviceType,_that.connectionState,_that.playbackState,_that.lastSeen,_that.currentPlaybackStartTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String canonicalDeviceId,  String displayName,  String deviceType,  ConnectionState connectionState,  PlaybackState playbackState,  DateTime lastSeen,  DateTime? currentPlaybackStartTime)  $default,) {final _that = this;
switch (_that) {
case _AudioDevice():
return $default(_that.canonicalDeviceId,_that.displayName,_that.deviceType,_that.connectionState,_that.playbackState,_that.lastSeen,_that.currentPlaybackStartTime);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String canonicalDeviceId,  String displayName,  String deviceType,  ConnectionState connectionState,  PlaybackState playbackState,  DateTime lastSeen,  DateTime? currentPlaybackStartTime)?  $default,) {final _that = this;
switch (_that) {
case _AudioDevice() when $default != null:
return $default(_that.canonicalDeviceId,_that.displayName,_that.deviceType,_that.connectionState,_that.playbackState,_that.lastSeen,_that.currentPlaybackStartTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioDevice implements AudioDevice {
  const _AudioDevice({required this.canonicalDeviceId, required this.displayName, required this.deviceType, this.connectionState = ConnectionState.unknown, this.playbackState = PlaybackState.unknown, required this.lastSeen, this.currentPlaybackStartTime});
  factory _AudioDevice.fromJson(Map<String, dynamic> json) => _$AudioDeviceFromJson(json);

@override final  String canonicalDeviceId;
@override final  String displayName;
@override final  String deviceType;
@override@JsonKey() final  ConnectionState connectionState;
@override@JsonKey() final  PlaybackState playbackState;
@override final  DateTime lastSeen;
@override final  DateTime? currentPlaybackStartTime;

/// Create a copy of AudioDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioDeviceCopyWith<_AudioDevice> get copyWith => __$AudioDeviceCopyWithImpl<_AudioDevice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioDeviceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioDevice&&(identical(other.canonicalDeviceId, canonicalDeviceId) || other.canonicalDeviceId == canonicalDeviceId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.deviceType, deviceType) || other.deviceType == deviceType)&&(identical(other.connectionState, connectionState) || other.connectionState == connectionState)&&(identical(other.playbackState, playbackState) || other.playbackState == playbackState)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.currentPlaybackStartTime, currentPlaybackStartTime) || other.currentPlaybackStartTime == currentPlaybackStartTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,canonicalDeviceId,displayName,deviceType,connectionState,playbackState,lastSeen,currentPlaybackStartTime);

@override
String toString() {
  return 'AudioDevice(canonicalDeviceId: $canonicalDeviceId, displayName: $displayName, deviceType: $deviceType, connectionState: $connectionState, playbackState: $playbackState, lastSeen: $lastSeen, currentPlaybackStartTime: $currentPlaybackStartTime)';
}


}

/// @nodoc
abstract mixin class _$AudioDeviceCopyWith<$Res> implements $AudioDeviceCopyWith<$Res> {
  factory _$AudioDeviceCopyWith(_AudioDevice value, $Res Function(_AudioDevice) _then) = __$AudioDeviceCopyWithImpl;
@override @useResult
$Res call({
 String canonicalDeviceId, String displayName, String deviceType, ConnectionState connectionState, PlaybackState playbackState, DateTime lastSeen, DateTime? currentPlaybackStartTime
});




}
/// @nodoc
class __$AudioDeviceCopyWithImpl<$Res>
    implements _$AudioDeviceCopyWith<$Res> {
  __$AudioDeviceCopyWithImpl(this._self, this._then);

  final _AudioDevice _self;
  final $Res Function(_AudioDevice) _then;

/// Create a copy of AudioDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? canonicalDeviceId = null,Object? displayName = null,Object? deviceType = null,Object? connectionState = null,Object? playbackState = null,Object? lastSeen = null,Object? currentPlaybackStartTime = freezed,}) {
  return _then(_AudioDevice(
canonicalDeviceId: null == canonicalDeviceId ? _self.canonicalDeviceId : canonicalDeviceId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,deviceType: null == deviceType ? _self.deviceType : deviceType // ignore: cast_nullable_to_non_nullable
as String,connectionState: null == connectionState ? _self.connectionState : connectionState // ignore: cast_nullable_to_non_nullable
as ConnectionState,playbackState: null == playbackState ? _self.playbackState : playbackState // ignore: cast_nullable_to_non_nullable
as PlaybackState,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,currentPlaybackStartTime: freezed == currentPlaybackStartTime ? _self.currentPlaybackStartTime : currentPlaybackStartTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
