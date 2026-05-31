// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'init_push_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InitPushResult<TState extends Object> {

 Uint8List get header; TState get state;
/// Create a copy of InitPushResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InitPushResultCopyWith<TState, InitPushResult<TState>> get copyWith => _$InitPushResultCopyWithImpl<TState, InitPushResult<TState>>(this as InitPushResult<TState>, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InitPushResult<TState>&&const DeepCollectionEquality().equals(other.header, header)&&const DeepCollectionEquality().equals(other.state, state));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(header),const DeepCollectionEquality().hash(state));

@override
String toString() {
  return 'InitPushResult<$TState>(header: $header, state: $state)';
}


}

/// @nodoc
abstract mixin class $InitPushResultCopyWith<TState extends Object,$Res>  {
  factory $InitPushResultCopyWith(InitPushResult<TState> value, $Res Function(InitPushResult<TState>) _then) = _$InitPushResultCopyWithImpl;
@useResult
$Res call({
 Uint8List header, TState state
});




}
/// @nodoc
class _$InitPushResultCopyWithImpl<TState extends Object,$Res>
    implements $InitPushResultCopyWith<TState, $Res> {
  _$InitPushResultCopyWithImpl(this._self, this._then);

  final InitPushResult<TState> _self;
  final $Res Function(InitPushResult<TState>) _then;

/// Create a copy of InitPushResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? header = null,Object? state = null,}) {
  return _then(_self.copyWith(
header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as Uint8List,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TState,
  ));
}

}


/// Adds pattern-matching-related methods to [InitPushResult].
extension InitPushResultPatterns<TState extends Object> on InitPushResult<TState> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InitPushResult<TState> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InitPushResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InitPushResult<TState> value)  $default,){
final _that = this;
switch (_that) {
case _InitPushResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InitPushResult<TState> value)?  $default,){
final _that = this;
switch (_that) {
case _InitPushResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List header,  TState state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InitPushResult() when $default != null:
return $default(_that.header,_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List header,  TState state)  $default,) {final _that = this;
switch (_that) {
case _InitPushResult():
return $default(_that.header,_that.state);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List header,  TState state)?  $default,) {final _that = this;
switch (_that) {
case _InitPushResult() when $default != null:
return $default(_that.header,_that.state);case _:
  return null;

}
}

}

/// @nodoc


class _InitPushResult<TState extends Object> implements InitPushResult<TState> {
  const _InitPushResult({required this.header, required this.state});
  

@override final  Uint8List header;
@override final  TState state;

/// Create a copy of InitPushResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InitPushResultCopyWith<TState, _InitPushResult<TState>> get copyWith => __$InitPushResultCopyWithImpl<TState, _InitPushResult<TState>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InitPushResult<TState>&&const DeepCollectionEquality().equals(other.header, header)&&const DeepCollectionEquality().equals(other.state, state));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(header),const DeepCollectionEquality().hash(state));

@override
String toString() {
  return 'InitPushResult<$TState>(header: $header, state: $state)';
}


}

/// @nodoc
abstract mixin class _$InitPushResultCopyWith<TState extends Object,$Res> implements $InitPushResultCopyWith<TState, $Res> {
  factory _$InitPushResultCopyWith(_InitPushResult<TState> value, $Res Function(_InitPushResult<TState>) _then) = __$InitPushResultCopyWithImpl;
@override @useResult
$Res call({
 Uint8List header, TState state
});




}
/// @nodoc
class __$InitPushResultCopyWithImpl<TState extends Object,$Res>
    implements _$InitPushResultCopyWith<TState, $Res> {
  __$InitPushResultCopyWithImpl(this._self, this._then);

  final _InitPushResult<TState> _self;
  final $Res Function(_InitPushResult<TState>) _then;

/// Create a copy of InitPushResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? header = null,Object? state = null,}) {
  return _then(_InitPushResult<TState>(
header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as Uint8List,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as TState,
  ));
}


}

// dart format on
