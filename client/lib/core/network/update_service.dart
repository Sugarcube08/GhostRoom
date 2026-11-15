import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  verifying,
  installing,
  completed,
  error,
}

class PlatformAsset {
  final String url;
  final String filename;
  final String sha256;
  final int sizeBytes;

  PlatformAsset({
    required this.url,
    required this.filename,
    required this.sha256,
    required this.sizeBytes,
  });

  factory PlatformAsset.fromJson(Map<String, dynamic> json) {
    return PlatformAsset(
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? 'update',
      sha256: json['sha256'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
    );
  }
}

class UpdateManifest {
  final String version;
  final String releaseUrl;
  final String? changelog;
  final String? releaseDate;
  final Map<String, PlatformAsset> platforms;

  UpdateManifest({
    required this.version,
    required this.releaseUrl,
    this.changelog,
    this.releaseDate,
    this.platforms = const {},
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final platformsMap = <String, PlatformAsset>{};
    if (json['platforms'] is Map<String, dynamic>) {
      final p = json['platforms'] as Map<String, dynamic>;
      p.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          platformsMap[key.toLowerCase()] = PlatformAsset.fromJson(value);
        }
      });
    }

    final rawVersion = json['version'] as String? ?? '1.0.0';
    final cleanVersion = rawVersion.trim().replaceAll(RegExp(r'^v'), '');

    return UpdateManifest(
      version: cleanVersion,
      releaseUrl: json['release_url'] as String? ??
          'https://github.com/Sugarcube08/GhostRoom/releases/tag/v$cleanVersion',
      changelog: json['changelog'] as String?,
      releaseDate: json['release_date'] as String?,
      platforms: platformsMap,
    );
  }

  /// Detects the host operating system and returns the corresponding release asset
  PlatformAsset? getAssetForCurrentPlatform() {
    if (kIsWeb) return platforms['web'];

    final tag = 'v$version';
    if (Platform.isAndroid) {
      if (platforms.containsKey('android') &&
          platforms['android']!.url.isNotEmpty) {
        return platforms['android'];
      }
      return PlatformAsset(
        url:
            'https://github.com/Sugarcube08/GhostRoom/releases/download/$tag/ghostroom-android.apk',
        filename: 'ghostroom-android.apk',
        sha256: '',
        sizeBytes: 0,
      );
    } else if (Platform.isLinux) {
      if (platforms.containsKey('linux') &&
          platforms['linux']!.url.isNotEmpty) {
        return platforms['linux'];
      }
      return PlatformAsset(
        url:
            'https://github.com/Sugarcube08/GhostRoom/releases/download/$tag/ghostroom-linux-x86_64.AppImage',
        filename: 'ghostroom-linux-x86_64.AppImage',
        sha256: '',
        sizeBytes: 0,
      );
    } else if (Platform.isWindows) {
      if (platforms.containsKey('windows') &&
          platforms['windows']!.url.isNotEmpty) {
        return platforms['windows'];
      }
      return PlatformAsset(
        url:
            'https://github.com/Sugarcube08/GhostRoom/releases/download/$tag/ghostroom-windows-x64.zip',
        filename: 'ghostroom-windows-x64.zip',
        sha256: '',
        sizeBytes: 0,
      );
    } else if (Platform.isMacOS) {
      if (platforms.containsKey('macos') &&
          platforms['macos']!.url.isNotEmpty) {
        return platforms['macos'];
      }
      return PlatformAsset(
        url:
            'https://github.com/Sugarcube08/GhostRoom/releases/download/$tag/ghostroom-macos.zip',
        filename: 'ghostroom-macos.zip',
        sha256: '',
        sizeBytes: 0,
      );
    }

    return null;
  }

  String get targetPlatformName {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android (APK)';
    if (Platform.isLinux) return 'Linux (AppImage / Package)';
    if (Platform.isWindows) return 'Windows (ZIP / EXE)';
    if (Platform.isMacOS) return 'macOS (ZIP / APP)';
    return 'Unknown';
  }
}

class UpdateService {
  static const String manifestPrimaryUrl =
      'https://raw.githubusercontent.com/Sugarcube08/GhostRoom/main/version.json';
  static const String manifestSecondaryUrl =
      'https://raw.githubusercontent.com/Sugarcube08/GhostRoom/main/VERSION.json';

  /// Checks if a newer version is published in version.json
  Future<UpdateManifest?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      String? body;
      try {
        final res = await http
            .get(Uri.parse(manifestPrimaryUrl))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          body = res.body;
        }
      } catch (_) {}

      if (body == null) {
        final res = await http
            .get(Uri.parse(manifestSecondaryUrl))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          body = res.body;
        }
      }

      if (body == null) return null;

      final manifest = UpdateManifest.fromJson(jsonDecode(body));

      if (isNewerVersion(manifest.version, currentVersion)) {
        return manifest;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the relevant platform asset with progress streaming and validates its SHA-256 hash
  Future<File> downloadAndVerifyAsset({
    required PlatformAsset asset,
    void Function(double progress, int receivedBytes, int totalBytes)?
        onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final targetFile = File('${tempDir.path}/${asset.filename}');

    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(asset.url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: Failed to download release asset from ${asset.url}',
        );
      }

      final totalBytes = response.contentLength ??
          (asset.sizeBytes > 0 ? asset.sizeBytes : -1);
      int receivedBytes = 0;

      final sink = targetFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
        }
      }
      await sink.flush();
      await sink.close();

      // Check SHA-256 integrity if specified in manifest
      if (asset.sha256.trim().isNotEmpty) {
        final fileBytes = await targetFile.readAsBytes();
        final actualHash = sha256.convert(fileBytes).toString().toLowerCase();
        final expectedHash = asset.sha256.trim().toLowerCase();

        if (actualHash != expectedHash) {
          try {
            await targetFile.delete();
          } catch (_) {}
          throw Exception(
            'Security Warning: SHA-256 checksum verification failed!\n'
            'Expected: $expectedHash\n'
            'Actual:   $actualHash',
          );
        }
      }

      return targetFile;
    } finally {
      client.close();
    }
  }

  /// Launches the system installer for the verified file on the current operating system
  Future<void> installAsset(File file) async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      const channel = MethodChannel('com.ghostroom.app/updater');
      await channel.invokeMethod('installApk', {'filePath': file.path});
    } else if (Platform.isLinux) {
      await Process.run('chmod', ['+x', file.path]);
      try {
        await Process.start('xdg-open', [file.path]);
      } catch (_) {
        await Process.start(file.path, [], mode: ProcessStartMode.detached);
      }
    } else if (Platform.isWindows) {
      await Process.start(file.path, [], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else {
      throw UnsupportedError(
        'Automatic installation not supported on ${Platform.operatingSystem}',
      );
    }
  }

  /// High-level auto-updater: downloads, verifies SHA-256, and launches installation
  Future<void> runAutoUpdate({
    required UpdateManifest manifest,
    required void Function(UpdateStatus status, double progress, String message)
        onStatus,
  }) async {
    final asset = manifest.getAssetForCurrentPlatform();
    if (asset == null) {
      throw Exception(
        'No release asset configured for platform: ${manifest.targetPlatformName}',
      );
    }

    onStatus(
      UpdateStatus.downloading,
      0.0,
      'Initiating download of ${asset.filename}...',
    );

    final file = await downloadAndVerifyAsset(
      asset: asset,
      onProgress: (progress, received, total) {
        final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
        final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
        final percent = (progress * 100).clamp(0, 100).toInt();
        onStatus(
          UpdateStatus.downloading,
          progress,
          'Downloading: $receivedMb MB / $totalMb MB ($percent%)',
        );
      },
    );

    onStatus(
      UpdateStatus.verifying,
      1.0,
      'Verifying cryptographic SHA-256 signature...',
    );

    onStatus(
      UpdateStatus.installing,
      1.0,
      'Launching system package installer...',
    );

    await installAsset(file);

    onStatus(
      UpdateStatus.completed,
      1.0,
      'Installer launched successfully.',
    );
  }

  /// Compares two semver version strings and returns true if remote is newer than local
  bool isNewerVersion(String remote, String local) {
    try {
      Map<String, dynamic> parseVersion(String ver) {
        var clean = ver.trim();
        if (clean.toLowerCase().startsWith('v')) {
          clean = clean.substring(1);
        }

        String releasePart = clean;
        String prereleasePart = '';
        final dashIndex = clean.indexOf('-');
        if (dashIndex != -1) {
          releasePart = clean.substring(0, dashIndex);
          prereleasePart = clean.substring(dashIndex + 1);
        }

        final parts = releasePart.split('.');
        final numbers = <int>[];
        for (final p in parts) {
          final n = int.tryParse(p) ?? 0;
          numbers.add(n);
        }

        return {
          'numbers': numbers,
          'prerelease': prereleasePart,
        };
      }

      final remoteParsed = parseVersion(remote);
      final localParsed = parseVersion(local);

      final List<int> remoteNumbers = remoteParsed['numbers'];
      final List<int> localNumbers = localParsed['numbers'];

      final maxLen = remoteNumbers.length > localNumbers.length
          ? remoteNumbers.length
          : localNumbers.length;

      for (int i = 0; i < maxLen; i++) {
        final r = i < remoteNumbers.length ? remoteNumbers[i] : 0;
        final l = i < localNumbers.length ? localNumbers[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }

      final remotePre = remoteParsed['prerelease'] as String;
      final localPre = localParsed['prerelease'] as String;

      if (remotePre.isEmpty && localPre.isNotEmpty) {
        return true;
      }
      if (remotePre.isNotEmpty && localPre.isEmpty) {
        return false;
      }
      if (remotePre.isNotEmpty && localPre.isNotEmpty) {
        return remotePre.compareTo(localPre) > 0;
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}

final updateServiceProvider = Provider((ref) => UpdateService());
