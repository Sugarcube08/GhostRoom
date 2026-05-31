import 'package:hive/hive.dart';

part 'message.g.dart';

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

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.plaintext,
    required this.timestamp,
    this.isRead = false,
  });
}
