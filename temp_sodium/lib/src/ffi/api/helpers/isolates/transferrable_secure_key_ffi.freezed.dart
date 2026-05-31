// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transferrable_secure_key_ffi.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransferrableSecureKeyFFI {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferrableSecureKeyFFI);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TransferrableSecureKeyFFI()';
}


}

/// @nodoc
class $TransferrableSecureKeyFFICopyWith<$Res>  {
$TransferrableSecureKeyFFICopyWith(TransferrableSecureKeyFFI _, $Res Function(TransferrableSecureKeyFFI) __);
}


/// Adds pattern-matching-related methods to [TransferrableSecureKeyFFI].
extension TransferrableSecureKeyFFIPatterns on TransferrableSecureKeyFFI {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TransferrableSecureKeyFFINative value)?  ffi,TResult Function( TransferrableSecureKeyFFIGeneric value)?  generic,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TransferrableSecureKeyFFINative() when ffi != null:
return ffi(_that);case TransferrableSecureKeyFFIGeneric() when generic != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TransferrableSecureKeyFFINative value)  ffi,required TResult Function( TransferrableSecureKeyFFIGeneric value)  generic,}){
final _that = this;
switch (_that) {
case TransferrableSecureKeyFFINative():
return ffi(_that);case TransferrableSecureKeyFFIGeneric():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TransferrableSecureKeyFFINative value)?  ffi,TResult? Function( TransferrableSecureKeyFFIGeneric value)?  generic,}){
final _that = this;
switch (_that) {
case TransferrableSecureKeyFFINative() when ffi != null:
return ffi(_that);case TransferrableSecureKeyFFIGeneric() when generic != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( SecureKeyFFINativeHandle nativeHandle)?  ffi,TResult Function( TransferableTypedData keyBytes)?  generic,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TransferrableSecureKeyFFINative() when ffi != null:
return ffi(_that.nativeHandle);case TransferrableSecureKeyFFIGeneric() when generic != null:
return generic(_that.keyBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( SecureKeyFFINativeHandle nativeHandle)  ffi,required TResult Function( TransferableTypedData keyBytes)  generic,}) {final _that = this;
switch (_that) {
case TransferrableSecureKeyFFINative():
return ffi(_that.nativeHandle);case TransferrableSecureKeyFFIGeneric():
return generic(_that.keyBytes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( SecureKeyFFINativeHandle nativeHandle)?  ffi,TResult? Function( TransferableTypedData keyBytes)?  generic,}) {final _that = this;
switch (_that) {
case TransferrableSecureKeyFFINative() when ffi != null:
return ffi(_that.nativeHandle);case TransferrableSecureKeyFFIGeneric() when generic != null:
return generic(_that.keyBytes);case _:
  return null;

}
}

}

/// @nodoc


class TransferrableSecureKeyFFINative extends TransferrableSecureKeyFFI {
  const TransferrableSecureKeyFFINative(this.nativeHandle): super._();
  

 final  SecureKeyFFINativeHandle nativeHandle;

/// Create a copy of TransferrableSecureKeyFFI
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferrableSecureKeyFFINativeCopyWith<TransferrableSecureKeyFFINative> get copyWith => _$TransferrableSecureKeyFFINativeCopyWithImpl<TransferrableSecureKeyFFINative>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferrableSecureKeyFFINative&&(identical(other.nativeHandle, nativeHandle) || other.nativeHandle == nativeHandle));
}


@override
int get hashCode => Object.hash(runtimeType,nativeHandle);

@override
String toString() {
  return 'TransferrableSecureKeyFFI.ffi(nativeHandle: $nativeHandle)';
}


}

/// @nodoc
abstract mixin class $TransferrableSecureKeyFFINativeCopyWith<$Res> implements $TransferrableSecureKeyFFICopyWith<$Res> {
  factory $TransferrableSecureKeyFFINativeCopyWith(TransferrableSecureKeyFFINative value, $Res Function(TransferrableSecureKeyFFINative) _then) = _$TransferrableSecureKeyFFINativeCopyWithImpl;
@useResult
$Res call({
 SecureKeyFFINativeHandle nativeHandle
});




}
/// @nodoc
class _$TransferrableSecureKeyFFINativeCopyWithImpl<$Res>
    implements $TransferrableSecureKeyFFINativeCopyWith<$Res> {
  _$TransferrableSecureKeyFFINativeCopyWithImpl(this._self, this._then);

  final TransferrableSecureKeyFFINative _self;
  final $Res Function(TransferrableSecureKeyFFINative) _then;

/// Create a copy of TransferrableSecureKeyFFI
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? nativeHandle = null,}) {
  return _then(TransferrableSecureKeyFFINative(
null == nativeHandle ? _self.nativeHandle : nativeHandle // ignore: cast_nullable_to_non_nullable
as SecureKeyFFINativeHandle,
  ));
}


}

/// @nodoc


class TransferrableSecureKeyFFIGeneric extends TransferrableSecureKeyFFI {
  const TransferrableSecureKeyFFIGeneric(this.keyBytes): super._();
  

 final  TransferableTypedData keyBytes;

/// Create a copy of TransferrableSecureKeyFFI
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransferrableSecureKeyFFIGenericCopyWith<TransferrableSecureKeyFFIGeneric> get copyWith => _$TransferrableSecureKeyFFIGenericCopyWithImpl<TransferrableSecureKeyFFIGeneric>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransferrableSecureKeyFFIGeneric&&(identical(other.keyBytes, keyBytes) || other.keyBytes == keyBytes));
}


@override
int get hashCode => Object.hash(runtimeType,keyBytes);

@override
String toString() {
  return 'TransferrableSecureKeyFFI.generic(keyBytes: $keyBytes)';
}


}

/// @nodoc
abstract mixin class $TransferrableSecureKeyFFIGenericCopyWith<$Res> implements $TransferrableSecureKeyFFICopyWith<$Res> {
  factory $TransferrableSecureKeyFFIGenericCopyWith(TransferrableSecureKeyFFIGeneric value, $Res Function(TransferrableSecureKeyFFIGeneric) _then) = _$TransferrableSecureKeyFFIGenericCopyWithImpl;
@useResult
$Res call({
 TransferableTypedData keyBytes
});




}
/// @nodoc
class _$TransferrableSecureKeyFFIGenericCopyWithImpl<$Res>
    implements $TransferrableSecureKeyFFIGenericCopyWith<$Res> {
  _$TransferrableSecureKeyFFIGenericCopyWithImpl(this._self, this._then);

  final TransferrableSecureKeyFFIGeneric _self;
  final $Res Function(TransferrableSecureKeyFFIGeneric) _then;

/// Create a copy of TransferrableSecureKeyFFI
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? keyBytes = null,}) {
  return _then(TransferrableSecureKeyFFIGeneric(
null == keyBytes ? _self.keyBytes : keyBytes // ignore: cast_nullable_to_non_nullable
as TransferableTypedData,
  ));
}


}

// dart format on
