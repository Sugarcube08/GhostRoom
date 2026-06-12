import 'dart:convert';
import 'dart:typed_data';
import 'package:sodium/sodium_sumo.dart';
import 'package:uuid/uuid.dart';
import '../../core/crypto/identity_service.dart';

class DMEnvelope {
  final String id;
  final String encryptedKey;
  final String nonce;
  final String ciphertext;
  final String signature;
  final int timestamp;
  final int version;

  DMEnvelope({
    required this.id,
    required this.encryptedKey,
    required this.nonce,
    required this.ciphertext,
    required this.signature,
    required this.timestamp,
    this.version = 2,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'k': encryptedKey,
    'n': nonce,
    'c': ciphertext,
    's': signature,
    't': timestamp,
    'v': version,
  };

  factory DMEnvelope.fromJson(Map<String, dynamic> json) => DMEnvelope(
    id: json['id'],
    encryptedKey: json['k'],
    nonce: json['n'],
    ciphertext: json['c'],
    signature: json['s'],
    timestamp: json['t'] ?? DateTime.now().millisecondsSinceEpoch,
    version: json['v'] ?? 2,
  );
}

class DMService {
  final SodiumSumo sodium;
  final _uuid = const Uuid();

  DMService(this.sodium);

  Future<DMEnvelope> encryptDM({
    required String plaintext,
    required String recipientPublicId,
    required Uint8List recipientXid,
    required Identity senderIdentity,
    String? messageId,
  }) async {
    // 1. Generate Message Key
    final messageKey = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    
    // 2. Encrypt Payload
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: utf8.encode(plaintext),
      nonce: nonce,
      key: messageKey,
    );

    // 3. Wrap Key (Anonymous Box / Seal)
    final encryptedKey = sodium.crypto.box.seal(
      message: messageKey.extractBytes(),
      publicKey: recipientXid,
    );

    // 4. Generate ID (UUID v7) and Timestamp
    final actualMessageId = messageId ?? _uuid.v7();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 5. Sign (v + id + t + recipient_id + k + n + c)
    final kBase64 = base64Encode(encryptedKey);
    final nBase64 = base64Encode(nonce);
    final cBase64 = base64Encode(ciphertext);
    
    final signMaterial = utf8.encode(
      '2$actualMessageId$timestamp$recipientPublicId$kBase64$nBase64$cBase64'
    );
    
    final signature = sodium.crypto.sign.detached(
      message: signMaterial,
      secretKey: senderIdentity.ed25519KeyPair.secretKey,
    );

    return DMEnvelope(
      id: actualMessageId,
      encryptedKey: kBase64,
      nonce: nBase64,
      ciphertext: cBase64,
      signature: base64Encode(signature),
      timestamp: timestamp,
      version: 2,
    );
  }

  String decryptDM({
    required DMEnvelope envelope,
    required String myPublicId,
    required KeyPair myXidKeyPair,
    required Uint8List senderEid,
  }) {
    // 1. Verify Signature (v + id + t + my_id + k + n + c)
    final signMaterial = utf8.encode(
      envelope.version.toString() + 
      envelope.id + 
      envelope.timestamp.toString() + 
      myPublicId + 
      envelope.encryptedKey + 
      envelope.nonce + 
      envelope.ciphertext
    );
    
    final isSignatureValid = sodium.crypto.sign.verifyDetached(
      message: signMaterial,
      signature: base64Decode(envelope.signature),
      publicKey: senderEid,
    );

    if (!isSignatureValid) {
      throw Exception('Invalid message signature');
    }

    // 2. Unwrap Key
    final messageKeyBytes = sodium.crypto.box.sealOpen(
      cipherText: base64Decode(envelope.encryptedKey),
      publicKey: myXidKeyPair.publicKey,
      secretKey: myXidKeyPair.secretKey,
    );
    final messageKey = SecureKey.fromList(sodium, messageKeyBytes);

    // 3. Decrypt Payload
    final plaintextBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: base64Decode(envelope.ciphertext),
      nonce: base64Decode(envelope.nonce),
      key: messageKey,
    );

    return utf8.decode(plaintextBytes);
  }
}
