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
import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import '../media/media_manager.dart';
import '../media/media_service.dart';
import '../media/attachment_envelope.dart';
import '../../core/network/relay_manager.dart';
import '../../core/stability_tracker.dart';

class ChatRepository {
  final IdentityService _idService;
  final DMService _dmService;
  final ContactService _contactService;
  final WebSocketService _wsService;
  final NotificationService _notificationService;
  final MediaManager _mediaManager;
  final MediaService _mediaService;
  final RelayManager _relayManager;
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
  static const String _offlineQueueBoxName = 'offline_send_queue';
  static const String _pendingDeletionsBoxName = 'pending_deletions';
  static const String _lastSyncKey = 'last_sync_t';

  ChatRepository(
    this._idService, 
    this._dmService, 
    this._contactService, 
    this._wsService,
    this._notificationService,
    this._mediaManager,
    this._mediaService,
    this._relayManager,
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
    if (!Hive.isBoxOpen(_offlineQueueBoxName)) {
      await Hive.openBox<Map>(_offlineQueueBoxName);
      StabilityTracker.logResource('HiveBox', 'Opened_$_offlineQueueBoxName');
    }
    if (!Hive.isBoxOpen(_pendingDeletionsBoxName)) {
      await Hive.openBox<bool>(_pendingDeletionsBoxName);
      StabilityTracker.logResource('HiveBox', 'Opened_$_pendingDeletionsBoxName');
    }

    // Register WebSocket Callbacks
    _wsService.onIdentityVerified(_handleIdentityVerified);
    _wsService.onMessage(_handleNewMessage);
    _wsService.onInboxMessages(_handleInboxMessages);
    
    // Global Cleanup
    await flushAllGhosts();

    // Process offline queue on startup
    unawaited(processOfflineQueue());
    unawaited(syncPendingDeletions());

    _logger.i('GHOST_LOG: ChatRepository initialized and listeners registered.');
    StabilityTracker.logMemory('ChatRepo_Init_End');
  }

  void _handleIdentityVerified(dynamic data) {
    _logger.i('GHOST_LOG: Identity verified. Triggering inbox sync...');
    _wsService.fetchInbox(since: lastSyncTimestamp);

    // Process offline queue on reconnect
    unawaited(processOfflineQueue());
    unawaited(syncPendingDeletions());
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

  Box<Map>? get _queueBox {
    if (!Hive.isBoxOpen(_offlineQueueBoxName)) return null;
    return Hive.box<Map>(_offlineQueueBoxName);
  }

  bool _isProcessingQueue = false;
  final List<String> _currentlySendingIds = [];

  Future<void> queueMediaSend({
    required String messageId,
    required String recipientId,
    required String text,
    required MessageType type,
    required File file,
    required String retention,
    Map<String, dynamic>? metadata,
  }) async {
    final queueItem = {
      'id': messageId,
      'recipientId': recipientId,
      'text': text,
      'type': type.name,
      'retention': retention,
      'metadata': metadata ?? {},
      'filePath': file.path,
      'status': 'pending_upload',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _queueBox?.put(messageId, queueItem);
    unawaited(processOfflineQueue());
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
    
    final messageId = existingId ?? 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final identity = _idService.currentIdentity;
    
    if (existingId == null && type != MessageType.system) {
      final message = Message(
        id: messageId,
        senderId: identity?.publicId ?? '',
        recipientId: recipientId,
        plaintext: text,
        timestamp: DateTime.now(),
        isRead: true,
        type: type,
        metadata: {
          'status': 'PENDING',
          'is_ghost': retention == 'EPHEMERAL',
          ...?metadata,
        },
      );
      await saveMessage(message);
    }

    final queueItem = {
      'id': messageId,
      'recipientId': recipientId,
      'text': text,
      'type': type.name,
      'retention': retention,
      'metadata': metadata ?? {},
      'filePath': null,
      'status': 'pending_send',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _queueBox?.put(messageId, queueItem);
    unawaited(processOfflineQueue());
  }

  Future<void> _updateMessageStatus(String messageId, String status, {String? error}) async {
    final message = _msgBox?.get(messageId);
    if (message != null) {
      final newMetadata = Map<String, dynamic>.from(message.metadata ?? {});
      newMetadata['status'] = status;
      if (error != null) {
        newMetadata['error'] = error;
      }
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
        groupId: message.groupId,
      );
      await _msgBox?.put(messageId, updatedMessage);
    }
  }

  Future<void> processOfflineQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (true) {
        final box = _queueBox;
        if (box == null || box.isEmpty) break;

        // Ensure we are connected and authenticated
        if (!_wsService.isConnected || !_wsService.isAuthenticated) {
          _logger.d('GHOST_LOG: Queue processing paused - offline or unauthenticated');
          break;
        }

        // Get and sort the first pending item
        final items = box.values.toList().cast<Map>()
          ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

        if (items.isEmpty) break;
        final item = items.first;

        // Process this single item
        final success = await _processQueueItem(item);
        if (!success) {
          // If a transient error occurs, we break to avoid infinite loop / blocking
          break;
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<bool> _processQueueItem(Map item) async {
    final box = _queueBox;
    if (box == null) return false;

    final String id = item['id'] as String;
    if (_currentlySendingIds.contains(id)) return false;
    _currentlySendingIds.add(id);

    try {
      final String recipientId = item['recipientId'] as String;
      final String text = item['text'] as String;
      final MessageType type = MessageType.values.firstWhere((e) => e.name == item['type']);
      final String retention = item['retention'] as String;
      final Map<String, dynamic> metadata = Map<String, dynamic>.from(item['metadata'] ?? {});
      final String? filePath = item['filePath'] as String?;
      String status = item['status'] as String;

      _logger.i('GHOST_LOG: Processing queue item $id (type: ${type.name}, status: $status)');

      // Step 1: Media Upload if pending
      if (status == 'pending_upload' && filePath != null) {
        final file = File(filePath);
        if (!file.existsSync()) {
          _logger.e('GHOST_LOG: Media file not found for queue item $id: $filePath');
          await _updateMessageStatus(id, 'FAILED', error: 'Local file missing');
          await box.delete(id);
          _currentlySendingIds.remove(id);
          return true; // Proceed to next item
        }

        _logger.i('GHOST_LOG: Uploading media for offline queue item $id');
        await _updateMessageStatus(id, 'UPLOADING');

        final activeRelay = await _relayManager.getActiveRelay();
        if (activeRelay == null) {
          _logger.w('GHOST_LOG: No active relay for upload. Halting queue.');
          _currentlySendingIds.remove(id);
          return false; // Halt queue
        }

        final contact = _contactService.getContact(recipientId);
        if (contact == null) {
          _logger.e('GHOST_LOG: Contact $recipientId not found for queue item $id');
          await _updateMessageStatus(id, 'FAILED', error: 'Contact not found');
          await box.delete(id);
          _currentlySendingIds.remove(id);
          return true; // Proceed to next item
        }

        AttachmentKind kind = AttachmentKind.image;
        if (type == MessageType.video) kind = AttachmentKind.video;
        if (type == MessageType.voice) kind = AttachmentKind.voice;

        final (envelope, thumbnailBytes) = await _mediaService.uploadMedia(
          file: file,
          kind: kind,
          relay: activeRelay,
          recipientXid: base64Decode(contact.xid),
          messageId: id,
        );

        await _mediaManager.cacheSentMedia(
          mediaId: envelope.mediaId,
          originalFile: file,
          thumbnailBytes: thumbnailBytes,
        );

        // Update queue item to pending_send with envelope meta
        final updatedItem = Map<String, dynamic>.from(item);
        updatedItem['status'] = 'pending_send';
        final newMetadata = Map<String, dynamic>.from(item['metadata'] ?? {});
        newMetadata.addAll(envelope.toJson());
        newMetadata['relay_url'] = activeRelay.apiUrl;
        newMetadata['is_ghost'] = retention == 'EPHEMERAL';
        updatedItem['metadata'] = newMetadata;
        
        await box.put(id, updatedItem);
        
        await updateMessageMetadata(id, {
          ...newMetadata,
          'status': 'UPLOADED',
        });

        // Update local variables for Step 2
        status = 'pending_send';
        metadata.addAll(newMetadata);
        _logger.i('GHOST_LOG: Media upload complete for queue item $id');
      }

      // Step 2: Encrypt and Send Envelope
      if (status == 'pending_send') {
        await _updateMessageStatus(id, 'SENDING');

        final contact = _contactService.getContact(recipientId);
        final String? recipientXidBase64 = contact?.xid;

        if (recipientXidBase64 == null || recipientXidBase64.isEmpty) {
          throw Exception('Missing recipient public key');
        }

        final identity = _idService.currentIdentity;
        if (identity == null) throw Exception('Identity not ready');

        final payload = {
          'type': type.name,
          'text': text,
          'sender_eid': base64Encode(identity.ed25519KeyPair.publicKey),
          'sender_xid': base64Encode(identity.x25519KeyPair.publicKey),
          'metadata': metadata,
        };

        final envelope = await _dmService.encryptDM(
          plaintext: jsonEncode(payload),
          recipientPublicId: recipientId,
          recipientXid: base64Decode(recipientXidBase64),
          senderIdentity: identity,
        );

        List<Map<String, dynamic>> targets = [];
        try {
          final recipientDevices = await _wsService.getDevices(recipientId);
          final myDevices = await _wsService.getDevices(identity.publicId);

          if (recipientDevices.isEmpty) {
            targets.add({'device_id': null});
          } else {
            for (final d in recipientDevices) {
              targets.add({'device_id': d['device_id']});
            }
          }
          for (final d in myDevices) {
            if (d['device_id'] != identity.deviceId) {
              targets.add({'device_id': d['device_id']});
            }
          }
        } catch (e) {
          _logger.w('GHOST_LOG: Fan-out lookup failed: $e. Using fallback single target.');
          targets.add({'device_id': null});
        }

        bool allSent = true;
        for (final target in targets) {
          final Map<String, dynamic> msgPayload = {
            ...envelope.toJson(),
            'retention': retention,
            'target_device_id': target['device_id'],
          };
          if (type == MessageType.image || type == MessageType.video || type == MessageType.voice) {
            if (metadata['media_id'] != null) {
              msgPayload['media_id'] = metadata['media_id'];
            }
          }

          final completer = Completer<bool>();
          _wsService.sendMessage(recipientId, msgPayload, version: 2, ack: (response) {
            if (response != null && response['status'] == 'ok') {
              completer.complete(true);
            } else {
              _logger.w('GHOST_LOG: Server rejected message emit: $response');
              completer.complete(false);
            }
          });

          final success = await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              _logger.w('GHOST_LOG: Timeout waiting for message send acknowledgment');
              return false;
            },
          );

          if (!success) {
            allSent = false;
            break;
          }
        }

        if (allSent) {
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
              metadata: {
                ...metadata,
                'status': 'SENT',
              },
            );
            
            if (id != envelope.id) {
              await _msgBox?.delete(id);
            }
            await _msgBox?.put(message.id, message);
          }

          if (type == MessageType.image || type == MessageType.video) {
            final mediaId = metadata['media_id'] ?? '';
            final relayUrl = metadata['relay_url'] ?? '';
            final mediaKind = type == MessageType.image ? 'image' : 'video';
            _logger.i('GHOST_LOG: MEDIA_MESSAGE_SENT messageId: ${envelope.id} mediaId: $mediaId mediaKind: $mediaKind url: $relayUrl');
            _logger.i('GHOST_LOG: MEDIA_ENVELOPE_SENT id: $mediaId');
          } else if (type == MessageType.voice) {
            final mediaId = metadata['media_id'] ?? '';
            _logger.i('GHOST_LOG: VOICE_ENVELOPE_SENT id: $mediaId');
          }

          // Remove from queue
          await box.delete(id);
          _logger.i('GHOST_LOG: Message $id successfully sent and removed from queue');
          _currentlySendingIds.remove(id);
          return true; // Success
        } else {
          _logger.w('GHOST_LOG: Send failed for item $id. Halting queue.');
          _currentlySendingIds.remove(id);
          return false; // Transient failure, halt
        }
      }
    } catch (e) {
      _logger.e('GHOST_LOG: Error processing queue item $id: $e');
      final errStr = e.toString();
      final isPermanent = errStr.contains('Missing recipient public key') ||
          errStr.contains('Contact not found') ||
          errStr.contains('"statusCode":40') ||
          errStr.contains('statusCode: 40') ||
          errStr.contains('statusCode:40') ||
          errStr.contains('"statusCode": 40') ||
          errStr.contains('too large') ||
          errStr.contains('Too large') ||
          errStr.contains('Bad Request') ||
          errStr.contains('400') ||
          errStr.contains('413') ||
          errStr.contains('403') ||
          errStr.contains('401');

      if (isPermanent) {
        await _updateMessageStatus(id, 'FAILED', error: errStr);
        await box.delete(id);
        _currentlySendingIds.remove(id);
        return true; // Proceed to next
      } else {
        await _updateMessageStatus(id, 'PENDING', error: errStr);
        _currentlySendingIds.remove(id);
        return false; // Transient failure, halt
      }
    }

    _currentlySendingIds.remove(id);
    return false;
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
      final delBox = Hive.box<bool>(_pendingDeletionsBoxName);
      for (final id in deletedIds) {
        await delBox.put(id, true);
      }
      _wsService.socket?.emit('message.delete', {
        'message_ids': deletedIds,
      });
      unawaited(syncPendingDeletions());
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
      final delBox = Hive.box<bool>(_pendingDeletionsBoxName);
      for (final id in deletedIds) {
        await delBox.put(id, true);
      }
      _wsService.socket?.emit('message.delete', {
        'message_ids': deletedIds,
      });
      unawaited(syncPendingDeletions());
    }
  }

  bool _isSyncingDeletions = false;

  Future<void> syncPendingDeletions() async {
    if (_isSyncingDeletions) return;
    _isSyncingDeletions = true;

    try {
      if (!Hive.isBoxOpen(_pendingDeletionsBoxName)) return;
      final delBox = Hive.box<bool>(_pendingDeletionsBoxName);
      if (delBox.isEmpty) return;

      if (!_wsService.isConnected || !_wsService.isAuthenticated) {
        return;
      }

      final ids = delBox.keys.cast<String>().toList();
      _logger.i('GHOST_LOG: Syncing ${ids.length} pending deletions to relay...');

      final completer = Completer<bool>();
      _wsService.socket?.emitWithAck('message.delete', {
        'message_ids': ids,
      }, ack: (response) {
        if (response != null && (response['status'] == 'success' || response['status'] == 'ok')) {
          completer.complete(true);
        } else {
          _logger.w('GHOST_LOG: Relay rejected delete sync: $response');
          completer.complete(false);
        }
      });

      final success = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (success) {
        await delBox.clear();
        _logger.i('GHOST_LOG: Successfully synced deletions to relay.');
      }
    } catch (e) {
      _logger.e('GHOST_LOG: Error syncing deletions: $e');
    } finally {
      _isSyncingDeletions = false;
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

  void logMemoryUsage() {
    final stats = {
      'initialized': _isInitialized,
      'activeConversationId': _activeConversationId,
      'messagesBoxCount': _msgBox?.length ?? 0,
      'statesBoxCount': _stateBox?.length ?? 0,
      'syncBoxCount': _syncBox?.length ?? 0,
      'processedBoxCount': _processedBox?.length ?? 0,
      'offlineQueueBoxCount': _queueBox?.length ?? 0,
      'pendingDeletionsBoxCount': Hive.isBoxOpen(_pendingDeletionsBoxName) ? Hive.box<bool>(_pendingDeletionsBoxName).length : 0,
    };
    StabilityTracker.logComponentMemory('ChatRepository', stats);
  }
}

