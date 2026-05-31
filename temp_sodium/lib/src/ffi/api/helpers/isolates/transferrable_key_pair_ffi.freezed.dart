// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transferrable_key_pair_ffi.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransferrableKeyPairFFI {

 TransferableTypedData get publicKeyBytes;
/// Create a copy of TransferrableKeyPairFFI
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferrableKeyPairFFICopyWith<TransferrableKeyPairFFI> get copyWith => _$TransferrableKeyPairFFICopyWithImpl<TransferrableKeyPairFFI>(this as TransferrableKeyPairFFI, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferrableKeyPairFFI&&(identical(other.publicKeyBytes, publicKeyBytes) || other.publicKeyBytes == publicKeyBytes));
}


@override
int get hashCode => Object.hash(runtimeType,publicKeyBytes);

@override
String toString() {
  return 'TransferrableKeyPairFFI(publicKeyBytes: $publicKeyBytes)';
}


}

/// @nodoc
abstract mixin class $TransferrableKeyPairFFICopyWith<$Res>  {
  factory $TransferrableKeyPairFFICopyWith(TransferrableKeyPairFFI value, $Res Function(TransferrableKeyPairFFI) _then) = _$TransferrableKeyPairFFICopyWithImpl;
@useResult
$Res call({
 TransferableTypedData publicKeyBytes
});




}
/// @nodoc
class _$TransferrableKeyPairFFICopyWithImpl<$Res>
    implements $TransferrableKeyPairFFICopyWith<$Res> {
  _$TransferrableKeyPairFFICopyWithImpl(this._self, this._then);

  final TransferrableKeyPairFFI _self;
  final $Res Function(TransferrableKeyPairFFI) _then;

/// Create a copy of TransferrableKeyPairFFI
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? publicKeyBytes = null,}) {
  return _then(_self.copyWith(
publicKeyBytes: null == publicKeyBytes ? _self.publicKeyBytes : publicKeyBytes // ignore: cast_nullable_to_non_nullable
as TransferableTypedData,
  ));
}

}


/// Adds pattern-matching-related methods to [TransferrableKeyPairFFI].
extension TransferrableKeyPairFFIPatterns on TransferrableKeyPairFFI {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransferrableKeyPairFFINative value)?  ffi,TResult Function( TransferrableKeyPairFFIGeneric value)?  generic,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransferrableKeyPairFFINative() when ffi != null:
return ffi(_that);case TransferrableKeyPairFFIGeneric() when generic != null:
return generic(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransferrableKeyPairFFINative value)  ffi,required TResult Function( TransferrableKeyPairFFIGeneric value)  generic,}){
final _that = this;
switch (_that) {
case TransferrableKeyPairFFINative():
return ffi(_that);case TransferrableKeyPairFFIGeneric():
return generic(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransferrableKeyPairFFINative value)?  ffi,TResult? Function( TransferrableKeyPairFFIGeneric value)?  generic,}){
final _that = this;
switch (_that) {
case TransferrableKeyPairFFINative() when ffi != null:
return ffi(_that);case TransferrableKeyPairFFIGeneric() when generic != null:
return generic(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( TransferableTypedData publicKeyBytes,  SecureKeyFFINativeHandle secretKeyNativeHandle)?  ffi,TResult Function( TransferableTypedData publicKeyBytes,  TransferableTypedData secretKeyBytes)?  generic,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransferrableKeyPairFFINative() when ffi != null:
return ffi(_that.publicKeyBytes,_that.secretKeyNativeHandle);case TransferrableKeyPairFFIGeneric() when generic != null:
return generic(_that.publicKeyBytes,_that.secretKeyBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( TransferableTypedData publicKeyBytes,  SecureKeyFFINativeHandle secretKeyNativeHandle)  ffi,required TResult Function( TransferableTypedData publicKeyBytes,  TransferableTypedData secretKeyBytes)  generic,}) {final _that = this;
switch (_that) {
case TransferrableKeyPairFFINative():
return ffi(_that.publicKeyBytes,_that.secretKeyNativeHandle);case TransferrableKeyPairFFIGeneric():
return generic(_that.publicKeyBytes,_that.secretKeyBytes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( TransferableTypedData publicKeyBytes,  SecureKeyFFINativeHandle secretKeyNativeHandle)?  ffi,TResult? Function( TransferableTypedData publicKeyBytes,  TransferableTypedData secretKeyBytes)?  generic,}) {final _that = this;
switch (_that) {
case TransferrableKeyPairFFINative() when ffi != null:
return ffi(_that.publicKeyBytes,_that.secretKeyNativeHandle);case TransferrableKeyPairFFIGeneric() when generic != null:
return generic(_that.publicKeyBytes,_that.secretKeyBytes);case _:
  return null;

}
}

}

/// @nodoc


class TransferrableKeyPairFFINative extends TransferrableKeyPairFFI {
  const TransferrableKeyPairFFINative({required this.publicKeyBytes, required this.secretKeyNativeHandle}): super._();
  

@override final  TransferableTypedData publicKeyBytes;
 final  SecureKeyFFINativeHandle secretKeyNativeHandle;

/// Create a copy of TransferrableKeyPairFFI
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferrableKeyPairFFINativeCopyWith<TransferrableKeyPairFFINative> get copyWith => _$TransferrableKeyPairFFINativeCopyWithImpl<TransferrableKeyPairFFINative>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferrableKeyPairFFINative&&(identical(other.publicKeyBytes, publicKeyBytes) || other.publicKeyBytes == publicKeyBytes)&&(identical(other.secretKeyNativeHandle, secretKeyNativeHandle) || other.secretKeyNativeHandle == secretKeyNativeHandle));
}


@override
int get hashCode => Object.hash(runtimeType,publicKeyBytes,secretKeyNativeHandle);

@override
String toString() {
  return 'TransferrableKeyPairFFI.ffi(publicKeyBytes: $publicKeyBytes, secretKeyNativeHandle: $secretKeyNativeHandle)';
}


}

/// @nodoc
abstract mixin class $TransferrableKeyPairFFINativeCopyWith<$Res> implements $TransferrableKeyPairFFICopyWith<$Res> {
  factory $TransferrableKeyPairFFINativeCopyWith(TransferrableKeyPairFFINative value, $Res Function(TransferrableKeyPairFFINative) _then) = _$TransferrableKeyPairFFINativeCopyWithImpl;
@override @useResult
$Res call({
 TransferableTypedData publicKeyBytes, SecureKeyFFINativeHandle secretKeyNativeHandle
});




}
/// @nodoc
class _$TransferrableKeyPairFFINativeCopyWithImpl<$Res>
    implements $TransferrableKeyPairFFINativeCopyWith<$Res> {
  _$TransferrableKeyPairFFINativeCopyWithImpl(this._self, this._then);

  final TransferrableKeyPairFFINative _self;
  final $Res Function(TransferrableKeyPairFFINative) _then;

/// Create a copy of TransferrableKeyPairFFI
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? publicKeyBytes = null,Object? secretKeyNativeHandle = null,}) {
  return _then(TransferrableKeyPairFFINative(
publicKeyBytes: null == publicKeyBytes ? _self.publicKeyBytes : publicKeyBytes // ignore: cast_nullable_to_non_nullable
as TransferableTypedData,secretKeyNativeHandle: null == secretKeyNativeHandle ? _self.secretKeyNativeHandle : secretKeyNativeHandle // ignore: cast_nullable_to_non_nullable
as SecureKeyFFINativeHandle,
  ));
}


}

/// @nodoc


class TransferrableKeyPairFFIGeneric extends TransferrableKeyPairFFI {
  const TransferrableKeyPairFFIGeneric({required this.publicKeyBytes, required this.secretKeyBytes}): super._();
  

@override final  TransferableTypedData publicKeyBytes;
 final  TransferableTypedData secretKeyBytes;

/// Create a copy of TransferrableKeyPairFFI
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferrableKeyPairFFIGenericCopyWith<TransferrableKeyPairFFIGeneric> get copyWith => _$TransferrableKeyPairFFIGenericCopyWithImpl<TransferrableKeyPairFFIGeneric>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferrableKeyPairFFIGeneric&&(identical(other.publicKeyBytes, publicKeyBytes) || other.publicKeyBytes == publicKeyBytes)&&(identical(other.secretKeyBytes, secretKeyBytes) || other.secretKeyBytes == secretKeyBytes));
}


@override
int get hashCode => Object.hash(runtimeType,publicKeyBytes,secretKeyBytes);

@override
String toString() {
  return 'TransferrableKeyPairFFI.generic(publicKeyBytes: $publicKeyBytes, secretKeyBytes: $secretKeyBytes)';
}


}

/// @nodoc
abstract mixin class $TransferrableKeyPairFFIGenericCopyWith<$Res> implements $TransferrableKeyPairFFICopyWith<$Res> {
  factory $TransferrableKeyPairFFIGenericCopyWith(TransferrableKeyPairFFIGeneric value, $Res Function(TransferrableKeyPairFFIGeneric) _then) = _$TransferrableKeyPairFFIGenericCopyWithImpl;
@override @useResult
$Res call({
 TransferableTypedData publicKeyBytes, TransferableTypedData secretKeyBytes
});




}
/// @nodoc
class _$TransferrableKeyPairFFIGenericCopyWithImpl<$Res>
    implements $TransferrableKeyPairFFIGenericCopyWith<$Res> {
  _$TransferrableKeyPairFFIGenericCopyWithImpl(this._self, this._then);

  final TransferrableKeyPairFFIGeneric _self;
  final $Res Function(TransferrableKeyPairFFIGeneric) _then;

/// Create a copy of TransferrableKeyPairFFI
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? publicKeyBytes = null,Object? secretKeyBytes = null,}) {
  return _then(TransferrableKeyPairFFIGeneric(
publicKeyBytes: null == publicKeyBytes ? _self.publicKeyBytes : publicKeyBytes // ignore: cast_nullable_to_non_nullable
as TransferableTypedData,secretKeyBytes: null == secretKeyBytes ? _self.secretKeyBytes : secretKeyBytes // ignore: cast_nullable_to_non_nullable
as TransferableTypedData,
  ));
}


}

// dart format on
