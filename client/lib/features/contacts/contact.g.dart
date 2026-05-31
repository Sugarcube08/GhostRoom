// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactAdapter extends TypeAdapter<Contact> {
  @override
  final int typeId = 0;

  @override
  Contact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contact(
      publicId: fields[0] as String,
      alias: fields[1] as String,
      notes: fields[2] as String?,
      eid: fields[3] as String,
      xid: fields[4] as String,
      fingerprint: fields[5] as String,
      createdAt: fields[6] as DateTime,
      preferredRelay: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Contact obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.publicId)
      ..writeByte(1)
      ..write(obj.alias)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.eid)
      ..writeByte(4)
      ..write(obj.xid)
      ..writeByte(5)
      ..write(obj.fingerprint)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.preferredRelay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
