import 'package:sodium/sodium_sumo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';

class Identity {
  final String mnemonic;
  final KeyPair ed25519KeyPair;
  final KeyPair x25519KeyPair;
  final String publicId;
  final String deviceId; // V1 compat

  Identity({
    required this.mnemonic,
    required this.ed25519KeyPair,
    required this.x25519KeyPair,
    required this.publicId,
    required this.deviceId,
  });
}

class IdentityService {
  final Sodium sodium;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _seedKey = 'identity_seed_phrase';
  static const String _deviceIdKey = 'device_id';

  Identity? _currentIdentity;

  IdentityService(this.sodium);

  Identity? get currentIdentity => _currentIdentity;

  Future<void> initIdentity() async {
    final seedPhrase = await _storage.read(key: _seedKey);
    if (seedPhrase != null) {
      await restoreIdentity(seedPhrase);
    } else {
      // V1 fallback check
      final oldDeviceId = await _storage.read(key: _deviceIdKey);
      if (oldDeviceId != null) {
        // Generate new identity but keep old device_id for V1 compat
        await _generateNewIdentity(preservedDeviceId: oldDeviceId);
      } else {
        await _generateNewIdentity();
      }
    }
  }

  Future<Identity> _generateNewIdentity({String? preservedDeviceId}) async {
    final mnemonic = bip39.generateMnemonic(strength: 256); // 24 words
    return await restoreIdentity(mnemonic, preservedDeviceId: preservedDeviceId);
  }

  Future<Identity> restoreIdentity(String mnemonic, {String? preservedDeviceId}) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic seed phrase');
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    // Ed25519 seed is 32 bytes
    final ed25519SeedBytes = seed.sublist(0, 32);
    final ed25519Seed = SecureKey.fromList(sodium, ed25519SeedBytes);
    
    // Derive Ed25519
    final ed25519KeyPair = sodium.crypto.sign.seedKeyPair(ed25519Seed);
    
    // Derive X25519 from Ed25519
    final sumo = sodium as SodiumSumo;
    final x25519Pk = sumo.crypto.sign.pkToCurve25519(ed25519KeyPair.publicKey);
    final x25519Sk = sumo.crypto.sign.skToCurve25519(ed25519KeyPair.secretKey);
    final x25519KeyPair = KeyPair(publicKey: x25519Pk, secretKey: x25519Sk);

    // Public ID: Blake2b hash of Ed25519 Public Key -> Base58
    final hashBytes = sodium.crypto.genericHash(
      message: ed25519KeyPair.publicKey,
      outLen: 20, // 160-bit Blake2b hash as recommended in spec
    );
    final publicId = base58.encode(hashBytes);

    // Device ID for V1 fallback
    String deviceId = preservedDeviceId ?? 
        await _storage.read(key: _deviceIdKey) ?? 
        sodium.randombytes.buf(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Save to storage
    await _storage.write(key: _seedKey, value: mnemonic);
    await _storage.write(key: _deviceIdKey, value: deviceId);

    _currentIdentity = Identity(
      mnemonic: mnemonic,
      ed25519KeyPair: ed25519KeyPair,
      x25519KeyPair: x25519KeyPair,
      publicId: publicId,
      deviceId: deviceId,
    );

    return _currentIdentity!;
  }

  Future<String?> exportIdentity() async {
    return await _storage.read(key: _seedKey);
  }

  Future<void> wipeIdentity() async {
    await _storage.delete(key: _seedKey);
    await _storage.delete(key: _deviceIdKey);
    // Delete legacy keys if they exist
    await _storage.delete(key: 'device_secret_key');
    await _storage.delete(key: 'device_public_key');
    await _storage.delete(key: 'signing_secret_key');
    await _storage.delete(key: 'signing_public_key');
    _currentIdentity = null;
  }

  Future<String?> getDeviceId() async {
    return _currentIdentity?.deviceId ?? await _storage.read(key: _deviceIdKey);
  }
}
