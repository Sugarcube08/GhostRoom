import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'contact.dart';

class ContactService {
  static const String _boxName = 'contacts';
  static const String _hiveKey = 'hive_encryption_key';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ContactAdapter());
    }

    // Get or generate encryption key
    final existingKey = await _storage.read(key: _hiveKey);
    Uint8List encryptionKey;
    if (existingKey == null) {
      encryptionKey = Uint8List.fromList(Hive.generateSecureKey());
      await _storage.write(key: _hiveKey, value: base64Encode(encryptionKey));
    } else {
      encryptionKey = base64.decode(existingKey);
    }

    await Hive.openBox<Contact>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  Box<Contact> get _box => Hive.box<Contact>(_boxName);

  List<Contact> getAllContacts() {
    return _box.values.toList();
  }

  Contact? getContact(String publicId) {
    return _box.get(publicId);
  }

  Future<void> saveContact(Contact contact) async {
    await _box.put(contact.publicId, contact);
  }

  Future<void> deleteContact(String publicId) async {
    await _box.delete(publicId);
  }

  Future<void> updateAlias(String publicId, String alias) async {
    final contact = getContact(publicId);
    if (contact != null) {
      contact.alias = alias;
      await contact.save();
    }
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
