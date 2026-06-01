import 'package:socket_io_client/socket_io_client.dart' as io;
import 'relay_manager.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'dart:convert';
import '../stability_tracker.dart';

class WebSocketService {
  final Ref _ref;
  final Logger _logger = Logger();
  io.Socket? _socket;
  bool _isAuthenticated = false;
  bool _isConnecting = false;
  String? _activeUrl;

  // Persistent callback registry to survive socket replacement
  final Map<String, dynamic> _callbacks = {};

  WebSocketService(this._ref);

  bool get isConnected => _socket?.connected ?? false;
  bool get isAuthenticated => _isAuthenticated;

  DateTime? _lastConnectAttempt;
  static const _minConnectInterval = Duration(seconds: 3);

  void connect(RelayProfile profile) async {
    final now = DateTime.now();
    if (_lastConnectAttempt != null && now.difference(_lastConnectAttempt!) < _minConnectInterval) {
      _logger.d('WebSocket connection attempt throttled for ${profile.label}');
      return;
    }
    _lastConnectAttempt = now;

    if (_isConnecting) {
      _logger.d('WebSocket connection already in progress for ${profile.label}');
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

    if (_socket != null && _socket!.connected && _activeUrl == connectionUrl) {
      _logger.d('Already connected to ${profile.label}');
      return;
    }

    _logger.i('Connecting to relay: ${profile.label} ($connectionUrl)');
    StabilityTracker.logEvent('WS_Connecting', data: {'relay': profile.label});
    _isConnecting = true;

    try {
      if (_socket != null) {
        _logger.i('Disposing existing socket before new connection');
        _socket!.dispose();
        _socket = null;
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

    _socket!.onConnect((_) {
      _logger.i('Connected to relay: ${profile.label}');
      _logger.i("SOCKET_CONNECTED");
      StabilityTracker.logEvent('WS_Connected');
    });

    _socket!.on('identity.challenge', (data) async {
      final nonce = data['nonce'] as String;
      _logger.d('Received identity challenge. Solving...');
      
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
        });
      } catch (e) {
        _logger.e('Failed to solve identity challenge: $e');
      }
    });

    _socket!.on('identity.verified', (data) {
      _isAuthenticated = true;
      _logger.i('Identity verified by relay: ${data['public_id']}');
      try {
        final lastSync = _ref.read(chatRepositoryProvider).lastSyncTimestamp;
        _logger.i("GHOST_LOG: INBOX_FETCH since $lastSync");
        fetchInbox(since: lastSync);
      } catch (e) {
        _logger.e('Failed to auto-fetch inbox after verification: $e');
      }
    });

    _socket!.on('message.receive', (data) {
      _logger.i("GHOST_LOG: MESSAGE_RECEIVED_CLIENT");
      
      if (data != null && data['v'] == 2) {
        try {
          _ref.read(chatRepositoryProvider).processEnvelopes([data]);
        } catch (e) {
          _logger.e('Failed to process real-time V2 envelope: $e');
        }
      }

      final callback = _callbacks['message.receive'];
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
      _logger.w('Disconnected from relay. Reason: $reason');
      _isAuthenticated = false;
    });

    _socket!.onConnectError((err) {
      _logger.e('Connection error: $err');
    });

    _socket!.onError((err) {
      _logger.e('Socket error: $err');
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

  void acknowledgeMessage(String messageId) {
    if (!_isAuthenticated) return;
    _socket?.emit('message.ack', {'message_id': messageId});
  }

  void sendMessage(String targetId, Map<String, dynamic> payload, {int version = 1, Function(dynamic)? ack}) {
    final Map<String, dynamic> data = {
      'target_id': targetId,
      'v': version,
      ...payload
    };
    if (ack != null) {
      _socket?.emitWithAck('message.send', data, ack: (response) {
        ack(response);
      });
    } else {
      _socket?.emit('message.send', data);
    }
  }

  void onInboxMessages(Function(List<dynamic>) callback) {
    _callbacks['inbox.messages'] = callback;
  }

  void onMessage(Function(dynamic) callback) {
    _callbacks['message.receive'] = callback;
  }

  void onHistory(Function(dynamic) callback) {
    _callbacks['space.history'] = callback;
  }

  void onSpaceExpired(Function(dynamic) callback) {
    _callbacks['space.expired'] = callback;
  }

  void clearRoomCallbacks() {
    _callbacks.remove('message.receive');
    _callbacks.remove('space.history');
    _callbacks.remove('space.expired');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isAuthenticated = false;
  }
}
