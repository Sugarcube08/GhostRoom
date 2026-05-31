// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'kx.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionKeys {

/// Session key to be used to decrypt received data
 SecureKey get rx;/// Session key to be used to encrypt data before transmitting it
 SecureKey get tx;
/// Create a copy of SessionKeys
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionKeysCopyWith<SessionKeys> get copyWith => _$SessionKeysCopyWithImpl<SessionKeys>(this as SessionKeys, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionKeys&&(identical(other.rx, rx) || other.rx == rx)&&(identical(other.tx, tx) || other.tx == tx));
}


@override
int get hashCode => Object.hash(runtimeType,rx,tx);

@override
String toString() {
  return 'SessionKeys(rx: $rx, tx: $tx)';
}


}

/// @nodoc
abstract mixin class $SessionKeysCopyWith<$Res>  {
  factory $SessionKeysCopyWith(SessionKeys value, $Res Function(SessionKeys) _then) = _$SessionKeysCopyWithImpl;
@useResult
$Res call({
 SecureKey rx, SecureKey tx
});




}
/// @nodoc
class _$SessionKeysCopyWithImpl<$Res>
    implements $SessionKeysCopyWith<$Res> {
  _$SessionKeysCopyWithImpl(this._self, this._then);

  final SessionKeys _self;
  final $Res Function(SessionKeys) _then;

/// Create a copy of SessionKeys
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rx = null,Object? tx = null,}) {
  return _then(_self.copyWith(
rx: null == rx ? _self.rx : rx // ignore: cast_nullable_to_non_nullable
as SecureKey,tx: null == tx ? _self.tx : tx // ignore: cast_nullable_to_non_nullable
as SecureKey,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionKeys].
extension SessionKeysPatterns on SessionKeys {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionKeys value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionKeys() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionKeys value)  $default,){
final _that = this;
switch (_that) {
case _SessionKeys():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionKeys value)?  $default,){
final _that = this;
switch (_that) {
case _SessionKeys() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SecureKey rx,  SecureKey tx)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionKeys() when $default != null:
return $default(_that.rx,_that.tx);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SecureKey rx,  SecureKey tx)  $default,) {final _that = this;
switch (_that) {
case _SessionKeys():
return $default(_that.rx,_that.tx);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SecureKey rx,  SecureKey tx)?  $default,) {final _that = this;
switch (_that) {
case _SessionKeys() when $default != null:
return $default(_that.rx,_that.tx);case _:
  return null;

}
}

}

/// @nodoc


class _SessionKeys extends SessionKeys {
  const _SessionKeys({required this.rx, required this.tx}): super._();
  

/// Session key to be used to decrypt received data
@override final  SecureKey rx;
/// Session key to be used to encrypt data before transmitting it
@override final  SecureKey tx;

/// Create a copy of SessionKeys
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionKeysCopyWith<_SessionKeys> get copyWith => __$SessionKeysCopyWithImpl<_SessionKeys>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionKeys&&(identical(other.rx, rx) || other.rx == rx)&&(identical(other.tx, tx) || other.tx == tx));
}


@override
int get hashCode => Object.hash(runtimeType,rx,tx);

@override
String toString() {
  return 'SessionKeys(rx: $rx, tx: $tx)';
}


}

/// @nodoc
abstract mixin class _$SessionKeysCopyWith<$Res> implements $SessionKeysCopyWith<$Res> {
  factory _$SessionKeysCopyWith(_SessionKeys value, $Res Function(_SessionKeys) _then) = __$SessionKeysCopyWithImpl;
@override @useResult
$Res call({
 SecureKey rx, SecureKey tx
});




}
/// @nodoc
class __$SessionKeysCopyWithImpl<$Res>
    implements _$SessionKeysCopyWith<$Res> {
  __$SessionKeysCopyWithImpl(this._self, this._then);

  final _SessionKeys _self;
  final $Res Function(_SessionKeys) _then;

/// Create a copy of SessionKeys
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rx = null,Object? tx = null,}) {
  return _then(_SessionKeys(
rx: null == rx ? _self.rx : rx // ignore: cast_nullable_to_non_nullable
as SecureKey,tx: null == tx ? _self.tx : tx // ignore: cast_nullable_to_non_nullable
as SecureKey,
  ));
}


}

// dart format on
