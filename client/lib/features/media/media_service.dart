import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sodium/sodium_sumo.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import '../../core/network/relay_manager.dart';
import '../../core/crypto/identity_service.dart';
import 'attachment_envelope.dart';

class MediaService {
  final SodiumSumo sodium;
  final IdentityService _idService;
  final Logger _logger = Logger();

  MediaService(this.sodium, this._idService);

  Future<File> compressImage(File file) async {
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_START kind: image');
    final targetPath = p.join(p.dirname(file.path), 'compressed_${p.basename(file.path)}');
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw Exception('Image compression failed');
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_SUCCESS');
    return File(result.path);
  }

  Future<Uint8List> generateImageThumbnail(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 100,
      minHeight: 100,
      quality: 50,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw Exception('Thumbnail generation failed');
    return result;
  }

  Future<File> compressVideo(File file) async {
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_START kind: video');
    // video_compress handles 720p / H264 via qualities.
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.Res1280x720Quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (info == null || info.file == null) throw Exception('Video compression failed');
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_SUCCESS');
    return info.file!;
  }

  Future<Uint8List> generateVideoThumbnail(File file) async {
    final result = await VideoCompress.getByteThumbnail(file.path, quality: 50);
    if (result == null) throw Exception('Video thumbnail failed');
    return result;
  }

  Future<Map<String, dynamic>> getVideoMetadata(File file) async {
    final info = await VideoCompress.getMediaInfo(file.path);
    return {
      'duration': info.duration, // ms
      'w': info.width,
      'h': info.height,
      'fps': 30, // Default assumption if not provided
    };
  }

  Future<Map<String, dynamic>> encryptMedia(Uint8List plaintext, SecureKey? existingKey) async {
    _logger.i('GHOST_LOG: MEDIA_ENCRYPT_START');
    final messageKey = existingKey ?? sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: messageKey,
    );
    final hash = crypto.sha256.convert(plaintext).toString();
    _logger.i('GHOST_LOG: MEDIA_ENCRYPT_SUCCESS');

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
    _logger.i('GHOST_LOG: MEDIA_DECRYPT_START');
    final decrypted = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: messageKey,
    );

    final actualHash = crypto.sha256.convert(decrypted).toString();
    if (actualHash != expectedHash) throw Exception('Integrity check failed: Hash mismatch');
    _logger.i('GHOST_LOG: MEDIA_DECRYPT_SUCCESS');
    return decrypted;
  }

  Future<AttachmentEnvelope> uploadMedia({
    required File file,
    required AttachmentKind kind,
    required RelayProfile relay,
    required Uint8List recipientXid,
  }) async {
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_START kind: ${kind.name}');
    final identity = _idService.currentIdentity;
    if (identity == null) throw Exception('Identity not initialized');

    final bytes = await file.readAsBytes();
    final encrypted = await encryptMedia(bytes, null);
    final SecureKey messageKey = encrypted['messageKey'];

    // Metadata extraction
    Map<String, dynamic>? meta = {
      'nonce': base64Encode(encrypted['nonce']),
    };
    if (kind == AttachmentKind.video) {
      final videoMeta = await getVideoMetadata(file);
      meta.addAll(videoMeta);
    }

    // 1. Request Upload URLs
    final response = await http.post(
      Uri.parse('${relay.apiUrl}/media/upload-url'),
      headers: {'Content-Type': 'application/json', 'x-public-id': identity.publicId},
      body: jsonEncode({
        'size': (encrypted['ciphertext'] as Uint8List).length,
        'mime': _getMime(kind),
        'hash': encrypted['hash'],
      }),
    );

    if (response.statusCode != 201) throw Exception('Upload request failed: ${response.body}');
    final data = jsonDecode(response.body);
    final String mediaId = data['mediaId'];
    final String uploadUrl = data['uploadUrl'];
    final String thumbUrl = data['thumbUrl'];

    // 2. PUT Bulk File
    await http.put(Uri.parse(uploadUrl), body: encrypted['ciphertext']);
    _logger.i('GHOST_LOG: MEDIA_BLOB_PUT_SUCCESS id: $mediaId');

    // 3. Handle Thumbnail
    String? thumbNonceBase64;
    if (kind == AttachmentKind.image || kind == AttachmentKind.video) {
      final thumbBytes = kind == AttachmentKind.image 
        ? await generateImageThumbnail(file)
        : await generateVideoThumbnail(file);
        
      final encryptedThumb = await encryptMedia(thumbBytes, messageKey);
      await http.put(Uri.parse(thumbUrl), body: encryptedThumb['ciphertext']);
      thumbNonceBase64 = base64Encode(encryptedThumb['nonce']);
      meta['thumb_nonce'] = thumbNonceBase64;
      _logger.i('GHOST_LOG: MEDIA_THUMB_PUT_SUCCESS');
    }

    // 4. Confirm Upload
    await http.post(
      Uri.parse('${relay.apiUrl}/media/confirm/$mediaId'),
      headers: {'x-public-id': identity.publicId},
    );
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_CONFIRMED');

    // 5. Wrap Key
    final wrappedKey = sodium.crypto.box.seal(
      message: messageKey.extractBytes(),
      publicKey: recipientXid,
    );

    _logger.i('GHOST_LOG: MEDIA_UPLOAD_SUCCESS');

    return AttachmentEnvelope(
      kind: kind,
      mediaId: mediaId,
      encryptedKey: base64Encode(wrappedKey),
      hash: encrypted['hash'],
      name: p.basename(file.path),
      meta: meta,
    );
  }

  Future<Uint8List> downloadMedia({
    required AttachmentEnvelope envelope,
    required RelayProfile relay,
    required KeyPair myXidKeyPair,
    bool isThumbnail = false,
  }) async {
    _logger.i('GHOST_LOG: MEDIA_DOWNLOAD_START isThumb: $isThumbnail');
    final response = await http.get(Uri.parse('${relay.apiUrl}/media/download-url/${envelope.mediaId}'));
    if (response.statusCode != 200) throw Exception('Download request failed');

    final data = jsonDecode(response.body);
    String downloadUrl = data['downloadUrl'];
    if (isThumbnail) {
      downloadUrl = downloadUrl.replaceFirst('/media/', '/thumbs/');
    }

    final getResponse = await http.get(Uri.parse(downloadUrl));
    if (getResponse.statusCode != 200) throw Exception('R2 Download failed');
    _logger.i('GHOST_LOG: MEDIA_DOWNLOAD_SUCCESS');

    final messageKeyBytes = sodium.crypto.box.sealOpen(
      cipherText: base64Decode(envelope.encryptedKey),
      publicKey: myXidKeyPair.publicKey,
      secretKey: myXidKeyPair.secretKey,
    );
    final messageKey = SecureKey.fromList(sodium, messageKeyBytes);

    final String? nonceBase64 = isThumbnail 
        ? (envelope.meta?['thumb_nonce'] as String?) 
        : (envelope.meta?['nonce'] as String?);
    
    if (nonceBase64 == null) throw Exception('Missing nonce');

    _logger.i('GHOST_LOG: MEDIA_DECRYPT_START isThumb: $isThumbnail');
    final decrypted = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: getResponse.bodyBytes,
      nonce: base64Decode(nonceBase64),
      key: messageKey,
    );
    _logger.i('GHOST_LOG: MEDIA_DECRYPT_SUCCESS isThumb: $isThumbnail');

    if (!isThumbnail) {
      final actualHash = crypto.sha256.convert(decrypted).toString();
      if (actualHash != envelope.hash) throw Exception('Integrity check failed');
      _logger.i('GHOST_LOG: MEDIA_INTEGRITY_CHECK_SUCCESS');
    }

    return decrypted;
  }

  String _getMime(AttachmentKind kind) {
    switch (kind) {
      case AttachmentKind.image: return 'image/jpeg';
      case AttachmentKind.video: return 'video/mp4';
      default: return 'application/octet-stream';
    }
  }
}
