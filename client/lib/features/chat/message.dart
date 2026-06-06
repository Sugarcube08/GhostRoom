import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 2) // Changed typeId because of schema change
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  file,
  @HiveField(4)
  system,
  @HiveField(5)
  voice,
}

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String recipientId;

  @HiveField(3)
  final String plaintext;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  bool isRead;

  @HiveField(6)
  final MessageType type;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  @HiveField(8)
  bool isRequest;

  @HiveField(9)
  final String? groupId;

  @HiveField(10)
  DateTime? deliveredAt;

  @HiveField(11)
  DateTime? seenAt;

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.plaintext,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.metadata,
    this.isRequest = false,
    this.groupId,
    this.deliveredAt,
    this.seenAt,
  });
}

