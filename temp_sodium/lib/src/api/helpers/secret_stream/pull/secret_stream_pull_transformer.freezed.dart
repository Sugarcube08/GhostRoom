// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'secret_stream_pull_transformer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SinkState<TState extends Object> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SinkState<TState>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return '_SinkState<$TState>()';
}


}

/// @nodoc
class _$SinkStateCopyWith<TState extends Object,$Res>  {
_$SinkStateCopyWith(_SinkState<TState> _, $Res Function(_SinkState<TState>) __);
}


/// Adds pattern-matching-related methods to [_SinkState].
extension _SinkStatePatterns<TState extends Object> on _SinkState<TState> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Uninitialized<TState> value)?  uninitialized,TResult Function( _PreInit<TState> value)?  preInit,TResult Function( _PostInit<TState> value)?  postInit,TResult Function( _Finalized<TState> value)?  finalized,TResult Function( _Closed<TState> value)?  closed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized(_that);case _PreInit() when preInit != null:
return preInit(_that);case _PostInit() when postInit != null:
return postInit(_that);case _Finalized() when finalized != null:
return finalized(_that);case _Closed() when closed != null:
return closed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Uninitialized<TState> value)  uninitialized,required TResult Function( _PreInit<TState> value)  preInit,required TResult Function( _PostInit<TState> value)  postInit,required TResult Function( _Finalized<TState> value)  finalized,required TResult Function( _Closed<TState> value)  closed,}){
final _that = this;
switch (_that) {
case _Uninitialized():
return uninitialized(_that);case _PreInit():
return preInit(_that);case _PostInit():
return postInit(_that);case _Finalized():
return finalized(_that);case _Closed():
return closed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Uninitialized<TState> value)?  uninitialized,TResult? Function( _PreInit<TState> value)?  preInit,TResult? Function( _PostInit<TState> value)?  postInit,TResult? Function( _Finalized<TState> value)?  finalized,TResult? Function( _Closed<TState> value)?  closed,}){
final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized(_that);case _PreInit() when preInit != null:
return preInit(_that);case _PostInit() when postInit != null:
return postInit(_that);case _Finalized() when finalized != null:
return finalized(_that);case _Closed() when closed != null:
return closed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  uninitialized,TResult Function( EventSink<SecretStreamPlainMessage> outSink,  SecureKey key)?  preInit,TResult Function( EventSink<SecretStreamPlainMessage> outSink,  TState cryptoState)?  postInit,TResult Function( EventSink<SecretStreamPlainMessage> outSink)?  finalized,TResult Function()?  closed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized();case _PreInit() when preInit != null:
return preInit(_that.outSink,_that.key);case _PostInit() when postInit != null:
return postInit(_that.outSink,_that.cryptoState);case _Finalized() when finalized != null:
return finalized(_that.outSink);case _Closed() when closed != null:
return closed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  uninitialized,required TResult Function( EventSink<SecretStreamPlainMessage> outSink,  SecureKey key)  preInit,required TResult Function( EventSink<SecretStreamPlainMessage> outSink,  TState cryptoState)  postInit,required TResult Function( EventSink<SecretStreamPlainMessage> outSink)  finalized,required TResult Function()  closed,}) {final _that = this;
switch (_that) {
case _Uninitialized():
return uninitialized();case _PreInit():
return preInit(_that.outSink,_that.key);case _PostInit():
return postInit(_that.outSink,_that.cryptoState);case _Finalized():
return finalized(_that.outSink);case _Closed():
return closed();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  uninitialized,TResult? Function( EventSink<SecretStreamPlainMessage> outSink,  SecureKey key)?  preInit,TResult? Function( EventSink<SecretStreamPlainMessage> outSink,  TState cryptoState)?  postInit,TResult? Function( EventSink<SecretStreamPlainMessage> outSink)?  finalized,TResult? Function()?  closed,}) {final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized();case _PreInit() when preInit != null:
return preInit(_that.outSink,_that.key);case _PostInit() when postInit != null:
return postInit(_that.outSink,_that.cryptoState);case _Finalized() when finalized != null:
return finalized(_that.outSink);case _Closed() when closed != null:
return closed();case _:
  return null;

}
}

}

/// @nodoc


class _Uninitialized<TState extends Object> implements _SinkState<TState> {
  const _Uninitialized();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Uninitialized<TState>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return '_SinkState<$TState>.uninitialized()';
}


}




/// @nodoc


class _PreInit<TState extends Object> implements _SinkState<TState> {
  const _PreInit(this.outSink, this.key);
  

 final  EventSink<SecretStreamPlainMessage> outSink;
 final  SecureKey key;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreInitCopyWith<TState, _PreInit<TState>> get copyWith => __$PreInitCopyWithImpl<TState, _PreInit<TState>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PreInit<TState>&&(identical(other.outSink, outSink) || other.outSink == outSink)&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,outSink,key);

@override
String toString() {
  return '_SinkState<$TState>.preInit(outSink: $outSink, key: $key)';
}


}

/// @nodoc
abstract mixin class _$PreInitCopyWith<TState extends Object,$Res> implements _$SinkStateCopyWith<TState, $Res> {
  factory _$PreInitCopyWith(_PreInit<TState> value, $Res Function(_PreInit<TState>) _then) = __$PreInitCopyWithImpl;
@useResult
$Res call({
 EventSink<SecretStreamPlainMessage> outSink, SecureKey key
});




}
/// @nodoc
class __$PreInitCopyWithImpl<TState extends Object,$Res>
    implements _$PreInitCopyWith<TState, $Res> {
  __$PreInitCopyWithImpl(this._self, this._then);

  final _PreInit<TState> _self;
  final $Res Function(_PreInit<TState>) _then;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? outSink = null,Object? key = null,}) {
  return _then(_PreInit<TState>(
null == outSink ? _self.outSink : outSink // ignore: cast_nullable_to_non_nullable
as EventSink<SecretStreamPlainMessage>,null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as SecureKey,
  ));
}


}

/// @nodoc


class _PostInit<TState extends Object> implements _SinkState<TState> {
  const _PostInit(this.outSink, this.cryptoState);
  

 final  EventSink<SecretStreamPlainMessage> outSink;
 final  TState cryptoState;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostInitCopyWith<TState, _PostInit<TState>> get copyWith => __$PostInitCopyWithImpl<TState, _PostInit<TState>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostInit<TState>&&(identical(other.outSink, outSink) || other.outSink == outSink)&&const DeepCollectionEquality().equals(other.cryptoState, cryptoState));
}


@override
int get hashCode => Object.hash(runtimeType,outSink,const DeepCollectionEquality().hash(cryptoState));

@override
String toString() {
  return '_SinkState<$TState>.postInit(outSink: $outSink, cryptoState: $cryptoState)';
}


}

/// @nodoc
abstract mixin class _$PostInitCopyWith<TState extends Object,$Res> implements _$SinkStateCopyWith<TState, $Res> {
  factory _$PostInitCopyWith(_PostInit<TState> value, $Res Function(_PostInit<TState>) _then) = __$PostInitCopyWithImpl;
@useResult
$Res call({
 EventSink<SecretStreamPlainMessage> outSink, TState cryptoState
});




}
/// @nodoc
class __$PostInitCopyWithImpl<TState extends Object,$Res>
    implements _$PostInitCopyWith<TState, $Res> {
  __$PostInitCopyWithImpl(this._self, this._then);

  final _PostInit<TState> _self;
  final $Res Function(_PostInit<TState>) _then;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? outSink = null,Object? cryptoState = null,}) {
  return _then(_PostInit<TState>(
null == outSink ? _self.outSink : outSink // ignore: cast_nullable_to_non_nullable
as EventSink<SecretStreamPlainMessage>,null == cryptoState ? _self.cryptoState : cryptoState // ignore: cast_nullable_to_non_nullable
as TState,
  ));
}


}

/// @nodoc


class _Finalized<TState extends Object> implements _SinkState<TState> {
  const _Finalized(this.outSink);
  

 final  EventSink<SecretStreamPlainMessage> outSink;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FinalizedCopyWith<TState, _Finalized<TState>> get copyWith => __$FinalizedCopyWithImpl<TState, _Finalized<TState>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Finalized<TState>&&(identical(other.outSink, outSink) || other.outSink == outSink));
}


@override
int get hashCode => Object.hash(runtimeType,outSink);

@override
String toString() {
  return '_SinkState<$TState>.finalized(outSink: $outSink)';
}


}

/// @nodoc
abstract mixin class _$FinalizedCopyWith<TState extends Object,$Res> implements _$SinkStateCopyWith<TState, $Res> {
  factory _$FinalizedCopyWith(_Finalized<TState> value, $Res Function(_Finalized<TState>) _then) = __$FinalizedCopyWithImpl;
@useResult
$Res call({
 EventSink<SecretStreamPlainMessage> outSink
});




}
/// @nodoc
class __$FinalizedCopyWithImpl<TState extends Object,$Res>
    implements _$FinalizedCopyWith<TState, $Res> {
  __$FinalizedCopyWithImpl(this._self, this._then);

  final _Finalized<TState> _self;
  final $Res Function(_Finalized<TState>) _then;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? outSink = null,}) {
  return _then(_Finalized<TState>(
null == outSink ? _self.outSink : outSink // ignore: cast_nullable_to_non_nullable
as EventSink<SecretStreamPlainMessage>,
  ));
}


}

/// @nodoc


class _Closed<TState extends Object> implements _SinkState<TState> {
  const _Closed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Closed<TState>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return '_SinkState<$TState>.closed()';
}


}




// dart format on
