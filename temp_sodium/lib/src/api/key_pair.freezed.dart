// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'key_pair.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$KeyPair {

/// The public key of the key pair.
 Uint8List get publicKey;/// The secret key of the key pair.
 SecureKey get secretKey;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyPair&&const DeepCollectionEquality().equals(other.publicKey, publicKey)&&(identical(other.secretKey, secretKey) || other.secretKey == secretKey));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(publicKey),secretKey);

@override
String toString() {
  return 'KeyPair(publicKey: $publicKey, secretKey: $secretKey)';
}


}




/// Adds pattern-matching-related methods to [KeyPair].
extension KeyPairPatterns on KeyPair {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KeyPair value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KeyPair() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KeyPair value)  $default,){
final _that = this;
switch (_that) {
case _KeyPair():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KeyPair value)?  $default,){
final _that = this;
switch (_that) {
case _KeyPair() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List publicKey,  SecureKey secretKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KeyPair() when $default != null:
return $default(_that.publicKey,_that.secretKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List publicKey,  SecureKey secretKey)  $default,) {final _that = this;
switch (_that) {
case _KeyPair():
return $default(_that.publicKey,_that.secretKey);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List publicKey,  SecureKey secretKey)?  $default,) {final _that = this;
switch (_that) {
case _KeyPair() when $default != null:
return $default(_that.publicKey,_that.secretKey);case _:
  return null;

}
}

}

/// @nodoc


class _KeyPair extends KeyPair {
   _KeyPair({required this.publicKey, required this.secretKey}): super._();
  

/// The public key of the key pair.
@override final  Uint8List publicKey;
/// The secret key of the key pair.
@override final  SecureKey secretKey;




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KeyPair&&const DeepCollectionEquality().equals(other.publicKey, publicKey)&&(identical(other.secretKey, secretKey) || other.secretKey == secretKey));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(publicKey),secretKey);

@override
String toString() {
  return 'KeyPair(publicKey: $publicKey, secretKey: $secretKey)';
}


}




// dart format on
