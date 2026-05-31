// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'isolate_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$IsolateResult<T> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IsolateResult<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IsolateResult<$T>()';
}


}

/// @nodoc
class $IsolateResultCopyWith<T,$Res>  {
$IsolateResultCopyWith(IsolateResult<T> _, $Res Function(IsolateResult<T>) __);
}


/// Adds pattern-matching-related methods to [IsolateResult].
extension IsolateResultPatterns<T> on IsolateResult<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IsolateResult<T> value)?  $default,{TResult Function( _SecureKeyIsolateResult<T> value)?  key,TResult Function( _KeyPairIsolateResult<T> value)?  keyPair,TResult Function( _BytesIsolateResult<T> value)?  bytes,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IsolateResult() when $default != null:
return $default(_that);case _SecureKeyIsolateResult() when key != null:
return key(_that);case _KeyPairIsolateResult() when keyPair != null:
return keyPair(_that);case _BytesIsolateResult() when bytes != null:
return bytes(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IsolateResult<T> value)  $default,{required TResult Function( _SecureKeyIsolateResult<T> value)  key,required TResult Function( _KeyPairIsolateResult<T> value)  keyPair,required TResult Function( _BytesIsolateResult<T> value)  bytes,}){
final _that = this;
switch (_that) {
case _IsolateResult():
return $default(_that);case _SecureKeyIsolateResult():
return key(_that);case _KeyPairIsolateResult():
return keyPair(_that);case _BytesIsolateResult():
return bytes(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IsolateResult<T> value)?  $default,{TResult? Function( _SecureKeyIsolateResult<T> value)?  key,TResult? Function( _KeyPairIsolateResult<T> value)?  keyPair,TResult? Function( _BytesIsolateResult<T> value)?  bytes,}){
final _that = this;
switch (_that) {
case _IsolateResult() when $default != null:
return $default(_that);case _SecureKeyIsolateResult() when key != null:
return key(_that);case _KeyPairIsolateResult() when keyPair != null:
return keyPair(_that);case _BytesIsolateResult() when bytes != null:
return bytes(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( T result)?  $default,{TResult Function( TransferrableSecureKeyFFI key)?  key,TResult Function( TransferrableKeyPairFFI keyPair)?  keyPair,TResult Function( TransferableTypedData data)?  bytes,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IsolateResult() when $default != null:
return $default(_that.result);case _SecureKeyIsolateResult() when key != null:
return key(_that.key);case _KeyPairIsolateResult() when keyPair != null:
return keyPair(_that.keyPair);case _BytesIsolateResult() when bytes != null:
return bytes(_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( T result)  $default,{required TResult Function( TransferrableSecureKeyFFI key)  key,required TResult Function( TransferrableKeyPairFFI keyPair)  keyPair,required TResult Function( TransferableTypedData data)  bytes,}) {final _that = this;
switch (_that) {
case _IsolateResult():
return $default(_that.result);case _SecureKeyIsolateResult():
return key(_that.key);case _KeyPairIsolateResult():
return keyPair(_that.keyPair);case _BytesIsolateResult():
return bytes(_that.data);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( T result)?  $default,{TResult? Function( TransferrableSecureKeyFFI key)?  key,TResult? Function( TransferrableKeyPairFFI keyPair)?  keyPair,TResult? Function( TransferableTypedData data)?  bytes,}) {final _that = this;
switch (_that) {
case _IsolateResult() when $default != null:
return $default(_that.result);case _SecureKeyIsolateResult() when key != null:
return key(_that.key);case _KeyPairIsolateResult() when keyPair != null:
return keyPair(_that.keyPair);case _BytesIsolateResult() when bytes != null:
return bytes(_that.data);case _:
  return null;

}
}

}

/// @nodoc


class _IsolateResult<T> extends IsolateResult<T> {
  const _IsolateResult(this.result): super._();
  

 final  T result;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IsolateResultCopyWith<T, _IsolateResult<T>> get copyWith => __$IsolateResultCopyWithImpl<T, _IsolateResult<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IsolateResult<T>&&const DeepCollectionEquality().equals(other.result, result));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(result));

@override
String toString() {
  return 'IsolateResult<$T>(result: $result)';
}


}

/// @nodoc
abstract mixin class _$IsolateResultCopyWith<T,$Res> implements $IsolateResultCopyWith<T, $Res> {
  factory _$IsolateResultCopyWith(_IsolateResult<T> value, $Res Function(_IsolateResult<T>) _then) = __$IsolateResultCopyWithImpl;
@useResult
$Res call({
 T result
});




}
/// @nodoc
class __$IsolateResultCopyWithImpl<T,$Res>
    implements _$IsolateResultCopyWith<T, $Res> {
  __$IsolateResultCopyWithImpl(this._self, this._then);

  final _IsolateResult<T> _self;
  final $Res Function(_IsolateResult<T>) _then;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? result = freezed,}) {
  return _then(_IsolateResult<T>(
freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as T,
  ));
}


}

/// @nodoc


class _SecureKeyIsolateResult<T> extends IsolateResult<T> {
  const _SecureKeyIsolateResult(this.key): assert(T == SecureKey, 'Cannot return subclasses of SecureKey from an isolate. Use SecureKey as return type instead.'),super._();
  

 final  TransferrableSecureKeyFFI key;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SecureKeyIsolateResultCopyWith<T, _SecureKeyIsolateResult<T>> get copyWith => __$SecureKeyIsolateResultCopyWithImpl<T, _SecureKeyIsolateResult<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SecureKeyIsolateResult<T>&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,key);

@override
String toString() {
  return 'IsolateResult<$T>.key(key: $key)';
}


}

/// @nodoc
abstract mixin class _$SecureKeyIsolateResultCopyWith<T,$Res> implements $IsolateResultCopyWith<T, $Res> {
  factory _$SecureKeyIsolateResultCopyWith(_SecureKeyIsolateResult<T> value, $Res Function(_SecureKeyIsolateResult<T>) _then) = __$SecureKeyIsolateResultCopyWithImpl;
@useResult
$Res call({
 TransferrableSecureKeyFFI key
});


$TransferrableSecureKeyFFICopyWith<$Res> get key;

}
/// @nodoc
class __$SecureKeyIsolateResultCopyWithImpl<T,$Res>
    implements _$SecureKeyIsolateResultCopyWith<T, $Res> {
  __$SecureKeyIsolateResultCopyWithImpl(this._self, this._then);

  final _SecureKeyIsolateResult<T> _self;
  final $Res Function(_SecureKeyIsolateResult<T>) _then;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,}) {
  return _then(_SecureKeyIsolateResult<T>(
null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as TransferrableSecureKeyFFI,
  ));
}

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransferrableSecureKeyFFICopyWith<$Res> get key {
  
  return $TransferrableSecureKeyFFICopyWith<$Res>(_self.key, (value) {
    return _then(_self.copyWith(key: value));
  });
}
}

/// @nodoc


class _KeyPairIsolateResult<T> extends IsolateResult<T> {
  const _KeyPairIsolateResult(this.keyPair): assert(T == KeyPair, 'Cannot return subclasses of KeyPair from an isolate. Use KeyPair as return type instead.'),super._();
  

 final  TransferrableKeyPairFFI keyPair;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KeyPairIsolateResultCopyWith<T, _KeyPairIsolateResult<T>> get copyWith => __$KeyPairIsolateResultCopyWithImpl<T, _KeyPairIsolateResult<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KeyPairIsolateResult<T>&&(identical(other.keyPair, keyPair) || other.keyPair == keyPair));
}


@override
int get hashCode => Object.hash(runtimeType,keyPair);

@override
String toString() {
  return 'IsolateResult<$T>.keyPair(keyPair: $keyPair)';
}


}

/// @nodoc
abstract mixin class _$KeyPairIsolateResultCopyWith<T,$Res> implements $IsolateResultCopyWith<T, $Res> {
  factory _$KeyPairIsolateResultCopyWith(_KeyPairIsolateResult<T> value, $Res Function(_KeyPairIsolateResult<T>) _then) = __$KeyPairIsolateResultCopyWithImpl;
@useResult
$Res call({
 TransferrableKeyPairFFI keyPair
});


$TransferrableKeyPairFFICopyWith<$Res> get keyPair;

}
/// @nodoc
class __$KeyPairIsolateResultCopyWithImpl<T,$Res>
    implements _$KeyPairIsolateResultCopyWith<T, $Res> {
  __$KeyPairIsolateResultCopyWithImpl(this._self, this._then);

  final _KeyPairIsolateResult<T> _self;
  final $Res Function(_KeyPairIsolateResult<T>) _then;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? keyPair = null,}) {
  return _then(_KeyPairIsolateResult<T>(
null == keyPair ? _self.keyPair : keyPair // ignore: cast_nullable_to_non_nullable
as TransferrableKeyPairFFI,
  ));
}

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransferrableKeyPairFFICopyWith<$Res> get keyPair {
  
  return $TransferrableKeyPairFFICopyWith<$Res>(_self.keyPair, (value) {
    return _then(_self.copyWith(keyPair: value));
  });
}
}

/// @nodoc


class _BytesIsolateResult<T> extends IsolateResult<T> {
  const _BytesIsolateResult(this.data): assert(T == Uint8List, 'Cannot return subclasses of Uint8List from an isolate. Use Uint8List as return type instead.'),super._();
  

 final  TransferableTypedData data;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BytesIsolateResultCopyWith<T, _BytesIsolateResult<T>> get copyWith => __$BytesIsolateResultCopyWithImpl<T, _BytesIsolateResult<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BytesIsolateResult<T>&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'IsolateResult<$T>.bytes(data: $data)';
}


}

/// @nodoc
abstract mixin class _$BytesIsolateResultCopyWith<T,$Res> implements $IsolateResultCopyWith<T, $Res> {
  factory _$BytesIsolateResultCopyWith(_BytesIsolateResult<T> value, $Res Function(_BytesIsolateResult<T>) _then) = __$BytesIsolateResultCopyWithImpl;
@useResult
$Res call({
 TransferableTypedData data
});




}
/// @nodoc
class __$BytesIsolateResultCopyWithImpl<T,$Res>
    implements _$BytesIsolateResultCopyWith<T, $Res> {
  __$BytesIsolateResultCopyWithImpl(this._self, this._then);

  final _BytesIsolateResult<T> _self;
  final $Res Function(_BytesIsolateResult<T>) _then;

/// Create a copy of IsolateResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_BytesIsolateResult<T>(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TransferableTypedData,
  ));
}


}

// dart format on
