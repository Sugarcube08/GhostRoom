import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateManifest {
  final String version;
  final String releaseUrl;
  final String? changelog;

  UpdateManifest({
    required this.version,
    required this.releaseUrl,
    this.changelog,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      version: json['version'] as String,
      releaseUrl: json['release_url'] as String,
      changelog: json['changelog'] as String?,
    );
  }
}

class UpdateService {
  final Logger _logger = Logger();
  
  // Official repository version manifest
  static const String manifestUrl = 'https://raw.githubusercontent.com/Sugarcube08/GhostRoom/main/VERSION.json';

  Future<UpdateManifest?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      _logger.d('Checking for update. Current version: $currentVersion');

      final response = await http.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _logger.w('Failed to fetch version manifest: ${response.statusCode}');
        return null;
      }

      final manifest = UpdateManifest.fromJson(jsonDecode(response.body));
      
      if (_isNewer(manifest.version, currentVersion)) {
        _logger.i('New version available: ${manifest.version}');
        return manifest;
      }
      
      return null;
    } catch (e) {
      _logger.e('Error checking for update: $e');
      return null;
    }
  }

  bool _isNewer(String remote, String local) {
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
