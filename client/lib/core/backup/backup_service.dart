import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sodium/sodium_sumo.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../crypto/identity_service.dart';
import '../../features/contacts/contact_service.dart';
import '../../features/contacts/contact.dart';
import '../network/relay_manager.dart';

class BackupService {
  final SodiumSumo sodium;
  final IdentityService _idService;
  final ContactService _contactService;
  final RelayManager _relayManager;

  BackupService(this.sodium, this._idService, this._contactService, this._relayManager);

  Future<void> exportBackup(String password) async {
    final identity = _idService.currentIdentity;
    if (identity == null) throw Exception('Identity not ready');

    // 1. Collect Data
    final relays = await _relayManager.getRelays();
    final contacts = _contactService.getAllContacts();
    final blocked = _contactService.getBlockedIdentities();

    final payload = {
      'version': 1,
      'seed': identity.mnemonic,
      'contacts': contacts.map((c) => {
        'id': c.publicId,
        'alias': c.alias,
        'eid': c.eid,
        'xid': c.xid,
        'fp': c.fingerprint,
        'r': c.preferredRelay,
      }).toList(),
      'blocked': blocked,
      'relays': relays.map((r) => r.toJson()).toList(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final plaintext = utf8.encode(jsonEncode(payload));

    // 2. Key Derivation (Argon2id)
    final salt = sodium.randombytes.buf(sodium.crypto.pwhash.saltBytes);
    final key = sodium.crypto.pwhash(
      outLen: 32,
      password: Int8List.fromList(utf8.encode(password)),
      salt: salt,
      opsLimit: sodium.crypto.pwhash.opsLimitInteractive,
      memLimit: sodium.crypto.pwhash.memLimitInteractive,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );

    // 3. Encryption (XChaCha20-Poly1305)
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintext,
      nonce: nonce,
      key: key,
    );

    // 4. Serialize Archive: salt + nonce + ciphertext
    final archive = Uint8List(salt.length + nonce.length + ciphertext.length);
    archive.setAll(0, salt);
    archive.setAll(salt.length, nonce);
    archive.setAll(salt.length + nonce.length, ciphertext);

    // 5. Share File
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ghostroom_${identity.publicId}.ghostroombackup');
    await file.writeAsBytes(archive);
    
    await Share.shareXFiles([XFile(file.path)], text: 'GhostRoom Backup');
  }

  Future<void> importBackup(Uint8List archive, String password) async {
    final saltBytes = sodium.crypto.pwhash.saltBytes;
    final nonceBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes;

    if (archive.length < saltBytes + nonceBytes) {
      throw Exception('Invalid backup file');
    }

    final salt = archive.sublist(0, saltBytes);
    final nonce = archive.sublist(saltBytes, saltBytes + nonceBytes);
    final ciphertext = archive.sublist(saltBytes + nonceBytes);

    // 1. Key Derivation
    final key = sodium.crypto.pwhash(
      outLen: 32,
      password: Int8List.fromList(utf8.encode(password)),
      salt: salt,
      opsLimit: sodium.crypto.pwhash.opsLimitInteractive,
      memLimit: sodium.crypto.pwhash.memLimitInteractive,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );

    // 2. Decryption
    final plaintextBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: key,
    );

    final payload = jsonDecode(utf8.decode(plaintextBytes));
    if (payload['version'] != 1) throw Exception('Unsupported backup version');

    // 3. Restore Identity
    await _idService.restoreIdentity(payload['seed']);

    // 4. Restore Contacts
    await _contactService.clearAll();
    for (final cData in payload['contacts']) {
      await _contactService.saveContact(Contact(
        publicId: cData['id'],
        alias: cData['alias'],
        eid: cData['eid'],
        xid: cData['xid'],
        fingerprint: cData['fp'],
        createdAt: DateTime.now(),
        preferredRelay: cData['r'],
      ));
    }

    // 5. Restore Blocked
    for (final bId in payload['blocked']) {
      await _contactService.blockIdentity(bId);
    }

    // 6. Restore Relays
    for (final rData in payload['relays']) {
      await _relayManager.saveRelay(RelayProfile.fromJson(rData));
    }
  }
}
