import 'dart:convert';
import 'dart:io';
import 'message.dart';
import 'chat_repository.dart';
import '../contacts/contact_resolver.dart';
import '../contacts/contact_service.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';
import '../../core/network/relay_manager.dart';
import '../media/media_service.dart';
import '../media/attachment_envelope.dart';

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
  final MediaService _mediaService;
  final RelayManager _relayManager;

  ConversationService(
    this._chatRepository, 
    this._contactResolver,
    this._contactService,
    this._idService,
    this._mediaService,
    this._relayManager,
  );

  List<Conversation> getConversations() {
    final Map<String, Message> lastMessages = {};
    final Map<String, int> unreadCounts = {};
    
    final myId = _chatRepository.myPublicId;

    for (final msg in _chatRepository.getAllMessages()) {
      if (msg.isRequest) continue;
      
      final otherId = msg.senderId == myId ? msg.recipientId : msg.senderId;
      
      // Update last message
      final existingLast = lastMessages[otherId];
      if (existingLast == null || msg.timestamp.isAfter(existingLast.timestamp)) {
        lastMessages[otherId] = msg;
      }

      // Update unread count
      if (!msg.isRead && msg.senderId == otherId) {
        unreadCounts[otherId] = (unreadCounts[otherId] ?? 0) + 1;
      }
    }

    return lastMessages.entries.map((entry) {
      final contactId = entry.key;
      final lastMsg = entry.value;
      
      return Conversation(
        contact: _contactResolver.resolveContact(contactId),
        contactId: contactId,
        alias: _contactResolver.resolveAlias(contactId),
        messages: [], // Don't load all messages here!
        lastMessage: lastMsg,
        unreadCount: unreadCounts[contactId] ?? 0,
      );
    }).toList()..sort((a, b) => (b.lastMessage?.timestamp ?? DateTime(0)).compareTo(a.lastMessage?.timestamp ?? DateTime(0)));
  }

  List<Conversation> getRequests() {
    final Map<String, Message> lastMessages = {};
    final Map<String, int> counts = {};
    final myId = _chatRepository.myPublicId;

    for (final msg in _chatRepository.getAllMessages()) {
      if (!msg.isRequest) continue;
      
      final otherId = msg.senderId == myId ? msg.recipientId : msg.senderId;
      
      final existingLast = lastMessages[otherId];
      if (existingLast == null || msg.timestamp.isAfter(existingLast.timestamp)) {
        lastMessages[otherId] = msg;
      }
      counts[otherId] = (counts[otherId] ?? 0) + 1;
    }

    return lastMessages.entries.map((entry) {
      final contactId = entry.key;
      
      return Conversation(
        contact: null,
        contactId: contactId,
        alias: _contactResolver.resolveAlias(contactId),
        messages: [], 
        lastMessage: entry.value,
        unreadCount: counts[contactId] ?? 0, 
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

  Future<void> sendMessage(String recipientId, String text, {String retention = 'PERSISTENT'}) async {
    await _chatRepository.sendMessage(recipientId: recipientId, text: text, retention: retention);
  }

  Future<void> sendImage(String recipientId, File file, {String retention = 'PERSISTENT'}) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');

    final activeRelay = await _relayManager.getActiveRelay();
    if (activeRelay == null) throw Exception('No active relay');

    final compressed = await _mediaService.compressImage(file);

    final envelope = await _mediaService.uploadMedia(
      file: compressed,
      kind: AttachmentKind.image,
      relay: activeRelay,
      recipientXid: base64Decode(contact.xid),
    );

    await _chatRepository.sendMessage(
      recipientId: recipientId,
      text: '[Image]',
      type: MessageType.image,
      retention: retention,
      metadata: envelope.toJson(),
    );
  }

  Future<void> sendVideo(String recipientId, File file, {String retention = 'PERSISTENT'}) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');

    final activeRelay = await _relayManager.getActiveRelay();
    if (activeRelay == null) throw Exception('No active relay');

    // 1. Compress
    final compressed = await _mediaService.compressVideo(file);

    // 2. Upload
    final envelope = await _mediaService.uploadMedia(
      file: compressed,
      kind: AttachmentKind.video,
      relay: activeRelay,
      recipientXid: base64Decode(contact.xid),
    );

    // 3. Send Message
    await _chatRepository.sendMessage(
      recipientId: recipientId,
      text: '[Video]',
      type: MessageType.video,
      retention: retention,
      metadata: envelope.toJson(),
    );
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
