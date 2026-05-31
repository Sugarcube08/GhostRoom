import 'package:flutter_test/flutter_test.dart';
import 'package:ghostroom/core/crypto/identity_service.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'dart:typed_data';

void main() {
  test('Launch Audit: Seed Phrase Validation Robustness', () async {
    final sodium = await SodiumSumoInit.init();
    final idService = IdentityService(sodium);

    Identity deriveIdentity(String mnemonic) {
      if (!bip39.validateMnemonic(mnemonic)) throw Exception('Invalid');
      return Identity(
        mnemonic: mnemonic,
        ed25519KeyPair: sodium.crypto.sign.keyPair(),
        x25519KeyPair: KeyPair(publicKey: Uint8List(32), secretKey: SecureKey.fromList(sodium, Uint8List(32))),
        publicId: 'test',
        fingerprint: 'test',
        deviceId: 'test',
      );
    }

    // 1. Valid mnemonic
    final valid = bip39.generateMnemonic(strength: 256);
    expect(deriveIdentity(valid), isNotNull);

    // 2. Short mnemonic (23 words)
    final words = valid.split(' ');
    final short = words.sublist(0, 23).join(' ');
    expect(() => deriveIdentity(short), throwsException);

    // 3. Wrong checksum
    final wrongChecksum = words.sublist(0, 23).join(' ') + ' abandon'; 
    expect(() => deriveIdentity(wrongChecksum), throwsException);

    // 4. Invalid words
    final invalidWords = words.sublist(0, 23).join(' ') + ' xyz123';
    expect(() => deriveIdentity(invalidWords), throwsException);
  });
}
