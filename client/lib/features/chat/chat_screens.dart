import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import 'conversation_service.dart';
import 'message.dart';

final conversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationServiceProvider).getConversations();
});

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHATS'),
      ),
      body: conversations.isEmpty
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
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No active conversations', style: TextStyle(color: Colors.white24)),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  const ConversationScreen({super.key, required this.conversation});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
          _buildInput(),
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
