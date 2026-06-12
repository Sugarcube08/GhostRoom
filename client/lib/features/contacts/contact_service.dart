import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'contact.dart';

class ContactService {
  static const String _boxName = 'contacts';
  static const String _blockBoxName = 'blocked_identities';
  static const String _hiveKey = 'hive_encryption_key';
  final FlutterSecureStorage _storage;
  bool _isInitialized = false;

  ContactService(this._storage);
  
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ContactAdapter());
    }

    // Get or generate encryption key
    String? existingKey = await _storage.read(key: _hiveKey);
    
    // FALLBACK: Try standard storage
    if (existingKey == null) {
      try {
        const fallbackStorage = FlutterSecureStorage();
        existingKey = await fallbackStorage.read(key: _hiveKey);
        if (existingKey != null) {
          await _storage.write(key: _hiveKey, value: existingKey);
        }
      } catch (_) {}
    }

    Uint8List encryptionKey;
    if (existingKey == null) {
      encryptionKey = Uint8List.fromList(Hive.generateSecureKey());
      await _storage.write(key: _hiveKey, value: base64Encode(encryptionKey));
    } else {
      encryptionKey = base64.decode(existingKey);
    }

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Contact>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }
    if (!Hive.isBoxOpen(_blockBoxName)) {
      await Hive.openBox<String>(_blockBoxName);
    }
  }

  Box<Contact>? get _box {
    if (!Hive.isBoxOpen(_boxName)) return null;
    return Hive.box<Contact>(_boxName);
  }
  Box<String>? get _blockBox {
    if (!Hive.isBoxOpen(_blockBoxName)) return null;
    return Hive.box<String>(_blockBoxName);
  }

  List<Contact> getAllContacts() {
    return _box?.values.toList() ?? [];
  }

  Contact? getContact(String publicId) {
    return _box?.get(publicId);
  }

  Future<void> saveContact(Contact contact) async {
    await _box?.put(contact.publicId, contact);
    await unblockIdentity(contact.publicId); // Unblock if they were blocked
  }

  Future<void> deleteContact(String publicId) async {
    await _box?.delete(publicId);
  }

  Future<void> updateAlias(String publicId, String alias) async {
    final contact = getContact(publicId);
    if (contact != null) {
      contact.alias = alias;
      await contact.save();
    }
  }

  Future<void> clearAll() async {
    await _box?.clear();
    await _blockBox?.clear();
  }

  // Block List Management
  bool isBlocked(String publicId) {
    return _blockBox?.containsKey(publicId) ?? false;
  }

  Future<void> blockIdentity(String publicId) async {
    await _blockBox?.put(publicId, publicId);
    await deleteContact(publicId); // Ensure not in contacts if blocked
  }

  Future<void> unblockIdentity(String publicId) async {
    await _blockBox?.delete(publicId);
  }

  List<String> getBlockedIdentities() {
    return _blockBox?.values.toList() ?? [];
  }
}

