import 'package:hive/hive.dart';

part 'conversation_state.g.dart';

@HiveType(typeId: 3)
enum ConversationMode {
  @HiveField(0)
  normal,
  @HiveField(1)
  ghost,
}

@HiveType(typeId: 4)
class ConversationState extends HiveObject {
  @HiveField(0)
  final String contactId;

  @HiveField(1)
  ConversationMode mode;

  @HiveField(2)
  String lastChangedBy;

  @HiveField(3)
  DateTime lastChangedAt;

  @HiveField(4)
  DateTime lastActivityAt;

  @HiveField(5)
  int? unreadCount;

  @HiveField(6)
  String? lastMessageId;

  ConversationState({
    required this.contactId,
    this.mode = ConversationMode.normal,
    required this.lastChangedBy,
    required this.lastChangedAt,
    required this.lastActivityAt,
    this.unreadCount = 0,
    this.lastMessageId,
  });

  int get effectiveUnreadCount => unreadCount ?? 0;
}
