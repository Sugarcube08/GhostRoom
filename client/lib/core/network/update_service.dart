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
    List<int> remoteParts = remote.split('.').map(int.parse).toList();
    List<int> localParts = local.split('.').map(int.parse).toList();

    for (int i = 0; i < remoteParts.length; i++) {
      if (i >= localParts.length) return true;
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return false;
  }
}

final updateServiceProvider = Provider((ref) => UpdateService());
