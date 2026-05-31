import 'package:socket_io_client/socket_io_client.dart' as io;
import 'relay_manager.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'dart:convert';

class WebSocketService {
  final Ref _ref;
  final Logger _logger = Logger();
  io.Socket? _socket;
  bool _isAuthenticated = false;

  WebSocketService(this._ref);

  bool get isConnected => _socket?.connected ?? false;
  bool get isAuthenticated => _isAuthenticated;

  void connect(RelayProfile profile) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    _isAuthenticated = false;

    // Ensure the URL is in a format socket_io_client likes
    String connectionUrl = profile.websocketUrl;
    if (connectionUrl.startsWith('ws://')) {
      connectionUrl = connectionUrl.replaceFirst('ws://', 'http://');
    } else if (connectionUrl.startsWith('wss://')) {
      connectionUrl = connectionUrl.replaceFirst('wss://', 'https://');
    }

    _socket = io.io(
      connectionUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .setExtraHeaders(
            profile.token != null
                ? {'Authorization': 'Bearer ${profile.token}'}
                : {},
          )
          .build(),
    );

    _socket!.onConnect((_) {
      _logger.i('Connected to relay: ${profile.label}');
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

  void sendMessage(String targetId, Map<String, dynamic> payload, {int version = 1}) {
    _socket?.emit('message.send', {
      'target_id': targetId,
      'v': version,
      ...payload
    });
  }

  void onInboxMessages(Function(List<dynamic>) callback) {
    _socket?.off('inbox.messages');
    _socket?.on('inbox.messages', (data) {
      callback(data['messages'] as List<dynamic>);
    });
  }

  void onMessage(Function(dynamic) callback) {
    _socket?.off('message.receive');
    _socket?.on('message.receive', (data) => callback(data));
  }

  void onHistory(Function(dynamic) callback) {
    _socket?.off('space.history');
    _socket?.on('space.history', (data) => callback(data));
  }

  void onSpaceExpired(Function(dynamic) callback) {
    _socket?.off('space.expired');
    _socket?.on('space.expired', (data) => callback(data));
  }

  void disconnect() {
    _socket?.disconnect();
  }
}
