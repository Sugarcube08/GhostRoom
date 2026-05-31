import 'dart:convert';
import 'message.dart';
import 'chat_repository.dart';
import '../contacts/contact_resolver.dart';
import '../contacts/contact_service.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';

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
  final ContactService _contactService;
  final IdentityService _idService;

  ConversationService(
    this._chatRepository, 
    this._contactResolver,
    this._contactService,
    this._idService,
  );

  List<Conversation> getConversations() {
    final Map<String, List<Message>> grouped = {};
    for (final msg in _chatRepository.getAllMessages().where((m) => !m.isRequest)) {
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

  List<Conversation> getRequests() {
    final Map<String, List<Message>> grouped = {};
    for (final msg in _chatRepository.getAllMessages().where((m) => m.isRequest)) {
      final otherId = msg.senderId == _chatRepository.myPublicId ? msg.recipientId : msg.senderId;
      grouped.putIfAbsent(otherId, () => []).add(msg);
    }

    return grouped.entries.map((entry) {
      final contactId = entry.key;
      final messages = entry.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return Conversation(
        contact: null,
        contactId: contactId,
        alias: _contactResolver.resolveAlias(contactId),
        messages: messages,
        lastMessage: messages.isNotEmpty ? messages.last : null,
        unreadCount: messages.length, 
      );
    }).toList()..sort((a, b) => (b.lastMessage?.timestamp ?? DateTime(0)).compareTo(a.lastMessage?.timestamp ?? DateTime(0)));
  }

  Future<void> acceptRequest(String publicId) async {
    final msgs = _chatRepository.getAllMessages().where((m) => m.senderId == publicId && m.isRequest).toList();
    if (msgs.isEmpty) return;

    final firstMsg = msgs.first;
    final senderEid = firstMsg.metadata?['sender_eid'] as String?;
    final senderXid = firstMsg.metadata?['sender_xid'] as String?;

    if (senderEid != null && senderXid != null) {
      final fingerprint = _idService.calculateFingerprint(
        base64Decode(senderEid), 
        base64Decode(senderXid),
      );

      final newContact = Contact(
        publicId: publicId,
        alias: 'New Contact',
        eid: senderEid,
        xid: senderXid,
        fingerprint: fingerprint,
        createdAt: DateTime.now(),
      );
      
      await _contactService.saveContact(newContact);

      // Convert request messages to regular messages
      for (final msg in msgs) {
        msg.isRequest = false;
        await msg.save();
      }
    }
  }

  Future<void> rejectRequest(String publicId) async {
    final msgs = _chatRepository.getAllMessages().where((m) => m.senderId == publicId && m.isRequest).toList();
    for (final msg in msgs) {
      await msg.delete();
    }
  }

  Future<void> blockRequest(String publicId) async {
    await rejectRequest(publicId);
    await _contactService.blockIdentity(publicId);
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
