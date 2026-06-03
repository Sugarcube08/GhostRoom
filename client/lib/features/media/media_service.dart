import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  MediaService(this.sodium, this._idService);

  Future<File> compressImage(File file) async {
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_START kind: image source_size: ${file.lengthSync()}');
    
    // Skip compression on desktop (libraries not supported)
    if (!Platform.isAndroid && !Platform.isIOS) {
      _logger.i('GHOST_LOG: MEDIA_COMPRESS_SKIP (Desktop platform)');
      _logger.i('GHOST_LOG: MEDIA_COMPRESSED size: ${file.lengthSync()}');
      return file;
    }

    final ext = p.extension(file.path).toLowerCase();
    final isJpeg = ext == '.jpg' || ext == '.jpeg';
    final targetName = 'compressed_${p.basenameWithoutExtension(file.path)}${isJpeg ? ext : '.jpg'}';
    final targetPath = p.join(p.dirname(file.path), targetName);
    
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (result == null) throw Exception('Image compression failed');
    final compressedFile = File(result.path);
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_SUCCESS compressed_size: ${compressedFile.lengthSync()}');
    _logger.i('GHOST_LOG: MEDIA_COMPRESSED size: ${compressedFile.lengthSync()}');
    return compressedFile;
  }

  Future<Uint8List> generateImageThumbnail(File file) async {
    // Basic fallback for desktop
    if (!Platform.isAndroid && !Platform.isIOS) {
      return await file.readAsBytes(); // Just use original as thumb on desktop for now
    }

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
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_START kind: video source_size: ${file.lengthSync()}');
    
    if (!Platform.isAndroid && !Platform.isIOS) {
      _logger.i('GHOST_LOG: MEDIA_COMPRESS_SKIP (Desktop platform)');
      _logger.i('GHOST_LOG: MEDIA_COMPRESSED size: ${file.lengthSync()}');
      return file;
    }

    // video_compress handles 720p / H264 via qualities.
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.Res1280x720Quality,
      deleteOrigin: false,
      includeAudio: true,
    );
    if (info == null || info.file == null) throw Exception('Video compression failed');
    _logger.i('GHOST_LOG: MEDIA_COMPRESS_SUCCESS compressed_size: ${info.file!.lengthSync()}');
    _logger.i('GHOST_LOG: MEDIA_COMPRESSED size: ${info.file!.lengthSync()}');
    return info.file!;
  }

  Future<Uint8List> generateVideoThumbnail(File file) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Hard fallback: we might need a desktop-compatible way to get a video frame
      // For now, return empty or a placeholder if desktop
      return Uint8List(0);
    }
    final result = await VideoCompress.getByteThumbnail(file.path, quality: 50);
    if (result == null) throw Exception('Video thumbnail failed');
    return result;
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
    _logger.i('GHOST_LOG: MEDIA_ENCRYPT_START size: ${plaintext.length}');
    final messageKey = existingKey ?? sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: messageKey,
    );
    final hash = crypto.sha256.convert(plaintext).toString();
    _logger.i('GHOST_LOG: MEDIA_ENCRYPT_SUCCESS hash: $hash');
    _logger.i('GHOST_LOG: MEDIA_ENCRYPTED hash: $hash');

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

  Future<(AttachmentEnvelope, Uint8List?)> uploadMedia({
    required File file,
    required AttachmentKind kind,
    required RelayProfile relay,
    required Uint8List recipientXid,
  }) async {
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_START kind: ${kind.name}');
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_START');
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
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_STEP_URL_START');
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
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_STEP_BLOB_START id: $mediaId');
    await _retryHttp(() => http.put(Uri.parse(uploadUrl), body: encrypted['ciphertext']));
    _logger.i('GHOST_LOG: MEDIA_BLOB_PUT_SUCCESS id: $mediaId');

    // 3. Handle Thumbnail
    String? thumbNonceBase64;
    Uint8List? thumbnailBytes;
    if (kind == AttachmentKind.image || kind == AttachmentKind.video) {
      _logger.i('GHOST_LOG: MEDIA_UPLOAD_STEP_THUMB_START');
      final thumbBytes = kind == AttachmentKind.image 
        ? await generateImageThumbnail(file)
        : await generateVideoThumbnail(file);
        
      thumbnailBytes = thumbBytes;
      _logger.i('GHOST_LOG: MEDIA_THUMBNAIL_SUCCESS');
      final encryptedThumb = await encryptMedia(thumbBytes, messageKey);
      await _retryHttp(() => http.put(Uri.parse(thumbUrl), body: encryptedThumb['ciphertext']));
      thumbNonceBase64 = base64Encode(encryptedThumb['nonce']);
      meta['thumb_nonce'] = thumbNonceBase64;
      _logger.i('GHOST_LOG: MEDIA_THUMB_PUT_SUCCESS');
    }

    // 4. Confirm Upload
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_STEP_CONFIRM_START');
    await _retryHttp(() => http.post(
      Uri.parse('${relay.apiUrl}/media/confirm/$mediaId'),
      headers: {'x-public-id': identity.publicId},
    ));
    _logger.i('GHOST_LOG: MEDIA_UPLOAD_CONFIRMED');
    _logger.i('GHOST_LOG: MEDIA_UPLOADED id: $mediaId');

    // 5. Wrap Key
    final wrappedKey = sodium.crypto.box.seal(
      message: messageKey.extractBytes(),
      publicKey: recipientXid,
    );

    _logger.i('GHOST_LOG: MEDIA_UPLOAD_SUCCESS');

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
        _logger.w('GHOST_LOG: HTTP_RETRY attempt: $attempts code: ${response.statusCode}');
      } catch (e) {
        if (attempts >= maxAttempts) rethrow;
        _logger.w('GHOST_LOG: HTTP_RETRY_ERROR attempt: $attempts error: $e');
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
    _logger.i('GHOST_LOG: MEDIA_DOWNLOAD_START isThumb: $isThumbnail');
    final urlString = isThumbnail 
        ? '${relay.apiUrl}/media/download-url/${envelope.mediaId}?thumbnail=true'
        : '${relay.apiUrl}/media/download-url/${envelope.mediaId}';
    final response = await http.get(Uri.parse(urlString));
    if (response.statusCode != 200) throw Exception('Download request failed');

    final data = jsonDecode(response.body);
    final String downloadUrl = data['downloadUrl'];

    final getResponse = await http.get(Uri.parse(downloadUrl));
    if (getResponse.statusCode != 200) throw Exception('R2 Download failed');
    _logger.i('GHOST_LOG: MEDIA_DOWNLOAD_SUCCESS');
    _logger.i('GHOST_LOG: MEDIA_DOWNLOADED isThumb: $isThumbnail');

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
    _logger.i('GHOST_LOG: MEDIA_DECRYPTED isThumb: $isThumbnail');

    if (!isThumbnail) {
      final actualHash = crypto.sha256.convert(decrypted).toString();
      _logger.i('GHOST_LOG: MEDIA_INTEGRITY_CHECK_START expected: ${envelope.hash} actual: $actualHash');
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
