import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers.dart';
import 'conversation_service.dart';
import 'conversation_state.dart';
import 'message.dart';
import '../contacts/contact.dart';
import '../media/attachment_envelope.dart';
import '../contacts/contact_actions.dart';

final conversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(conversationServiceProvider).getConversations();
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        Hive.box<Message>('messages').listenable(),
        Hive.box<Contact>('contacts').listenable(),
        Hive.box<ConversationState>('conversation_states').listenable(),
      ]),
      builder: (context, _) {
        final conversations = ref.read(conversationServiceProvider).getConversations();
        final requests = ref.read(conversationServiceProvider).getRequests();

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
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
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
          body: Column(
            children: [
              if (requests.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    child: Icon(Icons.mail_lock, color: Colors.black, size: 18),
                  ),
                  title: const Text('MESSAGE REQUESTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      requests.length.toString(),
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
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
                          final hasUnread = conv.unreadCount > 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hasUnread ? Colors.blueAccent.withAlpha(40) : Colors.white10,
                              child: Text(
                                conv.alias.isNotEmpty ? conv.alias[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: hasUnread ? Colors.blueAccent : Colors.white54,
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            title: Text(
                              conv.alias,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.normal,
                                color: hasUnread ? Colors.white : Colors.white70,
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
                                      color: hasUnread ? Colors.blueAccent : Colors.white24,
                                    ),
                                  ),
                                if (hasUnread)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(10)),
                                    child: Text(
                                      conv.unreadCount > 9 ? '9+' : conv.unreadCount.toString(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
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
          Text(
            'Messages are end-to-end encrypted.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white10, fontSize: 12),
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        Hive.box<Message>('messages').listenable(),
        Hive.box<ConversationState>('conversation_states').listenable(),
      ]),
      builder: (context, _) {
        final requests = ref.read(conversationServiceProvider).getRequests();

        return Scaffold(
          appBar: AppBar(title: const Text('MESSAGE REQUESTS')),
          body: requests.isEmpty
              ? const Center(child: Text('No pending requests.', style: TextStyle(color: Colors.white24)))
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
                        subtitle: _buildSubtitle(req),
                        trailing: req.unreadCount > 0 ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            req.unreadCount > 9 ? '9+' : req.unreadCount.toString(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ) : null,
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
  static final List<String> _sessionPickedPaths = [];
  
  DateTime? _lastRemoteChange;
  bool _showScrollButton = false;
  bool _isInitialScroll = true;

  @override
  void initState() {
    super.initState();
    ref.read(chatRepositoryProvider).setActiveConversation(widget.conversation.contactId);
    // Safety sync: ensure count is cleared even if setActiveConversation timing is tight
    ref.read(chatRepositoryProvider).markConversationAsRead(widget.conversation.contactId);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200;
    if (atBottom && _showScrollButton) {
      setState(() => _showScrollButton = false);
    }
  }

  @override
  void dispose() {
    ref.read(chatRepositoryProvider).setActiveConversation(null);
    _scrollController.removeListener(_onScroll);
    final contactId = widget.conversation.contactId;
    Future.microtask(() => ref.read(chatRepositoryProvider).flushGhostMessages(contactId));
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    await ref.read(conversationServiceProvider).sendMessage(widget.conversation.contactId, text);
  }

  Future<List<File>> _scanRecentMedia() async {
    final List<File> files = [];
    final List<String> pathsToScan = [];
    
    try {
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          pathsToScan.add('$home/Pictures');
          pathsToScan.add('$home/Downloads');
        }
        pathsToScan.add('/tmp');
      } else if (Platform.isAndroid) {
        pathsToScan.add('/storage/emulated/0/DCIM/Camera');
        pathsToScan.add('/storage/emulated/0/Pictures');
        pathsToScan.add('/storage/emulated/0/Download');
      }
      
      for (final path in pathsToScan) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final List<FileSystemEntity> entities = await dir.list(recursive: false, followLinks: false).toList();
          for (final entity in entities) {
            if (entity is File) {
              final pLower = entity.path.toLowerCase();
              if (pLower.endsWith('.jpg') || pLower.endsWith('.jpeg') || pLower.endsWith('.png') || pLower.endsWith('.webp') || pLower.endsWith('.mp4') || pLower.endsWith('.mov')) {
                files.add(entity);
              }
            }
          }
        }
      }
      
      files.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });
    } catch (e) {
      debugPrint('GHOST_LOG: Error scanning recent media: $e');
    }
    
    return files;
  }

  Future<List<File>> _getRecentMedia() async {
    final List<File> result = [];
    
    // Add session picked paths first
    for (final path in _sessionPickedPaths) {
      final file = File(path);
      if (file.existsSync()) {
        result.add(file);
      }
    }
    
    // Add scanned files
    final scanned = await _scanRecentMedia();
    for (final file in scanned) {
      if (!result.any((f) => f.path == file.path)) {
        result.add(file);
      }
    }
    
    return result.take(18).toList();
  }

  void _confirmAndSendRecentMedia(File file) {
    final path = file.path.toLowerCase();
    final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi') || path.endsWith('.mkv');
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(isVideo ? 'Send Video?' : 'Send Image?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 180,
                width: 240,
                child: isVideo
                  ? const Center(child: Icon(Icons.play_circle_outline, color: Colors.blueAccent, size: 48))
                  : Image.file(file, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 48)),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.basename(file.path), style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white30)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              debugPrint('GHOST_LOG: MEDIA_PICKED filepath: ${file.path}');
              if (isVideo) {
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Compressing & Uploading Video...')));
                await convService.sendVideo(contactId, file);
              } else {
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Encrypting & Uploading Image...')));
                await convService.sendImage(contactId, file);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _pickMedia() async {
    final messenger = ScaffoldMessenger.of(context);
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;
    
    try {
      File? pickedFile;
      
      if (Platform.isAndroid || Platform.isIOS) {
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        if (ps != PermissionState.authorized && ps != PermissionState.limited) {
          messenger.showSnackBar(const SnackBar(
            content: Text('GhostRoom needs gallery permissions to select photos and videos. Please enable it in Settings.'),
          ));
          await PhotoManager.openSetting();
          return;
        }

        if (!mounted) return;

        final List<AssetEntity>? result = await AssetPicker.pickAssets(
          context,
          pickerConfig: const AssetPickerConfig(
            maxAssets: 1,
            requestType: RequestType.common,
          ),
        );
        if (result == null || result.isEmpty) return;
        final file = await result.first.file;
        if (file == null) return;
        pickedFile = file;
      } else {
        final XFile? media = await _picker.pickMedia();
        if (media == null) return;
        pickedFile = File(media.path);
      }

      debugPrint('GHOST_LOG: MEDIA_PICKED filepath: ${pickedFile.path}');
      _sessionPickedPaths.insert(0, pickedFile.path);

      final path = pickedFile.path.toLowerCase();
      final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') || path.endsWith('.avi') || path.endsWith('.mkv');
      
      if (isVideo) {
        messenger.showSnackBar(const SnackBar(content: Text('Compressing & Uploading Video...')));
        await convService.sendVideo(contactId, pickedFile);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Encrypting & Uploading Image...')));
        await convService.sendImage(contactId, pickedFile);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Media selection/upload failed: $e')));
      }
    }
  }

  void _pickCamera() async {
    final messenger = ScaffoldMessenger.of(context);
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;
    
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      
      debugPrint('GHOST_LOG: MEDIA_PICKED filepath: ${photo.path}');
      _sessionPickedPaths.insert(0, photo.path);
      
      messenger.showSnackBar(const SnackBar(content: Text('Encrypting & Uploading Image...')));
      await convService.sendImage(contactId, File(photo.path));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Camera capture failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ConversationState>('conversation_states').listenable(keys: [widget.conversation.contactId]),
      builder: (context, Box<ConversationState> stateBox, _) {
        final state = stateBox.get(widget.conversation.contactId);
        final currentMode = state?.mode ?? ConversationMode.normal;

        if (state != null && state.lastChangedBy != ref.read(chatRepositoryProvider).myPublicId) {
          if (_lastRemoteChange == null || state.lastChangedAt.isAfter(_lastRemoteChange!)) {
            _lastRemoteChange = state.lastChangedAt;
          }
        }

        return ValueListenableBuilder(
          valueListenable: Hive.box<Message>('messages').listenable(),
          builder: (context, box, child) {
            final messages = ref.read(chatRepositoryProvider).getMessagesForContact(widget.conversation.contactId, limit: 200);
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients && messages.isNotEmpty) {
                final pos = _scrollController.position;
                final lastMsg = messages.last;
                final isMe = lastMsg.senderId == ref.read(chatRepositoryProvider).myPublicId;
                final atBottom = pos.pixels >= pos.maxScrollExtent - 200;

                if (_isInitialScroll) {
                  _isInitialScroll = false;
                  _scrollController.jumpTo(pos.maxScrollExtent);
                } else if (isMe || atBottom) {
                  _scrollController.animateTo(pos.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  if (_showScrollButton) setState(() => _showScrollButton = false);
                } else if (!isMe && !atBottom && !_showScrollButton) {
                  setState(() => _showScrollButton = true);
                }
              }
            });

            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  ref.read(chatRepositoryProvider).flushGhostMessages(widget.conversation.contactId);
                }
              },
              child: Scaffold(
                appBar: AppBar(
                  title: GestureDetector(
                    onTap: () => _showSafetyNumbers(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.conversation.alias),
                        const Text('TAP TO VERIFY IDENTITY', style: TextStyle(fontSize: 8, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                floatingActionButton: _showScrollButton ? FloatingActionButton.extended(
                  backgroundColor: Colors.blueAccent,
                  label: const Text('NEW MESSAGES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  onPressed: () {
                    _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    setState(() => _showScrollButton = false);
                  },
                ) : null,
                floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
                body: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) => _buildMessageBubble(messages[index], messages[index].senderId == ref.read(chatRepositoryProvider).myPublicId),
                      ),
                    ),
                    widget.isRequestMode ? _buildRequestActions() : _buildInput(currentMode, state),
                  ],
                ),
              ),
            );
          },
        );
      },
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
            const Text('Verify these numbers with your contact to ensure no interception.', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(16), color: Colors.white10, child: Text(contact.fingerprint, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1, fontSize: 13))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }

  Widget _buildRequestActions() {
    final navigator = Navigator.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withAlpha(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(onPressed: () async {
            await ref.read(conversationServiceProvider).blockRequest(widget.conversation.contactId);
            navigator.pop();
          }, child: const Text('BLOCK', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () async {
            await ref.read(conversationServiceProvider).rejectRequest(widget.conversation.contactId);
            navigator.pop();
          }, child: const Text('DELETE', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () async {
            await ref.read(conversationServiceProvider).acceptRequest(widget.conversation.contactId);
            navigator.pop();
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('ACCEPT')),
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
        decoration: BoxDecoration(color: isMe ? Colors.white10 : Colors.white.withAlpha(13), borderRadius: BorderRadius.circular(12)),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.type == MessageType.image || msg.type == MessageType.video) AttachmentWidget(message: msg) else Text(msg.plaintext),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat.Hm().format(msg.timestamp), style: const TextStyle(fontSize: 8, color: Colors.white24)),
                if (msg.metadata?['is_ghost'] == true) ...[const SizedBox(width: 4), const Icon(Icons.visibility_off_outlined, size: 8, color: Colors.white24)],
                if (msg.metadata?['consumed'] == true) ...[const SizedBox(width: 4), const Text('CONSUMED', style: TextStyle(fontSize: 8, color: Colors.blueAccent, fontWeight: FontWeight.w900))],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'zip', 'doc', 'docx', 'txt'],
      );
      if (result == null || result.files.single.path == null) return;
      
      messenger.showSnackBar(const SnackBar(
        content: Text('Document attachments (.pdf, .zip, .doc, .txt) will be supported in a future update.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('File selection failed: $e')));
    }
  }

  void _showGalleryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<File>>(
              future: _getRecentMedia(),
              builder: (context, snapshot) {
                final files = snapshot.data ?? [];
                
                return Column(
                  children: [
                    // Handlebar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'RECENT MEDIA',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    
                    // Recent Media Grid
                    Expanded(
                      child: files.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.photo_library_outlined, color: Colors.white24, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'No recent media found',
                                    style: TextStyle(color: Colors.white30, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: files.length,
                              itemBuilder: (context, index) {
                                final file = files[index];
                                final isVideo = file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov');
                                
                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _confirmAndSendRecentMedia(file);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          file,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.white10,
                                              child: const Icon(Icons.image, color: Colors.white24),
                                            );
                                          },
                                        ),
                                        if (isVideo)
                                          Container(
                                            color: Colors.black38,
                                            child: const Center(
                                              child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 28),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Action Buttons (Gallery, Files)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _pickMedia();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.photo_library_outlined, color: Colors.blueAccent),
                                    SizedBox(height: 8),
                                    Text(
                                      'Gallery',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _pickFile();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.insert_drive_file_outlined, color: Colors.amber),
                                    SizedBox(height: 8),
                                    Text(
                                      'Files',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInput(ConversationMode currentMode, ConversationState? state) {
    final isGhost = currentMode == ConversationMode.ghost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const BoxDecoration(color: Color(0xFF080808), border: Border(top: BorderSide(color: Colors.white10))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeSelector(currentMode, state),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.add, color: Colors.white54, size: 22), onPressed: _showGalleryBottomSheet),
                IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 22), onPressed: _pickCamera),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      decoration: InputDecoration(hintText: isGhost ? 'Ghost Message' : 'Secure Message', hintStyle: const TextStyle(color: Colors.white24, fontSize: 13), border: InputBorder.none),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: _sendMessage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(ConversationMode currentMode, ConversationState? state) {
    IconData icon = currentMode == ConversationMode.ghost ? Icons.visibility_off_outlined : Icons.chat_bubble_outline;
    String label = currentMode == ConversationMode.ghost ? 'GHOST' : 'NORMAL';
    final isRemoteChange = state != null && state.lastChangedBy != ref.read(chatRepositoryProvider).myPublicId && DateTime.now().difference(state.lastChangedAt).inSeconds < 10;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: _showModeOptions,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: isRemoteChange ? Colors.blueAccent.withAlpha(40) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: isRemoteChange ? Border.all(color: Colors.blueAccent.withAlpha(100)) : null),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isRemoteChange ? Colors.blueAccent : Colors.white24),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: isRemoteChange ? Colors.white : Colors.white24, fontWeight: FontWeight.bold)),
              const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeOptions() {
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('NORMAL'), subtitle: const Text('Standard encrypted chat'), onTap: () async {
            await ref.read(conversationServiceProvider).setConversationMode(widget.conversation.contactId, ConversationMode.normal);
            navigator.pop();
          }),
          ListTile(leading: const Icon(Icons.visibility_off_outlined), title: const Text('GHOST'), subtitle: const Text('Messages vanish when chat is closed'), onTap: () async {
            await ref.read(conversationServiceProvider).setConversationMode(widget.conversation.contactId, ConversationMode.ghost);
            navigator.pop();
          }),
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
  bool _hasLoggedRender = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  void _loadThumb() async {
    if (widget.message.metadata == null) return;
    final repo = ref.read(chatRepositoryProvider);
    final mediaService = ref.read(mediaServiceProvider);
    final identityService = ref.read(identityServiceProvider);
    
    try {
      final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
      
      // Check Cache First
      final cached = repo.getCachedThumbnail(envelope.mediaId);
      if (cached != null) {
        if (mounted) setState(() => _thumbData = cached);
        return;
      }

      final relay = await ref.read(activeRelayProvider.future);
      if (relay == null) return;
      
      final identity = identityService.currentIdentity;
      if (identity == null) return;
      
      final data = await mediaService.downloadMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: identity.x25519KeyPair,
        isThumbnail: true,
      );
      
      // Save to Cache
      await repo.cacheThumbnail(envelope.mediaId, data);
      
      if (mounted) setState(() => _thumbData = data);
    } catch (_) {}
  }

  void _download() async {
    if (widget.message.metadata == null) return;
    setState(() => _isDownloading = true);
    final messenger = ScaffoldMessenger.of(context);
    final mediaService = ref.read(mediaServiceProvider);
    final identityService = ref.read(identityServiceProvider);
    
    try {
      final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
      final relay = await ref.read(activeRelayProvider.future);
      if (relay == null) throw Exception('No active relay');
      
      final identity = identityService.currentIdentity;
      if (identity == null) throw Exception('No current identity');
      
      final data = await mediaService.downloadMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: identity.x25519KeyPair,
      );
      if (mounted) {
        setState(() { _decryptedData = data; _isDownloading = false; });
        _showFullScreen();
      }
    } catch (e) {
      if (mounted) { setState(() => _isDownloading = false); messenger.showSnackBar(SnackBar(content: Text('Download failed: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.message.metadata;
    final sizeStr = meta?['size'] != null ? '${((meta!['size'] as int) / 1024 / 1024).toStringAsFixed(1)} MB' : '';
    final isGhost = meta?['is_ghost'] == true;
    final status = meta?['status'] as String?;
    final isPending = status != null && status != 'SENT';
    final isFailed = status == 'FAILED';

    if (!_hasLoggedRender && (_thumbData != null || _decryptedData != null)) {
      _hasLoggedRender = true;
      debugPrint('GHOST_LOG: MEDIA_RENDERED type: ${widget.message.type.name} id: ${widget.message.id}');
    }

    return GestureDetector(
      onTap: (!isPending && _decryptedData != null) ? _showFullScreen : (!isPending ? _download : null),
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), image: _thumbData != null ? DecorationImage(image: MemoryImage(_thumbData!), fit: BoxFit.cover, opacity: isGhost ? 0.2 : 0.5) : null),
        child: Stack(
          children: [
            Center(
              child: (_isDownloading || (isPending && !isFailed)) ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 12),
                  Text(status ?? 'DOWNLOADING', style: const TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ) : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isGhost) const Padding(padding: EdgeInsets.only(bottom: 8.0), child: Icon(Icons.visibility_off_outlined, color: Colors.amber, size: 24)),
                  Icon(
                    isFailed ? Icons.error_outline : (widget.message.type == MessageType.video ? Icons.play_circle_outline : Icons.download_for_offline_outlined), 
                    color: isFailed ? Colors.redAccent : (isGhost ? Colors.amber : Colors.white70), 
                    size: 32
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFailed ? 'UPLOAD FAILED' : '${isGhost ? 'GHOST ' : ''}${widget.message.type.name.toUpperCase()} $sizeStr', 
                    style: TextStyle(color: isFailed ? Colors.redAccent : (isGhost ? Colors.amber.withAlpha(100) : Colors.white30), fontSize: 9, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
            if (widget.message.type == MessageType.video && !isPending) const Positioned(bottom: 8, right: 8, child: Icon(Icons.videocam_outlined, size: 16, color: Colors.white24)),
          ],
        ),
      ),
    );
  }

  void _showFullScreen() {
    if (_decryptedData == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenMediaViewer(data: _decryptedData!, type: widget.message.type)));
  }
}

class FullScreenMediaViewer extends StatelessWidget {
  final Uint8List data;
  final MessageType type;
  const FullScreenMediaViewer({super.key, required this.data, required this.type});

  @override
  Widget build(BuildContext context) {
    debugPrint('GHOST_LOG: MEDIA_RENDERED type: ${type.name} fullscreen: true');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: Center(
        child: type == MessageType.video ? _VideoPreview(data: data) : InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.memory(data, fit: BoxFit.contain)),
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
      if (!mounted) return;
      final controller = VideoPlayerController.file(tempFile);
      _controller = controller;
      await controller.initialize();
      if (!mounted) { controller.dispose(); return; }
      _chewieController = ChewieController(videoPlayerController: controller, autoPlay: true, looping: false, aspectRatio: controller.value.aspectRatio);
      if (mounted) setState(() {});
    } catch (e) { debugPrint('GHOST_ERROR: _VideoPreview failed: $e'); }
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
    return Container(constraints: const BoxConstraints(maxHeight: 400), child: Chewie(controller: _chewieController!));
  }
}
