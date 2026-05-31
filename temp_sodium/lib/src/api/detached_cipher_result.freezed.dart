// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detached_cipher_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DetachedCipherResult {

/// The encrypted data.
 Uint8List get cipherText;/// The message authentication code of the data.
 Uint8List get mac;
/// Create a copy of DetachedCipherResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetachedCipherResultCopyWith<DetachedCipherResult> get copyWith => _$DetachedCipherResultCopyWithImpl<DetachedCipherResult>(this as DetachedCipherResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetachedCipherResult&&const DeepCollectionEquality().equals(other.cipherText, cipherText)&&const DeepCollectionEquality().equals(other.mac, mac));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(cipherText),const DeepCollectionEquality().hash(mac));

@override
String toString() {
  return 'DetachedCipherResult(cipherText: $cipherText, mac: $mac)';
}


}

/// @nodoc
abstract mixin class $DetachedCipherResultCopyWith<$Res>  {
  factory $DetachedCipherResultCopyWith(DetachedCipherResult value, $Res Function(DetachedCipherResult) _then) = _$DetachedCipherResultCopyWithImpl;
@useResult
$Res call({
 Uint8List cipherText, Uint8List mac
});




}
/// @nodoc
class _$DetachedCipherResultCopyWithImpl<$Res>
    implements $DetachedCipherResultCopyWith<$Res> {
  _$DetachedCipherResultCopyWithImpl(this._self, this._then);

  final DetachedCipherResult _self;
  final $Res Function(DetachedCipherResult) _then;

/// Create a copy of DetachedCipherResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cipherText = null,Object? mac = null,}) {
  return _then(_self.copyWith(
cipherText: null == cipherText ? _self.cipherText : cipherText // ignore: cast_nullable_to_non_nullable
as Uint8List,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}

}


/// Adds pattern-matching-related methods to [DetachedCipherResult].
extension DetachedCipherResultPatterns on DetachedCipherResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetachedCipherResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetachedCipherResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetachedCipherResult value)  $default,){
final _that = this;
switch (_that) {
case _DetachedCipherResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetachedCipherResult value)?  $default,){
final _that = this;
switch (_that) {
case _DetachedCipherResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List cipherText,  Uint8List mac)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetachedCipherResult() when $default != null:
return $default(_that.cipherText,_that.mac);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List cipherText,  Uint8List mac)  $default,) {final _that = this;
switch (_that) {
case _DetachedCipherResult():
return $default(_that.cipherText,_that.mac);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List cipherText,  Uint8List mac)?  $default,) {final _that = this;
switch (_that) {
case _DetachedCipherResult() when $default != null:
return $default(_that.cipherText,_that.mac);case _:
  return null;

}
}

}

/// @nodoc


class _DetachedCipherResult implements DetachedCipherResult {
  const _DetachedCipherResult({required this.cipherText, required this.mac});
  

/// The encrypted data.
@override final  Uint8List cipherText;
/// The message authentication code of the data.
@override final  Uint8List mac;

/// Create a copy of DetachedCipherResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetachedCipherResultCopyWith<_DetachedCipherResult> get copyWith => __$DetachedCipherResultCopyWithImpl<_DetachedCipherResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetachedCipherResult&&const DeepCollectionEquality().equals(other.cipherText, cipherText)&&const DeepCollectionEquality().equals(other.mac, mac));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(cipherText),const DeepCollectionEquality().hash(mac));

@override
String toString() {
  return 'DetachedCipherResult(cipherText: $cipherText, mac: $mac)';
}


}

/// @nodoc
abstract mixin class _$DetachedCipherResultCopyWith<$Res> implements $DetachedCipherResultCopyWith<$Res> {
  factory _$DetachedCipherResultCopyWith(_DetachedCipherResult value, $Res Function(_DetachedCipherResult) _then) = __$DetachedCipherResultCopyWithImpl;
@override @useResult
$Res call({
 Uint8List cipherText, Uint8List mac
});




}
/// @nodoc
class __$DetachedCipherResultCopyWithImpl<$Res>
    implements _$DetachedCipherResultCopyWith<$Res> {
  __$DetachedCipherResultCopyWithImpl(this._self, this._then);

  final _DetachedCipherResult _self;
  final $Res Function(_DetachedCipherResult) _then;

/// Create a copy of DetachedCipherResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cipherText = null,Object? mac = null,}) {
  return _then(_DetachedCipherResult(
cipherText: null == cipherText ? _self.cipherText : cipherText // ignore: cast_nullable_to_non_nullable
as Uint8List,mac: null == mac ? _self.mac : mac // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

// dart format on
