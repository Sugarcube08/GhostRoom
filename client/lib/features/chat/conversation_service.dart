import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'message.dart';
import 'chat_repository.dart';
import '../contacts/contact_resolver.dart';
import '../contacts/contact_service.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';
import 'conversation_state.dart';
import '../media/media_service.dart';

class Conversation {
  final Contact? contact;
  final String contactId;
  final String alias;
  final List<Message> messages;
  final Message? lastMessage;
  final int unreadCount;
  final ConversationMode mode;
  final DateTime lastActivityAt;

  Conversation({
    this.contact,
    required this.contactId,
    required this.alias,
    required this.messages,
    this.lastMessage,
    this.unreadCount = 0,
    this.mode = ConversationMode.normal,
    required this.lastActivityAt,
  });
}

class ConversationService {
  final ChatRepository _chatRepository;
  final ContactResolver _contactResolver;
  final ContactService _contactService;
  final IdentityService _idService;
  final MediaService _mediaService;

  ConversationService(
    this._chatRepository,
    this._contactResolver,
    this._contactService,
    this._idService,
    this._mediaService,
  );

  List<Conversation> getConversations() {
    final Map<String, Message> lastMessages = {};
    final Map<String, int> unreadCounts = {};
    final Map<String, DateTime> lastActivities = {};

    final myId = _chatRepository.myPublicId;
    final knownContactIds = _contactService.getAllContacts().map((c) => c.publicId).toSet();

    for (final state in _chatRepository.getAllConversationStates()) {
      lastActivities[state.contactId] = state.lastActivityAt;
      unreadCounts[state.contactId] = state.effectiveUnreadCount;
      if (state.lastMessageId != null) {
        final msg = _chatRepository.getMessage(state.lastMessageId!);
        if (msg != null) {
          final isUnknownSender = !knownContactIds.contains(state.contactId) && state.contactId != myId;
          if (msg.isRequest || isUnknownSender) {
            // This belongs to requests, skip for main list
            continue;
          }
          lastMessages[state.contactId] = msg;
        }
      }
    }

    final Set<String> validContactIds = {};
    validContactIds.addAll(lastMessages.keys);
    validContactIds.addAll(knownContactIds);

    return validContactIds.map((contactId) {
      final lastMsg = lastMessages[contactId];
      final activity = lastActivities[contactId] ?? DateTime(0);

      return Conversation(
        contact: _contactResolver.resolveContact(contactId),
        contactId: contactId,
        alias: _contactResolver.resolveAlias(contactId),
        messages: [],
        lastMessage: lastMsg,
        unreadCount: unreadCounts[contactId] ?? 0,
        mode: getConversationMode(contactId),
        lastActivityAt: activity,
      );
    }).toList()..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
  }

  List<Conversation> getRequests() {
    final Map<String, Message> lastMessages = {};
    final Map<String, int> unreadCounts = {};
    final myId = _chatRepository.myPublicId;
    final knownContactIds = _contactService.getAllContacts().map((c) => c.publicId).toSet();

    for (final state in _chatRepository.getAllConversationStates()) {
      unreadCounts[state.contactId] = state.effectiveUnreadCount;
      if (state.lastMessageId != null) {
        final msg = _chatRepository.getMessage(state.lastMessageId!);
        if (msg != null) {
          final isUnknownSender = !knownContactIds.contains(state.contactId) && state.contactId != myId;
          if (msg.isRequest || isUnknownSender) {
            lastMessages[state.contactId] = msg;
          }
        }
      }
    }

    if (lastMessages.isNotEmpty) {
    }

    return lastMessages.entries.map((entry) {
      final contactId = entry.key;

      return Conversation(
        contact: null,
        contactId: contactId,
        alias: _contactResolver.resolveAlias(contactId),
        messages: [],
        lastMessage: entry.value,
        unreadCount: unreadCounts[contactId] ?? 0,
        lastActivityAt: entry.value.timestamp,
        mode: ConversationMode.normal,
      );
    }).toList()..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
  }

  Future<void> acceptRequest(String publicId) async {
    final msgs = _chatRepository
        .getMessagesForContact(publicId, limit: 1000)
        .where((m) => m.senderId == publicId && m.isRequest)
        .toList();
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
    final msgs = _chatRepository
        .getMessagesForContact(publicId, limit: 1000)
        .where((m) => m.senderId == publicId && m.isRequest)
        .toList();
    for (final msg in msgs) {
      await msg.delete();
    }
  }

  Future<void> blockRequest(String publicId) async {
    await rejectRequest(publicId);
    await _contactService.blockIdentity(publicId);
  }

  Future<void> sendMessage(String recipientId, String text) async {
    final mode = getConversationMode(recipientId);
    final isGhost = mode == ConversationMode.ghost;
    await _chatRepository.sendMessage(
      recipientId: recipientId,
      text: text,
      retention: isGhost ? 'EPHEMERAL' : 'PERSISTENT',
      metadata: {'is_ghost': isGhost},
    );
  }

  Future<void> sendImage(String recipientId, File file) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');

    final mode = getConversationMode(recipientId);
    final isGhost = mode == ConversationMode.ghost;

    // 1. Create Placeholder
    final placeholderId = const Uuid().v7();
    

    final placeholder = Message(
      id: placeholderId,
      senderId: _chatRepository.myPublicId,
      recipientId: recipientId,
      plaintext: '[Image]',
      timestamp: DateTime.now(),
      type: MessageType.image,
      metadata: {
        'status': 'COMPRESSING',
        'is_ghost': isGhost,
        'size': file.lengthSync(),
      },
    );
    await _chatRepository.saveMessage(placeholder);

    try {
      // 2. Compress
      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'COMPRESSING',
      });
      final compressed = await _mediaService.compressImage(file);

      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'UPLOADING',
      });

      // 3. Queue Media Send
      await _chatRepository.queueMediaSend(
        messageId: placeholderId,
        recipientId: recipientId,
        text: '[Image]',
        type: MessageType.image,
        file: compressed,
        retention: isGhost ? 'EPHEMERAL' : 'PERSISTENT',
        metadata: {
          'is_ghost': isGhost,
          'size': compressed.lengthSync(),
        },
      );
    } catch (e) {
      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'FAILED',
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<void> sendVideo(String recipientId, File file) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');

    final mode = getConversationMode(recipientId);
    final isGhost = mode == ConversationMode.ghost;

    // 1. Create Placeholder
    final placeholderId = const Uuid().v7();


    final placeholder = Message(
      id: placeholderId,
      senderId: _chatRepository.myPublicId,
      recipientId: recipientId,
      plaintext: '[Video]',
      timestamp: DateTime.now(),
      type: MessageType.video,
      metadata: {
        'status': 'COMPRESSING',
        'is_ghost': isGhost,
        'size': file.lengthSync(),
      },
    );
    await _chatRepository.saveMessage(placeholder);

    try {
      // 2. Compress
      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'COMPRESSING',
      });
      final compressed = await _mediaService.compressVideo(file);

      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'UPLOADING',
      });

      // 3. Queue Media Send
      await _chatRepository.queueMediaSend(
        messageId: placeholderId,
        recipientId: recipientId,
        text: '[Video]',
        type: MessageType.video,
        file: compressed,
        retention: isGhost ? 'EPHEMERAL' : 'PERSISTENT',
        metadata: {
          'is_ghost': isGhost,
          'size': compressed.lengthSync(),
        },
      );
    } catch (e) {
      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'FAILED',
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<void> sendVoiceNote(
    String recipientId,
    File file, {
    int durationMs = 0,
  }) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');

    final mode = getConversationMode(recipientId);
    final isGhost = mode == ConversationMode.ghost;

    // 1. Create Placeholder
    final placeholderId = const Uuid().v7();
    final placeholder = Message(
      id: placeholderId,
      senderId: _chatRepository.myPublicId,
      recipientId: recipientId,
      plaintext: '[Voice Note]',
      timestamp: DateTime.now(),
      type: MessageType.voice,
      metadata: {
        'status': 'UPLOADING',
        'is_ghost': isGhost,
        'size': file.lengthSync(),
        'duration_ms': durationMs,
      },
    );
    await _chatRepository.saveMessage(placeholder);

    try {
      // 2. Queue Media Send
      await _chatRepository.queueMediaSend(
        messageId: placeholderId,
        recipientId: recipientId,
        text: '[Voice Note]',
        type: MessageType.voice,
        file: file,
        retention: isGhost ? 'EPHEMERAL' : 'PERSISTENT',
        metadata: {
          'is_ghost': isGhost,
          'size': file.lengthSync(),
          'duration_ms': durationMs,
        },
      );
    } catch (e) {
      await _chatRepository.updateMessageMetadata(placeholderId, {
        'status': 'FAILED',
        'error': e.toString(),
      });
      rethrow;
    }
  }

  ConversationMode getConversationMode(String contactId) {
    final state = Hive.box<ConversationState>(
      'conversation_states',
    ).get(contactId);
    if (state == null) return ConversationMode.normal;

    // Check for 18-hour inactivity reset
    final inactivity = DateTime.now().difference(state.lastActivityAt);
    if (inactivity.inHours >= 18 && state.mode != ConversationMode.normal) {
      state.mode = ConversationMode.normal;
      state.lastChangedBy = 'system';
      state.lastChangedAt = DateTime.now();
      state.save();
    }

    return state.mode;
  }

  Future<void> setConversationMode(
    String contactId,
    ConversationMode mode,
  ) async {
    await _chatRepository.updateConversationMode(contactId, mode);
  }

  Future<void> markAsRead(String contactId) async {
    await _chatRepository.markConversationAsRead(contactId);

    // Also mark individual messages as read for local UI consistency
    final messages = _chatRepository.getMessagesForContact(
      contactId,
      limit: 100,
    );
    for (final msg in messages) {
      if (!msg.isRead && msg.senderId == contactId) {
        msg.isRead = true;
        await msg.save();
      }
    }
  }
}
