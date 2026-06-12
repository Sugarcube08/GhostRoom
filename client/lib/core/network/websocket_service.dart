import 'package:socket_io_client/socket_io_client.dart' as io;
import 'relay_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class WebSocketService {
  final Ref _ref;
  io.Socket? _socket;
  bool _isAuthenticated = false;
  bool _isConnecting = false;
  String? _activeUrl;

  // Persistent callback registry to survive socket replacement
  final Map<String, dynamic> _callbacks = {};

  bool _listenerSetupDone = false;

  WebSocketService(this._ref);

  bool get isConnected => _socket?.connected ?? false;
  bool get isAuthenticated => _isAuthenticated;
  io.Socket? get socket => _socket;

  DateTime? _lastConnectAttempt;
  static const _minConnectInterval = Duration(seconds: 3);

  void connect(RelayProfile profile) async {
    final now = DateTime.now();
    if (_lastConnectAttempt != null &&
        now.difference(_lastConnectAttempt!) < _minConnectInterval) {
      return;
    }
    _lastConnectAttempt = now;

    if (_isConnecting) {
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
      if (!_socket!.connected) {
        _socket!
            .connect(); // Manually trigger connect if autoConnect didn't catch it
      }
      return;
    }

    // ignore: avoid_print
    // ignore: avoid_print
    _isConnecting = true;

    try {
      if (_socket != null) {
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
    } catch (_) {
      // Ignore
    } finally {
      _isConnecting = false;
    }
  }

  void _setupInternalListeners(RelayProfile profile) {
    if (_socket == null) return;

    _socket!.onAny((event, data) {
    });

    assert(!_listenerSetupDone);
    _listenerSetupDone = true;

    _socket!.onConnect((_) {
      // ignore: avoid_print
      // ignore: avoid_print
    });

    _socket!.on('reconnect', (_) {
    });

    _socket!.on('identity.challenge', (data) async {
      final nonce = data['nonce'] as String;
      // ignore: avoid_print

      try {
        final idService = _ref.read(identityServiceProvider);
        final identity = idService.currentIdentity;
        if (identity == null) {
          return;
        }

        final signature = idService.signChallenge(nonce);

        _socket!.emit('identity.prove', {
          'public_id': identity.publicId,
          'public_key': base64Encode(identity.ed25519KeyPair.publicKey),
          'signature': signature,
          'device_id': identity.deviceId,
        });
      } catch (_) {
        // Ignore
      }
    });

    _socket!.on('identity.verified', (data) {
      _isAuthenticated = true;
      // ignore: avoid_print

      final callback = _callbacks['identity.verified'];
      if (callback != null) {
        try {
          callback(data);
        } catch (_) {
          // Ignore
        }
      }
    });

    _socket!.on('message.receive', (data) {

      final callback = _callbacks['message.receive'];
      if (callback != null) {
        callback(data);
      }
    });

    _socket!.on('message.status_update', (data) {
      // ignore: avoid_print
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
      _isAuthenticated = false;
    });

    _socket!.onConnectError((err) {
      // ignore: avoid_print
    });

    _socket!.onError((err) {
      // ignore: avoid_print
    });

    _socket!.on('space.joined', (data) {
    });

    _socket!.on('error', (data) {
    });
  }

  void joinSpace(String roomId, String deviceId) {
    _socket?.emit('space.join', {'roomId': roomId, 'deviceId': deviceId});
  }

  void fetchInbox({int since = 0}) {
    if (!_isAuthenticated) {
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
        return false;
      }
      
      final identity = idService.currentIdentity;
      if (identity == null) {
        return false;
      }

      final signature = idService.signChallenge(messageId);
      final publicKey = base64Encode(identity.ed25519KeyPair.publicKey);
      final publicId = identity.publicId;
      final deviceId = identity.deviceId;

      final url = '${relay.apiUrl}/delivery-receipt';

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
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> acknowledgeMessage(String messageId) async {
    final completer = Completer<bool>();
    
    // ignore: avoid_print

    if (!_isAuthenticated) {
      final success = await _sendDeliveryReceiptHttp(messageId);
      if (success) {
        // ignore: avoid_print
        return true;
      }
      // ignore: avoid_print
      return false;
    }

    // ignore: avoid_print
    // ignore: avoid_print
    _socket?.emitWithAck(
      'message.ack',
      {'message_id': messageId},
      ack: (response) {
        // ignore: avoid_print
        // ignore: avoid_print
        // ignore: avoid_print
        completer.complete(true);
      },
    );

    Future.delayed(const Duration(seconds: 3), () async {
      if (!completer.isCompleted) {
        final success = await _sendDeliveryReceiptHttp(messageId);
        if (success) {
          // ignore: avoid_print
          completer.complete(true);
        } else {
          // ignore: avoid_print
          completer.complete(false);
        }
      }
    });
    return completer.future;
  }

  Future<bool> sendDeliveryReceipt(String messageId) async {
    // ignore: avoid_print
    final result = await acknowledgeMessage(messageId);
    // ignore: avoid_print
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
}
