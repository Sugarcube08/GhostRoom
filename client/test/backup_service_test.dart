import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  test('Backup Cryptography: Argon2id + XChaCha20-Poly1305 works', () async {
    final sodium = await SodiumSumoInit.init();
    final sumo = sodium;
    final cryptoSumo = sumo.crypto;
    
    // Testing the crypto primitives used in BackupService directly
    final password = 'password123';
    final payload = {'test': 'data'};
    final plaintext = utf8.encode(jsonEncode(payload));
    
    // 1. Derive Key
    final salt = sodium.randombytes.buf(cryptoSumo.pwhash.saltBytes);
    final key = cryptoSumo.pwhash(
      outLen: 32,
      password: Int8List.fromList(utf8.encode(password)),
      salt: salt,
      opsLimit: cryptoSumo.pwhash.opsLimitInteractive,
      memLimit: cryptoSumo.pwhash.memLimitInteractive,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
    
    // 2. Encrypt
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: key,
    );
    
    // 3. Decrypt
    final decryptedKey = cryptoSumo.pwhash(
      outLen: 32,
      password: Int8List.fromList(utf8.encode(password)),
      salt: salt,
      opsLimit: cryptoSumo.pwhash.opsLimitInteractive,
      memLimit: cryptoSumo.pwhash.memLimitInteractive,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
    
    final decryptedPlaintext = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: decryptedKey,
    );
    
    expect(jsonDecode(utf8.decode(decryptedPlaintext)), payload);
  });
}
