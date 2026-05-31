// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'secret_stream.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SecretStreamPlainMessage {

/// The message that should be encrypted.
 Uint8List get message;/// Additional data, that should be used to generate authentication data.
///
/// See https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#encryption
 Uint8List? get additionalData;/// The message tag that should be attached to the encrypted message.
///
/// See https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#encryption
/// and https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#constants
 SecretStreamMessageTag get tag;
/// Create a copy of SecretStreamPlainMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SecretStreamPlainMessageCopyWith<SecretStreamPlainMessage> get copyWith => _$SecretStreamPlainMessageCopyWithImpl<SecretStreamPlainMessage>(this as SecretStreamPlainMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SecretStreamPlainMessage&&const DeepCollectionEquality().equals(other.message, message)&&const DeepCollectionEquality().equals(other.additionalData, additionalData)&&(identical(other.tag, tag) || other.tag == tag));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(message),const DeepCollectionEquality().hash(additionalData),tag);

@override
String toString() {
  return 'SecretStreamPlainMessage(message: $message, additionalData: $additionalData, tag: $tag)';
}


}

/// @nodoc
abstract mixin class $SecretStreamPlainMessageCopyWith<$Res>  {
  factory $SecretStreamPlainMessageCopyWith(SecretStreamPlainMessage value, $Res Function(SecretStreamPlainMessage) _then) = _$SecretStreamPlainMessageCopyWithImpl;
@useResult
$Res call({
 Uint8List message, Uint8List? additionalData, SecretStreamMessageTag tag
});




}
/// @nodoc
class _$SecretStreamPlainMessageCopyWithImpl<$Res>
    implements $SecretStreamPlainMessageCopyWith<$Res> {
  _$SecretStreamPlainMessageCopyWithImpl(this._self, this._then);

  final SecretStreamPlainMessage _self;
  final $Res Function(SecretStreamPlainMessage) _then;

/// Create a copy of SecretStreamPlainMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? additionalData = freezed,Object? tag = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Uint8List,additionalData: freezed == additionalData ? _self.additionalData : additionalData // ignore: cast_nullable_to_non_nullable
as Uint8List?,tag: null == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as SecretStreamMessageTag,
  ));
}

}


/// Adds pattern-matching-related methods to [SecretStreamPlainMessage].
extension SecretStreamPlainMessagePatterns on SecretStreamPlainMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SecretStreamPlainMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SecretStreamPlainMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SecretStreamPlainMessage value)  $default,){
final _that = this;
switch (_that) {
case _SecretStreamPlainMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SecretStreamPlainMessage value)?  $default,){
final _that = this;
switch (_that) {
case _SecretStreamPlainMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List message,  Uint8List? additionalData,  SecretStreamMessageTag tag)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SecretStreamPlainMessage() when $default != null:
return $default(_that.message,_that.additionalData,_that.tag);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List message,  Uint8List? additionalData,  SecretStreamMessageTag tag)  $default,) {final _that = this;
switch (_that) {
case _SecretStreamPlainMessage():
return $default(_that.message,_that.additionalData,_that.tag);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List message,  Uint8List? additionalData,  SecretStreamMessageTag tag)?  $default,) {final _that = this;
switch (_that) {
case _SecretStreamPlainMessage() when $default != null:
return $default(_that.message,_that.additionalData,_that.tag);case _:
  return null;

}
}

}

/// @nodoc


class _SecretStreamPlainMessage implements SecretStreamPlainMessage {
  const _SecretStreamPlainMessage(this.message, {this.additionalData, this.tag = SecretStreamMessageTag.message});
  

/// The message that should be encrypted.
@override final  Uint8List message;
/// Additional data, that should be used to generate authentication data.
///
/// See https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#encryption
@override final  Uint8List? additionalData;
/// The message tag that should be attached to the encrypted message.
///
/// See https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#encryption
/// and https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#constants
@override@JsonKey() final  SecretStreamMessageTag tag;

/// Create a copy of SecretStreamPlainMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecretStreamPlainMessageCopyWith<_SecretStreamPlainMessage> get copyWith => __$SecretStreamPlainMessageCopyWithImpl<_SecretStreamPlainMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SecretStreamPlainMessage&&const DeepCollectionEquality().equals(other.message, message)&&const DeepCollectionEquality().equals(other.additionalData, additionalData)&&(identical(other.tag, tag) || other.tag == tag));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(message),const DeepCollectionEquality().hash(additionalData),tag);

@override
String toString() {
  return 'SecretStreamPlainMessage(message: $message, additionalData: $additionalData, tag: $tag)';
}


}

/// @nodoc
abstract mixin class _$SecretStreamPlainMessageCopyWith<$Res> implements $SecretStreamPlainMessageCopyWith<$Res> {
  factory _$SecretStreamPlainMessageCopyWith(_SecretStreamPlainMessage value, $Res Function(_SecretStreamPlainMessage) _then) = __$SecretStreamPlainMessageCopyWithImpl;
@override @useResult
$Res call({
 Uint8List message, Uint8List? additionalData, SecretStreamMessageTag tag
});




}
/// @nodoc
class __$SecretStreamPlainMessageCopyWithImpl<$Res>
    implements _$SecretStreamPlainMessageCopyWith<$Res> {
  __$SecretStreamPlainMessageCopyWithImpl(this._self, this._then);

  final _SecretStreamPlainMessage _self;
  final $Res Function(_SecretStreamPlainMessage) _then;

/// Create a copy of SecretStreamPlainMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? additionalData = freezed,Object? tag = null,}) {
  return _then(_SecretStreamPlainMessage(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Uint8List,additionalData: freezed == additionalData ? _self.additionalData : additionalData // ignore: cast_nullable_to_non_nullable
as Uint8List?,tag: null == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as SecretStreamMessageTag,
  ));
}


}

/// @nodoc
mixin _$SecretStreamCipherMessage {

/// The message that should be decrypted.
 Uint8List get message;/// Additional data, that should be used to generate authentication data.
///
/// See https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#decryption
 Uint8List? get additionalData;
/// Create a copy of SecretStreamCipherMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SecretStreamCipherMessageCopyWith<SecretStreamCipherMessage> get copyWith => _$SecretStreamCipherMessageCopyWithImpl<SecretStreamCipherMessage>(this as SecretStreamCipherMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SecretStreamCipherMessage&&const DeepCollectionEquality().equals(other.message, message)&&const DeepCollectionEquality().equals(other.additionalData, additionalData));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(message),const DeepCollectionEquality().hash(additionalData));

@override
String toString() {
  return 'SecretStreamCipherMessage(message: $message, additionalData: $additionalData)';
}


}

/// @nodoc
abstract mixin class $SecretStreamCipherMessageCopyWith<$Res>  {
  factory $SecretStreamCipherMessageCopyWith(SecretStreamCipherMessage value, $Res Function(SecretStreamCipherMessage) _then) = _$SecretStreamCipherMessageCopyWithImpl;
@useResult
$Res call({
 Uint8List message, Uint8List? additionalData
});




}
/// @nodoc
class _$SecretStreamCipherMessageCopyWithImpl<$Res>
    implements $SecretStreamCipherMessageCopyWith<$Res> {
  _$SecretStreamCipherMessageCopyWithImpl(this._self, this._then);

  final SecretStreamCipherMessage _self;
  final $Res Function(SecretStreamCipherMessage) _then;

/// Create a copy of SecretStreamCipherMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? additionalData = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Uint8List,additionalData: freezed == additionalData ? _self.additionalData : additionalData // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}

}


/// Adds pattern-matching-related methods to [SecretStreamCipherMessage].
extension SecretStreamCipherMessagePatterns on SecretStreamCipherMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SecretStreamCipherMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SecretStreamCipherMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SecretStreamCipherMessage value)  $default,){
final _that = this;
switch (_that) {
case _SecretStreamCipherMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SecretStreamCipherMessage value)?  $default,){
final _that = this;
switch (_that) {
case _SecretStreamCipherMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List message,  Uint8List? additionalData)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SecretStreamCipherMessage() when $default != null:
return $default(_that.message,_that.additionalData);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List message,  Uint8List? additionalData)  $default,) {final _that = this;
switch (_that) {
case _SecretStreamCipherMessage():
return $default(_that.message,_that.additionalData);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List message,  Uint8List? additionalData)?  $default,) {final _that = this;
switch (_that) {
case _SecretStreamCipherMessage() when $default != null:
return $default(_that.message,_that.additionalData);case _:
  return null;

}
}

}

/// @nodoc


class _SecretStreamCipherMessage implements SecretStreamCipherMessage {
  const _SecretStreamCipherMessage(this.message, {this.additionalData});
  

/// The message that should be decrypted.
@override final  Uint8List message;
/// Additional data, that should be used to generate authentication data.
///
/// See https://libsodium.gitbook.io/doc/secret-key_cryptography/secretstream#decryption
@override final  Uint8List? additionalData;

/// Create a copy of SecretStreamCipherMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecretStreamCipherMessageCopyWith<_SecretStreamCipherMessage> get copyWith => __$SecretStreamCipherMessageCopyWithImpl<_SecretStreamCipherMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SecretStreamCipherMessage&&const DeepCollectionEquality().equals(other.message, message)&&const DeepCollectionEquality().equals(other.additionalData, additionalData));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(message),const DeepCollectionEquality().hash(additionalData));

@override
String toString() {
  return 'SecretStreamCipherMessage(message: $message, additionalData: $additionalData)';
}


}

/// @nodoc
abstract mixin class _$SecretStreamCipherMessageCopyWith<$Res> implements $SecretStreamCipherMessageCopyWith<$Res> {
  factory _$SecretStreamCipherMessageCopyWith(_SecretStreamCipherMessage value, $Res Function(_SecretStreamCipherMessage) _then) = __$SecretStreamCipherMessageCopyWithImpl;
@override @useResult
$Res call({
 Uint8List message, Uint8List? additionalData
});




}
/// @nodoc
class __$SecretStreamCipherMessageCopyWithImpl<$Res>
    implements _$SecretStreamCipherMessageCopyWith<$Res> {
  __$SecretStreamCipherMessageCopyWithImpl(this._self, this._then);

  final _SecretStreamCipherMessage _self;
  final $Res Function(_SecretStreamCipherMessage) _then;

/// Create a copy of SecretStreamCipherMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? additionalData = freezed,}) {
  return _then(_SecretStreamCipherMessage(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Uint8List,additionalData: freezed == additionalData ? _self.additionalData : additionalData // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}


}

// dart format on
