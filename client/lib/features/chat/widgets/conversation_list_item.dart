import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/typography.dart';
import '../../../design_system/spacing.dart';
import '../../../design_system/colors.dart';
import '../conversation_service.dart';
import '../message.dart';

class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasUnread = conversation.unreadCount > 0;
    
    return GhostCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.m),
      type: hasUnread ? GhostSurfaceType.elevated : GhostSurfaceType.secondary,
      child: Row(
        children: [
          GhostAvatar(
            alias: conversation.alias,
            size: 52,
            backgroundColor: hasUnread 
                ? colors.ghostAccent.withAlpha(30) 
                : colors.elevatedSurface,
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.alias,
                        style: AppTypography.section(context).copyWith(
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: hasUnread ? colors.primaryText : colors.primaryText.withAlpha(220),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conversation.lastMessage != null)
                      Text(
                        DateFormat.Hm().format(conversation.lastMessage!.timestamp),
                        style: AppTypography.caption(context).copyWith(
                          color: hasUnread ? colors.ghostAccent : colors.secondaryText.withAlpha(100),
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildSubtitle(context),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: AppSpacing.s),
                      GhostBadge(
                        label: conversation.unreadCount > 9 ? '9+' : conversation.unreadCount.toString(),
                        color: colors.ghostAccent,
                        textColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final colors = AppColors.of(context);
    final hasUnread = conversation.unreadCount > 0;
    
    if (conversation.lastMessage == null) {
      return Text(
        'No messages',
        style: AppTypography.secondary(context).copyWith(
          color: colors.secondaryText.withAlpha(80),
        ),
      );
    }

    String text = conversation.lastMessage!.plaintext;
    if (conversation.lastMessage!.type == MessageType.image) {
      text = 'Photo';
    } else if (conversation.lastMessage!.type == MessageType.video) {
      text = 'Video';
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.secondary(context).copyWith(
        color: hasUnread ? colors.primaryText.withAlpha(200) : colors.secondaryText.withAlpha(150),
        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
      ),
    );
  }
}
