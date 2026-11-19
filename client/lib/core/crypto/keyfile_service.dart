import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sodium/sodium_sumo.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GhostKeyfile {
  final int version;
  final String publicId;
  final String fingerprint;
  final String saltHex;
  final int opsLimit;
  final int memLimit;
  final String nonceHex;
  final String ciphertextHex;
  final String createdAt;

  GhostKeyfile({
    required this.version,
    required this.publicId,
    required this.fingerprint,
    required this.saltHex,
    required this.opsLimit,
    required this.memLimit,
    required this.nonceHex,
    required this.ciphertextHex,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'ghostroom_keyfile': 'ghostkey',
        'version': version,
        'public_id': publicId,
        'fingerprint': fingerprint,
        'kdf': {
          'algorithm': 'argon2id13',
          'salt_hex': saltHex,
          'ops_limit': opsLimit,
          'mem_limit': memLimit,
        },
        'cipher': {
          'algorithm': 'xchacha20poly1305_ietf',
          'nonce_hex': nonceHex,
          'ciphertext_hex': ciphertextHex,
        },
        'created_at': createdAt,
      };

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory GhostKeyfile.fromJson(Map<String, dynamic> json) {
    if (json['ghostroom_keyfile'] != 'ghostkey' && json['version'] == null) {
      throw const FormatException('Invalid GhostRoom keyfile format');
    }

    final kdf = json['kdf'] as Map<String, dynamic>? ?? {};
    final cipher = json['cipher'] as Map<String, dynamic>? ?? {};

    return GhostKeyfile(
      version: json['version'] as int? ?? 1,
      publicId: json['public_id'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      saltHex: kdf['salt_hex'] as String? ?? '',
      opsLimit: kdf['ops_limit'] as int? ?? 2,
      memLimit: kdf['mem_limit'] as int? ?? 67108864,
      nonceHex: cipher['nonce_hex'] as String? ?? '',
      ciphertextHex: cipher['ciphertext_hex'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory GhostKeyfile.fromJsonString(String jsonStr) {
    return GhostKeyfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

class KeyfileService {
  final SodiumSumo sodium;

  KeyfileService(this.sodium);

  /// Generates a portable encrypted .ghostkey JSON keyfile from a mnemonic seed phrase and PIN/password
  GhostKeyfile createKeyfile({
    required String mnemonic,
    required String publicId,
    required String fingerprint,
    required String password,
  }) {
    final salt = sodium.randombytes.buf(sodium.crypto.pwhash.saltBytes);
    final opsLimit = sodium.crypto.pwhash.opsLimitInteractive;
    final memLimit = sodium.crypto.pwhash.memLimitInteractive;

    final derivedKey = sodium.crypto.pwhash(
      outLen: 32,
      password: Int8List.fromList(utf8.encode(password)),
      salt: salt,
      opsLimit: opsLimit,
      memLimit: memLimit,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );

    final nonce = sodium.randombytes.buf(
      sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );

    final payload = {
      'mnemonic': mnemonic.trim(),
      'public_id': publicId,
      'fingerprint': fingerprint,
      'created_at': DateTime.now().toIso8601String(),
    };

    final plaintext = utf8.encode(jsonEncode(payload));
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: derivedKey,
    );

    return GhostKeyfile(
      version: 1,
      publicId: publicId,
      fingerprint: fingerprint,
      saltHex: _bytesToHex(salt),
      opsLimit: opsLimit,
      memLimit: memLimit,
      nonceHex: _bytesToHex(nonce),
      ciphertextHex: _bytesToHex(ciphertext),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Decrypts a .ghostkey JSON string with user PIN/password and extracts the BIP-39 mnemonic
  String unlockKeyfile({
    required String keyfileJson,
    required String password,
  }) {
    final keyfile = GhostKeyfile.fromJsonString(keyfileJson);

    final salt = _hexToBytes(keyfile.saltHex);
    final nonce = _hexToBytes(keyfile.nonceHex);
    final ciphertext = _hexToBytes(keyfile.ciphertextHex);

    final derivedKey = sodium.crypto.pwhash(
      outLen: 32,
      password: Int8List.fromList(utf8.encode(password)),
      salt: salt,
      opsLimit: keyfile.opsLimit,
      memLimit: keyfile.memLimit,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );

    try {
      final decryptedBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
        cipherText: ciphertext,
        nonce: nonce,
        key: derivedKey,
      );

      final payload = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
      final mnemonic = payload['mnemonic'] as String?;
      if (mnemonic == null || mnemonic.isEmpty) {
        throw const FormatException('Keyfile payload missing mnemonic seed phrase');
      }

      return mnemonic;
    } catch (e) {
      throw Exception('Failed to decrypt keyfile: Incorrect password/PIN or corrupted keyfile.');
    }
  }

  /// Exports the .ghostkey file to the device temporary directory for sharing or saving
  Future<File> writeKeyfileToTemp({required GhostKeyfile keyfile}) async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedId = keyfile.publicId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final filename = 'ghostroom_${sanitizedId.length > 8 ? sanitizedId.substring(0, 8) : sanitizedId}.ghostkey';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(keyfile.toFormattedJson(), flush: true);
    return file;
  }

  /// Prompts the native OS share sheet or save file dialog
  Future<void> shareKeyfile({required GhostKeyfile keyfile}) async {
    final file = await writeKeyfileToTemp(keyfile: keyfile);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'GhostRoom Ephemeral Keyfile (.ghostkey)',
    ));
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.trim().replaceAll(' ', '');
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
