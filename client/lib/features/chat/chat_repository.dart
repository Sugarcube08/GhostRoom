import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sodium/sodium_sumo.dart' hide Box;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:uuid/uuid.dart';
import '../media/media_manager.dart';
import '../media/media_service.dart';
import '../media/attachment_envelope.dart';
import '../../core/network/relay_manager.dart';
import '../../core/providers.dart';

class ChatRepository with WidgetsBindingObserver {
  final Ref? _ref;
  IdentityService? _idServiceField;
  DMService? _dmServiceField;
  ContactService? _contactServiceField;
  WebSocketService? _wsServiceField;
  NotificationService? _notificationServiceField;
  MediaManager? _mediaManagerField;
  MediaService? _mediaServiceField;
  RelayManager? _relayManagerField;

  IdentityService get _idService => _idServiceField ?? _ref!.read(identityServiceProvider);
  DMService get _dmService => _dmServiceField ?? _ref!.read(dmServiceProvider);
  ContactService get _contactService => _contactServiceField ?? _ref!.read(contactServiceProvider);
  WebSocketService get _wsService => _wsServiceField ?? _ref!.read(webSocketServiceProvider);
  NotificationService get _notificationService => _notificationServiceField ?? _ref!.read(notificationServiceProvider);
  MediaManager get _mediaManager => _mediaManagerField ?? _ref!.read(mediaManagerProvider);
  MediaService get _mediaService => _mediaServiceField ?? _ref!.read(mediaServiceProvider);
  RelayManager get _relayManager => _relayManagerField ?? _ref!.read(relayManagerProvider);

  String? _activeConversationId;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  static const String _msgBoxName = 'messages';
  static const String _syncBoxName = 'sync_metadata';
  static const String _processedBoxName = 'processed_envelopes';
  static const String _thumbCacheName = 'thumbnail_cache';
  static const String _offlineQueueBoxName = 'offline_send_queue';
  static const String _pendingDeletionsBoxName = 'pending_deletions';
  static const String _lastSyncKey = 'last_sync_t';

  ChatRepository(
    IdentityService idService, 
    DMService dmService, 
    ContactService contactService, 
    WebSocketService wsService,
    NotificationService notificationService,
    MediaManager mediaManager,
    MediaService mediaService,
    RelayManager relayManager,
  ) : _ref = null,
      _idServiceField = idService,
      _dmServiceField = dmService,
      _contactServiceField = contactService,
      _wsServiceField = wsService,
      _notificationServiceField = notificationService,
      _mediaManagerField = mediaManager,
      _mediaServiceField = mediaService,
      _relayManagerField = relayManager {
    WidgetsBinding.instance.addObserver(this);
  }

  ChatRepository.lazy(Ref ref) : _ref = ref {
    WidgetsBinding.instance.addObserver(this);
  }

  String get myPublicId => _idService.currentIdentity?.publicId ?? '';
  MediaManager get mediaManager => _mediaManager;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      sync();
    }
  }

  Future<void> sync() async {
    // ignore: avoid_print
    final relay = await _relayManager.getActiveRelay();
    if (relay != null) {
      await _relayManager.wakeUpRelay(relay);
      if (!_wsService.isConnected) {
        _wsService.connect(relay);
      } else if (!_wsService.isAuthenticated) {
        _wsService.connect(relay);
      } else {
        _wsService.fetchInbox(since: lastSyncTimestamp);
      }
    }
    // ignore: avoid_print
  }

  Future<void> syncInbox() async {
    await sync();
  }

  Future<bool> sendDeliveryReceipt(String messageId) async {
    // ignore: avoid_print
    final result = await _wsService.sendDeliveryReceipt(messageId);
    // ignore: avoid_print
    return result;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void setActiveConversation(String? contactId) {
    _activeConversationId = contactId;
    if (contactId != null) {
      // Immediate sync to prevent drift
      markConversationAsRead(contactId);
    } else {
      // Clear image cache when leaving conversation to free up memory (MEM-3)
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {
        // Ignore
      }
    }
  }

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Hive db path initialization is handled in main.dart
    
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
    }
    if (!Hive.isBoxOpen('conversation_states')) {
      await Hive.openBox<ConversationState>('conversation_states');
    }
    if (!Hive.isBoxOpen(_syncBoxName)) {
      await Hive.openBox(_syncBoxName);
    }
    if (!Hive.isBoxOpen(_processedBoxName)) {
      await Hive.openBox(_processedBoxName);
    }
    if (!Hive.isBoxOpen(_offlineQueueBoxName)) {
      await Hive.openBox<Map>(_offlineQueueBoxName);
    }
    if (!Hive.isBoxOpen(_pendingDeletionsBoxName)) {
      await Hive.openBox<bool>(_pendingDeletionsBoxName);
    }

    // Register WebSocket Callbacks
    _wsService.onIdentityVerified(_handleIdentityVerified);
    _wsService.onMessage(_handleNewMessage);
    _wsService.onInboxMessages(_handleInboxMessages);
    _wsService.onStatusUpdate(_handleMessageStatusUpdate);
    
    // Global Cleanup
    await flushAllGhosts();

    // Process offline queue on startup
    unawaited(processOfflineQueue());
    unawaited(syncPendingDeletions());
  }

  void _handleIdentityVerified(dynamic data) {
    // ignore: avoid_print
    _wsService.fetchInbox(since: lastSyncTimestamp);

    // Register FCM token on mobile platforms only
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FirebaseMessaging.instance.getToken().then((token) {
        if (token != null) {
          registerDeviceToken(token);
        }
      });
    }

    // Process offline queue on reconnect
    unawaited(processOfflineQueue());
    unawaited(syncPendingDeletions());
  }

  Future<void> registerDeviceToken(String fcmToken) async {
    final identity = _idService.currentIdentity;
    if (identity == null) {
      return;
    }
    final relay = await _relayManager.getActiveRelay();
    if (relay == null) {
      return;
    }

    final String platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
    final url = '${relay.apiUrl}/device/register';
    
    try {
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identityId': identity.publicId,
          'platform': platform,
          'fcmToken': fcmToken,
        }),
      );
    } catch (_) {
      // Ignore
    }
  }

  void _handleNewMessage(dynamic data) {
    processEnvelopes([data], enableNotification: true);
  }

  void _handleInboxMessages(List<dynamic> messages) {
    processEnvelopes(messages, enableNotification: false);
  }

  String _getMessageStatusString(Message msg) {
    if (msg.seenAt != null) return 'SEEN';
    if (msg.deliveredAt != null) return 'DELIVERED';
    if (msg.metadata?['status'] == 'SENT') return 'SENT';
    return 'PENDING';
  }

  void _handleMessageStatusUpdate(dynamic data) async {
    // ignore: avoid_print
    final String messageId = data['message_id'];
    final String status = data['status'];
    final int timestamp = data['timestamp'];

    final message = _msgBox?.get(messageId);
    if (message != null) {
      if (status == 'DELIVERED' && message.deliveredAt == null) {
        message.deliveredAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (status == 'SEEN' && message.seenAt == null) {
        message.deliveredAt ??= DateTime.fromMillisecondsSinceEpoch(timestamp);
        message.seenAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      await message.save();
    }
  }

  Future<void> markMessageAsSeen(String messageId) async {
    final message = _msgBox?.get(messageId);
    if (message != null && !message.isRead && message.senderId != myPublicId) {
      message.isRead = true;
      await message.save();
      _wsService.sendSeen(messageId);
    }
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

  Future<void> processEnvelopes(List<dynamic> envelopes, {bool enableNotification = true}) async {
    for (final data in envelopes) {
      try {
        final envelope = DMEnvelope.fromJson(data);
        
        if (isProcessed(envelope.id)) {
          await sendDeliveryReceipt(envelope.id);
          continue;
        }

        final identity = _idService.currentIdentity;
        if (identity == null) continue;

        String plaintext;
        Uint8List senderEid;

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
        
        final payload = jsonDecode(plaintext);
        final senderId = _idService.derivePublicId(senderEid);
        final actualTimestamp = envelope.timestamp;
        final type = _mapType(payload['type']);

        if (type == MessageType.image || type == MessageType.video) {
        }

        // TRUST LAYER ENFORCEMENT
        final isKnownContact = _contactService.getContact(senderId) != null;
        final isBlocked = _contactService.isBlocked(senderId);

        if (isBlocked) {
          await sendDeliveryReceipt(envelope.id);
          continue;
        }

        bool isRequest = false;
        if (!isKnownContact) {
          if (type != MessageType.text) {
            await sendDeliveryReceipt(envelope.id);
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
            }
          }
          // Do not save system messages to the box
          await _markProcessed(envelope.id, actualTimestamp);
          await sendDeliveryReceipt(envelope.id);
          continue;
        }

        // UPDATE CONVERSATION STATE & UNREAD COUNT
        var state = _stateBox?.get(senderId);
        final isCurrentlyActive = senderId == _activeConversationId && _lifecycleState == AppLifecycleState.resumed;

        if (isCurrentlyActive) {
          message.isRead = true;
          _wsService.sendSeen(message.id);
        }

        if (state != null) {
          // Check for 18-hour inactivity reset
          final inactivity = DateTime.now().difference(state.lastActivityAt);
          if (inactivity.inHours >= 18 && state.mode != ConversationMode.normal) {
            state.mode = ConversationMode.normal;
            state.lastChangedBy = 'system';
            state.lastChangedAt = DateTime.now();
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
        final wasNotified = _syncBox?.get('notified_${message.id}', defaultValue: false) == true;
        if (!isCurrentlyActive && enableNotification && !wasNotified) {
          await _syncBox?.put('notified_${message.id}', true);
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
        }

        await _markProcessed(message.id, actualTimestamp);
        await sendDeliveryReceipt(message.id);
        
      } catch (e) {
        // Acknowledge anyway to prevent infinite retry loop for broken envelopes
        if (data['id'] != null) {
          await sendDeliveryReceipt(data['id']);
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
    
    final messageId = existingId ?? const Uuid().v7();
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
      // Don't downgrade status if it is already DELIVERED or SEEN
      if (message.seenAt != null) return;
      if (message.deliveredAt != null && (status == 'SENT' || status == 'SENDING' || status == 'PENDING')) return;

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


      // Step 1: Media Upload if pending
      if (status == 'pending_upload' && filePath != null) {
        final file = File(filePath);
        if (!file.existsSync()) {
          await _updateMessageStatus(id, 'FAILED', error: 'Local file missing');
          await box.delete(id);
          _currentlySendingIds.remove(id);
          return true; // Proceed to next item
        }

        await _updateMessageStatus(id, 'UPLOADING');

        final activeRelay = await _relayManager.getActiveRelay();
        if (activeRelay == null) {
          _currentlySendingIds.remove(id);
          return false; // Halt queue
        }

        final contact = _contactService.getContact(recipientId);
        if (contact == null) {
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
          messageId: id,
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
              if (type == MessageType.image || type == MessageType.video || type == MessageType.voice) {
                 if (metadata['media_id'] != null) {
                 }
              }
              completer.complete(true);
            } else {
              completer.complete(false);
            }
          });

          final success = await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
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
            final existingMessage = _msgBox?.get(envelope.id);
            // If the message was already marked DELIVERED or SEEN by real-time status update, preserve it!
            final currentStatus = existingMessage != null ? _getMessageStatusString(existingMessage) : 'SENT';

            final message = Message(
              id: envelope.id,
              senderId: identity.publicId,
              recipientId: recipientId,
              plaintext: text,
              timestamp: existingMessage?.timestamp ?? DateTime.now(),
              deliveredAt: existingMessage?.deliveredAt,
              seenAt: existingMessage?.seenAt,
              isRead: true,
              type: type,
              metadata: {
                ...metadata,
                'status': currentStatus,
              },
            );
            
            if (id != envelope.id) {
              await _msgBox?.delete(id);
            }
            await _msgBox?.put(message.id, message);
          }


          // Remove from queue
          await box.delete(id);
          _currentlySendingIds.remove(id);
          return true; // Success
        } else {
          _currentlySendingIds.remove(id);
          return false; // Transient failure, halt
        }
      }
    } catch (e) {
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
    final List<String> deletedIds = [];
    final messages = _msgBox?.values ?? [];
    for (final msg in messages) {
      if (msg.metadata?['is_ghost'] == true) {
        deletedIds.add(msg.id);
        
        if (msg.type == MessageType.image || msg.type == MessageType.video) {
          final mediaId = msg.metadata?['media_id'] as String?;
          if (mediaId != null) {
            unawaited(_mediaManager.deleteMedia(mediaId));
          }
        }
      }
    }
    if (deletedIds.isNotEmpty) {
      await _msgBox?.deleteAll(deletedIds);
      final delBox = Hive.box<bool>(_pendingDeletionsBoxName);
      final Map<String, bool> delEntries = {for (var id in deletedIds) id: true};
      await delBox.putAll(delEntries);
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

      final completer = Completer<bool>();
      _wsService.socket?.emitWithAck('message.delete', {
        'message_ids': ids,
      }, ack: (response) {
        if (response != null && (response['status'] == 'success' || response['status'] == 'ok')) {
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      });

      final success = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (success) {
        await delBox.clear();
      }
    } catch (e) {
      // Ignore
    } finally {
      _isSyncingDeletions = false;
    }
  }

  Future<void> markConversationAsRead(String contactId) async {
    final state = _stateBox?.get(contactId);
    if (state != null && (state.unreadCount ?? 0) > 0) {
      state.unreadCount = 0;
      await _stateBox?.put(contactId, state);
    }

    // Mark individual messages as read and send seen notifications
    final messages = _msgBox?.values.where((m) => m.senderId == contactId && !m.isRead).toList() ?? [];
    for (final m in messages) {
      m.isRead = true;
      await m.save();
      _wsService.sendSeen(m.id);
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
    } catch (_) {
      // Ignore
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

  Message? getMessage(String messageId) {
    return _msgBox?.get(messageId);
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

