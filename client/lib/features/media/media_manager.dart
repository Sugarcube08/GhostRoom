import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:sodium/sodium_sumo.dart' hide Box;
import 'package:crypto/crypto.dart' as crypto;
import 'attachment_envelope.dart';
import '../../core/network/relay_manager.dart';
import 'media_service.dart';
import '../../core/storage/storage_directory_helper.dart';

import 'lru_memory_cache.dart';

// ignore_for_file: constant_identifier_names
enum MediaState {
  NOT_DOWNLOADED,
  DOWNLOADING,
  DECRYPTING,
  VERIFYING,
  READY,
  FAILED,
}

class MediaStateUpdate {
  final String mediaId;
  final MediaState state;
  final bool isThumbnail;
  MediaStateUpdate(this.mediaId, this.state, {this.isThumbnail = false});
}

class CachedMedia {
  final String mediaId;
  final String localPath;
  final String checksum;
  final int size;
  final DateTime downloadedAt;
  final bool isThumbnail;

  CachedMedia({
    required this.mediaId,
    required this.localPath,
    required this.checksum,
    required this.size,
    required this.downloadedAt,
    required this.isThumbnail,
  });

  Map<String, dynamic> toMap() {
    return {
      'mediaId': mediaId,
      'localPath': localPath,
      'checksum': checksum,
      'size': size,
      'downloadedAt': downloadedAt.toIso8601String(),
      'isThumbnail': isThumbnail,
    };
  }

  factory CachedMedia.fromMap(Map<dynamic, dynamic> map) {
    return CachedMedia(
      mediaId: map['mediaId'] as String,
      localPath: map['localPath'] as String,
      checksum: map['checksum'] as String,
      size: map['size'] as int,
      downloadedAt: DateTime.parse(map['downloadedAt'] as String),
      isThumbnail: map['isThumbnail'] as bool? ?? false,
    );
  }
}

class MediaManager {
  final SodiumSumo _sodium;
  final MediaService _mediaService;

  late final Directory _originalsDir;
  late final Directory _thumbsDir;
  late final Directory _tempDir;
  late final Box<dynamic> _cacheIndex;

  final Map<String, Future<File>> _activeDownloads = {};
  
  // Use LRU to bound states. Assuming each string is 50 bytes and state is 8 bytes.
  final LRUMemoryCache<String, MediaState> _states = LRUMemoryCache<String, MediaState>(
    maximumSizeBytes: 10 * 1024 * 1024, // 10MB limit for state cache
    sizeEstimator: (k, v) => k.length + 8,
  );
  
  final LRUMemoryCache<String, MediaState> _thumbStates = LRUMemoryCache<String, MediaState>(
    maximumSizeBytes: 10 * 1024 * 1024, // 10MB limit for thumb state cache
    sizeEstimator: (k, v) => k.length + 8,
  );

  final StreamController<MediaStateUpdate> _stateController =
      StreamController<MediaStateUpdate>.broadcast();
  late final ThumbnailQueue _thumbnailQueue;

  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitializing = false;

  MediaManager(this._sodium, this._mediaService) {
    _thumbnailQueue = ThumbnailQueue(_mediaService, this);
  }

  Stream<MediaStateUpdate> get stateStream => _stateController.stream;

  Future<void> init() async {
    if (_isInitializing) return _initCompleter.future;
    _isInitializing = true;
    try {
      final baseDir = await StorageDirectoryHelper.getBaseDirectory();
      _originalsDir = Directory(p.join(baseDir.path, 'media', 'originals'));
      _thumbsDir = Directory(p.join(baseDir.path, 'media', 'thumbs'));
      _tempDir = Directory(p.join(baseDir.path, 'media', 'temp'));

      await _originalsDir.create(recursive: true);
      await _thumbsDir.create(recursive: true);
      await _tempDir.create(recursive: true);

      _cacheIndex = await Hive.openBox<dynamic>('media_cache_index');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e, stackTrace) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initCompleter.isCompleted) {
      await init();
    }
  }

  MediaState getMediaState(String mediaId, {bool isThumbnail = false}) {
    if (!_initCompleter.isCompleted) {
      return MediaState.NOT_DOWNLOADED;
    }
    final state = isThumbnail ? _thumbStates.get(mediaId) : _states.get(mediaId);
    if (state != null) return state;

    final key = '${mediaId}_${isThumbnail ? 'thumb' : 'original'}';
    final cached = _cacheIndex.get(key);
    if (cached != null) {
      final cachedMedia = CachedMedia.fromMap(cached as Map);
      if (File(cachedMedia.localPath).existsSync()) {
        return MediaState.READY;
      }
    }
    return MediaState.NOT_DOWNLOADED;
  }

  Future<bool> isThumbnailCached(String mediaId) async {
    await _ensureInitialized();
    final key = '${mediaId}_thumb';
    final cached = _cacheIndex.get(key);
    if (cached != null) {
      final cachedMedia = CachedMedia.fromMap(cached as Map);
      return File(cachedMedia.localPath).exists();
    }
    return false;
  }

  Future<void> saveThumbnailDirectly(
    String mediaId,
    Uint8List thumbBytes,
  ) async {
    await _ensureInitialized();
    final extension = '.jpg';
    final targetPath = p.join(_thumbsDir.path, '$mediaId$extension');

    // Atomic write
    final tempFile = File(
      p.join(
        _tempDir.path,
        '${mediaId}_thumb_${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await tempFile.writeAsBytes(thumbBytes, flush: true);

    // Rename to final location
    final finalFile = File(targetPath);
    await tempFile.rename(finalFile.path);

    final entry = CachedMedia(
      mediaId: mediaId,
      localPath: finalFile.path,
      checksum: crypto.sha256.convert(thumbBytes).toString(),
      size: thumbBytes.length,
      downloadedAt: DateTime.now(),
      isThumbnail: true,
    );
    await _cacheIndex.put('${mediaId}_thumb', entry.toMap());
    _updateState(mediaId, MediaState.READY, isThumbnail: true);
  }

  bool _isValidTransition(MediaState? from, MediaState to) {
    if (from == null) return true;
    if (from == to) return true;
    switch (from) {
      case MediaState.NOT_DOWNLOADED:
        return to == MediaState.DOWNLOADING || to == MediaState.READY || to == MediaState.FAILED;
      case MediaState.DOWNLOADING:
        return to == MediaState.DECRYPTING || to == MediaState.FAILED;
      case MediaState.DECRYPTING:
        return to == MediaState.VERIFYING || to == MediaState.FAILED;
      case MediaState.VERIFYING:
        return to == MediaState.READY || to == MediaState.FAILED;
      case MediaState.READY:
        return to == MediaState.NOT_DOWNLOADED;
      case MediaState.FAILED:
        return to == MediaState.DOWNLOADING || to == MediaState.NOT_DOWNLOADED;
    }
  }

  void _updateState(
    String mediaId,
    MediaState state, {
    bool isThumbnail = false,
  }) {
    final currentState = isThumbnail ? _thumbStates.get(mediaId) : _states.get(mediaId);
    if (currentState == state) return;

    if (!_isValidTransition(currentState, state)) {
    }
    assert(
      _isValidTransition(currentState, state),
      'GHOST_ERROR: Invalid MediaState transition from ${currentState?.name ?? "null"} to ${state.name} for media $mediaId isThumb $isThumbnail',
    );

    if (isThumbnail) {
      _thumbStates.put(mediaId, state);
    } else {
      _states.put(mediaId, state);
    }
    _stateController.add(
      MediaStateUpdate(mediaId, state, isThumbnail: isThumbnail),
    );
  }

  Future<File> getMedia({
    required AttachmentEnvelope envelope,
    required RelayProfile relay,
    required KeyPair myXidKeyPair,
    bool isThumbnail = false,
    String? messageId,
  }) {
    final key = '${envelope.mediaId}_${isThumbnail ? 'thumb' : 'original'}';

    // Use federation hint if available, otherwise fallback to active relay
    RelayProfile targetRelay = relay;
    if (envelope.relayUrl != null) {
      // Create a temporary profile for the federated relay if different
      if (envelope.relayUrl != relay.apiUrl) {
        targetRelay = RelayProfile(
          id: envelope.relayUrl!,
          label: 'Federated Relay',
          apiUrl: envelope.relayUrl!,
          websocketUrl: envelope.relayUrl!.replaceFirst('http', 'ws'),
        );
      }
    }

    // Check active downloads (Critical Rule #1)
    return _activeDownloads.putIfAbsent(key, () async {
      await _ensureInitialized();
      try {
        // Local cache lookup (Critical Rule #2 & #3)
        final cached = _cacheIndex.get(key);
        if (cached != null) {
          final cachedMedia = CachedMedia.fromMap(cached as Map);
          final file = File(cachedMedia.localPath);
          if (await file.exists()) {
            _updateState(
              envelope.mediaId,
              MediaState.READY,
              isThumbnail: isThumbnail,
            );
            return file;
          }
        }

        // Cache miss -> Trigger pipeline (Critical Rule #8: retry policy is wrapped inside _downloadAndProcess)
        final file = await _downloadAndProcess(
          envelope: envelope,
          relay: targetRelay,
          myXidKeyPair: myXidKeyPair,
          isThumbnail: isThumbnail,
          messageId: messageId,
        );

        // Background thumbnail generation (Critical Rule #6)
        if (!isThumbnail &&
            (envelope.kind == AttachmentKind.image ||
                envelope.kind == AttachmentKind.video)) {
          _thumbnailQueue.queue(envelope.mediaId, file, envelope.kind);
        }

        return file;
      } catch (e) {
        _updateState(
          envelope.mediaId,
          MediaState.FAILED,
          isThumbnail: isThumbnail,
        );
        rethrow;
      } finally {
        _activeDownloads.remove(key);
      }
    });
  }

  Future<File> _downloadAndProcess({
    required AttachmentEnvelope envelope,
    required RelayProfile relay,
    required KeyPair myXidKeyPair,
    required bool isThumbnail,
    required String? messageId,
  }) async {
    final mediaId = envelope.mediaId;

    // Retry policy logic (Critical Rule #8)
    int attempts = 0;
    const maxAttempts = 3;
    bool isHashMismatch = false;

    while (attempts < maxAttempts) {
      attempts++;
      File? tempFile;
      try {
        // Step 1: Downloading
        _updateState(mediaId, MediaState.DOWNLOADING, isThumbnail: isThumbnail);

        final urlString = isThumbnail
            ? '${relay.apiUrl}/media/download-url/$mediaId?thumbnail=true'
            : '${relay.apiUrl}/media/download-url/$mediaId';


        final response = await http.get(Uri.parse(urlString));
        if (response.statusCode == 404) {
          throw Exception('404: Media not found'); // Fail immediately
        }
        if (response.statusCode != 200) {
          throw Exception(
            'Download request failed with status: ${response.statusCode}',
          );
        }

        final data = jsonDecode(response.body);
        final String downloadUrl = data['downloadUrl'];

        final getResponse = await http.get(Uri.parse(downloadUrl));
        if (getResponse.statusCode == 404) {
          throw Exception(
            '404: Media file not found in storage',
          ); // Fail immediately
        }
        if (getResponse.statusCode != 200) {
          throw Exception(
            'R2 download failed with status: ${getResponse.statusCode}',
          );
        }

        final ciphertext = getResponse.bodyBytes;

        // Step 2: Decrypting
        _updateState(mediaId, MediaState.DECRYPTING, isThumbnail: isThumbnail);

        late final Uint8List decrypted;
        try {
          final messageKeyBytes = _sodium.crypto.box.sealOpen(
            cipherText: base64Decode(envelope.encryptedKey),
            publicKey: myXidKeyPair.publicKey,
            secretKey: myXidKeyPair.secretKey,
          );
          final messageKey = SecureKey.fromList(_sodium, messageKeyBytes);

          final String? nonceBase64 = isThumbnail
              ? (envelope.meta?['thumb_nonce'] as String?)
              : (envelope.meta?['nonce'] as String?);

          if (nonceBase64 == null) throw Exception('Missing nonce in metadata');

          decrypted = _sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
            cipherText: ciphertext,
            nonce: base64Decode(nonceBase64),
            key: messageKey,
          );
        } catch (e) {
          throw Exception(
            'Decryption failure: $e',
          ); // Fail immediately (Critical Rule #8)
        }

        // Step 3: Verifying
        _updateState(mediaId, MediaState.VERIFYING, isThumbnail: isThumbnail);

        if (!isThumbnail) {
          final actualHash = crypto.sha256.convert(decrypted).toString();
          if (actualHash != envelope.hash) {
            isHashMismatch = true;
            throw Exception(
              'Hash mismatch: expected ${envelope.hash}, got $actualHash',
            );
          }
        }

        // Step 4: Persist (Atomic writes, Critical Rule #4 & #7)
        final extension = _getFileExtension(envelope);
        final baseDir = isThumbnail ? _thumbsDir : _originalsDir;
        final finalFile = File(p.join(baseDir.path, '$mediaId$extension'));

        tempFile = File(
          p.join(
            _tempDir.path,
            '${mediaId}_${isThumbnail ? 'thumb' : 'orig'}_${DateTime.now().microsecondsSinceEpoch}.tmp',
          ),
        );
        await tempFile.writeAsBytes(decrypted, flush: true);

        // Atomically rename
        await tempFile.rename(finalFile.path);

        // Update Index (Critical Rule #3)
        final entry = CachedMedia(
          mediaId: mediaId,
          localPath: finalFile.path,
          checksum: isThumbnail
              ? crypto.sha256.convert(decrypted).toString()
              : envelope.hash,
          size: decrypted.length,
          downloadedAt: DateTime.now(),
          isThumbnail: isThumbnail,
        );
        final indexKey = '${mediaId}_${isThumbnail ? 'thumb' : 'original'}';
        await _cacheIndex.put(indexKey, entry.toMap());

        // Step 5: Ready
        _updateState(mediaId, MediaState.READY, isThumbnail: isThumbnail);
        return finalFile;
      } catch (e) {
        // Clean up temp file if it exists
        if (tempFile != null && await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }

        final errStr = e.toString();
        // Fail immediately rules
        if (errStr.contains('404') || errStr.contains('Decryption failure')) {
          rethrow;
        }

        // Hash mismatch rule: retry once (max 2 attempts total)
        if (isHashMismatch) {
          if (attempts >= 2) {
            rethrow;
          }
          continue;
        }

        // Other network/timeout errors: retry 3x
        if (attempts >= maxAttempts) {
          rethrow;
        }

        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }

    throw Exception('Failed to download and process media');
  }

  String _getFileExtension(AttachmentEnvelope envelope) {
    if (envelope.name != null && envelope.name!.contains('.')) {
      return p.extension(envelope.name!).toLowerCase();
    }
    switch (envelope.kind) {
      case AttachmentKind.image:
        return '.jpg';
      case AttachmentKind.video:
        return '.mp4';
      default:
        return '.bin';
    }
  }

  Future<void> cacheSentMedia({
    required String mediaId,
    required File originalFile,
    required Uint8List? thumbnailBytes,
  }) async {
    await _ensureInitialized();

    // 1. Copy original file to originals directory to prevent it from being deleted if it's in temp or elsewhere
    final extension = p.extension(originalFile.path).toLowerCase();
    final targetOriginalPath = p.join(_originalsDir.path, '$mediaId$extension');
    final finalOriginalFile = File(targetOriginalPath);

    if (originalFile.path != finalOriginalFile.path) {
      if (await originalFile.exists()) {
        try {
          await originalFile.copy(finalOriginalFile.path);
        } catch (_) {
          // Ignore
        }
      }
    }

    final originalEntry = CachedMedia(
      mediaId: mediaId,
      localPath: finalOriginalFile.path,
      checksum: '', // Hash is optional for cache hits
      size: await finalOriginalFile.exists()
          ? await finalOriginalFile.length()
          : 0,
      downloadedAt: DateTime.now(),
      isThumbnail: false,
    );
    await _cacheIndex.put('${mediaId}_original', originalEntry.toMap());
    _updateState(mediaId, MediaState.READY, isThumbnail: false);

    // 2. If thumbnail bytes are present, save them
    if (thumbnailBytes != null) {
      await saveThumbnailDirectly(mediaId, thumbnailBytes);
    }
  }

  Future<void> clearCache() async {
    await _ensureInitialized();
    await _originalsDir.delete(recursive: true);
    await _thumbsDir.delete(recursive: true);
    await _tempDir.delete(recursive: true);
    await _originalsDir.create();
    await _thumbsDir.create();
    await _tempDir.create();
    await _cacheIndex.clear();
    _states.clear();
    _thumbStates.clear();
  }

  Future<void> deleteMedia(String mediaId) async {
    await _ensureInitialized();
    final origKey = '${mediaId}_original';
    final thumbKey = '${mediaId}_thumb';

    final origCached = _cacheIndex.get(origKey);
    if (origCached != null) {
      final cachedMedia = CachedMedia.fromMap(origCached as Map);
      final file = File(cachedMedia.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await _cacheIndex.delete(origKey);
    }

    final thumbCached = _cacheIndex.get(thumbKey);
    if (thumbCached != null) {
      final cachedMedia = CachedMedia.fromMap(thumbCached as Map);
      final file = File(cachedMedia.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await _cacheIndex.delete(thumbKey);
    }

    _states.remove(mediaId);
    _thumbStates.remove(mediaId);
  }

  Map<String, int> getCacheSizes() {
    if (!_initCompleter.isCompleted) return {'thumbnailBytes': 0, 'mediaBytes': 0, 'thumbnailCount': 0, 'mediaCount': 0};
    int thumbBytes = 0;
    int mediaBytes = 0;
    int thumbCount = 0;
    int mediaCount = 0;
    try {
      for (final key in _cacheIndex.keys) {
        final val = _cacheIndex.get(key);
        if (val != null) {
          final cached = CachedMedia.fromMap(val as Map);
          if (cached.isThumbnail) {
            thumbBytes += cached.size;
            thumbCount++;
          } else {
            mediaBytes += cached.size;
            mediaCount++;
          }
        }
      }
    } catch (_) {}
    return {
      'thumbnailBytes': thumbBytes,
      'mediaBytes': mediaBytes,
      'thumbnailCount': thumbCount,
      'mediaCount': mediaCount,
    };
  }

}

class ThumbnailQueue {
  final MediaService _mediaService;
  final MediaManager _mediaManager;
  final List<_ThumbnailTask> _queue = [];
  bool _isProcessing = false;

  ThumbnailQueue(this._mediaService, this._mediaManager);

  void queue(String mediaId, File file, AttachmentKind kind) {
    _queue.add(_ThumbnailTask(mediaId, file, kind));
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;
    final task = _queue.removeAt(0);
    try {
      final exists = await _mediaManager.isThumbnailCached(task.mediaId);
      if (!exists) {
        Uint8List? thumbBytes;
        if (task.kind == AttachmentKind.image) {
          thumbBytes = await _mediaService.generateImageThumbnail(task.file);
        } else if (task.kind == AttachmentKind.video) {
          thumbBytes = await _mediaService.generateVideoThumbnail(task.file);
        }
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          await _mediaManager.saveThumbnailDirectly(task.mediaId, thumbBytes);
        }
      }
    } catch (_) {
      // Ignore
    } finally {
      _isProcessing = false;
      _processNext();
    }
  }
}

class _ThumbnailTask {
  final String mediaId;
  final File file;
  final AttachmentKind kind;
  _ThumbnailTask(this.mediaId, this.file, this.kind);
}
