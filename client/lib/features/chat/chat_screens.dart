import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../core/providers.dart';
import 'conversation_service.dart';
import 'message.dart';
import '../media/attachment_envelope.dart';

final conversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationServiceProvider).getConversations();
});

final requestsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationServiceProvider).getRequests();
});

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final requests = ref.watch(requestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHATS'),
      ),
      body: Column(
        children: [
          if (requests.isNotEmpty)
            ListTile(
              tileColor: Colors.redAccent.withAlpha(25),
              leading: const Icon(Icons.mail_lock, color: Colors.redAccent),
              title: const Text('Message Requests'),
              trailing: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.redAccent,
                child: Text(
                  requests.length.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestsScreen()),
                );
              },
            ),
          Expanded(
            child: conversations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Text(conv.alias.isNotEmpty ? conv.alias[0].toUpperCase() : '?'),
                        ),
                        title: Text(conv.alias),
                        subtitle: Text(
                          conv.lastMessage?.plaintext ?? 'No messages',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conv.unreadCount > 0 ? Colors.white70 : Colors.white24,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (conv.lastMessage != null)
                              Text(
                                DateFormat.Hm().format(conv.lastMessage!.timestamp),
                                style: const TextStyle(fontSize: 10, color: Colors.white24),
                              ),
                            if (conv.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  conv.unreadCount.toString(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(conversation: conv),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No active conversations', style: TextStyle(color: Colors.white24)),
    );
  }
}

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('REQUESTS'),
      ),
      body: requests.isEmpty
          ? const Center(child: Text('No message requests', style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.person_outline, color: Colors.white54),
                  ),
                  title: const Text('Unknown Sender'),
                  subtitle: Text(
                    req.lastMessage?.plaintext ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConversationScreen(conversation: req, isRequestMode: true),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  final bool isRequestMode;
  const ConversationScreen({super.key, required this.conversation, this.isRequestMode = false});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(conversationServiceProvider).markAsRead(widget.conversation.contactId);
    });
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    
    await ref.read(conversationServiceProvider).sendMessage(widget.conversation.contactId, text);
  }

  void _pickAndSendImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    messenger.showSnackBar(const SnackBar(content: Text('Uploading encrypted image...')));
    
    try {
      await ref.read(conversationServiceProvider).sendImage(widget.conversation.contactId, File(image.path));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatRepositoryProvider).getMessagesForContact(widget.conversation.contactId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.alias),
            Text(
              widget.conversation.contactId,
              style: const TextStyle(fontSize: 10, color: Colors.white24),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.senderId == ref.read(chatRepositoryProvider).myPublicId;
                return _buildMessageBubble(msg, isMe);
              },
            ),
          ),
          widget.isRequestMode ? _buildRequestActions() : _buildInput(),
        ],
      ),
    );
  }

  Widget _buildRequestActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withAlpha(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await ref.read(conversationServiceProvider).blockRequest(widget.conversation.contactId);
              navigator.pop();
              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Sender Blocked')));
            },
            child: const Text('BLOCK', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await ref.read(conversationServiceProvider).rejectRequest(widget.conversation.contactId);
              navigator.pop();
              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Request Deleted')));
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await ref.read(conversationServiceProvider).acceptRequest(widget.conversation.contactId);
              navigator.pop();
              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Request Accepted')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('ACCEPT'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white10 : Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.type == MessageType.image)
              AttachmentWidget(message: msg)
            else
              Text(msg.plaintext),
            const SizedBox(height: 4),
            Text(
              DateFormat.Hm().format(msg.timestamp),
              style: const TextStyle(fontSize: 8, color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white54),
            onPressed: _pickAndSendImage,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class AttachmentWidget extends ConsumerStatefulWidget {
  final Message message;
  const AttachmentWidget({super.key, required this.message});

  @override
  ConsumerState<AttachmentWidget> createState() => _AttachmentWidgetState();
}

class _AttachmentWidgetState extends ConsumerState<AttachmentWidget> {
  Uint8List? _decryptedData;
  bool _isDownloading = false;

  void _download() async {
    if (widget.message.metadata == null) return;
    setState(() => _isDownloading = true);
    
    try {
      final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
      final relay = await ref.read(activeRelayProvider.future);
      final idService = ref.read(identityServiceProvider);
      
      if (relay == null) throw Exception('No active relay');
      
      final data = await ref.read(mediaServiceProvider).downloadMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: idService.currentIdentity!.x25519KeyPair,
      );
      
      if (mounted) {
        setState(() {
          _decryptedData = data;
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_decryptedData != null) {
      return GestureDetector(
        onTap: () => _showFullScreen(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(_decryptedData!, fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: _isDownloading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : TextButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white24),
                label: const Text('DOWNLOAD IMAGE', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ),
      ),
    );
  }

  void _showFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.black),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(_decryptedData!),
            ),
          ),
        ),
      ),
    );
  }
}
