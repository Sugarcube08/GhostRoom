import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sodium/sodium_sumo.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:http/http.dart' as http;
import '../../core/network/relay_manager.dart';
import '../../core/crypto/identity_service.dart';
import 'attachment_envelope.dart';

class MediaService {
  final Sodium sodium;
  final IdentityService _idService;

  MediaService(this.sodium, this._idService);

  Future<File> compressImage(File file) async {
    final targetPath = '${file.path}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw Exception('Image compression failed');
    return File(result.path);
  }

  Future<File> compressVideo(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    if (info == null || info.file == null) throw Exception('Video compression failed');
    return info.file!;
  }

  Future<Map<String, dynamic>> encryptMedia(Uint8List plaintext) async {
    // 1. Generate Message Key
    final messageKey = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    
    // 2. Encrypt Payload
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: messageKey,
    );

    // 3. Compute Hash of plaintext
    final hash = crypto.sha256.convert(plaintext).toString();

    return {
      'ciphertext': ciphertext,
      'nonce': nonce,
      'messageKey': messageKey,
      'hash': hash,
    };
  }

  Future<Uint8List> decryptMedia({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required SecureKey messageKey,
    required String expectedHash,
  }) async {
    final decrypted = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: messageKey,
    );

    final actualHash = crypto.sha256.convert(decrypted).toString();
    if (actualHash != expectedHash) {
      throw Exception('Integrity check failed: Hash mismatch');
    }

    return decrypted;
  }

  Future<AttachmentEnvelope> uploadMedia({
    required File file,
    required AttachmentKind kind,
    required RelayProfile relay,
    required Uint8List recipientXid,
  }) async {
    final identity = _idService.currentIdentity;
    if (identity == null) throw Exception('Identity not initialized');

    final bytes = await file.readAsBytes();
    final encrypted = await encryptMedia(bytes);

    // 1. Request Upload URL
    final response = await http.post(
      Uri.parse('${relay.apiUrl}/media/upload-url'),
      headers: {
        'Content-Type': 'application/json',
        'x-public-id': identity.publicId,
      },
      body: jsonEncode({
        'size': (encrypted['ciphertext'] as Uint8List).length,
        'mime': _getMime(kind),
        'hash': encrypted['hash'],
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Upload request failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final String mediaId = data['mediaId'];
    final String uploadUrl = data['uploadUrl'];

    // 2. PUT to R2
    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      body: encrypted['ciphertext'],
      headers: {'Content-Type': _getMime(kind)},
    );

    if (putResponse.statusCode != 200) {
      throw Exception('R2 Upload failed');
    }

    // 3. Confirm Upload
    await http.post(
      Uri.parse('${relay.apiUrl}/media/confirm/$mediaId'),
      headers: {'x-public-id': identity.publicId},
    );

    // 4. Wrap Key for recipient
    final encryptedKey = sodium.crypto.box.seal(
      message: (encrypted['messageKey'] as SecureKey).extractBytes(),
      publicKey: recipientXid,
    );

    return AttachmentEnvelope(
      kind: kind,
      mediaId: mediaId,
      encryptedKey: base64Encode(encryptedKey),
      hash: encrypted['hash'],
      name: file.path.split('/').last,
      meta: kind == AttachmentKind.video ? {'nonce': base64Encode(encrypted['nonce'])} : {'nonce': base64Encode(encrypted['nonce'])},
    );
  }

  Future<Uint8List> downloadMedia({
    required AttachmentEnvelope envelope,
    required RelayProfile relay,
    required KeyPair myXidKeyPair,
  }) async {
    // 1. Get Download URL
    final response = await http.get(Uri.parse('${relay.apiUrl}/media/download-url/${envelope.mediaId}'));
    if (response.statusCode != 200) throw Exception('Download request failed');

    final data = jsonDecode(response.body);
    final downloadUrl = data['downloadUrl'];

    // 2. GET from R2
    final getResponse = await http.get(Uri.parse(downloadUrl));
    if (getResponse.statusCode != 200) throw Exception('R2 Download failed');

    // 3. Unwrap Key
    final messageKeyBytes = sodium.crypto.box.sealOpen(
      cipherText: base64Decode(envelope.encryptedKey),
      publicKey: myXidKeyPair.publicKey,
      secretKey: myXidKeyPair.secretKey,
    );
    final messageKey = SecureKey.fromList(sodium, messageKeyBytes);

    // 4. Decrypt & Verify
    final nonceBase64 = envelope.meta?['nonce'] as String?;
    if (nonceBase64 == null) throw Exception('Missing nonce in envelope');

    return await decryptMedia(
      ciphertext: getResponse.bodyBytes,
      nonce: base64Decode(nonceBase64),
      messageKey: messageKey,
      expectedHash: envelope.hash,
    );
  }

  String _getMime(AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.image: return 'image/jpeg';
      case AttachmentKind.video: return 'video/mp4';
      default: return 'application/octet-stream';
    }
  }
}
