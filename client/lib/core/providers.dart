import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium.dart';
import 'crypto/identity_service.dart';
import 'network/relay_manager.dart';
import 'network/websocket_service.dart';

import '../features/spaces/space_service.dart';

final sodiumProvider = Provider<Sodium>((ref) => throw UnimplementedError());

final identityServiceProvider = Provider<IdentityService>((ref) {
  final sodium = ref.watch(sodiumProvider);
  return IdentityService(sodium);
});

// Alias for V1 backward compatibility
final cryptoServiceProvider = identityServiceProvider;

final spaceServiceProvider = Provider<SpaceService>((ref) {
  final sodium = ref.watch(sodiumProvider);
  return SpaceService(sodium);
});

final relayManagerProvider = Provider<RelayManager>((ref) {
  return RelayManager();
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
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
