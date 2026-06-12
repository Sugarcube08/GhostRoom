import 'package:socket_io_client/socket_io_client.dart' as io;
import 'relay_manager.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../providers.dart';
import 'dart:convert';
import 'dart:async';
import '../stability_tracker.dart';
import 'package:http/http.dart' as http;

class WebSocketService {
  final Ref _ref;
  final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.info,
  );
  io.Socket? _socket;
  bool _isAuthenticated = false;
  bool _isConnecting = false;
  String? _activeUrl;

  // Persistent callback registry to survive socket replacement
  final Map<String, dynamic> _callbacks = {};

  bool _listenerSetupDone = false;
  int _connectCount = 0;
  int _disconnectCount = 0;
  int _reconnectCount = 0;
  int _listenerInitCount = 0;

  WebSocketService(this._ref) {
    _logger.i(
      'GHOST_LOG: WebSocketService constructor invoked (Singleton verification)',
    );
  }

  bool get isConnected => _socket?.connected ?? false;
  bool get isAuthenticated => _isAuthenticated;
  io.Socket? get socket => _socket;

  DateTime? _lastConnectAttempt;
  static const _minConnectInterval = Duration(seconds: 3);

  void connect(RelayProfile profile) async {
    final now = DateTime.now();
    if (_lastConnectAttempt != null &&
        now.difference(_lastConnectAttempt!) < _minConnectInterval) {
      _logger.d('WebSocket connection attempt throttled for ${profile.label}');
      return;
    }
    _lastConnectAttempt = now;

    if (_isConnecting) {
      _logger.d(
        'WebSocket connection already in progress for ${profile.label}',
      );
      StabilityTracker.logEvent('WS_Connect_Skipped_Busy');
      return;
    }

    // Ensure the URL is in a format socket_io_client likes
    String connectionUrl = profile.websocketUrl;
    if (connectionUrl.startsWith('ws://')) {
      connectionUrl = connectionUrl.replaceFirst('ws://', 'http://');
    } else if (connectionUrl.startsWith('wss://')) {
      connectionUrl = connectionUrl.replaceFirst('wss://', 'https://');
    }

    if (_socket != null && _activeUrl == connectionUrl) {
      _logger.d(
        'WebSocket already targeting ${profile.label}. Status: ${_socket!.connected ? "Connected" : "Reconnecting/Disconnected"}',
      );
      if (!_socket!.connected) {
        _logger.d('Ensuring existing socket is connected...');
        _socket!
            .connect(); // Manually trigger connect if autoConnect didn't catch it
      }
      return;
    }

    _logger.i('Connecting to relay: ${profile.label} ($connectionUrl)');
    // ignore: avoid_print
    print("WS_CONNECT_START");
    // ignore: avoid_print
    print("SOCKET_CONNECT_START");
    StabilityTracker.logEvent('WS_Connecting', data: {'relay': profile.label});
    _isConnecting = true;

    try {
      if (_socket != null) {
        _logger.i(
          'Disposing existing socket for different URL: $_activeUrl -> $connectionUrl',
        );
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

  void _setupInternalListeners(RelayProfile profile) {
    if (_socket == null) return;

    _socket!.onAny((event, data) {
      debugPrint('SOCKET_EVENT=$event');
    });

    assert(!_listenerSetupDone);
    _listenerSetupDone = true;

    _listenerInitCount++;
    _logger.i('GHOST_LOG: WS_LISTENERS_INITIALIZED count: $_listenerInitCount');

    _socket!.onConnect((_) {
      _connectCount++;
      _logger.i('Connected to relay: ${profile.label}');
      // ignore: avoid_print
      print("WS_CONNECT_SUCCESS");
      // ignore: avoid_print
      print("SOCKET_CONNECT_SUCCESS");
      _logger.i("SOCKET_CONNECTED");
      _logger.i('GHOST_LOG: WS_CONNECT count: $_connectCount');
      StabilityTracker.logEvent('WS_Connected');
    });

    _socket!.on('reconnect', (_) {
      _reconnectCount++;
      _logger.i('GHOST_LOG: WS_RECONNECT count: $_reconnectCount');
    });

    _socket!.on('identity.challenge', (data) async {
      final nonce = data['nonce'] as String;
      _logger.d('Received identity challenge. Solving...');
      // ignore: avoid_print
      print("AUTH_START");

      try {
        final idService = _ref.read(identityServiceProvider);
        final identity = idService.currentIdentity;
        if (identity == null) {
          _logger.w('Identity not ready. Cannot solve challenge.');
          return;
        }

        final signature = idService.signChallenge(nonce);

        _socket!.emit('identity.prove', {
          'public_id': identity.publicId,
          'public_key': base64Encode(identity.ed25519KeyPair.publicKey),
          'signature': signature,
          'device_id': identity.deviceId,
        });
      } catch (e) {
        _logger.e('Failed to solve identity challenge: $e');
      }
    });

    _socket!.on('identity.verified', (data) {
      _isAuthenticated = true;
      _logger.i('Identity verified by relay: ${data['public_id']}');
      // ignore: avoid_print
      print("AUTH_SUCCESS");

      final callback = _callbacks['identity.verified'];
      if (callback != null) {
        try {
          callback(data);
        } catch (e) {
          _logger.e('Error in identity.verified callback: $e');
        }
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
      // ignore: avoid_print
      print('STATUS_UPDATE_RECEIVED=$data');
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

    _socket!.onDisconnect((reason) {
      _disconnectCount++;
      _logger.w('Disconnected from relay. Reason: $reason');
      _logger.i('GHOST_LOG: WS_DISCONNECT count: $_disconnectCount');
      _isAuthenticated = false;
    });

    _socket!.onConnectError((err) {
      _logger.e('Connection error: $err');
      // ignore: avoid_print
      print("SOCKET_CONNECT_FAILURE");
    });

    _socket!.onError((err) {
      _logger.e('Socket error: $err');
      // ignore: avoid_print
      print("SOCKET_CONNECT_FAILURE");
    });

    _socket!.on('space.joined', (data) {
      _logger.i('Successfully joined space: ${data['roomId']}');
    });

    _socket!.on('error', (data) {
      _logger.e('Server error: ${data['message']}');
    });
  }

  void joinSpace(String roomId, String deviceId) {
    _socket?.emit('space.join', {'roomId': roomId, 'deviceId': deviceId});
  }

  void fetchInbox({int since = 0}) {
    if (!_isAuthenticated) {
      _logger.w('Cannot fetch inbox: Not authenticated');
      return;
    }
    _socket?.emit('inbox.fetch', {'since': since});
  }

  Future<bool> _sendDeliveryReceiptHttp(String messageId) async {
    try {
      final idService = _ref.read(identityServiceProvider);
      final relayManager = _ref.read(relayManagerProvider);
      final relay = await relayManager.getActiveRelay();
      
      if (relay == null) {
        _logger.e('HTTP delivery receipt: No active relay.');
        return false;
      }
      
      final identity = idService.currentIdentity;
      if (identity == null) {
        _logger.e('HTTP delivery receipt: No identity initialized.');
        return false;
      }

      final signature = idService.signChallenge(messageId);
      final publicKey = base64Encode(identity.ed25519KeyPair.publicKey);
      final publicId = identity.publicId;
      final deviceId = identity.deviceId;

      final url = '${relay.apiUrl}/delivery-receipt';
      _logger.i('HTTP delivery receipt: Sending POST to $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'public_id': publicId,
          'device_id': deviceId,
          'message_id': messageId,
          'public_key': publicKey,
          'signature': signature,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('HTTP delivery receipt: Successfully acknowledged $messageId');
        return true;
      } else {
        _logger.e('HTTP delivery receipt: Failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('HTTP delivery receipt: Error sending receipt: $e');
      return false;
    }
  }

  Future<bool> acknowledgeMessage(String messageId) async {
    final completer = Completer<bool>();
    
    // ignore: avoid_print
    print("DELIVERY_RECEIPT_START");

    if (!_isAuthenticated) {
      final success = await _sendDeliveryReceiptHttp(messageId);
      if (success) {
        // ignore: avoid_print
        print("DELIVERY_RECEIPT_SUCCESS");
        return true;
      }
      // ignore: avoid_print
      print("DELIVERY_RECEIPT_FAILURE=Not authenticated and HTTP receipt failed");
      return false;
    }

    // ignore: avoid_print
    print("DELIVERY_RECEIPT_SEND_START");
    // ignore: avoid_print
    print("SOCKET_EMIT_WITH_ACK_START");
    _socket?.emitWithAck(
      'message.ack',
      {'message_id': messageId},
      ack: (response) {
        // ignore: avoid_print
        print("SOCKET_EMIT_WITH_ACK_SUCCESS");
        // ignore: avoid_print
        print("DELIVERY_RECEIPT_SEND_SUCCESS");
        // ignore: avoid_print
        print("DELIVERY_RECEIPT_SUCCESS");
        completer.complete(true);
      },
    );

    Future.delayed(const Duration(seconds: 3), () async {
      if (!completer.isCompleted) {
        final success = await _sendDeliveryReceiptHttp(messageId);
        if (success) {
          // ignore: avoid_print
          print("DELIVERY_RECEIPT_SUCCESS");
          completer.complete(true);
        } else {
          // ignore: avoid_print
          print("DELIVERY_RECEIPT_FAILURE=Socket ack timeout and HTTP receipt failed");
          completer.complete(false);
        }
      }
    });
    return completer.future;
  }

  Future<bool> sendDeliveryReceipt(String messageId) async {
    // ignore: avoid_print
    print("API_SEND_DELIVERY_RECEIPT_START");
    final result = await acknowledgeMessage(messageId);
    // ignore: avoid_print
    print("API_SEND_DELIVERY_RECEIPT_SUCCESS");
    return result;
  }

  void sendMessage(
    String targetId,
    Map<String, dynamic> payload, {
    int version = 1,
    Function(dynamic)? ack,
  }) {
    final Map<String, dynamic> data = {
      'target_id': targetId,
      'v': version,
      ...payload,
    };
    if (ack != null) {
      _socket?.emitWithAck(
        'message.send',
        data,
        ack: (response) {
          ack(response);
        },
      );
    } else {
      _socket?.emit('message.send', data);
    }
  }

  void onIdentityVerified(Function(dynamic) callback) {
    _callbacks['identity.verified'] = callback;
  }

  void onInboxMessages(Function(List<dynamic>) callback) {
    _callbacks['inbox.messages'] = callback;
  }

  void onMessage(Function(dynamic) callback) {
    _callbacks['message.receive'] = callback;
  }

  void onStatusUpdate(Function(dynamic) callback) {
    _callbacks['message.status_update'] = callback;
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

  Future<List<Map<String, dynamic>>> getDevices(String publicId) async {
    if (!_isAuthenticated) return [];

    final completer = Completer<List<Map<String, dynamic>>>();
    _socket?.emitWithAck(
      'identity.devices',
      {'public_id': publicId},
      ack: (response) {
        if (response != null && response['status'] == 'ok') {
          final devices = List<Map<String, dynamic>>.from(
            response['devices'] ?? [],
          );
          completer.complete(devices);
        } else {
          completer.complete([]);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => [],
    );
  }

  void logMemoryUsage() {
    final stats = {
      'isConnected': isConnected,
      'isAuthenticated': _isAuthenticated,
      'isConnecting': _isConnecting,
      'activeUrl': _activeUrl,
      'callbacksCount': _callbacks.length,
      'connectCount': _connectCount,
      'disconnectCount': _disconnectCount,
      'reconnectCount': _reconnectCount,
    };
    StabilityTracker.logComponentDiagnostics('WebSocketService', stats);
  }
}
