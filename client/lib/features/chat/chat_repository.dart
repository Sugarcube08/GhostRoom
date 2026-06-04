import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:sodium/sodium_sumo.dart' hide Box;
import 'message.dart';
import 'dm_service.dart';
import 'conversation_state.dart';
import '../../core/crypto/identity_service.dart';
import '../../core/network/websocket_service.dart';
import '../../core/notification_service.dart';
import '../contacts/contact_service.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import '../media/media_manager.dart';
import '../../core/stability_tracker.dart';

class ChatRepository {
  final IdentityService _idService;
  final DMService _dmService;
  final ContactService _contactService;
  final WebSocketService _wsService;
  final NotificationService _notificationService;
  final MediaManager _mediaManager;
  String? _activeConversationId;
  final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.info,
    printer: PrettyPrinter(
      methodCount: 0, 
      errorMethodCount: 5, 
      lineLength: 50, 
      colors: true, 
      printEmojis: true, 
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static const String _msgBoxName = 'messages';
  static const String _syncBoxName = 'sync_metadata';
  static const String _processedBoxName = 'processed_envelopes';
  static const String _thumbCacheName = 'thumbnail_cache';
  static const String _lastSyncKey = 'last_sync_t';

  ChatRepository(
    this._idService, 
    this._dmService, 
    this._contactService, 
    this._wsService,
    this._notificationService,
    this._mediaManager,
  );

  String get myPublicId => _idService.currentIdentity?.publicId ?? '';
  MediaManager get mediaManager => _mediaManager;

  void setActiveConversation(String? contactId) {
    _activeConversationId = contactId;
    if (contactId != null) {
      // Immediate sync to prevent drift
      markConversationAsRead(contactId);
    }
  }

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    StabilityTracker.logMemory('ChatRepo_Init_Start');
    if (!Hive.isAdapterRegistered(MessageTypeAdapter().typeId)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(MessageAdapter().typeId)) {
      Hive.registerAdapter(MessageAdapter());
    }
    if (!Hive.isAdapterRegistered(ConversationModeAdapter().typeId)) {
      Hive.registerAdapter(ConversationModeAdapter());
    }
    if (!Hive.isAdapterRegistered(ConversationStateAdapter().typeId)) {
      Hive.registerAdapter(ConversationStateAdapter());
    }
    
    if (!Hive.isBoxOpen(_msgBoxName)) {
      await Hive.openBox<Message>(_msgBoxName);
      StabilityTracker.logResource('HiveBox', 'Opened_$_msgBoxName');
    }
    if (!Hive.isBoxOpen('conversation_states')) {
      await Hive.openBox<ConversationState>('conversation_states');
      StabilityTracker.logResource('HiveBox', 'Opened_conversation_states');
    }
    if (!Hive.isBoxOpen(_syncBoxName)) {
      await Hive.openBox(_syncBoxName);
      StabilityTracker.logResource('HiveBox', 'Opened_$_syncBoxName');
    }
    if (!Hive.isBoxOpen(_processedBoxName)) {
      await Hive.openBox(_processedBoxName);
      StabilityTracker.logResource('HiveBox', 'Opened_$_processedBoxName');
    }

    // Register WebSocket Callbacks
    _wsService.onIdentityVerified(_handleIdentityVerified);
    _wsService.onMessage(_handleNewMessage);
    _wsService.onInboxMessages(_handleInboxMessages);
    
    // Global Cleanup
    await flushAllGhosts();

    _logger.i('GHOST_LOG: ChatRepository initialized and listeners registered.');
    StabilityTracker.logMemory('ChatRepo_Init_End');
  }

  void _handleIdentityVerified(dynamic data) {
    _logger.i('GHOST_LOG: Identity verified. Triggering inbox sync...');
    _wsService.fetchInbox(since: lastSyncTimestamp);
  }

  void _handleNewMessage(dynamic data) {
    _logger.i('GHOST_LOG: Real-time message received via WebSocket.');
    processEnvelopes([data]);
  }

  void _handleInboxMessages(List<dynamic> messages) {
    _logger.i('GHOST_LOG: Inbox batch received. Count: ${messages.length}');
    processEnvelopes(messages);
  }

  Box<Message>? get _msgBox {
    if (!Hive.isBoxOpen(_msgBoxName)) return null;
    return Hive.box<Message>(_msgBoxName);
  }
  Box<ConversationState>? get _stateBox {
    if (!Hive.isBoxOpen('conversation_states')) return null;
    return Hive.box<ConversationState>('conversation_states');
  }
  Box? get _syncBox {
    if (!Hive.isBoxOpen(_syncBoxName)) return null;
    return Hive.box(_syncBoxName);
  }
  Box? get _processedBox {
    if (!Hive.isBoxOpen(_processedBoxName)) return null;
    return Hive.box(_processedBoxName);
  }
  Box<Uint8List>? get _thumbBox {
    if (!Hive.isBoxOpen(_thumbCacheName)) return null;
    return Hive.box<Uint8List>(_thumbCacheName);
  }

  Uint8List? getCachedThumbnail(String mediaId) => _thumbBox?.get(mediaId);
  Future<void> cacheThumbnail(String mediaId, Uint8List data) async => _thumbBox?.put(mediaId, data);

  int get lastSyncTimestamp => _syncBox?.get(_lastSyncKey, defaultValue: 0) ?? 0;
  
  bool isProcessed(String id) => _processedBox?.containsKey(id) ?? false;

  Future<void> _markProcessed(String id, int timestamp) async {
    await _processedBox?.put(id, true);
    
    if (timestamp > lastSyncTimestamp) {
      await _syncBox?.put(_lastSyncKey, timestamp);
    }
  }

  Future<void> processEnvelopes(List<dynamic> envelopes) async {
    for (final data in envelopes) {
      try {
        final envelope = DMEnvelope.fromJson(data);
        _logger.i('GHOST_LOG: MESSAGE_RECEIVED id: ${envelope.id}');
        
        if (isProcessed(envelope.id)) {
          _wsService.acknowledgeMessage(envelope.id);
          continue;
        }

        final identity = _idService.currentIdentity;
        if (identity == null) continue;

        String plaintext;
        Uint8List senderEid;

        _logger.i('GHOST_LOG: DECRYPT_START');
        _logger.i("MESSAGE_DECRYPT_START");
        // Try Signature-First (Known Contacts)
        final knownEid = _getSenderEid(envelope);
        if (knownEid != null) {
          plaintext = _dmService.decryptDM(
            envelope: envelope,
            myPublicId: identity.publicId,
            myXidKeyPair: identity.x25519KeyPair,
            senderEid: knownEid,
          );
          senderEid = knownEid;
        } else {
          // Fallback: Decrypt-First (Unknown Senders)
          final messageKeyBytes = _idService.sodium.crypto.box.sealOpen(
            cipherText: base64Decode(envelope.encryptedKey),
            publicKey: identity.x25519KeyPair.publicKey,
            secretKey: identity.x25519KeyPair.secretKey,
          );
          final messageKey = SecureKey.fromList(_idService.sodium, messageKeyBytes);

          final plaintextBytes = _idService.sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
            cipherText: base64Decode(envelope.ciphertext),
            nonce: base64Decode(envelope.nonce),
            key: messageKey,
          );
          
          plaintext = utf8.decode(plaintextBytes);
          final payload = jsonDecode(plaintext);
          final senderEidBase64 = payload['sender_eid'] as String;
          senderEid = base64Decode(senderEidBase64);
          
          // Verify Signature after decryption
          final signMaterial = utf8.encode(
            '${envelope.version}${envelope.id}${envelope.timestamp}${identity.publicId}${envelope.encryptedKey}${envelope.nonce}${envelope.ciphertext}'
          );
          
          final isSignatureValid = _idService.sodium.crypto.sign.verifyDetached(
            message: signMaterial,
            signature: base64Decode(envelope.signature),
            publicKey: senderEid,
          );

          if (!isSignatureValid) {
            throw Exception('Cryptographic signature verification failed');
          }
        }
        _logger.i('GHOST_LOG: DECRYPT_SUCCESS');
        _logger.i("MESSAGE_DECRYPT_SUCCESS");
        _logger.i("MESSAGE_DECRYPTED");
        
        final payload = jsonDecode(plaintext);
        final senderId = _idService.derivePublicId(senderEid);
        final actualTimestamp = envelope.timestamp;
        final type = _mapType(payload['type']);

        if (type == MessageType.image || type == MessageType.video) {
          _logger.i('GHOST_LOG: MEDIA_RECEIVED id: ${envelope.id}');
        }

        // TRUST LAYER ENFORCEMENT
        final isKnownContact = _contactService.getContact(senderId) != null;
        final isBlocked = _contactService.isBlocked(senderId);

        if (isBlocked) {
          _logger.i('Auto-rejected message from blocked sender: $senderId');
          _wsService.acknowledgeMessage(envelope.id);
          continue;
        }

        bool isRequest = false;
        if (!isKnownContact) {
          if (type != MessageType.text) {
            _logger.w('Dropped media attachment from unknown sender: $senderId');
            _wsService.acknowledgeMessage(envelope.id);
            continue;
          }
          isRequest = true;
        }

        final message = Message(
          id: envelope.id,
          senderId: senderId,
          recipientId: identity.publicId,
          plaintext: payload['text'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(actualTimestamp),
          type: type,
          metadata: {
            ...?payload['metadata'],
            'sender_eid': base64Encode(senderEid),
            'sender_xid': payload['sender_xid'],
          },
          isRequest: isRequest,
          groupId: data['group_id'] as String?,
        );

        // HANDLE SYSTEM MESSAGES
        if (type == MessageType.system) {
          final systemType = payload['metadata']?['system_type'];
          if (systemType == 'receipt') {
            final targetId = payload['metadata']?['target_id'];
            if (targetId != null) {
              final targetMsg = _msgBox?.get(targetId);
              if (targetMsg != null) {
                targetMsg.metadata?['consumed'] = true;
                await targetMsg.save();
                _logger.i('Message $targetId marked as consumed by receipt.');
              }
            }
          } else if (systemType == 'mode_change') {
            final modeIndex = payload['metadata']?['mode'] as int?;
            if (modeIndex != null && modeIndex < ConversationMode.values.length) {
              final newMode = ConversationMode.values[modeIndex];
              final state = _stateBox?.get(senderId) ?? ConversationState(
                contactId: senderId, 
                lastChangedBy: senderId, 
                lastChangedAt: DateTime.now(), 
                lastActivityAt: DateTime.now(),
              );
              state.mode = newMode;
              state.lastChangedBy = senderId;
              state.lastChangedAt = DateTime.now();
              await _stateBox?.put(senderId, state);
              _logger.i('Conversation mode for $senderId changed to ${newMode.name} by partner.');
              _logger.i('GHOST_LOG: MODE_CHANGE_RECEIVED');
              _logger.i('GHOST_LOG: MODE_CHANGE_APPLIED');
            }
          }
          // Do not save system messages to the box
          await _markProcessed(envelope.id, actualTimestamp);
          _wsService.acknowledgeMessage(envelope.id);
          continue;
        }

        // UPDATE CONVERSATION STATE & UNREAD COUNT
        var state = _stateBox?.get(senderId);
        final isCurrentlyActive = senderId == _activeConversationId;
        if (state != null) {
          // Check for 18-hour inactivity reset
          final inactivity = DateTime.now().difference(state.lastActivityAt);
          if (inactivity.inHours >= 18 && state.mode != ConversationMode.normal) {
            state.mode = ConversationMode.normal;
            state.lastChangedBy = 'system';
            state.lastChangedAt = DateTime.now();
            _logger.i('Conversation mode for $senderId reset to normal due to inactivity.');
          }
          state.lastActivityAt = DateTime.now();
          if (!isCurrentlyActive) {
            state.unreadCount = (state.unreadCount ?? 0) + 1;
          }
          state.lastMessageId = message.id;
          await _stateBox?.put(senderId, state);
        } else {
          state = ConversationState(
            contactId: senderId,
            lastChangedBy: 'system',
            lastChangedAt: DateTime.now(),
            lastActivityAt: DateTime.now(),
            unreadCount: isCurrentlyActive ? 0 : 1,
            lastMessageId: message.id,
          );
          await _stateBox?.put(senderId, state);
        }

        await _msgBox?.put(message.id, message);
        
        // TRIGGER NOTIFICATION
        if (isRequest) {
          _notificationService.showNotification(
            title: 'GhostRoom',
            body: 'New secure message request',
            payload: 'requests',
          );
        } else {
          final alias = _contactService.getContact(senderId)?.alias ?? 'Contact';
          _notificationService.showNotification(
            title: 'GhostRoom',
            body: 'You received a message from $alias',
            payload: senderId,
          );
        }

        _logger.i("MESSAGE_SAVED_LOCAL");
        _logger.i('GHOST_LOG: MESSAGE_RENDERED');
        _logger.i("MESSAGE_RENDERED_UI");
        _logger.i("MESSAGE_RENDERED");
        await _markProcessed(message.id, actualTimestamp);
        _wsService.acknowledgeMessage(message.id);
        
      } catch (e) {
        _logger.e("MESSAGE_DECRYPT_FAILED");
        _logger.e('Error processing envelope: $e');
        // Acknowledge anyway to prevent infinite retry loop for broken envelopes
        if (data['id'] != null) {
          _wsService.acknowledgeMessage(data['id']);
        }
      }
    }
  }

  Uint8List? _getSenderEid(DMEnvelope envelope) {
    for (final contact in _contactService.getAllContacts()) {
      try {
        final eid = base64Decode(contact.eid);
        final signMaterial = utf8.encode(
          '${envelope.version}${envelope.id}${envelope.timestamp}${_idService.currentIdentity!.publicId}${envelope.encryptedKey}${envelope.nonce}${envelope.ciphertext}'
        );
        if (_idService.sodium.crypto.sign.verifyDetached(
          message: signMaterial,
          signature: base64Decode(envelope.signature),
          publicKey: eid,
        )) {
          return eid;
        }
      } catch (_) {}
    }
    return null; // Unknown sender
  }

  MessageType _mapType(String? type) {
    switch (type) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'voice': return MessageType.voice;
      case 'file': return MessageType.file;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  Future<void> saveMessage(Message message) async {
    await _msgBox?.put(message.id, message);
  }

  Future<void> updateMessageMetadata(String messageId, Map<String, dynamic> metadata) async {
    final message = _msgBox?.get(messageId);
    if (message != null) {
      final newMetadata = Map<String, dynamic>.from(message.metadata ?? {});
      newMetadata.addAll(metadata);
      final updatedMessage = Message(
        id: message.id,
        senderId: message.senderId,
        recipientId: message.recipientId,
        plaintext: message.plaintext,
        timestamp: message.timestamp,
        isRead: message.isRead,
        type: message.type,
        metadata: newMetadata,
        isRequest: message.isRequest,
      );
      await _msgBox?.put(messageId, updatedMessage);
    }
  }

  Future<void> sendMessage({
    required String recipientId,
    required String text,
    MessageType type = MessageType.text,
    String retention = 'PERSISTENT',
    Map<String, dynamic>? metadata,
    String? existingId,
  }) async {
    _logger.i('GHOST_LOG: SEND_START for recipient: $recipientId');
    
    final identity = _idService.currentIdentity;
    if (identity == null) throw Exception('Identity not ready');

    // Attempt to find XID for encryption
    final contact = _contactService.getContact(recipientId);
    final String? recipientXidBase64 = contact?.xid;

    if (recipientXidBase64 == null || recipientXidBase64.isEmpty) {
      _logger.e('GHOST_FATAL: Cannot send E2EE message to $recipientId - missing X25519 public key.');
      throw Exception('Cannot send E2EE message without recipient public key. Please scan their Identity Package QR.');
    }

    final payload = {
      'type': type.name,
      'text': text,
      'sender_eid': base64Encode(identity.ed25519KeyPair.publicKey),
      'sender_xid': base64Encode(identity.x25519KeyPair.publicKey),
      'metadata': metadata ?? {},
    };

    if (metadata?['system_type'] == 'mode_change') {
      _logger.i('MODE_CHANGE_SENT: ${metadata?['mode']}');
    }

    final envelope = await _dmService.encryptDM(
      plaintext: jsonEncode(payload),
      recipientPublicId: recipientId,
      recipientXid: base64Decode(recipientXidBase64),
      senderIdentity: identity,
    );
    _logger.i('GHOST_LOG: SEND_ENCRYPT_SUCCESS');

    // MULTI-DEVICE FAN-OUT
    try {
      final recipientDevices = await _wsService.getDevices(recipientId);
      final myDevices = await _wsService.getDevices(identity.publicId);

      _logger.i('GHOST_LOG: FAN_OUT_START rec=${recipientDevices.length} self=${myDevices.length}');

      final List<Map<String, dynamic>> targets = [];
      
      // Target Recipient Devices
      if (recipientDevices.isEmpty) {
        // Fallback for V1/Legacy
        targets.add({'device_id': null, 'relay_url': null});
      } else {
        for (final d in recipientDevices) {
          targets.add({'device_id': d['device_id'], 'relay_url': d['relay_url']});
        }
      }

      // Target Self Devices (Sync)
      for (final d in myDevices) {
        if (d['device_id'] != identity.deviceId) {
          targets.add({'device_id': d['device_id'], 'relay_url': d['relay_url']});
        }
      }

      for (final target in targets) {
        final Map<String, dynamic> msgPayload = {
          ...envelope.toJson(),
          'retention': retention,
          'target_device_id': target['device_id'],
        };
        if (type == MessageType.image || type == MessageType.video || type == MessageType.voice) {
          if (metadata != null && metadata['media_id'] != null) {
            msgPayload['media_id'] = metadata['media_id'];
          }
        }

        // TODO: Handle remote relay delivery explicitly if relay_url is different
        // For now, our Home Relay handles S2S forwarding automatically
        _wsService.sendMessage(recipientId, msgPayload, version: 2, ack: (ackData) {
          _logger.i('GHOST_LOG: SEND_ACK_RECEIVED for device ${target['device_id']}');
        });
      }

    } catch (e) {
      _logger.e('GHOST_LOG: FAN_OUT_FAILED error: $e');
      // Fallback to single delivery if fan-out lookup fails
      final Map<String, dynamic> msgPayload = {
        ...envelope.toJson(),
        'retention': retention,
      };
      _wsService.sendMessage(recipientId, msgPayload, version: 2);
    }

    _logger.i('GHOST_LOG: SEND_SOCKET_EMIT_COMPLETE');
    _logger.i("MESSAGE_SENT");

    // Update Activity
    final state = _stateBox?.get(recipientId) ?? ConversationState(
      contactId: recipientId,
      lastChangedBy: identity.publicId,
      lastChangedAt: DateTime.now(),
      lastActivityAt: DateTime.now(),
    );
    state.lastActivityAt = DateTime.now();
    if (type != MessageType.system) {
      state.lastMessageId = envelope.id;
    }
    await _stateBox?.put(recipientId, state);

    if (type != MessageType.system) {
      final message = Message(
        id: envelope.id,
        senderId: identity.publicId,
        recipientId: recipientId,
        plaintext: text,
        timestamp: DateTime.now(),
        isRead: true,
        type: type,
        metadata: metadata,
      );
      
      if (existingId != null && existingId != envelope.id) {
        await _msgBox?.delete(existingId);
      }
      await _msgBox?.put(message.id, message);
    }
  }

  Future<void> updateConversationMode(String contactId, ConversationMode mode) async {
    final identity = _idService.currentIdentity;
    if (identity == null) return;

    final state = _stateBox?.get(contactId) ?? ConversationState(
      contactId: contactId, 
      lastChangedBy: identity.publicId, 
      lastChangedAt: DateTime.now(), 
      lastActivityAt: DateTime.now(),
    );

    state.mode = mode;
    state.lastChangedBy = identity.publicId;
    state.lastChangedAt = DateTime.now();
    await _stateBox?.put(contactId, state);

    // Send synchronization message
    await sendMessage(
      recipientId: contactId,
      text: '[MODE_CHANGE]',
      type: MessageType.system,
      metadata: {
        'system_type': 'mode_change',
        'mode': mode.index,
      },
    );
  }

  Future<void> flushGhostMessages(String contactId) async {
    final messages = getMessagesForContact(contactId, limit: 1000);
    final List<String> deletedIds = [];
    for (final msg in messages) {
      if (msg.metadata?['is_ghost'] == true) {
        await msg.delete();
        deletedIds.add(msg.id);
        
        if (msg.type == MessageType.image || msg.type == MessageType.video) {
          final mediaId = msg.metadata?['media_id'] as String?;
          if (mediaId != null) {
            await _mediaManager.deleteMedia(mediaId);
          }
        }
      }
    }
    if (deletedIds.isNotEmpty) {
      _logger.i('GHOST_LOG: Local ghost messages flushed for $contactId: $deletedIds');
      _wsService.socket?.emit('message.delete', {
        'message_ids': deletedIds,
      });
    }
  }

  Future<void> flushAllGhosts() async {
    _logger.i('GHOST_LOG: Global ghost flush starting...');
    final List<String> deletedIds = [];
    final messages = _msgBox?.values ?? [];
    for (final msg in messages) {
      if (msg.metadata?['is_ghost'] == true) {
        await msg.delete();
        deletedIds.add(msg.id);
        
        if (msg.type == MessageType.image || msg.type == MessageType.video) {
          final mediaId = msg.metadata?['media_id'] as String?;
          if (mediaId != null) {
            await _mediaManager.deleteMedia(mediaId);
          }
        }
      }
    }
    if (deletedIds.isNotEmpty) {
      _logger.i('GHOST_LOG: Global ghost flush complete. Pruned ${deletedIds.length} messages.');
      _wsService.socket?.emit('message.delete', {
        'message_ids': deletedIds,
      });
    }
  }

  Future<void> markConversationAsRead(String contactId) async {
    final state = _stateBox?.get(contactId);
    if (state != null && (state.unreadCount ?? 0) > 0) {
      state.unreadCount = 0;
      await _stateBox?.put(contactId, state);
      _logger.i('Conversation with $contactId marked as read.');
    }
  }

  Future<void> sendConsumptionReceipt(String recipientId, String messageId) async {
    try {
      await sendMessage(
        recipientId: recipientId,
        text: '[RECEIPT]',
        type: MessageType.system,
        metadata: {
          'system_type': 'receipt',
          'target_id': messageId,
        },
      );
      _logger.i('Sent consumption receipt for message $messageId to $recipientId');
    } catch (e) {
      _logger.w('Failed to send consumption receipt: $e');
    }
  }

  List<Message> getMessagesForContact(String contactId, {int limit = 100}) {
    // RAM OPTIMIZATION: Do not load all values. Iterate and filter.
    // Future improvement: use an index box for performance.
    final result = <Message>[];
    final values = _msgBox?.values ?? [];
    
    // Reverse iteration to get latest messages first
    for (var i = values.length - 1; i >= 0; i--) {
      final m = values.elementAt(i);
      if (m.senderId == contactId || m.recipientId == contactId) {
        result.add(m);
        if (result.length >= limit) break;
      }
    }
    
    return result.reversed.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Iterable<Message> getAllMessages() {
    return _msgBox?.values ?? [];
  }

  Iterable<ConversationState> getAllConversationStates() {
    return _stateBox?.values ?? [];
  }

  Future<void> dangerouslyClearAll() async {
    await _msgBox?.clear();
    await _syncBox?.clear();
  }
}

