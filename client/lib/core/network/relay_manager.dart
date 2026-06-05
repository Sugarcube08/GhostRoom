import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class RelayProfile {
  final String id;
  final String label;
  final String websocketUrl;
  final String apiUrl;
  final String? token;

  RelayProfile({
    required this.id,
    required this.label,
    required this.websocketUrl,
    required String apiUrl,
    this.token,
  }) : apiUrl = _normalizeApiUrl(websocketUrl, apiUrl);

  static String _normalizeApiUrl(String wsUrl, String api) {
    final cleanedApi = api.trim();
    if (cleanedApi.isNotEmpty && cleanedApi != '/') return cleanedApi;

    // Derive from websocketUrl
    final ws = wsUrl.trim();
    if (ws.startsWith('wss://')) {
      return ws.replaceFirst('wss://', 'https://');
    } else if (ws.startsWith('ws://')) {
      return ws.replaceFirst('ws://', 'http://');
    } else if (ws.startsWith('https://') || ws.startsWith('http://')) {
      return ws;
    } else if (ws.isNotEmpty) {
      return 'https://$ws';
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'websocketUrl': websocketUrl,
    'apiUrl': apiUrl,
    'token': token,
  };

  factory RelayProfile.fromJson(Map<String, dynamic> json) => RelayProfile(
    id: json['id'] ?? '',
    label: json['label'] ?? '',
    websocketUrl: json['websocketUrl'] ?? '',
    apiUrl: json['apiUrl'] ?? '',
    token: json['token'],
  );
}

class RelayManager {
  final FlutterSecureStorage _storage;
  static const String _relaysKey = 'saved_relays';
  static const String _activeRelayIdKey = 'active_relay_id';
  static const String _recentRoomsKey = 'recent_rooms';

  RelayManager(this._storage);

  /// Pings the relay's API to wake it up (for Render free tier)
  Future<void> wakeUpRelay(RelayProfile profile) async {
    try {
      debugPrint('GHOST_LOG: Waking up relay: ${profile.apiUrl}');
      // We don't care about the response, just that it reaches the server
      final response = await http
          .get(Uri.parse('${profile.apiUrl}/health'))
          .timeout(const Duration(seconds: 5));
      debugPrint(
        'GHOST_LOG: Relay wake-up signal sent. Status: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint(
        'GHOST_LOG: Relay wake-up signal failed (expected if server is starting): $e',
      );
    }
  }

  Future<List<RelayProfile>> getRelays() async {
    String? data = await _storage.read(key: _relaysKey);

    // FALLBACK: Try reading from standard storage if encrypted read returns null
    if (data == null) {
      try {
        const fallbackStorage = FlutterSecureStorage();
        data = await fallbackStorage.read(key: _relaysKey);
        if (data != null) {
          debugPrint('GHOST_LOG: Migrating relays from fallback storage...');
          await _storage.write(key: _relaysKey, value: data);
          final activeId = await fallbackStorage.read(key: _activeRelayIdKey);
          if (activeId != null) {
            await _storage.write(key: _activeRelayIdKey, value: activeId);
          }
        }
      } catch (_) {}
    }

    List<RelayProfile> relays = [];
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      relays = decoded.map((e) => RelayProfile.fromJson(e)).toList();
    }

    // Migration / Update check for legacy or incorrect relay URLs
    bool migrated = false;
    for (int i = 0; i < relays.length; i++) {
      final r = relays[i];
      if (r.websocketUrl.contains('relay.ghostroom.app') ||
          r.apiUrl.contains('relay.ghostroom.app') ||
          r.websocketUrl.contains('https://https://') ||
          r.apiUrl.contains('https://https://')) {
        relays[i] = RelayProfile(
          id: r.id,
          label: r.label,
          websocketUrl: 'https://ghostroom-vdd6.onrender.com',
          apiUrl: 'https://ghostroom-vdd6.onrender.com',
          token: r.token,
        );
        migrated = true;
      }
    }
    if (migrated) {
      debugPrint('GHOST_LOG: Migrated relay URLs to https://ghostroom-vdd6.onrender.com');
      await _storage.write(key: _relaysKey, value: jsonEncode(relays.map((r) => r.toJson()).toList()));
    }

    // Add default relay if not present
    if (relays.isEmpty) {
      final defaultRelay = RelayProfile(
        id: 'ghostroom-global',
        label: 'GhostRoom Global',
        websocketUrl: 'https://ghostroom-vdd6.onrender.com',
        apiUrl: 'https://ghostroom-vdd6.onrender.com',
      );
      relays.add(defaultRelay);
    }
    
    return relays;
  }

  Future<void> saveRelay(RelayProfile profile) async {
    final relays = await getRelays();
    final index = relays.indexWhere((r) => r.id == profile.id);
    if (index >= 0) {
      relays[index] = profile;
    } else {
      relays.add(profile);
    }
    await _storage.write(
      key: _relaysKey,
      value: jsonEncode(relays.map((r) => r.toJson()).toList()),
    );
  }

  Future<RelayProfile?> getActiveRelay() async {
    final activeId = await getActiveRelayId();
    final relays = await getRelays();
    if (activeId == null && relays.isNotEmpty) return relays.first;
    return relays.where((r) => r.id == activeId).firstOrNull ??
        (relays.isNotEmpty ? relays.first : null);
  }

  Future<String?> getActiveRelayId() async {
    return await _storage.read(key: _activeRelayIdKey);
  }

  Future<void> setActiveRelay(String id) async {
    await _storage.write(key: _activeRelayIdKey, value: id);
  }

  Future<void> deleteRelay(String id) async {
    final relays = await getRelays();
    relays.removeWhere((r) => r.id == id);
    await _storage.write(
      key: _relaysKey,
      value: jsonEncode(relays.map((r) => r.toJson()).toList()),
    );

    final activeId = await getActiveRelayId();
    if (activeId == id) {
      await _storage.delete(key: _activeRelayIdKey);
    }
  }

  Future<void> panicWipe() async {
    await _storage.deleteAll();
  }

  // Recent Rooms
  Future<List<Map<String, dynamic>>> getRecentRooms() async {
    final data = await _storage.read(key: _recentRoomsKey);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  Future<void> addRecentRoom(
    String roomId,
    String keyBase64,
    String relayLabel,
  ) async {
    final rooms = await getRecentRooms();
    // Remove if already exists
    rooms.removeWhere((r) => r['roomId'] == roomId);

    rooms.insert(0, {
      'roomId': roomId,
      'key': keyBase64,
      'relayLabel': relayLabel,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last 10
    if (rooms.length > 10) rooms.removeLast();

    await _storage.write(key: _recentRoomsKey, value: jsonEncode(rooms));
  }

  Future<void> clearRecentRooms() async {
    await _storage.delete(key: _recentRoomsKey);
  }
}
