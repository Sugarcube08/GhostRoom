import 'package:hive_flutter/hive_flutter.dart';
import 'package:sodium/sodium_sumo.dart' hide Box;
import 'dart:typed_data';
import 'message.dart';
import 'dm_service.dart';
import '../../core/crypto/identity_service.dart';
import '../../core/network/websocket_service.dart';
import '../../core/notification_service.dart';
import '../contacts/contact_service.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import '../../core/stability_tracker.dart';

class ChatRepository {
  final IdentityService _idService;
  final DMService _dmService;
  final ContactService _contactService;
  final WebSocketService _wsService;
  final NotificationService _notificationService;
  final Logger _logger = Logger();

  static const String _msgBoxName = 'messages';
  static const String _syncBoxName = 'sync_metadata';
  static const String _processedBoxName = 'processed_envelopes';
  static const String _lastSyncKey = 'last_sync_t';

  ChatRepository(
    this._idService, 
    this._dmService, 
    this._contactService, 
    this._wsService,
    this._notificationService,
  );

  String get myPublicId => _idService.currentIdentity?.publicId ?? '';

  Future<void> init() async {
    StabilityTracker.logMemory('ChatRepo_Init_Start');
    if (!Hive.isAdapterRegistered(MessageTypeAdapter().typeId)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(MessageAdapter().typeId)) {
      Hive.registerAdapter(MessageAdapter());
    }
    
    if (!Hive.isBoxOpen(_msgBoxName)) {
      await Hive.openBox<Message>(_msgBoxName);
      StabilityTracker.logResource('HiveBox', 'Opened_$_msgBoxName');
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

  Box<Message> get _msgBox => Hive.box<Message>(_msgBoxName);
  Box get _syncBox => Hive.box(_syncBoxName);
  Box get _processedBox => Hive.box(_processedBoxName);

  int get lastSyncTimestamp => _syncBox.get(_lastSyncKey, defaultValue: 0);
  
  bool isProcessed(String id) => _processedBox.containsKey(id);

  Future<void> _markProcessed(String id, int timestamp) async {
    await _processedBox.put(id, true);
    
    if (timestamp > lastSyncTimestamp) {
      await _syncBox.put(_lastSyncKey, timestamp);
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
        );

        // HANDLE SYSTEM MESSAGES
        if (type == MessageType.system) {
          final systemType = payload['metadata']?['system_type'];
          if (systemType == 'receipt') {
            final targetId = payload['metadata']?['target_id'];
            if (targetId != null) {
              final targetMsg = _msgBox.get(targetId);
              if (targetMsg != null) {
                targetMsg.metadata?['consumed'] = true;
                await targetMsg.save();
                _logger.i('Message $targetId marked as consumed by receipt.');
              }
            }
          }
          // Do not save system messages to the box
          await _markProcessed(envelope.id, actualTimestamp);
          _wsService.acknowledgeMessage(envelope.id);
          continue;
        }

        await _msgBox.put(message.id, message);
        
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
            title: alias,
            body: type == MessageType.text ? (payload['text'] ?? 'New message') : 'Sent an attachment',
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
      case 'file': return MessageType.file;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  Future<void> sendMessage({
    required String recipientId,
    required String text,
    MessageType type = MessageType.text,
    String retention = 'PERSISTENT',
    Map<String, dynamic>? metadata,
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
      ...?metadata,
    };

    final envelope = await _dmService.encryptDM(
      plaintext: jsonEncode(payload),
      recipientPublicId: recipientId,
      recipientXid: base64Decode(recipientXidBase64),
      senderIdentity: identity,
    );
    _logger.i('GHOST_LOG: SEND_ENCRYPT_SUCCESS');

    _wsService.sendMessage(recipientId, {
      ...envelope.toJson(),
      'retention': retention,
    }, version: 2, ack: (ackData) {
      _logger.i('GHOST_LOG: SEND_ACK_RECEIVED');
    });
    _logger.i('GHOST_LOG: SEND_SOCKET_EMIT');
    _logger.i("MESSAGE_SENT");

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
    await _msgBox.put(message.id, message);
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

  List<Message> getMessagesForContact(String contactId) {
    return _msgBox.values
        .where((m) => m.senderId == contactId || m.recipientId == contactId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Iterable<Message> getAllMessages() {
    return _msgBox.values;
  }

  Future<void> dangerouslyClearAll() async {
    await _msgBox.clear();
    await _syncBox.clear();
  }
}
