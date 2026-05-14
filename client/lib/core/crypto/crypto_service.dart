import 'dart:typed_data';
import 'dart:convert';
import 'package:sodium/sodium.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  final Sodium sodium;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _deviceIdKey = 'device_id';
  static const String _deviceSecretKey = 'device_secret_key';
  static const String _devicePublicKey = 'device_public_key';
  static const String _signingSecretKey = 'signing_secret_key';
  static const String _signingPublicKey = 'signing_public_key';

  CryptoService(this.sodium);

  Future<void> initIdentity() async {
    final hasIdentity = await _storage.containsKey(key: _deviceIdKey);
    if (!hasIdentity) {
      await _generateNewIdentity();
    }
  }

  Future<void> _generateNewIdentity() async {
    // X25519 Keypair for encryption
    final encKeypair = sodium.crypto.box.keyPair();
    
    // Ed25519 Keypair for signing
    final signKeypair = sodium.crypto.sign.keyPair();

    final deviceId = sodium.randombytes.buf(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _deviceIdKey, value: deviceId);
    await _storage.write(key: _deviceSecretKey, value: _encode(encKeypair.secretKey));
    await _storage.write(key: _devicePublicKey, value: _encodeBytes(encKeypair.publicKey));
    await _storage.write(key: _signingSecretKey, value: _encode(signKeypair.secretKey));
    await _storage.write(key: _signingPublicKey, value: _encodeBytes(signKeypair.publicKey));
  }

  String _encode(SecureKey key) => base64Encode(key.extractBytes());
  String _encodeBytes(Uint8List bytes) => base64Encode(bytes);

  Future<String?> getDeviceId() => _storage.read(key: _deviceIdKey);
}
