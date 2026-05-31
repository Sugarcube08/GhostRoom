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
}

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id; // UUID v7

  @HiveField(1)
  final String senderId; // Public ID

  @HiveField(2)
  final String recipientId; // Public ID (Me)

  @HiveField(3)
  final String plaintext;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  bool isRead;

  @HiveField(6)
  final MessageType type;

  @HiveField(7)
  final Map<String, dynamic>? metadata; // For media URLs, sizes, etc.

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.plaintext,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.metadata,
  });
}
