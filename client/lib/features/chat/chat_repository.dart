import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
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

  String get myPublicId => _idService.currentIdentity?.publicId ?? '';

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(MessageTypeAdapter().typeId)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(MessageAdapter().typeId)) {
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

        // Hybrid Decrypt
        final plaintext = _dmService.decryptDM(
          envelope: envelope,
          myPublicId: identity.publicId,
          myXidKeyPair: identity.x25519KeyPair,
          senderEid: _getSenderEid(envelope),
        );
        
        final payload = jsonDecode(plaintext);
        final senderEidBase64 = payload['sender_eid'] as String;
        final senderEid = base64Decode(senderEidBase64);
        
        final senderId = _idService.derivePublicId(senderEid);
        final actualTimestamp = envelope.timestamp;

        final message = Message(
          id: envelope.id,
          senderId: senderId,
          recipientId: identity.publicId,
          plaintext: payload['text'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(actualTimestamp),
          type: _mapType(payload['type']),
          metadata: payload['metadata'],
        );

        await _msgBox.put(message.id, message);
        await _markProcessed(message.id, actualTimestamp);
        _wsService.acknowledgeMessage(message.id);
        
      } catch (e) {
        _logger.e('Error processing envelope: $e');
      }
    }
  }

  Uint8List _getSenderEid(DMEnvelope envelope) {
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
    throw Exception('Unknown sender or invalid signature');
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
    Map<String, dynamic>? metadata,
  }) async {
    final contact = _contactService.getContact(recipientId);
    if (contact == null) throw Exception('Contact not found');
    
    final identity = _idService.currentIdentity;
    if (identity == null) throw Exception('Identity not ready');

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
      type: type,
      metadata: metadata,
    );
    await _msgBox.put(message.id, message);
  }

  List<Message> getMessagesForContact(String contactId) {
    return _msgBox.values
        .where((m) => m.senderId == contactId || m.recipientId == contactId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<Message> getAllMessages() {
    return _msgBox.values.toList();
  }

  Future<void> dangerouslyClearAll() async {
    await _msgBox.clear();
    await _syncBox.clear();
  }
}
