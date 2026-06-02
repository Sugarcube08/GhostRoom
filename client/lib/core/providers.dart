import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'crypto/identity_service.dart';
import 'network/relay_manager.dart';
import 'network/websocket_service.dart';
import 'notification_service.dart';

import '../features/spaces/space_service.dart';
import '../features/contacts/contact_service.dart';
import '../features/contacts/contact_resolver.dart';
import '../features/chat/dm_service.dart';
import '../features/chat/chat_repository.dart';
import '../features/chat/conversation_service.dart';
import '../features/media/media_service.dart';
import 'backup/backup_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final sodiumProvider = Provider<SodiumSumo>((ref) => throw UnimplementedError());

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // On some devices, the key might be lost if we don't use this
      resetOnError: true,
    ),
  );
});

final identityServiceProvider = Provider<IdentityService>((ref) {
  final sodium = ref.watch(sodiumProvider);
  return IdentityService(sodium, ref.watch(secureStorageProvider));
});

final dmServiceProvider = Provider<DMService>((ref) {
  final sodium = ref.watch(sodiumProvider);
  return DMService(sodium);
});

final contactServiceProvider = Provider<ContactService>((ref) {
  return ContactService(ref.watch(secureStorageProvider));
});

final contactResolverProvider = Provider<ContactResolver>((ref) {
  return ContactResolver(ref.watch(contactServiceProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(identityServiceProvider),
    ref.watch(dmServiceProvider),
    ref.watch(contactServiceProvider),
    ref.watch(webSocketServiceProvider),
    ref.watch(notificationServiceProvider),
  );
});

final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService(
    ref.watch(chatRepositoryProvider),
    ref.watch(contactResolverProvider),
    ref.watch(contactServiceProvider),
    ref.watch(identityServiceProvider),
    ref.watch(mediaServiceProvider),
    ref.watch(relayManagerProvider),
  );
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(
    ref.watch(sodiumProvider),
    ref.watch(identityServiceProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(sodiumProvider),
    ref.watch(identityServiceProvider),
    ref.watch(contactServiceProvider),
    ref.watch(relayManagerProvider),
  );
});

// Alias for V1 backward compatibility
final cryptoServiceProvider = identityServiceProvider;

final spaceServiceProvider = Provider<SpaceService>((ref) {
  final sodium = ref.watch(sodiumProvider);
  return SpaceService(sodium);
});

final relayManagerProvider = Provider<RelayManager>((ref) {
  return RelayManager(ref.watch(secureStorageProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(ref);
});

final activeRelayProvider = FutureProvider<RelayProfile?>((ref) async {
  final manager = ref.watch(relayManagerProvider);
  final relays = await manager.getRelays();
  final activeId = await manager.getActiveRelayId();
  if (activeId == null && relays.isNotEmpty) {
    return relays.first;
  }
  return relays.where((r) => r.id == activeId).firstOrNull ?? (relays.isNotEmpty ? relays.first : null);
});

final recentRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(relayManagerProvider).getRecentRooms();
});
