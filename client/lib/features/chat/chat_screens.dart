import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers.dart';
import 'conversation_service.dart';
import 'conversation_state.dart';
import 'message.dart';
import '../media/attachment_envelope.dart';
import '../contacts/contact_actions.dart';

final conversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationServiceProvider).getConversations();
});

final requestsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationServiceProvider).getRequests();
});

Widget _buildSubtitle(Conversation conv) {
  String text = conv.lastMessage?.plaintext ?? 'No messages';
  bool isSystem = conv.lastMessage?.type == MessageType.system;
  
  if (conv.lastMessage?.type == MessageType.image) {
    text = '[Image]';
  } else if (conv.lastMessage?.type == MessageType.video) {
    text = '[Video]';
  }

  return Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: conv.unreadCount > 0 ? Colors.white.withAlpha(200) : Colors.white24,
      fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
      fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
    ),
  );
}

Widget _buildDismissBackground(Color color, IconData icon, Alignment alignment) {
  return Container(
    color: color,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Icon(icon, color: Colors.white),
  );
}

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> with ContactActions {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Message>('messages').listenable(),
      builder: (context, _, _) {
        final conversations = ref.watch(conversationsProvider);
        final requests = ref.watch(requestsProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('MESSAGES'),
            actions: [
              if (requests.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mail_lock_outlined, color: Colors.orangeAccent),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RequestsScreen()),
                        );
                      },
                      tooltip: 'Message Requests',
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text(
                          requests.length.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                onPressed: () => showAddOptions(context),
              ),
            ],
          ),
          body: conversations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: conv.unreadCount > 0 ? Colors.blueAccent.withAlpha(40) : Colors.white10,
                        child: Text(
                          conv.alias.isNotEmpty ? conv.alias[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: conv.unreadCount > 0 ? Colors.blueAccent : Colors.white54,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      title: Text(
                        conv.alias,
                        style: TextStyle(
                          fontWeight: conv.unreadCount > 0 ? FontWeight.w900 : FontWeight.normal,
                          color: conv.unreadCount > 0 ? Colors.white : Colors.white70,
                        ),
                      ),
                      subtitle: _buildSubtitle(conv),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (conv.lastMessage != null)
                            Text(
                              DateFormat.Hm().format(conv.lastMessage!.timestamp),
                              style: TextStyle(
                                fontSize: 10, 
                                color: conv.unreadCount > 0 ? Colors.blueAccent : Colors.white24,
                                fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          if (conv.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withAlpha(100),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Text(
                                conv.unreadCount > 9 ? '9+' : conv.unreadCount.toString(),
                                style: const TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
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
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white10),
          SizedBox(height: 16),
          Text('Secure channel established.', style: TextStyle(color: Colors.white24)),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Messages in GhostRoom are end-to-end encrypted before they leave your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white10, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Message>('messages').listenable(),
      builder: (context, _, _) {
        final requests = ref.watch(requestsProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('REQUESTS'),
          ),
          body: requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_lock_outlined, size: 64, color: Colors.white10),
                      SizedBox(height: 16),
                      Text('No pending requests.', style: TextStyle(color: Colors.white24)),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'Unknown senders appear here before entering your inbox.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white10, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return Dismissible(
                      key: Key(req.contactId),
                      background: _buildDismissBackground(Colors.green, Icons.check, Alignment.centerLeft),
                      secondaryBackground: _buildDismissBackground(Colors.red, Icons.block, Alignment.centerRight),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await ref.read(conversationServiceProvider).acceptRequest(req.contactId);
                          return true;
                        } else {
                          await ref.read(conversationServiceProvider).blockRequest(req.contactId);
                          return true;
                        }
                      },
                      child: ListTile(
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
                      ),
                    );
                  },
                ),
        );
      },
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
  
  // Visual state for highlight
  DateTime? _lastRemoteChange;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(conversationServiceProvider).markAsRead(widget.conversation.contactId);
    });
  }

  @override
  void dispose() {
    final contactId = widget.conversation.contactId;
    Future.microtask(() async {
      final messages = ref.read(chatRepositoryProvider).getMessagesForContact(contactId);
      bool didDeleteGhost = false;
      for (final msg in messages) {
        if (msg.metadata?['is_ghost'] == true) {
          await msg.delete();
          didDeleteGhost = true;
        }
      }
      if (didDeleteGhost) {
        await ref.read(chatRepositoryProvider).sendGhostFlush(contactId);
      }
    });
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    
    await ref.read(conversationServiceProvider).sendMessage(
      widget.conversation.contactId, 
      text,
    );
  }

  void _pickMedia() async {
    final messenger = ScaffoldMessenger.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('PHOTO'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image == null || !mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('Encrypting & Uploading...')));
              try {
                await ref.read(conversationServiceProvider).sendImage(
                  widget.conversation.contactId, 
                  File(image.path),
                );
              } catch (e) {
                if (mounted) messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('VIDEO'),
            onTap: () async {
              Navigator.pop(context);
              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
              if (video == null || !mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('Compressing & Uploading...')));
              try {
                await ref.read(conversationServiceProvider).sendVideo(
                  widget.conversation.contactId, 
                  File(video.path),
                );
              } catch (e) {
                if (mounted) messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ConversationState>('conversation_states').listenable(keys: [widget.conversation.contactId]),
      builder: (context, Box<ConversationState> stateBox, _) {
        final state = stateBox.get(widget.conversation.contactId);
        final currentMode = state?.mode ?? ConversationMode.normal;
        
        // Detect remote change for highlight
        if (state != null && state.lastChangedBy != ref.read(chatRepositoryProvider).myPublicId) {
          if (_lastRemoteChange == null || state.lastChangedAt.isAfter(_lastRemoteChange!)) {
            _lastRemoteChange = state.lastChangedAt;
          }
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<Message>('messages').listenable(),
          builder: (context, _, _) {
            final messages = ref.watch(chatRepositoryProvider).getMessagesForContact(widget.conversation.contactId);

            // Auto-scroll logic
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final pos = _scrollController.position;
                final atBottom = pos.pixels >= pos.maxScrollExtent - 100;
                
                if (atBottom) {
                  _scrollController.animateTo(
                    pos.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              }
            });

            return Scaffold(
              appBar: AppBar(
                title: GestureDetector(
                  onTap: () => _showSafetyNumbers(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.conversation.alias),
                      const Text(
                        'TAP TO VERIFY IDENTITY',
                        style: TextStyle(fontSize: 8, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
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
                  widget.isRequestMode ? _buildRequestActions() : _buildInput(currentMode, state),
                ],
              ),
            );
          },
        );
      }
    );
  }

  void _showSafetyNumbers(BuildContext context) {
    final contact = widget.conversation.contact;
    if (contact == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SAFETY NUMBERS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Verify these numbers with your contact to ensure no one is intercepting your messages.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white10,
              child: Text(
                contact.fingerprint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
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
            if (msg.type == MessageType.image || msg.type == MessageType.video)
              AttachmentWidget(message: msg)
            else
              Text(msg.plaintext),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.Hm().format(msg.timestamp),
                  style: const TextStyle(fontSize: 8, color: Colors.white24),
                ),
                if (msg.metadata?['is_ghost'] == true) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.visibility_off_outlined,
                    size: 8,
                    color: Colors.white24,
                  ),
                ],
                if (msg.metadata?['consumed'] == true) ...[
                  const SizedBox(width: 4),
                  const Text(
                    'CONSUMED',
                    style: TextStyle(
                      fontSize: 8, 
                      color: Colors.blueAccent, 
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(ConversationMode currentMode, ConversationState? state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeSelector(currentMode, state),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                  onPressed: () => _showMediaOptions(context),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(ConversationMode currentMode, ConversationState? state) {
    IconData icon = Icons.chat_bubble_outline;
    String label = 'NORMAL';
    if (currentMode == ConversationMode.ghost) {
      icon = Icons.visibility_off_outlined;
      label = 'GHOST';
    }

    final isRemoteChange = state != null && 
                           state.lastChangedBy != ref.read(chatRepositoryProvider).myPublicId &&
                           DateTime.now().difference(state.lastChangedAt).inSeconds < 10;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: _showModeOptions,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isRemoteChange ? Colors.blueAccent.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isRemoteChange ? Border.all(color: Colors.blueAccent.withAlpha(100)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isRemoteChange ? Colors.blueAccent : Colors.white24),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10, 
                  color: isRemoteChange ? Colors.white : Colors.white24, 
                  fontWeight: FontWeight.bold
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 12, color: isRemoteChange ? Colors.blueAccent : Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('NORMAL'),
            subtitle: const Text('Standard encrypted chat'),
            onTap: () async {
              await ref.read(conversationServiceProvider).setConversationMode(widget.conversation.contactId, ConversationMode.normal);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('GHOST'),
            subtitle: const Text('Messages vanish when chat is closed'),
            onTap: () async {
              await ref.read(conversationServiceProvider).setConversationMode(widget.conversation.contactId, ConversationMode.ghost);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('SEND PHOTO'),
            onTap: () {
              Navigator.pop(context);
              _pickMedia();
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('SEND VIDEO'),
            onTap: () {
              Navigator.pop(context);
              _pickMedia();
            },
          ),
          const SizedBox(height: 16),
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
  Uint8List? _thumbData;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  void _loadThumb() async {
    if (widget.message.metadata == null) return;
    try {
      final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
      final relay = await ref.read(activeRelayProvider.future);
      final idService = ref.read(identityServiceProvider);
      if (relay == null) return;

      final data = await ref.read(mediaServiceProvider).downloadMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: idService.currentIdentity!.x25519KeyPair,
        isThumbnail: true,
      );
      if (mounted) setState(() => _thumbData = data);
    } catch (_) {}
  }

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
      if (widget.message.type == MessageType.video) {
        return _VideoPreview(data: _decryptedData!);
      }
      return GestureDetector(
        onTap: () => _showFullScreen(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(_decryptedData!, fit: BoxFit.cover),
        ),
      );
    }

    final meta = widget.message.metadata;
    final sizeStr = meta?['size'] != null ? '${((meta!['size'] as int) / 1024 / 1024).toStringAsFixed(1)} MB' : '';
    final isGhost = meta?['is_ghost'] == true;

    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        image: _thumbData != null ? DecorationImage(
          image: MemoryImage(_thumbData!),
          fit: BoxFit.cover,
          opacity: isGhost ? 0.1 : 0.3,
        ) : null,
      ),
      child: Stack(
        children: [
          Center(
            child: _isDownloading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isGhost)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Icon(Icons.visibility_off_outlined, color: Colors.amber, size: 24),
                        ),
                      IconButton(
                        icon: Icon(
                          widget.message.type == MessageType.video 
                            ? Icons.play_circle_outline 
                            : Icons.download_for_offline_outlined, 
                          color: isGhost ? Colors.amber : Colors.white70,
                          size: 32,
                        ),
                        onPressed: _download,
                      ),
                      Text(
                        '${isGhost ? 'GHOST ' : ''}${widget.message.type.name.toUpperCase()} $sizeStr',
                        style: TextStyle(
                          color: isGhost ? Colors.amber.withAlpha(100) : Colors.white30, 
                          fontSize: 9, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
          ),
          if (widget.message.type == MessageType.video)
            Positioned(
              bottom: 8,
              right: 8,
              child: Icon(Icons.videocam_outlined, size: 16, color: isGhost ? Colors.amber.withAlpha(100) : Colors.white24),
            ),
        ],
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

class _VideoPreview extends StatefulWidget {
  final Uint8List data;
  const _VideoPreview({required this.data});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;

      final tempFile = File('${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.mp4');
      _tempFile = tempFile;
      await tempFile.writeAsBytes(widget.data);
      if (!mounted) {
        _tempFile?.delete().catchError((_) => File(''));
        return;
      }

      final controller = VideoPlayerController.file(tempFile);
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        _tempFile?.delete().catchError((_) => File(''));
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('GHOST_ERROR: _VideoPreview _initPlayer failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _chewieController?.dispose();
    _tempFile?.delete().catchError((_) => File(''));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Chewie(controller: _chewieController!),
    );
  }
}
