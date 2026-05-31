import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:ghostroom/features/chat/dm_service.dart';
import 'package:ghostroom/core/crypto/identity_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;

void main() {
  test('Hybrid Encryption (DMService) works', () async {
    final sodium = await SodiumSumoInit.init();
    final dmService = DMService(sodium);
    
    // Helper to derive keys without IdentityService storage dependencies
    Identity deriveIdentity(String mnemonic) {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final ed25519Seed = SecureKey.fromList(sodium, seed.sublist(0, 32));
      final ed25519 = sodium.crypto.sign.seedKeyPair(ed25519Seed);
      
      final sumo = sodium as SodiumSumo;
      final x25519Pk = sumo.crypto.sign.pkToCurve25519(ed25519.publicKey);
      final x25519Sk = sumo.crypto.sign.skToCurve25519(ed25519.secretKey);
      final x25519 = KeyPair(publicKey: x25519Pk, secretKey: x25519Sk);

      return Identity(
        mnemonic: mnemonic,
        ed25519KeyPair: ed25519,
        x25519KeyPair: x25519,
        publicId: 'test',
        fingerprint: 'test',
        deviceId: 'test',
      );
    }

    final senderIdentity = deriveIdentity(bip39.generateMnemonic(strength: 256));
    final recipientIdentity = deriveIdentity(bip39.generateMnemonic(strength: 256));
    
    const plaintext = 'Hello, this is a hybrid encrypted message!';
    
    // 1. Encrypt
    final envelope = await dmService.encryptDM(
      plaintext: plaintext,
      recipientXid: recipientIdentity.x25519KeyPair.publicKey,
      senderIdentity: senderIdentity,
    );
    
    expect(envelope.version, 2);
    expect(envelope.encryptedKey, isNotNull);
    
    // 2. Decrypt
    final decrypted = dmService.decryptDM(
      envelope: envelope,
      myXidKeyPair: recipientIdentity.x25519KeyPair,
      senderEid: senderIdentity.ed25519KeyPair.publicKey,
    );
    
    expect(decrypted, plaintext);
  });
}
