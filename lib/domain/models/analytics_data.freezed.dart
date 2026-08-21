// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnalyticsData {

 Duration get totalListenTime; Duration get averageSession; Duration get longestSession; TimeOfDayUsage get timeOfDayUsage; Map<String, double> get deviceUsagePercentages;
/// Create a copy of AnalyticsData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalyticsDataCopyWith<AnalyticsData> get copyWith => _$AnalyticsDataCopyWithImpl<AnalyticsData>(this as AnalyticsData, _$identity);

  /// Serializes this AnalyticsData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalyticsData&&(identical(other.totalListenTime, totalListenTime) || other.totalListenTime == totalListenTime)&&(identical(other.averageSession, averageSession) || other.averageSession == averageSession)&&(identical(other.longestSession, longestSession) || other.longestSession == longestSession)&&(identical(other.timeOfDayUsage, timeOfDayUsage) || other.timeOfDayUsage == timeOfDayUsage)&&const DeepCollectionEquality().equals(other.deviceUsagePercentages, deviceUsagePercentages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalListenTime,averageSession,longestSession,timeOfDayUsage,const DeepCollectionEquality().hash(deviceUsagePercentages));

@override
String toString() {
  return 'AnalyticsData(totalListenTime: $totalListenTime, averageSession: $averageSession, longestSession: $longestSession, timeOfDayUsage: $timeOfDayUsage, deviceUsagePercentages: $deviceUsagePercentages)';
}


}

/// @nodoc
abstract mixin class $AnalyticsDataCopyWith<$Res>  {
  factory $AnalyticsDataCopyWith(AnalyticsData value, $Res Function(AnalyticsData) _then) = _$AnalyticsDataCopyWithImpl;
@useResult
$Res call({
 Duration totalListenTime, Duration averageSession, Duration longestSession, TimeOfDayUsage timeOfDayUsage, Map<String, double> deviceUsagePercentages
});


$TimeOfDayUsageCopyWith<$Res> get timeOfDayUsage;

}
/// @nodoc
class _$AnalyticsDataCopyWithImpl<$Res>
    implements $AnalyticsDataCopyWith<$Res> {
  _$AnalyticsDataCopyWithImpl(this._self, this._then);

  final AnalyticsData _self;
  final $Res Function(AnalyticsData) _then;

/// Create a copy of AnalyticsData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalListenTime = null,Object? averageSession = null,Object? longestSession = null,Object? timeOfDayUsage = null,Object? deviceUsagePercentages = null,}) {
  return _then(_self.copyWith(
totalListenTime: null == totalListenTime ? _self.totalListenTime : totalListenTime // ignore: cast_nullable_to_non_nullable
as Duration,averageSession: null == averageSession ? _self.averageSession : averageSession // ignore: cast_nullable_to_non_nullable
as Duration,longestSession: null == longestSession ? _self.longestSession : longestSession // ignore: cast_nullable_to_non_nullable
as Duration,timeOfDayUsage: null == timeOfDayUsage ? _self.timeOfDayUsage : timeOfDayUsage // ignore: cast_nullable_to_non_nullable
as TimeOfDayUsage,deviceUsagePercentages: null == deviceUsagePercentages ? _self.deviceUsagePercentages : deviceUsagePercentages // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}
/// Create a copy of AnalyticsData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimeOfDayUsageCopyWith<$Res> get timeOfDayUsage {
  
  return $TimeOfDayUsageCopyWith<$Res>(_self.timeOfDayUsage, (value) {
    return _then(_self.copyWith(timeOfDayUsage: value));
  });
}
}


/// Adds pattern-matching-related methods to [AnalyticsData].
extension AnalyticsDataPatterns on AnalyticsData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnalyticsData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnalyticsData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnalyticsData value)  $default,){
final _that = this;
switch (_that) {
case _AnalyticsData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnalyticsData value)?  $default,){
final _that = this;
switch (_that) {
case _AnalyticsData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Duration totalListenTime,  Duration averageSession,  Duration longestSession,  TimeOfDayUsage timeOfDayUsage,  Map<String, double> deviceUsagePercentages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnalyticsData() when $default != null:
return $default(_that.totalListenTime,_that.averageSession,_that.longestSession,_that.timeOfDayUsage,_that.deviceUsagePercentages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Duration totalListenTime,  Duration averageSession,  Duration longestSession,  TimeOfDayUsage timeOfDayUsage,  Map<String, double> deviceUsagePercentages)  $default,) {final _that = this;
switch (_that) {
case _AnalyticsData():
return $default(_that.totalListenTime,_that.averageSession,_that.longestSession,_that.timeOfDayUsage,_that.deviceUsagePercentages);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Duration totalListenTime,  Duration averageSession,  Duration longestSession,  TimeOfDayUsage timeOfDayUsage,  Map<String, double> deviceUsagePercentages)?  $default,) {final _that = this;
switch (_that) {
case _AnalyticsData() when $default != null:
return $default(_that.totalListenTime,_that.averageSession,_that.longestSession,_that.timeOfDayUsage,_that.deviceUsagePercentages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnalyticsData implements AnalyticsData {
  const _AnalyticsData({required this.totalListenTime, required this.averageSession, required this.longestSession, required this.timeOfDayUsage, required final  Map<String, double> deviceUsagePercentages}): _deviceUsagePercentages = deviceUsagePercentages;
  factory _AnalyticsData.fromJson(Map<String, dynamic> json) => _$AnalyticsDataFromJson(json);

@override final  Duration totalListenTime;
@override final  Duration averageSession;
@override final  Duration longestSession;
@override final  TimeOfDayUsage timeOfDayUsage;
 final  Map<String, double> _deviceUsagePercentages;
@override Map<String, double> get deviceUsagePercentages {
  if (_deviceUsagePercentages is EqualUnmodifiableMapView) return _deviceUsagePercentages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_deviceUsagePercentages);
}


/// Create a copy of AnalyticsData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnalyticsDataCopyWith<_AnalyticsData> get copyWith => __$AnalyticsDataCopyWithImpl<_AnalyticsData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnalyticsDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnalyticsData&&(identical(other.totalListenTime, totalListenTime) || other.totalListenTime == totalListenTime)&&(identical(other.averageSession, averageSession) || other.averageSession == averageSession)&&(identical(other.longestSession, longestSession) || other.longestSession == longestSession)&&(identical(other.timeOfDayUsage, timeOfDayUsage) || other.timeOfDayUsage == timeOfDayUsage)&&const DeepCollectionEquality().equals(other._deviceUsagePercentages, _deviceUsagePercentages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalListenTime,averageSession,longestSession,timeOfDayUsage,const DeepCollectionEquality().hash(_deviceUsagePercentages));

@override
String toString() {
  return 'AnalyticsData(totalListenTime: $totalListenTime, averageSession: $averageSession, longestSession: $longestSession, timeOfDayUsage: $timeOfDayUsage, deviceUsagePercentages: $deviceUsagePercentages)';
}


}

/// @nodoc
abstract mixin class _$AnalyticsDataCopyWith<$Res> implements $AnalyticsDataCopyWith<$Res> {
  factory _$AnalyticsDataCopyWith(_AnalyticsData value, $Res Function(_AnalyticsData) _then) = __$AnalyticsDataCopyWithImpl;
@override @useResult
$Res call({
 Duration totalListenTime, Duration averageSession, Duration longestSession, TimeOfDayUsage timeOfDayUsage, Map<String, double> deviceUsagePercentages
});


@override $TimeOfDayUsageCopyWith<$Res> get timeOfDayUsage;

}
/// @nodoc
class __$AnalyticsDataCopyWithImpl<$Res>
    implements _$AnalyticsDataCopyWith<$Res> {
  __$AnalyticsDataCopyWithImpl(this._self, this._then);

  final _AnalyticsData _self;
  final $Res Function(_AnalyticsData) _then;

/// Create a copy of AnalyticsData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalListenTime = null,Object? averageSession = null,Object? longestSession = null,Object? timeOfDayUsage = null,Object? deviceUsagePercentages = null,}) {
  return _then(_AnalyticsData(
totalListenTime: null == totalListenTime ? _self.totalListenTime : totalListenTime // ignore: cast_nullable_to_non_nullable
as Duration,averageSession: null == averageSession ? _self.averageSession : averageSession // ignore: cast_nullable_to_non_nullable
as Duration,longestSession: null == longestSession ? _self.longestSession : longestSession // ignore: cast_nullable_to_non_nullable
as Duration,timeOfDayUsage: null == timeOfDayUsage ? _self.timeOfDayUsage : timeOfDayUsage // ignore: cast_nullable_to_non_nullable
as TimeOfDayUsage,deviceUsagePercentages: null == deviceUsagePercentages ? _self._deviceUsagePercentages : deviceUsagePercentages // ignore: cast_nullable_to_non_nullable
as Map<String, double>,
  ));
}

/// Create a copy of AnalyticsData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TimeOfDayUsageCopyWith<$Res> get timeOfDayUsage {
  
  return $TimeOfDayUsageCopyWith<$Res>(_self.timeOfDayUsage, (value) {
    return _then(_self.copyWith(timeOfDayUsage: value));
  });
}
}


/// @nodoc
mixin _$TimeOfDayUsage {

 Duration get morning; Duration get afternoon; Duration get evening; Duration get night;
/// Create a copy of TimeOfDayUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeOfDayUsageCopyWith<TimeOfDayUsage> get copyWith => _$TimeOfDayUsageCopyWithImpl<TimeOfDayUsage>(this as TimeOfDayUsage, _$identity);

  /// Serializes this TimeOfDayUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeOfDayUsage&&(identical(other.morning, morning) || other.morning == morning)&&(identical(other.afternoon, afternoon) || other.afternoon == afternoon)&&(identical(other.evening, evening) || other.evening == evening)&&(identical(other.night, night) || other.night == night));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,morning,afternoon,evening,night);

@override
String toString() {
  return 'TimeOfDayUsage(morning: $morning, afternoon: $afternoon, evening: $evening, night: $night)';
}


}

/// @nodoc
abstract mixin class $TimeOfDayUsageCopyWith<$Res>  {
  factory $TimeOfDayUsageCopyWith(TimeOfDayUsage value, $Res Function(TimeOfDayUsage) _then) = _$TimeOfDayUsageCopyWithImpl;
@useResult
$Res call({
 Duration morning, Duration afternoon, Duration evening, Duration night
});




}
/// @nodoc
class _$TimeOfDayUsageCopyWithImpl<$Res>
    implements $TimeOfDayUsageCopyWith<$Res> {
  _$TimeOfDayUsageCopyWithImpl(this._self, this._then);

  final TimeOfDayUsage _self;
  final $Res Function(TimeOfDayUsage) _then;

/// Create a copy of TimeOfDayUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? morning = null,Object? afternoon = null,Object? evening = null,Object? night = null,}) {
  return _then(_self.copyWith(
morning: null == morning ? _self.morning : morning // ignore: cast_nullable_to_non_nullable
as Duration,afternoon: null == afternoon ? _self.afternoon : afternoon // ignore: cast_nullable_to_non_nullable
as Duration,evening: null == evening ? _self.evening : evening // ignore: cast_nullable_to_non_nullable
as Duration,night: null == night ? _self.night : night // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [TimeOfDayUsage].
extension TimeOfDayUsagePatterns on TimeOfDayUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimeOfDayUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimeOfDayUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimeOfDayUsage value)  $default,){
final _that = this;
switch (_that) {
case _TimeOfDayUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimeOfDayUsage value)?  $default,){
final _that = this;
switch (_that) {
case _TimeOfDayUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Duration morning,  Duration afternoon,  Duration evening,  Duration night)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimeOfDayUsage() when $default != null:
return $default(_that.morning,_that.afternoon,_that.evening,_that.night);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Duration morning,  Duration afternoon,  Duration evening,  Duration night)  $default,) {final _that = this;
switch (_that) {
case _TimeOfDayUsage():
return $default(_that.morning,_that.afternoon,_that.evening,_that.night);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Duration morning,  Duration afternoon,  Duration evening,  Duration night)?  $default,) {final _that = this;
switch (_that) {
case _TimeOfDayUsage() when $default != null:
return $default(_that.morning,_that.afternoon,_that.evening,_that.night);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TimeOfDayUsage implements TimeOfDayUsage {
  const _TimeOfDayUsage({required this.morning, required this.afternoon, required this.evening, required this.night});
  factory _TimeOfDayUsage.fromJson(Map<String, dynamic> json) => _$TimeOfDayUsageFromJson(json);

@override final  Duration morning;
@override final  Duration afternoon;
@override final  Duration evening;
@override final  Duration night;

/// Create a copy of TimeOfDayUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimeOfDayUsageCopyWith<_TimeOfDayUsage> get copyWith => __$TimeOfDayUsageCopyWithImpl<_TimeOfDayUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimeOfDayUsageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeOfDayUsage&&(identical(other.morning, morning) || other.morning == morning)&&(identical(other.afternoon, afternoon) || other.afternoon == afternoon)&&(identical(other.evening, evening) || other.evening == evening)&&(identical(other.night, night) || other.night == night));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,morning,afternoon,evening,night);

@override
String toString() {
  return 'TimeOfDayUsage(morning: $morning, afternoon: $afternoon, evening: $evening, night: $night)';
}


}

/// @nodoc
abstract mixin class _$TimeOfDayUsageCopyWith<$Res> implements $TimeOfDayUsageCopyWith<$Res> {
  factory _$TimeOfDayUsageCopyWith(_TimeOfDayUsage value, $Res Function(_TimeOfDayUsage) _then) = __$TimeOfDayUsageCopyWithImpl;
@override @useResult
$Res call({
 Duration morning, Duration afternoon, Duration evening, Duration night
});




}
/// @nodoc
class __$TimeOfDayUsageCopyWithImpl<$Res>
    implements _$TimeOfDayUsageCopyWith<$Res> {
  __$TimeOfDayUsageCopyWithImpl(this._self, this._then);

  final _TimeOfDayUsage _self;
  final $Res Function(_TimeOfDayUsage) _then;

/// Create a copy of TimeOfDayUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? morning = null,Object? afternoon = null,Object? evening = null,Object? night = null,}) {
  return _then(_TimeOfDayUsage(
morning: null == morning ? _self.morning : morning // ignore: cast_nullable_to_non_nullable
as Duration,afternoon: null == afternoon ? _self.afternoon : afternoon // ignore: cast_nullable_to_non_nullable
as Duration,evening: null == evening ? _self.evening : evening // ignore: cast_nullable_to_non_nullable
as Duration,night: null == night ? _self.night : night // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}


/// @nodoc
mixin _$WellbeingData {

 int? get healthScore; int get volumeAvgDb; int get volumePeakDb; int get breaksCount; String? get recommendation;
/// Create a copy of WellbeingData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WellbeingDataCopyWith<WellbeingData> get copyWith => _$WellbeingDataCopyWithImpl<WellbeingData>(this as WellbeingData, _$identity);

  /// Serializes this WellbeingData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WellbeingData&&(identical(other.healthScore, healthScore) || other.healthScore == healthScore)&&(identical(other.volumeAvgDb, volumeAvgDb) || other.volumeAvgDb == volumeAvgDb)&&(identical(other.volumePeakDb, volumePeakDb) || other.volumePeakDb == volumePeakDb)&&(identical(other.breaksCount, breaksCount) || other.breaksCount == breaksCount)&&(identical(other.recommendation, recommendation) || other.recommendation == recommendation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,healthScore,volumeAvgDb,volumePeakDb,breaksCount,recommendation);

@override
String toString() {
  return 'WellbeingData(healthScore: $healthScore, volumeAvgDb: $volumeAvgDb, volumePeakDb: $volumePeakDb, breaksCount: $breaksCount, recommendation: $recommendation)';
}


}

/// @nodoc
abstract mixin class $WellbeingDataCopyWith<$Res>  {
  factory $WellbeingDataCopyWith(WellbeingData value, $Res Function(WellbeingData) _then) = _$WellbeingDataCopyWithImpl;
@useResult
$Res call({
 int? healthScore, int volumeAvgDb, int volumePeakDb, int breaksCount, String? recommendation
});




}
/// @nodoc
class _$WellbeingDataCopyWithImpl<$Res>
    implements $WellbeingDataCopyWith<$Res> {
  _$WellbeingDataCopyWithImpl(this._self, this._then);

  final WellbeingData _self;
  final $Res Function(WellbeingData) _then;

/// Create a copy of WellbeingData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? healthScore = freezed,Object? volumeAvgDb = null,Object? volumePeakDb = null,Object? breaksCount = null,Object? recommendation = freezed,}) {
  return _then(_self.copyWith(
healthScore: freezed == healthScore ? _self.healthScore : healthScore // ignore: cast_nullable_to_non_nullable
as int?,volumeAvgDb: null == volumeAvgDb ? _self.volumeAvgDb : volumeAvgDb // ignore: cast_nullable_to_non_nullable
as int,volumePeakDb: null == volumePeakDb ? _self.volumePeakDb : volumePeakDb // ignore: cast_nullable_to_non_nullable
as int,breaksCount: null == breaksCount ? _self.breaksCount : breaksCount // ignore: cast_nullable_to_non_nullable
as int,recommendation: freezed == recommendation ? _self.recommendation : recommendation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WellbeingData].
extension WellbeingDataPatterns on WellbeingData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WellbeingData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WellbeingData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WellbeingData value)  $default,){
final _that = this;
switch (_that) {
case _WellbeingData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WellbeingData value)?  $default,){
final _that = this;
switch (_that) {
case _WellbeingData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? healthScore,  int volumeAvgDb,  int volumePeakDb,  int breaksCount,  String? recommendation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WellbeingData() when $default != null:
return $default(_that.healthScore,_that.volumeAvgDb,_that.volumePeakDb,_that.breaksCount,_that.recommendation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? healthScore,  int volumeAvgDb,  int volumePeakDb,  int breaksCount,  String? recommendation)  $default,) {final _that = this;
switch (_that) {
case _WellbeingData():
return $default(_that.healthScore,_that.volumeAvgDb,_that.volumePeakDb,_that.breaksCount,_that.recommendation);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? healthScore,  int volumeAvgDb,  int volumePeakDb,  int breaksCount,  String? recommendation)?  $default,) {final _that = this;
switch (_that) {
case _WellbeingData() when $default != null:
return $default(_that.healthScore,_that.volumeAvgDb,_that.volumePeakDb,_that.breaksCount,_that.recommendation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WellbeingData implements WellbeingData {
  const _WellbeingData({required this.healthScore, required this.volumeAvgDb, required this.volumePeakDb, required this.breaksCount, required this.recommendation});
  factory _WellbeingData.fromJson(Map<String, dynamic> json) => _$WellbeingDataFromJson(json);

@override final  int? healthScore;
@override final  int volumeAvgDb;
@override final  int volumePeakDb;
@override final  int breaksCount;
@override final  String? recommendation;

/// Create a copy of WellbeingData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WellbeingDataCopyWith<_WellbeingData> get copyWith => __$WellbeingDataCopyWithImpl<_WellbeingData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WellbeingDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WellbeingData&&(identical(other.healthScore, healthScore) || other.healthScore == healthScore)&&(identical(other.volumeAvgDb, volumeAvgDb) || other.volumeAvgDb == volumeAvgDb)&&(identical(other.volumePeakDb, volumePeakDb) || other.volumePeakDb == volumePeakDb)&&(identical(other.breaksCount, breaksCount) || other.breaksCount == breaksCount)&&(identical(other.recommendation, recommendation) || other.recommendation == recommendation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,healthScore,volumeAvgDb,volumePeakDb,breaksCount,recommendation);

@override
String toString() {
  return 'WellbeingData(healthScore: $healthScore, volumeAvgDb: $volumeAvgDb, volumePeakDb: $volumePeakDb, breaksCount: $breaksCount, recommendation: $recommendation)';
}


}

/// @nodoc
abstract mixin class _$WellbeingDataCopyWith<$Res> implements $WellbeingDataCopyWith<$Res> {
  factory _$WellbeingDataCopyWith(_WellbeingData value, $Res Function(_WellbeingData) _then) = __$WellbeingDataCopyWithImpl;
@override @useResult
$Res call({
 int? healthScore, int volumeAvgDb, int volumePeakDb, int breaksCount, String? recommendation
});




}
/// @nodoc
class __$WellbeingDataCopyWithImpl<$Res>
    implements _$WellbeingDataCopyWith<$Res> {
  __$WellbeingDataCopyWithImpl(this._self, this._then);

  final _WellbeingData _self;
  final $Res Function(_WellbeingData) _then;

/// Create a copy of WellbeingData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? healthScore = freezed,Object? volumeAvgDb = null,Object? volumePeakDb = null,Object? breaksCount = null,Object? recommendation = freezed,}) {
  return _then(_WellbeingData(
healthScore: freezed == healthScore ? _self.healthScore : healthScore // ignore: cast_nullable_to_non_nullable
as int?,volumeAvgDb: null == volumeAvgDb ? _self.volumeAvgDb : volumeAvgDb // ignore: cast_nullable_to_non_nullable
as int,volumePeakDb: null == volumePeakDb ? _self.volumePeakDb : volumePeakDb // ignore: cast_nullable_to_non_nullable
as int,breaksCount: null == breaksCount ? _self.breaksCount : breaksCount // ignore: cast_nullable_to_non_nullable
as int,recommendation: freezed == recommendation ? _self.recommendation : recommendation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
