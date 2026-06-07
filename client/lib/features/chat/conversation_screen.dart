import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers.dart';
import '../media/attachment_envelope.dart';
import '../media/media_manager.dart';
import 'chat_repository.dart';
import 'conversation_service.dart';
import 'conversation_state.dart';
import 'message.dart';
import 'messages_provider.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/components/components.dart';
import '../../design_system/haptics.dart';
import 'widgets/voice_recorder.dart';
import 'widgets/voice_message_bubble.dart';
import 'package:logger/logger.dart';
import '../../core/stability_tracker.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  final bool isRequestMode;
  final VoidCallback? onBack;
  const ConversationScreen({
    super.key,
    required this.conversation,
    this.isRequestMode = false,
    this.onBack,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class RecentMediaItem {
  final AssetEntity? asset;
  final File? file;

  RecentMediaItem({this.asset, this.file});

  bool get isVideo {
    if (asset != null) {
      return asset!.type == AssetType.video;
    }
    if (file != null) {
      final pLower = file!.path.toLowerCase();
      return pLower.endsWith('.mp4') || pLower.endsWith('.mov') || pLower.endsWith('.avi') || pLower.endsWith('.mkv');
    }
    return false;
  }

  Future<File?> get filePromise async {
    if (asset != null) {
      return await asset!.file;
    }
    return file;
  }

  Widget buildThumbnail(BuildContext context) {
    if (asset != null) {
      return AssetEntityImage(
        asset!,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize(200, 200),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.white10,
            child: const Icon(Icons.image, color: Colors.white24),
          );
        },
      );
    } else if (file != null) {
      return Image.file(
        file!,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.white10,
            child: const Icon(Icons.image, color: Colors.white24),
          );
        },
      );
    }
    return Container(
      color: Colors.white10,
      child: const Icon(Icons.image, color: Colors.white24),
    );
  }
}

class FolderItem {
  final AssetPathEntity folder;
  final int count;
  FolderItem(this.folder, this.count);
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  static final List<String> _sessionPickedPaths = [];
  
  bool _showScrollButton = false;
  bool _isInitialScroll = true;
  bool _isRecording = false;
  late final ChatRepository _chatRepository;
  final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.info,
  );
  int _lastMessageCount = 0;
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    StabilityTracker.activeConversationScreens++;
    _chatRepository = ref.read(chatRepositoryProvider);
    _chatRepository.setActiveConversation(widget.conversation.contactId);
    _chatRepository.markConversationAsRead(widget.conversation.contactId);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    if (_scrollController.position.pixels <= 100) {
      ref.read(messagesProvider(widget.conversation.contactId).notifier).loadMore();
    }
    
    final atBottom = _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200;
    if (atBottom && _showScrollButton) {
      setState(() => _showScrollButton = false);
    }
  }

  @override
  void dispose() {
    StabilityTracker.activeConversationScreens--;
    _chatRepository.setActiveConversation(null);
    _scrollController.removeListener(_onScroll);
    final contactId = widget.conversation.contactId;
    Future.microtask(() => _chatRepository.flushGhostMessages(contactId));
    _controller.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;
    await convService.sendMessage(contactId, text);
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    if (_buildCount % 10 == 0) {
      _logger.w("GHOST_LOG: ConversationScreen build count: $_buildCount");
    }
    final colors = AppColors.of(context);
    
    return ValueListenableBuilder(
      valueListenable: Hive.box<ConversationState>('conversation_states').listenable(keys: [widget.conversation.contactId]),
      builder: (context, Box<ConversationState> stateBox, _) {
        final state = stateBox.get(widget.conversation.contactId);
        final currentMode = state?.mode ?? ConversationMode.normal;

        final messages = ref.watch(messagesProvider(widget.conversation.contactId));
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && messages.isNotEmpty) {
            final pos = _scrollController.position;
            final lastMsg = messages.last;
            final isMe = lastMsg.senderId == ref.read(chatRepositoryProvider).myPublicId;
            final atBottom = pos.pixels >= pos.maxScrollExtent - 200;

            final hasNewMessage = messages.length > _lastMessageCount;
            _lastMessageCount = messages.length;

            if (_isInitialScroll) {
              _isInitialScroll = false;
              _scrollController.jumpTo(pos.maxScrollExtent);
            } else if (hasNewMessage && (isMe || atBottom)) {
              _scrollController.animateTo(pos.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              if (_showScrollButton) setState(() => _showScrollButton = false);
            } else if (!isMe && !atBottom && !_showScrollButton) {
              setState(() => _showScrollButton = true);
            }
          }
        });

        return Scaffold(
          backgroundColor: colors.primaryBackground,
          appBar: AppBar(
                backgroundColor: colors.primaryBackground,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                ),
                title: GestureDetector(
                  onTap: () => _showSafetyNumbers(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.conversation.alias, style: AppTypography.section(context).copyWith(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, size: 10, color: colors.success),
                          const SizedBox(width: 4),
                          Text('SECURE CHANNEL', style: TextStyle(fontSize: 8, color: colors.secondaryText.withAlpha(100), fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GhostAvatar(alias: widget.conversation.alias, size: 36),
                  ),
                ],
              ),
              floatingActionButton: _showScrollButton ? FloatingActionButton.extended(
                backgroundColor: colors.ghostAccent,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == ref.read(chatRepositoryProvider).myPublicId;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
                  ),
                  widget.isRequestMode 
                      ? _buildRequestActions() 
                      : (_isRecording ? _buildVoiceRecorder() : _buildComposer(currentMode)),
                ],
              ),
            );
      },
    );
  }

  Widget _buildVoiceRecorder() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: VoiceRecorder(
        onRecordingComplete: (file, durationMs) async {
          setState(() => _isRecording = false);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(conversationServiceProvider).sendVoiceNote(
              widget.conversation.contactId, 
              file, 
              durationMs: durationMs
            );
          } catch (e) {
            _logger.e('GHOST_LOG: VOICE_SEND_ERROR voice_recorder: $e');
            messenger.showSnackBar(SnackBar(content: Text('Failed to send voice note: $e')));
          }
        },
        onCancel: () => setState(() => _isRecording = false),
      ),
    );
  }

  Widget _buildComposer(ConversationMode currentMode) {
    final colors = AppColors.of(context);
    final isGhost = currentMode == ConversationMode.ghost;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: colors.primaryBackground,
        border: Border(top: BorderSide(color: colors.hairline, width: 0.5)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeSegmentedControl(currentMode),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colors.secondaryText.withAlpha(150)),
                  onPressed: _showGalleryBottomSheet,
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt_outlined, color: colors.secondaryText.withAlpha(150)),
                  onPressed: _pickCamera,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      style: AppTypography.body(context),
                      cursorColor: colors.ghostAccent,
                      decoration: InputDecoration(
                        hintText: isGhost ? 'Ghost Message...' : 'Secure Message...',
                        hintStyle: AppTypography.body(context).copyWith(color: colors.secondaryText.withAlpha(80)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: colors.secondaryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    if (value.text.trim().isEmpty) {
                      return IconButton(
                        icon: Icon(Icons.mic_none_rounded, color: colors.secondaryText.withAlpha(150)),
                        onPressed: () {
                          AppHaptics.medium();
                          setState(() => _isRecording = true);
                        },
                      );
                    }
                    return IconButton(
                      icon: Icon(Icons.send_rounded, color: colors.ghostAccent),
                      onPressed: _sendMessage,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSegmentedControl(ConversationMode currentMode) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        height: 32,
        width: 180,
        decoration: BoxDecoration(
          color: colors.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildModeOption('NORMAL', ConversationMode.normal, currentMode == ConversationMode.normal),
            _buildModeOption('GHOST', ConversationMode.ghost, currentMode == ConversationMode.ghost),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(String label, ConversationMode mode, bool isSelected) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          ref.read(conversationServiceProvider).setConversationMode(widget.conversation.contactId, mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? (mode == ConversationMode.ghost ? colors.warning : colors.ghostAccent) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.caption(context).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.black : colors.secondaryText.withAlpha(100),
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTicks(Message msg) {
    final colors = AppColors.of(context);
    final isSent = msg.metadata?['status'] == 'SENT';
    final isDelivered = msg.deliveredAt != null;
    final isSeen = msg.seenAt != null;

    IconData icon = Icons.access_time;
    Color color = colors.secondaryText.withAlpha(80);
    double size = 8;

    if (isSeen) {
      icon = Icons.done_all;
      color = Colors.blueAccent;
      size = 12;
    } else if (isDelivered) {
      icon = Icons.done_all;
      size = 12;
    } else if (isSent) {
      icon = Icons.done;
      size = 12;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        if (isSeen && msg.seenAt != null) ...[
          const SizedBox(width: 2),
          Text(
            '${DateTime.now().difference(msg.seenAt!).inMinutes}m',
            style: TextStyle(fontSize: 7, color: color.withAlpha(150)),
          ),
        ],
      ],
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    final colors = AppColors.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: msg.type == MessageType.voice ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colors.ghostAccent.withAlpha(40) : colors.elevatedSurface, 
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
            bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
          border: Border.all(color: colors.hairline, width: 0.5),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.type == MessageType.image || msg.type == MessageType.video) 
              AttachmentWidget(message: msg) 
            else if (msg.type == MessageType.voice)
              VoiceMessageBubble(message: msg, isMe: isMe)
            else 
              Text(msg.plaintext, style: AppTypography.body(context)),
            
            if (msg.type != MessageType.voice) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat.Hm().format(msg.timestamp), style: AppTypography.caption(context).copyWith(fontSize: 8, color: colors.secondaryText.withAlpha(80))),
                  if (msg.metadata?['is_ghost'] == true) ...[
                    const SizedBox(width: 4), 
                    Icon(Icons.visibility_off_outlined, size: 8, color: colors.warning)
                  ],
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusTicks(msg),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSafetyNumbers(BuildContext context) {
    final contact = widget.conversation.contact;
    if (contact == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).secondaryBackground,
        title: const Text('SAFETY NUMBERS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Verify these numbers with your contact to ensure no interception.', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16), 
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(contact.fingerprint, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1, fontSize: 13))
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }

  Widget _buildRequestActions() {
    final colors = AppColors.of(context);
    final navigator = Navigator.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: colors.elevatedSurface,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GhostButton(
              label: 'BLOCK',
              type: GhostButtonType.danger,
              onPressed: () async {
                await ref.read(conversationServiceProvider).blockRequest(widget.conversation.contactId);
                navigator.pop();
              },
            ),
            GhostButton(
              label: 'ACCEPT',
              type: GhostButtonType.primary,
              onPressed: () async {
                await ref.read(conversationServiceProvider).acceptRequest(widget.conversation.contactId);
                navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickCamera() async {
    _logger.i('GHOST_LOG: MEDIA_BUTTON_TAPPED camera');
    final messenger = ScaffoldMessenger.of(context);
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;
    try {
      _logger.i('GHOST_LOG: MEDIA_PICKER_OPEN_START camera');
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        _logger.i('GHOST_LOG: MEDIA_PICKER_CANCELLED camera');
        return;
      }
      _logger.i('GHOST_LOG: MEDIA_PICKER_RETURNED camera path=${photo.path}');
      _sessionPickedPaths.insert(0, photo.path);
      
      messenger.showSnackBar(const SnackBar(content: Text('Encrypting & Uploading Image...')));
      await convService.sendImage(contactId, File(photo.path));
    } catch (e) {
      _logger.e('GHOST_LOG: MEDIA_PICKER_ERROR camera: $e');
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Camera capture failed: $e')));
    }
  }

  void _confirmAndSendRecentMedia(RecentMediaItem item) async {
    _logger.i('GHOST_LOG: RECENT_MEDIA_SELECTED');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final file = await item.filePromise;
    if (file == null) {
      _logger.e('GHOST_LOG: RECENT_MEDIA_FILE_NULL');
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Failed to load media file.')));
      return;
    }
    if (!mounted) return;
    
    final isVideo = item.isVideo;
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;
    
    _logger.i('GHOST_LOG: SHOWING_CONFIRMATION_DIALOG isVideo=$isVideo');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(isVideo ? 'Send Video?' : 'Send Image?'),
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
                  : item.buildThumbnail(context),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                if (isVideo) {
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Compressing & Uploading Video...')));
                  await convService.sendVideo(contactId, file);
                } else {
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Encrypting & Uploading Image...')));
                  await convService.sendImage(contactId, file);
                }
              } catch (e) {
                _logger.e('GHOST_LOG: MEDIA_SEND_ERROR confirm_dialog: $e');
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to send media: $e')));
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showGalleryBottomSheet() {
    _logger.i('GHOST_LOG: MEDIA_BUTTON_TAPPED gallery_sheet');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).primaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return FutureBuilder<List<RecentMediaItem>>(
                  future: _getRecentMedia(),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    final colors = AppColors.of(context);
                    
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10), 
                          width: 40, 
                          height: 4, 
                          decoration: BoxDecoration(color: colors.hairline, borderRadius: BorderRadius.circular(2))
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: items.isEmpty
                              ? const Center(child: Icon(Icons.photo_library_outlined, size: 48, color: Colors.white10))
                              : GridView.builder(
                                  controller: scrollController,
                                  padding: EdgeInsets.zero,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3, 
                                    crossAxisSpacing: 1, 
                                    mainAxisSpacing: 1
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _confirmAndSendRecentMedia(item);
                                      },
                                      child: Stack(
                                        fit: StackFit.expand, 
                                        children: [
                                          item.buildThumbnail(context),
                                          if (item.isVideo) 
                                            Container(
                                              color: Colors.black38, 
                                              child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 28))
                                            ),
                                        ]
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
                          child: Row(
                            children: [
                              _buildActionItem(context, Icons.camera_alt_outlined, 'Camera', Colors.pinkAccent, _pickCamera),
                              const SizedBox(width: 8),
                              _buildActionItem(context, Icons.photo_library_outlined, 'Gallery', Colors.blueAccent, _pickMedia),
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
      },
    );
  }

  void _pickMedia() async {
    _logger.i('GHOST_LOG: MEDIA_BUTTON_TAPPED native_picker');
    final messenger = ScaffoldMessenger.of(context);
    final convService = ref.read(conversationServiceProvider);
    final contactId = widget.conversation.contactId;

    try {
      _logger.i('GHOST_LOG: MEDIA_PICKER_OPEN_START native_picker');
      File? pickedFile;

      if (Platform.isAndroid || Platform.isIOS) {
        final List<AssetEntity>? result = await AssetPicker.pickAssets(
          context,
          pickerConfig: const AssetPickerConfig(
            maxAssets: 1,
            requestType: RequestType.common,
          ),
        );

        if (result != null && result.isNotEmpty) {
          pickedFile = await result.first.file;
        }
      } else {
        // Desktop Fallback
        final platformFile = await FilePicker.pickFile(
          type: FileType.media,
        );

        if (platformFile != null && platformFile.path != null) {
          pickedFile = File(platformFile.path!);
        }
      }

      if (pickedFile == null) {
        _logger.i('GHOST_LOG: MEDIA_PICKER_CANCELLED native_picker');
        return;
      }

      _logger.i('GHOST_LOG: MEDIA_PICKER_RETURNED native_picker path=${pickedFile.path}');
      _sessionPickedPaths.insert(0, pickedFile.path);

      final path = pickedFile.path.toLowerCase();
      final isVideo = path.endsWith('.mp4') ||
          path.endsWith('.mov') ||
          path.endsWith('.avi') ||
          path.endsWith('.mkv');

      if (isVideo) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Compressing & Uploading Video...')),
        );
        await convService.sendVideo(contactId, pickedFile);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Encrypting & Uploading Image...')),
        );
        await convService.sendImage(contactId, pickedFile);
      }
    } catch (e) {
      _logger.e('GHOST_LOG: MEDIA_PICKER_ERROR native_picker: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Media selection/upload failed: $e')),
        );
      }
    }
  }

  Future<List<RecentMediaItem>> _getRecentMedia() async {
    final List<RecentMediaItem> result = [];

    // Add session picked paths first
    for (final path in _sessionPickedPaths) {
      final file = File(path);
      if (file.existsSync()) {
        result.add(RecentMediaItem(file: file));
      }
    }

    // Only use PhotoManager on supported platforms
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        if (ps == PermissionState.authorized || ps == PermissionState.limited) {
          final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
            type: RequestType.common,
            filterOption: FilterOptionGroup(
              orders: [
                const OrderOption(type: OrderOptionType.createDate, asc: false),
              ],
            ),
          );

          if (paths.isNotEmpty) {
            final List<AssetEntity> assets =
                await paths.first.getAssetListRange(start: 0, end: 30);
            for (final asset in assets) {
              result.add(RecentMediaItem(asset: asset));
            }
          }
        }
      } catch (e) {
        _logger.w('GHOST_LOG: Error getting recent media: $e');
      }
    }

    return result;
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final colors = AppColors.of(context);
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.elevatedSurface, 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: colors.hairline)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label, 
                style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
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
  File? _decryptedFile;
  File? _thumbFile;
  MediaState _mediaState = MediaState.NOT_DOWNLOADED;
  MediaState _thumbState = MediaState.NOT_DOWNLOADED;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    StabilityTracker.activeMediaAttachmentBubbles++;
    _initMedia();
  }

  @override
  void dispose() {
    StabilityTracker.activeMediaAttachmentBubbles--;
    _stateSub?.cancel();
    super.dispose();
  }

  void _initMedia() async {
    if (widget.message.metadata == null || widget.message.metadata?['media_id'] == null) return;
    final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
    final mediaId = envelope.mediaId;
    final mediaManager = ref.read(mediaManagerProvider);

    final urlHint = envelope.relayUrl ?? "active_relay";
    debugPrint('GHOST_LOG: MEDIA_ATTACHMENT_DETECTED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint');

    setState(() {
      _mediaState = mediaManager.getMediaState(mediaId, isThumbnail: false);
      _thumbState = mediaManager.getMediaState(mediaId, isThumbnail: true);
    });

    _stateSub = mediaManager.stateStream.listen((update) {
      if (update.mediaId == mediaId) {
        if (mounted) {
          setState(() {
            if (update.isThumbnail) {
              _thumbState = update.state;
            } else {
              _mediaState = update.state;
            }
          });
          if (update.state == MediaState.READY) {
            _loadFiles();
          } else if (update.state == MediaState.FAILED) {
            debugPrint('GHOST_LOG: MEDIA_RENDER_FAILED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint error: Media state transitioned to failed');
          }
        }
      }
    });

    _loadFiles();
  }

  void _loadFiles() async {
    if (widget.message.metadata == null || widget.message.metadata?['media_id'] == null) return;
    final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
    final mediaId = envelope.mediaId;
    final mediaManager = ref.read(mediaManagerProvider);
    final relay = await ref.read(activeRelayProvider.future);
    if (!mounted) return;
    
    final identity = ref.read(identityServiceProvider).currentIdentity;
    final urlHint = envelope.relayUrl ?? relay?.apiUrl ?? "unknown";

    if (relay == null || identity == null) {
      debugPrint('GHOST_LOG: MEDIA_RENDER_FAILED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint error: Active relay or identity is null');
      return;
    }

    if (_thumbState == MediaState.READY) {
      try {
        final file = await mediaManager.getMedia(
          envelope: envelope,
          relay: relay,
          myXidKeyPair: identity.x25519KeyPair,
          isThumbnail: true,
          messageId: widget.message.id,
        );
        if (mounted) {
          setState(() => _thumbFile = file);
          debugPrint('GHOST_LOG: MEDIA_RENDER_READY messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint (Thumbnail)');
        }
      } catch (e) {
        debugPrint('GHOST_LOG: MEDIA_RENDER_FAILED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint error: Failed loading ready thumbnail: $e');
      }
    } else if (_thumbState == MediaState.NOT_DOWNLOADED) {
      try {
        final file = await mediaManager.getMedia(
          envelope: envelope,
          relay: relay,
          myXidKeyPair: identity.x25519KeyPair,
          isThumbnail: true,
          messageId: widget.message.id,
        );
        if (mounted) {
          setState(() { _thumbFile = file; _thumbState = MediaState.READY; });
          debugPrint('GHOST_LOG: MEDIA_RENDER_READY messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint (Thumbnail downloaded)');
        }
      } catch (e) {
        debugPrint('GHOST_LOG: MEDIA_RENDER_FAILED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint error: Failed downloading/decrypting thumbnail: $e');
      }
    }

    if (_mediaState == MediaState.READY) {
      try {
        final file = await mediaManager.getMedia(
          envelope: envelope,
          relay: relay,
          myXidKeyPair: identity.x25519KeyPair,
          isThumbnail: false,
          messageId: widget.message.id,
        );
        if (mounted) {
          setState(() => _decryptedFile = file);
          debugPrint('GHOST_LOG: MEDIA_RENDER_READY messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint (Original)');
        }
      } catch (e) {
        debugPrint('GHOST_LOG: MEDIA_RENDER_FAILED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint error: Failed loading ready original: $e');
      }
    }
  }

  void _download() async {
    if (widget.message.metadata == null || widget.message.metadata?['media_id'] == null) return;
    if (_mediaState == MediaState.DOWNLOADING || _mediaState == MediaState.DECRYPTING || _mediaState == MediaState.VERIFYING) return;

    final mediaManager = ref.read(mediaManagerProvider);
    final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
    final mediaId = envelope.mediaId;
    final relay = await ref.read(activeRelayProvider.future);
    final urlHint = envelope.relayUrl ?? relay?.apiUrl ?? "unknown";

    try {
      if (!mounted) return;
      
      final identity = ref.read(identityServiceProvider).currentIdentity;
      if (relay == null || identity == null) {
        throw Exception('Active relay or identity is null');
      }

      final file = await mediaManager.getMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: identity.x25519KeyPair,
        isThumbnail: false,
        messageId: widget.message.id,
      );
      if (mounted) {
        setState(() { _decryptedFile = file; _mediaState = MediaState.READY; });
        debugPrint('GHOST_LOG: MEDIA_RENDER_READY messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint (Downloaded Original)');
        _showFullScreen();
      }
    } catch (e) {
      debugPrint('GHOST_LOG: MEDIA_RENDER_FAILED messageId: ${widget.message.id} mediaId: $mediaId mediaKind: ${envelope.kind.name} url: $urlHint error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final meta = widget.message.metadata;
    final isGhost = meta?['is_ghost'] == true;
    final status = meta?['status'] as String?;
    final isPending = status != null && status != 'SENT';
    final isFailed = status == 'FAILED';
    final isProcessing = _mediaState == MediaState.DOWNLOADING || _mediaState == MediaState.DECRYPTING || _mediaState == MediaState.VERIFYING;

    return GestureDetector(
      onTap: (!isPending && _decryptedFile != null) ? _showFullScreen : (!isPending && !isProcessing ? _download : null),
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: colors.elevatedSurface, 
          borderRadius: BorderRadius.circular(12), 
          image: _thumbFile != null ? DecorationImage(image: ResizeImage(FileImage(_thumbFile!), width: 200, height: 150), fit: BoxFit.cover, opacity: isGhost ? 0.3 : 0.6) : null
        ),
        child: Center(
          child: (isProcessing || (isPending && !isFailed)) 
            ? const CircularProgressIndicator(strokeWidth: 2) 
            : Icon(isFailed ? Icons.error_outline : (widget.message.type == MessageType.video ? Icons.play_circle_outline : Icons.image_outlined), color: isFailed ? colors.error : colors.primaryText.withAlpha(100), size: 32),
        ),
      ),
    );
  }

  void _showFullScreen() {
    if (_decryptedFile == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenMediaViewer(file: _decryptedFile!, type: widget.message.type)));
  }
}

class FullScreenMediaViewer extends StatefulWidget {
  final File file;
  final MessageType type;
  const FullScreenMediaViewer({super.key, required this.file, required this.type});

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  @override
  void initState() {
    super.initState();
    StabilityTracker.activeFullScreenViews++;
  }

  @override
  void dispose() {
    StabilityTracker.activeFullScreenViews--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(widget.file.path)])))],
      ),
      body: Center(
        child: widget.type == MessageType.video 
            ? _VideoPreview(file: widget.file) 
            : InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.file(widget.file, fit: BoxFit.contain)),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final File file;
  const _VideoPreview({required this.file});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    StabilityTracker.activeVideoControllers++;
    _initPlayer();
  }

  void _initPlayer() async {
    try {
      final controller = VideoPlayerController.file(widget.file);
      _controller = controller;
      await controller.initialize();
      if (!mounted) { controller.dispose(); return; }
      _chewieController = ChewieController(videoPlayerController: controller, autoPlay: true, aspectRatio: controller.value.aspectRatio);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    _chewieController?.dispose();
    StabilityTracker.activeVideoControllers--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null) return const Center(child: CircularProgressIndicator());
    return AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: Chewie(controller: _chewieController!));
  }
}

