import 'dart:convert';
import 'package:sodium/sodium_sumo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';
import '../network/relay_manager.dart';
import 'package:flutter/foundation.dart';
import '../storage/storage_directory_helper.dart';

Uint8List _deriveSeedBackground(String mnemonic) {
  return bip39.mnemonicToSeed(mnemonic);
}

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
  final FlutterSecureStorage _storage;

  static const String _seedKey = 'identity_seed_phrase';
  static const String _deviceIdKey = 'device_id';
  static const String _drillKey = 'last_drill_t';

  Identity? _currentIdentity;

  IdentityService(this.sodium, this._storage);

  Identity? get currentIdentity => _currentIdentity;

  bool get hasIdentity => _currentIdentity != null;

  Future<bool> isDrillRequired() async {
    final lastDrill = await _storage.read(key: _drillKey);
    if (lastDrill == null) return true;
    final lastTime = DateTime.fromMillisecondsSinceEpoch(int.parse(lastDrill));
    return DateTime.now().difference(lastTime).inDays > 90; // Every 90 days
  }

  Future<void> recordDrillSuccess() async {
    await _storage.write(key: _drillKey, value: DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<bool> _checkPublicIdentityFlag() async {
    try {
      final file = await StorageDirectoryHelper.getIdentityFlagFile();
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> _writePublicIdentityFlag() async {
    try {
      final file = await StorageDirectoryHelper.getIdentityFlagFile();
      await file.writeAsString('true');
    } catch (_) {}
  }

  Future<void> _clearPublicIdentityFlag() async {
    try {
      final file = await StorageDirectoryHelper.getIdentityFlagFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> initIdentity() async {
    try {
      // 1. Keystore settlement delay
      await Future.delayed(const Duration(seconds: 2));

      String? seedPhrase;
      for (int i = 0; i < 5; i++) {
        try {
          seedPhrase = await _storage.read(key: _seedKey);
          if (seedPhrase != null) {
            break;
          }
          
          // FALLBACK: Try reading from standard storage if encrypted read returns null
          // This helps if the app was previously using default options.
          if (i == 0) {
            const fallbackStorage = FlutterSecureStorage();
            seedPhrase = await fallbackStorage.read(key: _seedKey);
            if (seedPhrase != null) {
              await _storage.write(key: _seedKey, value: seedPhrase);
              final devId = await fallbackStorage.read(key: _deviceIdKey);
              if (devId != null) await _storage.write(key: _deviceIdKey, value: devId);
              break;
            }
          }
          
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      final flagExists = await _checkPublicIdentityFlag();

      if (seedPhrase != null) {
        await restoreIdentity(seedPhrase);
        if (!flagExists) {
          await _writePublicIdentityFlag();
        }
      } else {
        if (flagExists) {
        } else {
        }
      }
    } catch (e) {
      rethrow; 
    } finally {
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
    try {
      final sanitizedMnemonic = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (!bip39.validateMnemonic(sanitizedMnemonic)) {
        throw Exception('Invalid mnemonic seed phrase');
      }

      final seed = await compute(_deriveSeedBackground, sanitizedMnemonic);
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

      await _storage.write(key: _seedKey, value: sanitizedMnemonic);
      await _storage.write(key: _deviceIdKey, value: deviceId);
      
      // Write public flag to survive keyring lockouts
      await _writePublicIdentityFlag();

      _currentIdentity = Identity(
        mnemonic: sanitizedMnemonic,
        ed25519KeyPair: ed25519KeyPair,
        x25519KeyPair: x25519KeyPair,
        publicId: publicId,
        fingerprint: fingerprint,
        deviceId: deviceId,
      );

      await saveBackgroundCache();

      return _currentIdentity!;
    } catch (e) {
      rethrow;
    }
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
    
    // Clear fallback storage too
    try {
      const fallbackStorage = FlutterSecureStorage();
      await fallbackStorage.deleteAll();
    } catch (_) {}

    try {
      final file = await StorageDirectoryHelper.getBackgroundCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    await _clearPublicIdentityFlag();
    _currentIdentity = null;
  }

  Future<String?> getDeviceId() async {
    return _currentIdentity?.deviceId ?? await _storage.read(key: _deviceIdKey);
  }

  Future<void> saveBackgroundCache({String? customHiveKey}) async {
    try {
      if (_currentIdentity == null) return;
      final file = await StorageDirectoryHelper.getBackgroundCacheFile();
      
      String? hiveKey = customHiveKey;
      if (hiveKey == null) {
        try {
          hiveKey = await _storage.read(key: 'hive_encryption_key');
        } catch (_) {}
      }

      // Read active relay details
      final relayManager = RelayManager(_storage);
      final activeRelay = await relayManager.getActiveRelay();
      
      final data = {
        'public_id': _currentIdentity!.publicId,
        'device_id': _currentIdentity!.deviceId,
        'ed25519_public_key': base64Encode(_currentIdentity!.ed25519KeyPair.publicKey),
        'ed25519_secret_key': base64Encode(_currentIdentity!.ed25519KeyPair.secretKey.extractBytes()),
        'x25519_public_key': base64Encode(_currentIdentity!.x25519KeyPair.publicKey),
        'x25519_secret_key': base64Encode(_currentIdentity!.x25519KeyPair.secretKey.extractBytes()),
        'hive_encryption_key': hiveKey,
        if (activeRelay != null) ...{
          'active_relay_id': activeRelay.id,
          'active_relay_label': activeRelay.label,
          'active_relay_websocket_url': activeRelay.websocketUrl,
          'active_relay_api_url': activeRelay.apiUrl,
          'active_relay_token': activeRelay.token,
        }
      };
      
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Ignore
    }
  }

  Future<bool> loadIdentityFromCache() async {
    try {
      final file = await StorageDirectoryHelper.getBackgroundCacheFile();
      if (!await file.exists()) {
        return false;
      }
      
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      final ed25519Pk = base64Decode(data['ed25519_public_key']);
      final ed25519Sk = base64Decode(data['ed25519_secret_key']);
      final x25519Pk = base64Decode(data['x25519_public_key']);
      final x25519Sk = base64Decode(data['x25519_secret_key']);
      
      _currentIdentity = Identity(
        mnemonic: '', // Not needed for background operations
        ed25519KeyPair: KeyPair(publicKey: ed25519Pk, secretKey: SecureKey.fromList(sodium, ed25519Sk)),
        x25519KeyPair: KeyPair(publicKey: x25519Pk, secretKey: SecureKey.fromList(sodium, x25519Sk)),
        publicId: data['public_id'],
        fingerprint: '', // Not needed for background operations
        deviceId: data['device_id'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
