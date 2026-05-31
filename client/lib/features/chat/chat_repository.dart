import 'package:hive_flutter/hive_flutter.dart';
import 'package:sodium/sodium_sumo.dart' hide Box;
import 'message.dart';
import 'dm_service.dart';
import '../../core/crypto/identity_service.dart';
import '../../core/network/websocket_service.dart';
import '../contacts/contact_service.dart';
import 'dart:convert';
import 'package:logger/logger.dart';

class ChatRepository {
  final IdentityService _idService;
  final DMService _dmService;
  final ContactService _contactService;
  final WebSocketService _wsService;
  final Logger _logger = Logger();

  static const String _msgBoxName = 'messages';
  static const String _syncBoxName = 'sync_metadata';
  static const String _processedIdsKey = 'processed_ids';
  static const String _lastSyncKey = 'last_sync_t';

  ChatRepository(this._idService, this._dmService, this._contactService, this._wsService);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MessageAdapter());
    }
    await Hive.openBox<Message>(_msgBoxName);
    await Hive.openBox(_syncBoxName);
  }

  Box<Message> get _msgBox => Hive.box<Message>(_msgBoxName);
  Box get _syncBox => Hive.box(_syncBoxName);

  int get lastSyncTimestamp => _syncBox.get(_lastSyncKey, defaultValue: 0);
  
  Set<String> get processedIds => Set<String>.from(_syncBox.get(_processedIdsKey, defaultValue: []));

  Future<void> _markProcessed(String id, int timestamp) async {
    final ids = processedIds;
    ids.add(id);
    await _syncBox.put(_processedIdsKey, ids.toList());
    
    if (timestamp > lastSyncTimestamp) {
      await _syncBox.put(_lastSyncKey, timestamp);
    }
  }

  Future<void> processEnvelopes(List<dynamic> envelopes) async {
    for (final data in envelopes) {
      try {
        final envelope = DMEnvelope.fromJson(data);
        
        if (processedIds.contains(envelope.id)) {
          _wsService.acknowledgeMessage(envelope.id);
          continue;
        }

        final identity = _idService.currentIdentity;
        if (identity == null) continue;

        // 1. Unwrap Message Key (Anonymous)
        final messageKeyBytes = _idService.sodium.crypto.box.sealOpen(
          cipherText: base64Decode(envelope.encryptedKey),
          publicKey: identity.x25519KeyPair.publicKey,
          secretKey: identity.x25519KeyPair.secretKey,
        );
        final messageKey = SecureKey.fromList(_idService.sodium, messageKeyBytes);

        // 2. Decrypt Payload (Symmetric)
        final plaintextBytes = _idService.sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
          cipherText: base64Decode(envelope.ciphertext),
          nonce: base64Decode(envelope.nonce),
          key: messageKey,
        );
        
        final payload = jsonDecode(utf8.decode(plaintextBytes));
        final senderEidBase64 = payload['sender_eid'] as String;
        final senderEid = base64Decode(senderEidBase64);
        
        // 3. Verify Signature (Sender Identity)
        final signMaterial = utf8.encode(envelope.id + envelope.encryptedKey + envelope.nonce + envelope.ciphertext);
        final isSignatureValid = _idService.sodium.crypto.sign.verifyDetached(
          message: signMaterial,
          signature: base64Decode(envelope.signature),
          publicKey: senderEid,
        );

        if (!isSignatureValid) {
          _logger.w('Invalid signature for message ${envelope.id}. Dropping.');
          _wsService.acknowledgeMessage(envelope.id);
          continue;
        }

        final senderId = _idService.derivePublicId(senderEid);
        final actualTimestamp = data['t'] ?? DateTime.now().millisecondsSinceEpoch;

        final finalMessage = Message(
          id: envelope.id,
          senderId: senderId,
          recipientId: identity.publicId,
          plaintext: payload['text'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(actualTimestamp),
        );

        await _msgBox.put(finalMessage.id, finalMessage);
        await _markProcessed(finalMessage.id, actualTimestamp);
        _wsService.acknowledgeMessage(finalMessage.id);
        
      } catch (e) {
        _logger.e('Error processing envelope: $e');
      }
    }
  }

  Future<void> sendMessage(String recipientId, String text) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');
    
    final identity = _idService.currentIdentity;
    if (identity == null) throw Exception('Identity not ready');

    final payload = {
      'text': text,
      'sender_eid': base64Encode(identity.ed25519KeyPair.publicKey),
      'sender_xid': base64Encode(identity.x25519KeyPair.publicKey),
    };

    final envelope = await _dmService.encryptDM(
      plaintext: jsonEncode(payload),
      recipientXid: base64Decode(contact.xid),
      senderIdentity: identity,
    );

    _wsService.sendMessage(recipientId, envelope.toJson(), version: 2);

    final message = Message(
      id: envelope.id,
      senderId: identity.publicId,
      recipientId: recipientId,
      plaintext: text,
      timestamp: DateTime.now(),
      isRead: true,
    );
    await _msgBox.put(message.id, message);
  }

  List<Message> getMessagesForContact(String contactId) {
    return _msgBox.values
        .where((m) => m.senderId == contactId || m.recipientId == contactId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
