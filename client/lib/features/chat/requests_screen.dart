import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers.dart';
import 'conversation_service.dart';
import 'message.dart';
import 'conversation_state.dart';
import 'conversation_screen.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  String _buildSubtitleText(Conversation conv) {
    String text = conv.lastMessage?.plaintext ?? 'No messages';
    if (conv.lastMessage?.type == MessageType.image) {
      text = 'Photo';
    } else if (conv.lastMessage?.type == MessageType.video) {
      text = 'Video';
    } else if (conv.lastMessage?.type == MessageType.voice) {
      text = 'Voice Note';
    }
    return text;
  }

  Widget _buildDismissBackground(Color color, IconData icon, Alignment alignment) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    
    return ListenableBuilder(
      listenable: Listenable.merge([
        Hive.box<Message>('messages').listenable(),
        Hive.box<ConversationState>('conversation_states').listenable(),
      ]),
      builder: (context, _) {
        final requests = ref.read(conversationServiceProvider).getRequests();

        return Scaffold(
          backgroundColor: colors.primaryBackground,
          appBar: AppBar(
            title: const Text('IDENTITY LINKS'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_lock_outlined, size: 64, color: colors.secondaryText.withAlpha(20)),
                      const SizedBox(height: 24),
                      Text(
                        'No pending requests.',
                        style: AppTypography.section(context).copyWith(
                          color: colors.secondaryText.withAlpha(80),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return Dismissible(
                      key: Key(req.contactId),
                      background: _buildDismissBackground(colors.success, Icons.check_circle_outline, Alignment.centerLeft),
                      secondaryBackground: _buildDismissBackground(colors.error, Icons.block_outlined, Alignment.centerRight),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await ref.read(conversationServiceProvider).acceptRequest(req.contactId);
                          return true;
                        } else {
                          await ref.read(conversationServiceProvider).blockRequest(req.contactId);
                          return true;
                        }
                      },
                      child: GhostCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(conversation: req, isRequestMode: true),
                            ),
                          );
                        },
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.xs),
                        padding: const EdgeInsets.all(AppSpacing.m),
                        type: GhostSurfaceType.secondary,
                        child: Row(
                          children: [
                            GhostAvatar(
                              alias: 'Unknown',
                              size: 48,
                              backgroundColor: colors.elevatedSurface,
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unknown Sender',
                                    style: AppTypography.section(context).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _buildSubtitleText(req),
                                    style: AppTypography.caption(context).copyWith(
                                      color: colors.secondaryText.withAlpha(150),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (req.unreadCount > 0)
                              GhostBadge(
                                label: req.unreadCount.toString(),
                                color: colors.ghostAccent,
                                textColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            const SizedBox(width: AppSpacing.s),
                            Icon(Icons.chevron_right, size: 16, color: colors.secondaryText.withAlpha(50)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
