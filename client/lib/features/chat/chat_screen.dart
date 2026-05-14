import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../spaces/space_service.dart';
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
    print('GHOST_LOG: ChatScreen initState starting');
    _setupListeners();
    print('GHOST_LOG: ChatScreen initState completed');
  }

  void _setupListeners() {
    print('GHOST_LOG: ChatScreen _setupListeners starting');
    final ws = ref.read(webSocketServiceProvider);
    print('GHOST_LOG: ChatScreen ws provider ready');
    ws.joinSpace(widget.config.roomId);
    print('GHOST_LOG: ChatScreen joinSpace called');
    
    ws.onMessage((data) {
      print('GHOST_LOG: ChatScreen onMessage received: $data');
      if (!mounted) return;
      final ciphertext = data['ciphertext'];
      try {
        final decrypted = ref.read(spaceServiceProvider).decryptMessage(
          base64Decode(ciphertext),
          widget.config.roomKey,
        );
        print('GHOST_LOG: ChatScreen message decrypted');

        setState(() {
          _messages.insert(0, Message(
            id: DateTime.now().toString(),
            text: decrypted,
            isMe: false,
            timestamp: DateTime.now(),
          ));
        });
      } catch (e) {
        print('GHOST_LOG: ChatScreen decryption error: $e');
      }
    });

    _socketErrorListener();

    ws.onSpaceExpired((_) {
      print('GHOST_LOG: ChatScreen space expired');
      if (mounted) _showExpiredDialog();
    });
  }

  void _socketErrorListener() {
    // This is a bit simplified, but helps with debugging
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    final plaintext = _controller.text;
    final encrypted = ref.read(spaceServiceProvider).encryptMessage(
      plaintext,
      widget.config.roomKey,
    );

    ref.read(webSocketServiceProvider).sendMessage(widget.config.roomId, {
      'ciphertext': base64Encode(encrypted),
      'expiry': 300, // 5 minutes message TTL
    });

    setState(() {
      _messages.insert(0, Message(
        id: DateTime.now().toString(),
        text: plaintext,
        isMe: true,
        timestamp: DateTime.now(),
      ));
    });
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
