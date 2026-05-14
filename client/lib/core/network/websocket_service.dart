import 'package:socket_io_client/socket_io_client.dart' as io;
import 'relay_manager.dart';
import 'package:logger/logger.dart';

class WebSocketService {
  final Logger _logger = Logger();
  io.Socket? _socket;
  RelayProfile? _currentProfile;

  bool get isConnected => _socket?.connected ?? false;

  void connect(RelayProfile profile) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    _currentProfile = profile;
    
    // Ensure the URL is in a format socket_io_client likes (http/https instead of ws/wss for the handshake)
    String connectionUrl = profile.websocketUrl;
    if (connectionUrl.startsWith('ws://')) {
      connectionUrl = connectionUrl.replaceFirst('ws://', 'http://');
    } else if (connectionUrl.startsWith('wss://')) {
      connectionUrl = connectionUrl.replaceFirst('wss://', 'https://');
    }

    _socket = io.io(connectionUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'forceNew': true,
      'extraHeaders': profile.token != null ? {'Authorization': 'Bearer ${profile.token}'} : {},
    });

    _socket!.onConnect((_) {
      _logger.i('Connected to relay: ${profile.label} at $connectionUrl');
    });

    _socket!.onDisconnect((reason) {
      _logger.w('Disconnected from relay: ${profile.label}. Reason: $reason');
    });

    _socket!.onConnectError((err) {
      _logger.e('Connection error for ${profile.label} at $connectionUrl: $err');
    });

    _socket!.onError((err) {
      _logger.e('Socket error: $err');
    });
  }

  void joinSpace(String roomId) {
    _socket?.emit('space.join', {'roomId': roomId});
  }

  void sendMessage(String roomId, Map<String, dynamic> payload) {
    _socket?.emit('message.send', {
      'roomId': roomId,
      ...payload,
    });
  }

  void onMessage(Function(dynamic) callback) {
    _socket?.on('message.receive', (data) => callback(data));
  }

  void onSpaceExpired(Function(dynamic) callback) {
    _socket?.on('space.expired', (data) => callback(data));
  }

  void disconnect() {
    _socket?.disconnect();
  }
}
