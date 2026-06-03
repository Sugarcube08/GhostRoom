import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../spaces/space_service.dart';
import '../invite/invite_screen.dart';
import 'dart:convert';

class Message {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;

  Message({required this.id, required this.text, required this.isMe, required this.timestamp});
}

class ChatScreen extends ConsumerStatefulWidget {
  final SpaceConfig config;

  const ChatScreen({super.key, required this.config});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('GHOST_LOG: ChatScreen initState starting');
    _setupListeners();
    debugPrint('GHOST_LOG: ChatScreen initState completed');
  }

  @override
  void dispose() {
    ref.read(webSocketServiceProvider).clearRoomCallbacks();
    _controller.dispose();
    super.dispose();
  }

  void _setupListeners() {
    debugPrint('GHOST_LOG: ChatScreen _setupListeners starting');
    final ws = ref.read(webSocketServiceProvider);
    final crypto = ref.read(cryptoServiceProvider);
    
    debugPrint('GHOST_LOG: ChatScreen ws provider ready');
    
    // Get device ID for sender-aware history filtering
    crypto.getDeviceId().then((deviceId) {
      if (deviceId != null) {
        ws.joinSpace(widget.config.roomId, deviceId);
        debugPrint('GHOST_LOG: ChatScreen joinSpace called with DeviceID');
      } else {
        debugPrint('GHOST_LOG: ChatScreen Error: No DeviceID found');
        ws.joinSpace(widget.config.roomId, 'unknown_device');
      }
    });
    
    ws.onMessage((data) {
      debugPrint('GHOST_LOG: ChatScreen onMessage received: $data');
      _processMessage(data, isMe: false);
    });

    ws.onHistory((data) {
      debugPrint('GHOST_LOG: ChatScreen onHistory received. Messages: ${data['messages']?.length}');
      final List<dynamic> messages = data['messages'] ?? [];
      for (final msg in messages) {
        _processMessage(msg, isMe: false);
      }
    });

    _socketErrorListener();

    ws.onSpaceExpired((_) {
      debugPrint('GHOST_LOG: ChatScreen space expired');
      if (mounted) _showExpiredDialog();
    });
  }

  void _processMessage(dynamic data, {required bool isMe}) {
    if (!mounted) return;
    final ciphertext = data['ciphertext'];
    if (ciphertext == null) {
      debugPrint('GHOST_LOG: ChatScreen Error: Received message with no ciphertext');
      return;
    }
    
    try {
      final decrypted = ref.read(spaceServiceProvider).decryptMessage(
        base64Decode(ciphertext),
        widget.config.roomKey,
      );
      debugPrint('GHOST_LOG: ChatScreen message decrypted successfully');

      setState(() {
        _messages.insert(0, Message(
          id: DateTime.now().toString() + (isMe ? '_me' : '_other'),
          text: decrypted,
          isMe: isMe,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      debugPrint('GHOST_LOG: ChatScreen Decryption Error: $e');
      debugPrint('GHOST_LOG: Ciphertext was: $ciphertext');
    }
  }

  void _socketErrorListener() {
    // This is a bit simplified, but helps with debugging
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final plaintext = _controller.text;
    final spaceService = ref.read(spaceServiceProvider);
    final cryptoService = ref.read(cryptoServiceProvider);
    final wsService = ref.read(webSocketServiceProvider);
    final roomKey = widget.config.roomKey;
    final roomId = widget.config.roomId;

    final encrypted = spaceService.encryptMessage(
      plaintext,
      roomKey,
    );

    final deviceId = await cryptoService.getDeviceId();

    wsService.sendMessage(roomId, {
      'ciphertext': base64Encode(encrypted),
      'expiry': 300, // 5 minutes message TTL
      'senderId': deviceId,
    });

    _processMessage({
      'ciphertext': base64Encode(encrypted),
    }, isMe: true);
    
    _controller.clear();
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Space Expired'),
        content: const Text('This space has reached its end of life and has been destroyed.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Return Home'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('ENCRYPTED SPACE'),
            Text(
              widget.config.roomId.substring(0, 8),
              style: const TextStyle(fontSize: 10, color: Colors.white30),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InviteScreen(config: widget.config),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMe ? Colors.white : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isMe ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Type an encrypted message...'),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
