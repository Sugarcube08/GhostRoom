import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../core/network/relay_manager.dart';
import '../../core/crypto/identity_service.dart';
import 'attachment_envelope.dart';

class MediaService {
  final SodiumSumo sodium;
  final IdentityService _idService;

  MediaService(this.sodium, this._idService);

  Future<File> compressImage(File file) async {
    
    // Skip compression on desktop (libraries not supported)
    if (!Platform.isAndroid && !Platform.isIOS) {
      return file;
    }

    try {
      final ext = p.extension(file.path).toLowerCase();
      final isJpeg = ext == '.jpg' || ext == '.jpeg';
      final targetName = 'compressed_${p.basenameWithoutExtension(file.path)}${isJpeg ? ext : '.jpg'}';
      final targetPath = p.join(p.dirname(file.path), targetName);
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg,
      ).timeout(const Duration(seconds: 30));
      
      if (result == null) throw Exception('FlutterImageCompress returned null');
      final compressedFile = File(result.path);
      return compressedFile;
    } catch (e) {
      return file;
    }
  }

  Future<Uint8List> generateImageThumbnail(File file) async {
    // Basic fallback for desktop
    if (!Platform.isAndroid && !Platform.isIOS) {
      return await file.readAsBytes(); // Just use original as thumb on desktop for now
    }

    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 100,
        minHeight: 100,
        quality: 50,
        format: CompressFormat.jpeg,
      ).timeout(const Duration(seconds: 30));
      if (result == null) throw Exception('FlutterImageCompress returned null');
      return result;
    } catch (e) {
      return await file.readAsBytes();
    }
  }

  Future<File> compressVideo(File file) async {
    
    if (!Platform.isAndroid && !Platform.isIOS) {
      return file;
    }

    try {
      // video_compress handles 720p / H264 via qualities.
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
      ).timeout(const Duration(seconds: 30));
      if (info == null || info.file == null) throw Exception('VideoCompress returned null');
      return info.file!;
    } catch (e) {
      return file;
    }
  }

  Future<Uint8List> generateVideoThumbnail(File file) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Hard fallback: we might need a desktop-compatible way to get a video frame
      // For now, return empty or a placeholder if desktop
      return Uint8List(0);
    }
    try {
      final result = await VideoCompress.getByteThumbnail(file.path, quality: 50)
          .timeout(const Duration(seconds: 30));
      if (result == null) throw Exception('VideoCompress.getByteThumbnail returned null');
      return result;
    } catch (e) {
      return Uint8List(0);
    }
  }

  Future<Map<String, dynamic>> getVideoMetadata(File file) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return {
        'duration': 0,
        'w': 0,
        'h': 0,
        'fps': 30,
      };
    }
    final info = await VideoCompress.getMediaInfo(file.path);
    return {
      'duration': info.duration, // ms
      'w': info.width,
      'h': info.height,
      'fps': 30, // Default assumption if not provided
    };
  }

  Future<Map<String, dynamic>> encryptMedia(Uint8List plaintext, SecureKey? existingKey) async {
    final messageKey = existingKey ?? sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: messageKey,
    );
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
    if (actualHash != expectedHash) throw Exception('Integrity check failed: Hash mismatch');
    return decrypted;
  }

  Future<(AttachmentEnvelope, Uint8List?)> uploadMedia({
    required File file,
    required AttachmentKind kind,
    required RelayProfile relay,
    required Uint8List recipientXid,
    String? messageId,
  }) async {
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
    final response = await _retryHttp(() => http.post(
      Uri.parse('${relay.apiUrl}/media/upload-url'),
      headers: {'Content-Type': 'application/json', 'x-public-id': identity.publicId},
      body: jsonEncode({
        'size': (encrypted['ciphertext'] as Uint8List).length,
        'mime': _getMime(kind),
        'hash': encrypted['hash'],
      }),
    ));

    if (response.statusCode != 201) throw Exception('Upload request failed: ${response.body}');
    final data = jsonDecode(response.body);
    final String mediaId = data['mediaId'];
    final String uploadUrl = data['uploadUrl'];
    final String thumbUrl = data['thumbUrl'];

    // 2. PUT Bulk File
    await _retryHttp(() => http.put(Uri.parse(uploadUrl), body: encrypted['ciphertext']));

    // 3. Handle Thumbnail
    String? thumbNonceBase64;
    Uint8List? thumbnailBytes;
    if (kind == AttachmentKind.image || kind == AttachmentKind.video) {
      final thumbBytes = kind == AttachmentKind.image 
        ? await generateImageThumbnail(file)
        : await generateVideoThumbnail(file);
        
      thumbnailBytes = thumbBytes;
      final encryptedThumb = await encryptMedia(thumbBytes, messageKey);
      await _retryHttp(() => http.put(Uri.parse(thumbUrl), body: encryptedThumb['ciphertext']));
      thumbNonceBase64 = base64Encode(encryptedThumb['nonce']);
      meta['thumb_nonce'] = thumbNonceBase64;
    }

    // 4. Confirm Upload
    await _retryHttp(() => http.post(
      Uri.parse('${relay.apiUrl}/media/confirm/$mediaId'),
      headers: {'x-public-id': identity.publicId},
    ));

    // 5. Wrap Key
    final wrappedKey = sodium.crypto.box.seal(
      message: messageKey.extractBytes(),
      publicKey: recipientXid,
    );


    final envelope = AttachmentEnvelope(
      kind: kind,
      mediaId: mediaId,
      encryptedKey: base64Encode(wrappedKey),
      hash: encrypted['hash'],
      name: p.basename(file.path),
      meta: meta,
    );

    return (envelope, thumbnailBytes);
  }

  Future<http.Response> _retryHttp(Future<http.Response> Function() call, {int maxAttempts = 3}) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        attempts++;
        final response = await call();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        if (attempts >= maxAttempts) return response;
      } catch (e) {
        if (attempts >= maxAttempts) rethrow;
      }
      await Future.delayed(Duration(seconds: attempts * 2));
    }
    throw Exception('HTTP retry failed after $maxAttempts attempts');
  }

  Future<Uint8List> downloadMedia({
    required AttachmentEnvelope envelope,
    required RelayProfile relay,
    required KeyPair myXidKeyPair,
    bool isThumbnail = false,
  }) async {
    final urlString = isThumbnail 
        ? '${relay.apiUrl}/media/download-url/${envelope.mediaId}?thumbnail=true'
        : '${relay.apiUrl}/media/download-url/${envelope.mediaId}';
    final response = await http.get(Uri.parse(urlString));
    if (response.statusCode != 200) throw Exception('Download request failed');

    final data = jsonDecode(response.body);
    final String downloadUrl = data['downloadUrl'];

    final getResponse = await http.get(Uri.parse(downloadUrl));
    if (getResponse.statusCode != 200) throw Exception('R2 Download failed');

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

    final decrypted = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: getResponse.bodyBytes,
      nonce: base64Decode(nonceBase64),
      key: messageKey,
    );

    if (!isThumbnail) {
      final actualHash = crypto.sha256.convert(decrypted).toString();
      if (actualHash != envelope.hash) throw Exception('Integrity check failed');
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
