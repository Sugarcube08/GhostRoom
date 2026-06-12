import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../core/providers.dart';
import '../features/contacts/contact.dart';
import '../features/chat/message.dart';
import '../features/chat/conversation_state.dart';

enum InitializationStatus { idle, initializing, success, failure }

class AppInitializer {
  final ProviderContainer container;
  InitializationStatus status = InitializationStatus.idle;
  String? errorMessage;

  AppInitializer(this.container);

  Future<void> initialize() async {
    if (status == InitializationStatus.initializing ||
        status == InitializationStatus.success) {
      return;
    }

    status = InitializationStatus.initializing;

    try {
      // 1. Eagerly register Hive Adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ContactAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MessageAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(MessageTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(ConversationModeAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(ConversationStateAdapter());
      }

      // 2. Eagerly open standard Hive boxes
      if (!Hive.isBoxOpen('messages')) {
        await Hive.openBox<Message>('messages');
      }
      if (!Hive.isBoxOpen('conversation_states')) {
        await Hive.openBox<ConversationState>('conversation_states');
      }
      if (!Hive.isBoxOpen('sync_metadata')) {
        await Hive.openBox('sync_metadata');
      }
      if (!Hive.isBoxOpen('processed_envelopes')) {
        await Hive.openBox('processed_envelopes');
      }
      if (!Hive.isBoxOpen('offline_send_queue')) {
        await Hive.openBox<Map>('offline_send_queue');
      }
      if (!Hive.isBoxOpen('pending_deletions')) {
        await Hive.openBox<bool>('pending_deletions');
      }
      if (!Hive.isBoxOpen('thumbnail_cache')) {
        await Hive.openBox<Uint8List>('thumbnail_cache');
      }
      if (!Hive.isBoxOpen('media_cache_index')) {
        await Hive.openBox<dynamic>('media_cache_index');
      }

      // 3. Eagerly open encrypted contacts box
      final storage = container.read(secureStorageProvider);
      String? existingKey = await storage.read(key: 'hive_encryption_key');
      if (existingKey == null) {
        try {
          const fallbackStorage = FlutterSecureStorage();
          existingKey = await fallbackStorage.read(key: 'hive_encryption_key');
          if (existingKey != null) {
            await storage.write(key: 'hive_encryption_key', value: existingKey);
          }
        } catch (_) {}
      }
      Uint8List encryptionKey;
      if (existingKey == null) {
        encryptionKey = Uint8List.fromList(Hive.generateSecureKey());
        await storage.write(key: 'hive_encryption_key', value: base64Encode(encryptionKey));
      } else {
        encryptionKey = base64.decode(existingKey);
      }

      if (!Hive.isBoxOpen('contacts')) {
        await Hive.openBox<Contact>(
          'contacts',
          encryptionCipher: HiveAesCipher(encryptionKey),
        );
      }
      if (!Hive.isBoxOpen('blocked_identities')) {
        await Hive.openBox<String>('blocked_identities');
      }

      // 4. Identity
      await container.read(identityServiceProvider).initIdentity();
      await container.read(identityServiceProvider).saveBackgroundCache(
        customHiveKey: base64Encode(encryptionKey),
      );

      status = InitializationStatus.success;
    } catch (e) {
      status = InitializationStatus.failure;
      errorMessage = e.toString();
    }
  }
}

final appInitializerProvider = Provider<AppInitializer>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
