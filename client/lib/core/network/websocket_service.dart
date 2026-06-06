import 'package:socket_io_client/socket_io_client.dart' as io;
import 'relay_manager.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'dart:async';
import 'dart:convert';
import '../stability_tracker.dart';

class WebSocketService {
  final Ref _ref;
  io.Socket? _socket;
  final Logger _logger = Logger();
  bool _isConnected = false;
  bool _isAuthenticated = false;
  String? _activeUrl;
  bool _isConnecting = false;
  bool _listenerSetupDone = false;

  // Diagnostics
  int _connectCount = 0;
  int _disconnectCount = 0;
  int _reconnectCount = 0;
  int _listenerInitCount = 0;

  final Map<String, Function> _callbacks = {};

  WebSocketService(this._ref);

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  io.Socket? get socket => _socket;

  Future<void> connect(RelayProfile profile) async {
    if (_isConnecting) return;
    
    String connectionUrl = profile.websocketUrl;
    // Socket.IO client expects http/https but will upgrade to ws
    if (connectionUrl.startsWith('ws://')) {
      connectionUrl = connectionUrl.replaceFirst('ws://', 'http://');
    } else if (connectionUrl.startsWith('wss://')) {
      connectionUrl = connectionUrl.replaceFirst('wss://', 'https://');
    }

    if (_socket != null && _activeUrl == connectionUrl) {
      _logger.d('WebSocket already targeting ${profile.label}. Status: ${_socket!.connected ? "Connected" : "Reconnecting/Disconnected"}');
      if (!_socket!.connected) {
        _logger.d('Ensuring existing socket is connected...');
        _socket!.connect(); // Manually trigger connect if autoConnect didn't catch it
      }
      return;
    }

    _logger.i('Connecting to relay: ${profile.label} ($connectionUrl)');
    StabilityTracker.logEvent('WS_Connecting', data: {'relay': profile.label});
    _isConnecting = true;

    try {
      if (_socket != null) {
        _logger.i('Disposing existing socket for different URL: $_activeUrl -> $connectionUrl');
        _socket!.dispose();
        _socket = null;
        _listenerSetupDone = false;
      }

      _isAuthenticated = false;

      _socket = io.io(
        connectionUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableForceNew() // Ensure a fresh instance
            .setExtraHeaders(
              profile.token != null
                  ? {'Authorization': 'Bearer ${profile.token}'}
                  : {},
            )
            .build(),
      );

      _activeUrl = connectionUrl;
      _setupInternalListeners(profile);

    } catch (e) {
      _logger.e('Failed to initiate WebSocket connection: $e');
    } finally {
      _isConnecting = false;
    }
  }

  static io.Socket createRawSocket(RelayProfile profile) {
    String connectionUrl = profile.websocketUrl;
    if (connectionUrl.startsWith('ws://')) {
      connectionUrl = connectionUrl.replaceFirst('ws://', 'http://');
    } else if (connectionUrl.startsWith('wss://')) {
      connectionUrl = connectionUrl.replaceFirst('wss://', 'https://');
    }

    return io.io(
      connectionUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect() // Correct method
          .setExtraHeaders(
            profile.token != null
                ? {'Authorization': 'Bearer ${profile.token}'}
                : {},
          )
          .build(),
    );
  }

  void _setupInternalListeners(RelayProfile profile) {
    if (_socket == null) return;

    assert(!_listenerSetupDone);
    _listenerSetupDone = true;

    _listenerInitCount++;
    _logger.i('GHOST_LOG: WS_LISTENERS_INITIALIZED count: $_listenerInitCount');

    _socket!.on('connect', (_) {
      _connectCount++;
      _logger.i('Connected to relay: ${profile.label}');
      _logger.i("SOCKET_CONNECTED");
      _logger.i('GHOST_LOG: WS_CONNECT count: $_connectCount');
      StabilityTracker.logEvent('WS_Connected');
      
      _isConnected = true;
      _ref.invalidate(activeRelayProvider);
    });

    _socket!.on('reconnect', (_) {
      _reconnectCount++;
      _logger.i('Reconnected to relay: ${profile.label}');
      _logger.i('GHOST_LOG: WS_RECONNECT count: $_reconnectCount');
      StabilityTracker.logEvent('WS_Reconnected');
    });

    _socket!.on('disconnect', (reason) {
      _disconnectCount++;
      _isConnected = false;
      _isAuthenticated = false;
      _logger.w('Disconnected from relay: ${profile.label}. Reason: $reason');
      _logger.i('GHOST_LOG: WS_DISCONNECT count: $_disconnectCount');
      StabilityTracker.logEvent('WS_Disconnected', data: {'reason': reason});
      _ref.invalidate(activeRelayProvider);
    });

    _socket!.on('identity.challenge', (data) async {
      _logger.d('Received identity challenge');
      final nonce = data['nonce'] as String;
      
      final idService = _ref.read(identityServiceProvider);
      final identity = idService.currentIdentity;
      
      if (identity == null) {
        _logger.e('Cannot prove identity: No identity loaded');
        return;
      }

      final signature = idService.signChallenge(nonce);
      
      _socket!.emit('identity.prove', {
        'public_id': identity.publicId,
        'public_key': base64Encode(identity.ed25519KeyPair.publicKey),
        'signature': signature,
        'device_id': identity.deviceId,
      });
    });

    _socket!.on('identity.verified', (data) {
      _logger.i('GHOST_LOG: Identity verified successfully');
      _isAuthenticated = true;
      
      final callback = _callbacks['identity.verified'];
      if (callback != null) {
        callback(data);
      }
    });

    _socket!.on('message.receive', (data) {
      _logger.i("GHOST_LOG: MESSAGE_RECEIVED_CLIENT");

      final callback = _callbacks['message.receive'];
      if (callback != null) {
        callback(data);
      }
    });

    _socket!.on('message.status_update', (data) {
      _logger.d('Received status update: $data');
      final callback = _callbacks['message.status_update'];
      if (callback != null) {
        callback(data);
      }
    });

    _socket!.on('inbox.messages', (data) {
      final callback = _callbacks['inbox.messages'];
      if (callback != null) {
        final messages = data['messages'] as List<dynamic>? ?? [];
        callback(messages);
      }
    });

    _socket!.on('space.joined', (data) {
      _logger.i('Joined space: ${data['roomId']}');
    });

    _socket!.on('space.history', (data) {
      final callback = _callbacks['space.history'];
      if (callback != null) {
        callback(data);
      }
    });

    _socket!.on('space.expired', (data) {
      final callback = _callbacks['space.expired'];
      if (callback != null) {
        callback(data);
      }
    });

    _socket!.on('error', (data) {
      _logger.e('WebSocket error: $data');
      StabilityTracker.logEvent('WS_Error', data: {'error': data.toString()});
    });

    _socket!.onConnectError((err) {
      _logger.e('Connection error: $err');
      StabilityTracker.logEvent('WS_Connect_Error', data: {'error': err.toString()});
    });
  }

  void onIdentityVerified(Function(dynamic) callback) {
    _callbacks['identity.verified'] = callback;
  }

  void onMessage(Function(dynamic) callback) {
    _callbacks['message.receive'] = callback;
  }

  void onStatusUpdate(Function(dynamic) callback) {
    _callbacks['message.status_update'] = callback;
  }

  void onInboxMessages(Function(List<dynamic>) callback) {
    _callbacks['inbox.messages'] = callback;
  }

  void onHistory(Function(dynamic) callback) {
    _callbacks['space.history'] = callback;
  }

  void onSpaceExpired(Function(dynamic) callback) {
    _callbacks['space.expired'] = callback;
  }

  void clearRoomCallbacks() {
    _callbacks.remove('message.receive');
    _callbacks.remove('message.status_update');
    _callbacks.remove('space.history');
    _callbacks.remove('space.expired');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isAuthenticated = false;
    _listenerSetupDone = false;
  }

  void sendSeen(String messageId) {
    if (!_isAuthenticated) return;
    _socket?.emit('message.seen', {'message_id': messageId});
  }

  void acknowledgeMessage(String messageId) {
    if (!_isAuthenticated) return;
    _socket?.emit('message.ack', {'message_id': messageId});
  }

  void joinRoom(String roomId) {
    if (!_isAuthenticated) return;
    _socket?.emit('space.join', {'roomId': roomId});
  }

  void sendMessage(String recipientId, Map<String, dynamic> payload, {int version = 1, Function(dynamic)? ack}) {
    if (!_isAuthenticated) {
      _logger.w('Cannot send message: Not authenticated');
      return;
    }
    
    if (ack != null) {
       _socket?.emitWithAck('message.send', {
        'recipient_id': recipientId,
        'payload': payload,
        'version': version,
      }, ack: ack);
    } else {
      _socket?.emit('message.send', {
        'recipient_id': recipientId,
        'payload': payload,
        'version': version,
      });
    }
  }

  void fetchInbox({int since = 0}) {
    if (!_isAuthenticated) return;
    _socket?.emit('inbox.fetch', {'since': since});
  }

  Future<List<Map<String, dynamic>>> getDevices(String publicId) async {
    if (!_isAuthenticated) return [];
    
    final completer = Completer<List<Map<String, dynamic>>>();
    _socket?.emitWithAck('identity.devices', {'public_id': publicId}, ack: (response) {
      if (response != null && response['status'] == 'ok') {
        final devices = List<Map<String, dynamic>>.from(response['devices'] ?? []);
        completer.complete(devices);
      } else {
        completer.complete([]);
      }
    });
    
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  void logMemoryUsage() {
    final stats = {
      'isConnected': _isConnected,
      'isAuthenticated': _isAuthenticated,
      'callbacksCount': _callbacks.length,
      'connectCount': _connectCount,
      'disconnectCount': _disconnectCount,
      'reconnectCount': _reconnectCount,
    };
    StabilityTracker.logComponentDiagnostics('WebSocketService', stats);
  }
}
