import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:ghostroom/core/crypto/keyfile_service.dart';

void main() {
  late SodiumSumo sodium;
  late KeyfileService keyfileService;

  const testMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';
  const testPublicId = '5Hq7R8v1xZkM9P2w4LQJ';
  const testFingerprint = 'A1B2-C3D4-E5F6-0708-9A0B-1C2D-3E4F-5A6B';
  const testPassword = 'SecureMasterPassphrase!2026';

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    keyfileService = KeyfileService(sodium);
  });

  group('KeyfileService Encryption & Decryption', () {
    test('creates valid .ghostkey keyfile JSON with Argon2id and XChaCha20-Poly1305', () {
      final keyfile = keyfileService.createKeyfile(
        mnemonic: testMnemonic,
        publicId: testPublicId,
        fingerprint: testFingerprint,
        password: testPassword,
      );

      expect(keyfile.version, 1);
      expect(keyfile.publicId, testPublicId);
      expect(keyfile.fingerprint, testFingerprint);
      expect(keyfile.saltHex.length, 32); // 16 bytes = 32 hex chars
      expect(keyfile.nonceHex.length, 48); // 24 bytes = 48 hex chars
      expect(keyfile.ciphertextHex.isNotEmpty, isTrue);

      final jsonStr = keyfile.toFormattedJson();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(parsed['ghostroom_keyfile'], 'ghostkey');
      expect(parsed['public_id'], testPublicId);
      expect(parsed['fingerprint'], testFingerprint);
      expect(parsed['kdf']['algorithm'], 'argon2id13');
      expect(parsed['cipher']['algorithm'], 'xchacha20poly1305_ietf');
    });

    test('decrypts and restores exact mnemonic with correct password', () {
      final keyfile = keyfileService.createKeyfile(
        mnemonic: testMnemonic,
        publicId: testPublicId,
        fingerprint: testFingerprint,
        password: testPassword,
      );

      final jsonStr = keyfile.toFormattedJson();
      final unlockedMnemonic = keyfileService.unlockKeyfile(
        keyfileJson: jsonStr,
        password: testPassword,
      );

      expect(unlockedMnemonic, testMnemonic);
    });

    test('fails decryption when provided incorrect password or PIN', () {
      final keyfile = keyfileService.createKeyfile(
        mnemonic: testMnemonic,
        publicId: testPublicId,
        fingerprint: testFingerprint,
        password: testPassword,
      );

      final jsonStr = keyfile.toFormattedJson();

      expect(
        () => keyfileService.unlockKeyfile(
          keyfileJson: jsonStr,
          password: 'WrongPassword123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('fails decryption when ciphertext is tampered', () {
      final keyfile = keyfileService.createKeyfile(
        mnemonic: testMnemonic,
        publicId: testPublicId,
        fingerprint: testFingerprint,
        password: testPassword,
      );

      final map = keyfile.toJson();
      final cipher = map['cipher'] as Map<String, dynamic>;
      final originalHex = cipher['ciphertext_hex'] as String;
      // Flip the last hex character
      final lastChar = originalHex[originalHex.length - 1];
      final flippedChar = lastChar == 'a' ? 'b' : 'a';
      cipher['ciphertext_hex'] =
          originalHex.substring(0, originalHex.length - 1) + flippedChar;

      final tamperedJson = jsonEncode(map);

      expect(
        () => keyfileService.unlockKeyfile(
          keyfileJson: tamperedJson,
          password: testPassword,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
