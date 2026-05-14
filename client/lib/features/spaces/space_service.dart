import 'dart:convert';
import 'dart:typed_data';
import 'package:sodium/sodium.dart';
import 'package:http/http.dart' as http;
import '../../core/network/relay_manager.dart';

class SpaceConfig {
  final String roomId;
  final SecureKey roomKey;
  final DateTime expiry;

  SpaceConfig({
    required this.roomId,
    required this.roomKey,
    required this.expiry,
  });
}

class SpaceService {
  final Sodium sodium;

  SpaceService(this.sodium);

  Future<SpaceConfig> createSpace(RelayProfile relay, {int expirySeconds = 7200}) async {
    // 1. Generate symmetric room key
    final roomKey = sodium.crypto.secretBox.keygen();

    // 2. Request roomId from relay
    final response = await http.post(
      Uri.parse('${relay.apiUrl}/rooms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mode': 'temporary',
        'expirySeconds': expirySeconds,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create space on relay');
    }

    final data = jsonDecode(response.body);
    final roomId = data['roomId'];

    return SpaceConfig(
      roomId: roomId,
      roomKey: roomKey,
      expiry: DateTime.now().add(Duration(seconds: expirySeconds)),
    );
  }

  Uint8List encryptMessage(String plaintext, SecureKey roomKey) {
    final nonce = sodium.randombytes.buf(sodium.crypto.secretBox.nonceBytes);
    final ciphertext = sodium.crypto.secretBox.easy(
      message: utf8.encode(plaintext),
      nonce: nonce,
      key: roomKey,
    );
    
    // Combine nonce + ciphertext
    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setAll(0, nonce);
    combined.setAll(nonce.length, ciphertext);
    return combined;
  }

  String decryptMessage(Uint8List combined, SecureKey roomKey) {
    final nonceBytes = sodium.crypto.secretBox.nonceBytes;
    final nonce = combined.sublist(0, nonceBytes);
    final ciphertext = combined.sublist(nonceBytes);

    final decrypted = sodium.crypto.secretBox.openEasy(
      cipherText: ciphertext,
      nonce: nonce,
      key: roomKey,
    );

    return utf8.decode(decrypted);
  }
}
