import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/providers.dart';

enum InitializationStatus { idle, initializing, success, failure }

class AppInitializer {
  final ProviderContainer container;
  InitializationStatus status = InitializationStatus.idle;
  String? errorMessage;

  AppInitializer(this.container);

  Future<void> initialize() async {
    if (status == InitializationStatus.initializing || status == InitializationStatus.success) {
      return;
    }

    status = InitializationStatus.initializing;
    debugPrint('GHOST_LOG: Starting system initialization...');

    try {
      // 1. Hive
      await Hive.initFlutter();
      
      // 2. Identity
      debugPrint('GHOST_LOG: Initializing IdentityService...');
      await container.read(identityServiceProvider).initIdentity();
      
      // 3. Contacts
      debugPrint('GHOST_LOG: Initializing ContactService...');
      await container.read(contactServiceProvider).init();
      
      // 4. Chat Repository
      debugPrint('GHOST_LOG: Initializing ChatRepository...');
      await container.read(chatRepositoryProvider).init();

      // 5. Notifications
      debugPrint('GHOST_LOG: Initializing NotificationService...');
      await container.read(notificationServiceProvider).init();

      status = InitializationStatus.success;
      debugPrint('GHOST_LOG: System initialization complete.');
    } catch (e, stack) {
      status = InitializationStatus.failure;
      errorMessage = e.toString();
      debugPrint('GHOST_FATAL: System initialization failed: $e');
      debugPrint(stack.toString());
    }
  }
}

final appInitializerProvider = Provider<AppInitializer>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
