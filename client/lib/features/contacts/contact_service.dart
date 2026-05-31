import 'package:hive_flutter/hive_flutter.dart';
import 'contact.dart';

class ContactService {
  static const String _boxName = 'contacts';
  
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ContactAdapter());
    }
    await Hive.openBox<Contact>(_boxName);
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
