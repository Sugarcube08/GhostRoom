import 'dart:convert';
import 'dart:typed_data';
import 'package:sodium/sodium_sumo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';
import '../network/relay_manager.dart';

class IdentityPackage {
  final int version;
  final String eid;
  final String xid;
  final List<String> relays;
  final String? signature;

  IdentityPackage({
    required this.version,
    required this.eid,
    required this.xid,
    required this.relays,
    this.signature,
  });

  Map<String, dynamic> toJson() => {
    'v': version,
    'eid': eid,
    'xid': xid,
    'r': relays,
    if (signature != null) 's': signature,
  };

  factory IdentityPackage.fromJson(Map<String, dynamic> json) => IdentityPackage(
    version: json['v'] ?? 1,
    eid: json['eid'],
    xid: json['xid'],
    relays: List<String>.from(json['r'] ?? []),
    signature: json['s'],
  );

  String toEncodedString() => base64UrlEncode(utf8.encode(jsonEncode(toJson())));

  factory IdentityPackage.fromEncodedString(String encoded) {
    final decoded = utf8.decode(base64Url.decode(encoded));
    return IdentityPackage.fromJson(jsonDecode(decoded));
  }
}

class Identity {
  final String mnemonic;
  final KeyPair ed25519KeyPair;
  final KeyPair x25519KeyPair;
  final String publicId;
  final String fingerprint;
  final String deviceId; // V1 compat

  Identity({
    required this.mnemonic,
    required this.ed25519KeyPair,
    required this.x25519KeyPair,
    required this.publicId,
    required this.fingerprint,
    required this.deviceId,
  });
}

class IdentityService {
  final SodiumSumo sodium;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _seedKey = 'identity_seed_phrase';
  static const String _deviceIdKey = 'device_id';

  Identity? _currentIdentity;

  IdentityService(this.sodium);

  Identity? get currentIdentity => _currentIdentity;

  bool get hasIdentity => _currentIdentity != null;

  Future<void> initIdentity() async {
    final seedPhrase = await _storage.read(key: _seedKey);
    if (seedPhrase != null) {
      await restoreIdentity(seedPhrase);
    }
  }

  String generateNewMnemonic() {
    return bip39.generateMnemonic(strength: 256);
  }

  String derivePublicId(Uint8List ed25519PubKey) {
    final hashBytes = sodium.crypto.genericHash(
      message: ed25519PubKey,
      outLen: 20,
    );
    return base58.encode(hashBytes);
  }

  String calculateFingerprint(Uint8List eid, Uint8List xid) {
    final combined = Uint8List(eid.length + xid.length);
    combined.setAll(0, eid);
    combined.setAll(eid.length, xid);
    
    final hash = sodium.crypto.genericHash(
      message: combined,
      outLen: 32,
    );
    
    // Format as ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ12-3456
    final hex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    final chunks = <String>[];
    for (var i = 0; i < hex.length; i += 4) {
      chunks.add(hex.substring(i, i + 4));
    }
    return chunks.take(8).join('-'); // Take first 32 chars / 8 chunks
  }

  Future<Identity> restoreIdentity(String mnemonic, {String? preservedDeviceId}) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic seed phrase');
    }

    final seed = bip39.mnemonicToSeed(mnemonic);
    final ed25519SeedBytes = seed.sublist(0, 32);
    final ed25519Seed = SecureKey.fromList(sodium, ed25519SeedBytes);
    
    final ed25519KeyPair = sodium.crypto.sign.seedKeyPair(ed25519Seed);
    
    final x25519Pk = sodium.crypto.sign.pkToCurve25519(ed25519KeyPair.publicKey);
    final x25519Sk = sodium.crypto.sign.skToCurve25519(ed25519KeyPair.secretKey);
    final x25519KeyPair = KeyPair(publicKey: x25519Pk, secretKey: x25519Sk);

    final publicId = derivePublicId(ed25519KeyPair.publicKey);
    final fingerprint = calculateFingerprint(ed25519KeyPair.publicKey, x25519KeyPair.publicKey);

    String deviceId = preservedDeviceId ?? 
        await _storage.read(key: _deviceIdKey) ?? 
        sodium.randombytes.buf(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _seedKey, value: mnemonic);
    await _storage.write(key: _deviceIdKey, value: deviceId);

    _currentIdentity = Identity(
      mnemonic: mnemonic,
      ed25519KeyPair: ed25519KeyPair,
      x25519KeyPair: x25519KeyPair,
      publicId: publicId,
      fingerprint: fingerprint,
      deviceId: deviceId,
    );

    return _currentIdentity!;
  }

  String _canonicalJson(Map<String, dynamic> data) {
    final sortedKeys = data.keys.toList()..sort();
    final sortedMap = {
      for (final key in sortedKeys) key: data[key]
    };
    return jsonEncode(sortedMap);
  }

  Future<IdentityPackage> createPackage(List<RelayProfile> preferredRelays) async {
    if (_currentIdentity == null) throw Exception('Identity not initialized');

    final pkgData = {
      'v': 1,
      'eid': base64Encode(_currentIdentity!.ed25519KeyPair.publicKey),
      'xid': base64Encode(_currentIdentity!.x25519KeyPair.publicKey),
      'r': preferredRelays.map((r) => r.websocketUrl).toList(),
    };

    final signature = sodium.crypto.sign.detached(
      message: utf8.encode(_canonicalJson(pkgData)),
      secretKey: _currentIdentity!.ed25519KeyPair.secretKey,
    );

    return IdentityPackage(
      version: 1,
      eid: pkgData['eid'] as String,
      xid: pkgData['xid'] as String,
      relays: List<String>.from(pkgData['r'] as List),
      signature: base64Encode(signature),
    );
  }

  bool verifyPackage(IdentityPackage package) {
    if (package.signature == null) return false;
    
    final pkgData = {
      'v': package.version,
      'eid': package.eid,
      'xid': package.xid,
      'r': package.relays,
    };

    return sodium.crypto.sign.verifyDetached(
      message: utf8.encode(_canonicalJson(pkgData)),
      signature: base64Decode(package.signature!),
      publicKey: base64Decode(package.eid),
    );
  }

  String signChallenge(String nonce) {
    if (_currentIdentity == null) throw Exception('Identity not initialized');
    
    final signature = sodium.crypto.sign.detached(
      message: utf8.encode(nonce),
      secretKey: _currentIdentity!.ed25519KeyPair.secretKey,
    );
    
    return base64Encode(signature);
  }

  Future<String?> exportIdentity() async {
    return await _storage.read(key: _seedKey);
  }

  Future<void> wipeIdentity() async {
    await _storage.delete(key: _seedKey);
    await _storage.delete(key: _deviceIdKey);
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
