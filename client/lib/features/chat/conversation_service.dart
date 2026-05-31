import 'message.dart';
import 'chat_repository.dart';
import '../contacts/contact_resolver.dart';
import '../contacts/contact.dart';

class Conversation {
  final Contact? contact;
  final String contactId;
  final String alias;
  final List<Message> messages;
  final Message? lastMessage;
  final int unreadCount;

  Conversation({
    this.contact,
    required this.contactId,
    required this.alias,
    required this.messages,
    this.lastMessage,
    this.unreadCount = 0,
  });
}

class ConversationService {
  final ChatRepository _chatRepository;
  final ContactResolver _contactResolver;

  ConversationService(this._chatRepository, this._contactResolver);

  List<Conversation> getConversations() {
    final Map<String, List<Message>> grouped = {};
    for (final msg in _chatRepository.getAllMessages()) {
      final otherId = msg.senderId == _chatRepository.myPublicId ? msg.recipientId : msg.senderId;
      grouped.putIfAbsent(otherId, () => []).add(msg);
    }

    return grouped.entries.map((entry) {
      final contactId = entry.key;
      final messages = entry.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final unreadCount = messages.where((m) => !m.isRead && m.senderId == contactId).length;
      
      return Conversation(
        contact: _contactResolver.resolveContact(contactId),
        contactId: contactId,
        alias: _contactResolver.resolveAlias(contactId),
        messages: messages,
        lastMessage: messages.isNotEmpty ? messages.last : null,
        unreadCount: unreadCount,
      );
    }).toList()..sort((a, b) => (b.lastMessage?.timestamp ?? DateTime(0)).compareTo(a.lastMessage?.timestamp ?? DateTime(0)));
  }

  Future<void> sendMessage(String recipientId, String text) async {
    await _chatRepository.sendMessage(recipientId: recipientId, text: text);
  }

  Future<void> markAsRead(String contactId) async {
    final messages = _chatRepository.getMessagesForContact(contactId);
    for (final msg in messages) {
      if (!msg.isRead && msg.senderId == contactId) {
        msg.isRead = true;
        await msg.save();
      }
    }
  }
}
