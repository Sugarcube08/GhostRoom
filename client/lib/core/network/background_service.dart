import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// We import the core services to re-initialize them in the background isolate
import '../crypto/identity_service.dart';
import 'relay_manager.dart';
import 'websocket_service.dart';
import '../notification_service.dart';
import '../../features/chat/message.dart';

class GhostBackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configure for Android
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'ghostroom_background',
        initialNotificationTitle: 'GHOSTROOM ACTIVE',
        initialNotificationContent: 'Listening for private messages...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // 1. Initialize Background Environment
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(MessageTypeAdapter().typeId)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(MessageAdapter().typeId)) {
      Hive.registerAdapter(MessageAdapter());
    }

    final sodium = await SodiumSumoInit.init();
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    
    final idService = IdentityService(sodium, storage);
    final relayManager = RelayManager(storage);
    final notificationService = NotificationService();
    await notificationService.init();

    // 2. Connect to Relay
    _connectBackground(idService, relayManager, notificationService, sodium);
  }

  static void _connectBackground(
    IdentityService idService,
    RelayManager relayManager,
    NotificationService notificationService,
    SodiumSumo sodium,
  ) async {
    void attemptConnection() async {
      try {
        await idService.initIdentity(); // Correct method name
        final identity = idService.currentIdentity;
        if (identity == null) {
          debugPrint('BG_SERVICE: No identity found. Retrying in 30s...');
          Future.delayed(const Duration(seconds: 30), attemptConnection);
          return;
        }

        final activeId = await relayManager.getActiveRelayId();
        final relays = await relayManager.getRelays();
        final profile = relays.where((r) => r.id == activeId).firstOrNull ?? (relays.isNotEmpty ? relays.first : null);

        if (profile == null) {
          debugPrint('BG_SERVICE: No relay found. Retrying in 30s...');
          Future.delayed(const Duration(seconds: 30), attemptConnection);
          return;
        }

        final socket = WebSocketService.createRawSocket(profile);
        
        socket.on('connect', (_) {
          debugPrint('BG_SERVICE: Connected to relay');
        });

        socket.on('identity.challenge', (data) {
          final nonce = data['nonce'] as String;
          final signature = idService.signChallenge(nonce);
          socket.emit('identity.prove', {
            'public_id': identity.publicId,
            'public_key': base64Encode(identity.ed25519KeyPair.publicKey),
            'signature': signature,
            'device_id': identity.deviceId,
          });
        });

        socket.on('message.receive', (data) async {
          try {
            // In background, we just notify. The actual UI will sync on resume.
            notificationService.showNotification(
              title: 'New Private Message',
              body: 'Encrypted payload received via GhostRoom.',
              payload: identity.publicId,
            );
            
            // Ack to relay so it doesn't keep resending while we are in background
            socket.emit('message.ack', {'message_id': data['id']});
          } catch (e) {
            debugPrint('BG_SERVICE: Error processing background message: $e');
          }
        });

        socket.on('disconnect', (reason) {
          debugPrint('BG_SERVICE: Disconnected ($reason). Retrying in 10s...');
          socket.dispose();
          Future.delayed(const Duration(seconds: 10), attemptConnection);
        });

        socket.connect();
      } catch (e) {
        debugPrint('BG_SERVICE: Connection loop failed: $e. Retrying in 30s...');
        Future.delayed(const Duration(seconds: 30), attemptConnection);
      }
    }

    attemptConnection();
  }
}
