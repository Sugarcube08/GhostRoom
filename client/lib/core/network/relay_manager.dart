import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    required this.apiUrl,
    this.token,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'websocketUrl': websocketUrl,
    'apiUrl': apiUrl,
    'token': token,
  };

  factory RelayProfile.fromJson(Map<String, dynamic> json) => RelayProfile(
    id: json['id'],
    label: json['label'],
    websocketUrl: json['websocketUrl'],
    apiUrl: json['apiUrl'],
    token: json['token'],
  );
}

class RelayManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _relaysKey = 'saved_relays';
  static const String _activeRelayIdKey = 'active_relay_id';
  static const String _recentRoomsKey = 'recent_rooms';

  Future<List<RelayProfile>> getRelays() async {
    final data = await _storage.read(key: _relaysKey);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => RelayProfile.fromJson(e)).toList();
  }

  Future<void> saveRelay(RelayProfile profile) async {
    final relays = await getRelays();
    final index = relays.indexWhere((r) => r.id == profile.id);
    if (index >= 0) {
      relays[index] = profile;
    } else {
      relays.add(profile);
    }
    await _storage.write(key: _relaysKey, value: jsonEncode(relays.map((r) => r.toJson()).toList()));
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
    await _storage.write(key: _relaysKey, value: jsonEncode(relays.map((r) => r.toJson()).toList()));
    
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

  Future<void> addRecentRoom(String roomId, String keyBase64, String relayLabel) async {
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
}
