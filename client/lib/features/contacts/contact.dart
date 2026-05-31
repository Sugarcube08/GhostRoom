import 'package:hive/hive.dart';

part 'contact.g.dart';

@HiveType(typeId: 0)
class Contact extends HiveObject {
  @HiveField(0)
  final String publicId;

  @HiveField(1)
  String alias;

  @HiveField(2)
  String? notes;

  @HiveField(3)
  final String eid; // Ed25519 Public Key (Base64)

  @HiveField(4)
  final String xid; // X25519 Public Key (Base64)

  @HiveField(5)
  final String fingerprint; // Visual hash / Safety number

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  String? preferredRelay;

  Contact({
    required this.publicId,
    required this.alias,
    this.notes,
    required this.eid,
    required this.xid,
    required this.fingerprint,
    required this.createdAt,
    this.preferredRelay,
  });
}
