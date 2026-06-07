import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;

// We import the core services to re-initialize them in the background isolate
import '../crypto/identity_service.dart';
import 'relay_manager.dart';
import 'websocket_service.dart';
import '../notification_service.dart';
import '../../features/chat/message.dart';

@pragma('vm:entry-point')
class GhostBackgroundService {
  static io.Socket? _bgSocket;
  static Timer? _heartbeatTimer;
  static bool _uiAppActive = false;
  static bool _isConnecting = false;

  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'ghostroom_background',
            'Background Service',
            description: 'Maintains secure connection in background',
            importance: Importance.low,
            showBadge: false,
          ),
        );
      }
    }

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
    DartPluginRegistrant.ensureInitialized();
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(MessageTypeAdapter().typeId)) {
      Hive.registerAdapter(MessageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(MessageAdapter().typeId)) {
      Hive.registerAdapter(MessageAdapter());
    }

    final sodium = await SodiumSumoInit.init();
    const storage = FlutterSecureStorage();
    
    final idService = IdentityService(sodium, storage);
    final relayManager = RelayManager(storage);
    final notificationService = NotificationService();
    await notificationService.init();

    // Setup communication with UI App
    service.on('appForeground').listen((event) {
      debugPrint('BG_SERVICE: Received appForeground. Disconnecting background socket.');
      _uiAppActive = true;
      _disconnectBackground();
      _resetHeartbeatTimeout(idService, relayManager, notificationService, sodium, storage);
    });

    service.on('appBackground').listen((event) {
      debugPrint('BG_SERVICE: Received appBackground. Connecting background socket.');
      _uiAppActive = false;
      _cancelHeartbeatTimeout();
      _connectBackground(idService, relayManager, notificationService, sodium, storage);
    });

    service.on('heartbeat').listen((event) {
      debugPrint('BG_SERVICE: Received heartbeat. UI App is active.');
      _uiAppActive = true;
      _disconnectBackground();
      _resetHeartbeatTimeout(idService, relayManager, notificationService, sodium, storage);
    });

    // Startup behavior: wait 15 seconds for a heartbeat / foreground event
    _heartbeatTimer = Timer(const Duration(seconds: 15), () {
      if (!_uiAppActive) {
        debugPrint('BG_SERVICE: Startup timeout reached without UI heartbeat. Connecting...');
        _connectBackground(idService, relayManager, notificationService, sodium, storage);
      }
    });
  }

  static void _resetHeartbeatTimeout(
    IdentityService idService,
    RelayManager relayManager,
    NotificationService notificationService,
    SodiumSumo sodium,
    FlutterSecureStorage storage,
  ) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(const Duration(seconds: 12), () {
      debugPrint('BG_SERVICE: Heartbeat timeout reached. Assuming UI App inactive. Connecting...');
      _uiAppActive = false;
      _connectBackground(idService, relayManager, notificationService, sodium, storage);
    });
  }

  static void _cancelHeartbeatTimeout() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static void _disconnectBackground() {
    if (_bgSocket != null) {
      debugPrint('BG_SERVICE: Disposing background socket.');
      _bgSocket!.disconnect();
      _bgSocket!.dispose();
      _bgSocket = null;
    }
    _isConnecting = false;
  }

  static void _connectBackground(
    IdentityService idService,
    RelayManager relayManager,
    NotificationService notificationService,
    SodiumSumo sodium,
    FlutterSecureStorage storage,
  ) async {
    if (_uiAppActive) {
      debugPrint('BG_SERVICE: Prevent connection because UI App is active.');
      return;
    }
    if (_bgSocket != null && _bgSocket!.connected) {
      debugPrint('BG_SERVICE: Already connected.');
      return;
    }
    if (_isConnecting) {
      debugPrint('BG_SERVICE: Connection attempt already in progress.');
      return;
    }
    _isConnecting = true;

    void attemptConnection() async {
      if (_uiAppActive) {
        _isConnecting = false;
        return;
      }

      try {
        await idService.initIdentity();
        final identity = idService.currentIdentity;
        if (identity == null) {
          debugPrint('BG_SERVICE: No identity found. Retrying in 30s...');
          _isConnecting = false;
          _heartbeatTimer = Timer(const Duration(seconds: 30), attemptConnection);
          return;
        }

        final activeId = await relayManager.getActiveRelayId();
        final relays = await relayManager.getRelays();
        final profile = relays.where((r) => r.id == activeId).firstOrNull ?? (relays.isNotEmpty ? relays.first : null);

        if (profile == null) {
          debugPrint('BG_SERVICE: No relay found. Retrying in 30s...');
          _isConnecting = false;
          _heartbeatTimer = Timer(const Duration(seconds: 30), attemptConnection);
          return;
        }

        if (_uiAppActive) {
          _isConnecting = false;
          return;
        }

        // Dispose previous socket if any
        if (_bgSocket != null) {
          _bgSocket!.dispose();
          _bgSocket = null;
        }

        debugPrint('BG_SERVICE: Connecting to relay: ${profile.websocketUrl}');
        final socket = WebSocketService.createRawSocket(profile);
        _bgSocket = socket;
        
        socket.on('connect', (_) {
          debugPrint('BG_SERVICE: Connected to relay');
          _isConnecting = false;
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

        socket.on('identity.verified', (_) async {
          debugPrint('BG_SERVICE: Identity verified. Fetching missed messages...');
          try {
            final lastSyncStr = await storage.read(key: 'bg_last_sync_t');
            final lastSync = lastSyncStr != null ? int.parse(lastSyncStr) : 0;
            socket.emit('inbox.fetch', {'since': lastSync});
          } catch (e) {
            debugPrint('BG_SERVICE: Error fetching inbox: $e');
          }
        });

        socket.on('inbox.messages', (data) async {
          try {
            final messages = data['messages'] as List<dynamic>;
            debugPrint('BG_SERVICE: Received ${messages.length} messages in inbox fetch.');
            
            final lastSyncStr = await storage.read(key: 'bg_last_sync_t');
            int lastSync = lastSyncStr != null ? int.parse(lastSyncStr) : 0;
            bool updated = false;

            for (final msg in messages) {
              final String msgId = msg['id'] as String;
              final int timestamp = msg['t'] as int;
              
              final isProc = await _isMessageProcessed(storage, msgId);
              if (!isProc) {
                updated = true;
                debugPrint('BG_SERVICE: Notifying for missed message: $msgId');
                notificationService.showNotification(
                  title: 'New Private Message',
                  body: 'Encrypted payload received via GhostRoom.',
                  payload: identity.publicId,
                );
                await _markMessageProcessed(storage, msgId);
                if (timestamp > lastSync) {
                  lastSync = timestamp;
                }
              }
              socket.emit('message.ack', {'message_id': msgId});
            }
            if (updated) {
              await storage.write(key: 'bg_last_sync_t', value: lastSync.toString());
            }
          } catch (e) {
            debugPrint('BG_SERVICE: Error processing inbox messages: $e');
          }
        });

        socket.on('message.receive', (data) async {
          try {
            final String msgId = data['id'] as String;
            final int timestamp = data['t'] as int;
            
            final isProc = await _isMessageProcessed(storage, msgId);
            if (!isProc) {
              debugPrint('BG_SERVICE: Notifying for real-time message: $msgId');
              notificationService.showNotification(
                title: 'New Private Message',
                body: 'Encrypted payload received via GhostRoom.',
                payload: identity.publicId,
              );
              await _markMessageProcessed(storage, msgId);
              
              final lastSyncStr = await storage.read(key: 'bg_last_sync_t');
              final lastSync = lastSyncStr != null ? int.parse(lastSyncStr) : 0;
              if (timestamp > lastSync) {
                await storage.write(key: 'bg_last_sync_t', value: timestamp.toString());
              }
            }
            socket.emit('message.ack', {'message_id': msgId});
          } catch (e) {
            debugPrint('BG_SERVICE: Error processing background message: $e');
          }
        });

        socket.on('disconnect', (reason) {
          debugPrint('BG_SERVICE: Disconnected ($reason).');
          _isConnecting = false;
          socket.dispose();
          if (_bgSocket == socket) {
            _bgSocket = null;
          }
          if (!_uiAppActive) {
            debugPrint('BG_SERVICE: Retrying connection in 10s...');
            _heartbeatTimer = Timer(const Duration(seconds: 10), attemptConnection);
          }
        });

        socket.connect();
      } catch (e) {
        debugPrint('BG_SERVICE: Connection loop failed: $e.');
        _isConnecting = false;
        if (!_uiAppActive) {
          debugPrint('BG_SERVICE: Retrying connection in 30s...');
          _heartbeatTimer = Timer(const Duration(seconds: 30), attemptConnection);
        }
      }
    }

    attemptConnection();
  }

  static Future<bool> _isMessageProcessed(FlutterSecureStorage storage, String msgId) async {
    try {
      final jsonStr = await storage.read(key: 'bg_processed_ids');
      if (jsonStr == null) return false;
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.contains(msgId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markMessageProcessed(FlutterSecureStorage storage, String msgId) async {
    try {
      final jsonStr = await storage.read(key: 'bg_processed_ids');
      List<String> list = [];
      if (jsonStr != null) {
        list = List<String>.from(jsonDecode(jsonStr));
      }
      if (!list.contains(msgId)) {
        list.add(msgId);
        if (list.length > 200) {
          list.removeAt(0); // Bound size
        }
        await storage.write(key: 'bg_processed_ids', value: jsonEncode(list));
      }
    } catch (_) {}
  }
}
