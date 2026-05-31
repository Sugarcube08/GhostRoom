// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'secret_stream_push_transformer.dart';

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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Uninitialized<TState> value)?  uninitialized,TResult Function( _Initialized<TState> value)?  initialized,TResult Function( _Finalized<TState> value)?  finalized,TResult Function( _Closed<TState> value)?  closed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized(_that);case _Initialized() when initialized != null:
return initialized(_that);case _Finalized() when finalized != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Uninitialized<TState> value)  uninitialized,required TResult Function( _Initialized<TState> value)  initialized,required TResult Function( _Finalized<TState> value)  finalized,required TResult Function( _Closed<TState> value)  closed,}){
final _that = this;
switch (_that) {
case _Uninitialized():
return uninitialized(_that);case _Initialized():
return initialized(_that);case _Finalized():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Uninitialized<TState> value)?  uninitialized,TResult? Function( _Initialized<TState> value)?  initialized,TResult? Function( _Finalized<TState> value)?  finalized,TResult? Function( _Closed<TState> value)?  closed,}){
final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized(_that);case _Initialized() when initialized != null:
return initialized(_that);case _Finalized() when finalized != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  uninitialized,TResult Function( EventSink<SecretStreamCipherMessage> outSink,  TState cryptoState,  Uint8List? pendingHeader)?  initialized,TResult Function( EventSink<SecretStreamCipherMessage> outSink)?  finalized,TResult Function()?  closed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized();case _Initialized() when initialized != null:
return initialized(_that.outSink,_that.cryptoState,_that.pendingHeader);case _Finalized() when finalized != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  uninitialized,required TResult Function( EventSink<SecretStreamCipherMessage> outSink,  TState cryptoState,  Uint8List? pendingHeader)  initialized,required TResult Function( EventSink<SecretStreamCipherMessage> outSink)  finalized,required TResult Function()  closed,}) {final _that = this;
switch (_that) {
case _Uninitialized():
return uninitialized();case _Initialized():
return initialized(_that.outSink,_that.cryptoState,_that.pendingHeader);case _Finalized():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  uninitialized,TResult? Function( EventSink<SecretStreamCipherMessage> outSink,  TState cryptoState,  Uint8List? pendingHeader)?  initialized,TResult? Function( EventSink<SecretStreamCipherMessage> outSink)?  finalized,TResult? Function()?  closed,}) {final _that = this;
switch (_that) {
case _Uninitialized() when uninitialized != null:
return uninitialized();case _Initialized() when initialized != null:
return initialized(_that.outSink,_that.cryptoState,_that.pendingHeader);case _Finalized() when finalized != null:
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


class _Initialized<TState extends Object> implements _SinkState<TState> {
  const _Initialized(this.outSink, this.cryptoState, this.pendingHeader);
  

 final  EventSink<SecretStreamCipherMessage> outSink;
 final  TState cryptoState;
 final  Uint8List? pendingHeader;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InitializedCopyWith<TState, _Initialized<TState>> get copyWith => __$InitializedCopyWithImpl<TState, _Initialized<TState>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Initialized<TState>&&(identical(other.outSink, outSink) || other.outSink == outSink)&&const DeepCollectionEquality().equals(other.cryptoState, cryptoState)&&const DeepCollectionEquality().equals(other.pendingHeader, pendingHeader));
}


@override
int get hashCode => Object.hash(runtimeType,outSink,const DeepCollectionEquality().hash(cryptoState),const DeepCollectionEquality().hash(pendingHeader));

@override
String toString() {
  return '_SinkState<$TState>.initialized(outSink: $outSink, cryptoState: $cryptoState, pendingHeader: $pendingHeader)';
}


}

/// @nodoc
abstract mixin class _$InitializedCopyWith<TState extends Object,$Res> implements _$SinkStateCopyWith<TState, $Res> {
  factory _$InitializedCopyWith(_Initialized<TState> value, $Res Function(_Initialized<TState>) _then) = __$InitializedCopyWithImpl;
@useResult
$Res call({
 EventSink<SecretStreamCipherMessage> outSink, TState cryptoState, Uint8List? pendingHeader
});




}
/// @nodoc
class __$InitializedCopyWithImpl<TState extends Object,$Res>
    implements _$InitializedCopyWith<TState, $Res> {
  __$InitializedCopyWithImpl(this._self, this._then);

  final _Initialized<TState> _self;
  final $Res Function(_Initialized<TState>) _then;

/// Create a copy of _SinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? outSink = null,Object? cryptoState = null,Object? pendingHeader = freezed,}) {
  return _then(_Initialized<TState>(
null == outSink ? _self.outSink : outSink // ignore: cast_nullable_to_non_nullable
as EventSink<SecretStreamCipherMessage>,null == cryptoState ? _self.cryptoState : cryptoState // ignore: cast_nullable_to_non_nullable
as TState,freezed == pendingHeader ? _self.pendingHeader : pendingHeader // ignore: cast_nullable_to_non_nullable
as Uint8List?,
  ));
}


}

/// @nodoc


class _Finalized<TState extends Object> implements _SinkState<TState> {
  const _Finalized(this.outSink);
  

 final  EventSink<SecretStreamCipherMessage> outSink;

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
 EventSink<SecretStreamCipherMessage> outSink
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
as EventSink<SecretStreamCipherMessage>,
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
