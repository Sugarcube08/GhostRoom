import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:ghostroom/features/media/media_service.dart';
import 'package:ghostroom/features/media/attachment_envelope.dart';
import 'package:ghostroom/core/crypto/identity_service.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  test('Media Cryptography: Encryption/Decryption Integrity', () async {
    final sodium = await SodiumSumoInit.init();
    final idService = IdentityService(sodium);
    final mediaService = MediaService(sodium, idService);
    
    final plaintext = Uint8List.fromList(utf8.encode('This is a secret image data blob'));
    
    // 1. Encrypt
    final result = await mediaService.encryptMedia(plaintext);
    
    expect(result['ciphertext'], isNotNull);
    expect(result['nonce'], isNotNull);
    expect(result['messageKey'], isA<SecureKey>());
    expect(result['hash'], isNotNull);
    
    // 2. Decrypt
    final decrypted = await mediaService.decryptMedia(
      ciphertext: result['ciphertext'] as Uint8List,
      nonce: result['nonce'] as Uint8List,
      messageKey: result['messageKey'] as SecureKey,
      expectedHash: result['hash'] as String,
    );
    
    expect(decrypted, plaintext);
    expect(utf8.decode(decrypted), 'This is a secret image data blob');
  });

  test('AttachmentEnvelope JSON consistency', () {
    final envelope = AttachmentEnvelope(
      kind: AttachmentKind.image,
      mediaId: 'test-uuid',
      encryptedKey: 'base64-key',
      hash: 'sha256-hash',
      meta: {'nonce': 'base64-nonce'},
    );

    final json = envelope.toJson();
    expect(json['kind'], 'image');
    expect(json['media_id'], 'test-uuid');

    final decoded = AttachmentEnvelope.fromJson(json);
    expect(decoded.kind, AttachmentKind.image);
    expect(decoded.mediaId, 'test-uuid');
    expect(decoded.meta?['nonce'], 'base64-nonce');
  });
}
