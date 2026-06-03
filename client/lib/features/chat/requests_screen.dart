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

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  Widget _buildSubtitle(Conversation conv) {
    String text = conv.lastMessage?.plaintext ?? 'No messages';
    if (conv.lastMessage?.type == MessageType.image) {
      text = '[Image]';
    } else if (conv.lastMessage?.type == MessageType.video) {
      text = '[Video]';
    }
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildDismissBackground(Color color, IconData icon, Alignment alignment) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
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
            title: const Text('MESSAGE REQUESTS'),
            backgroundColor: colors.primaryBackground,
            elevation: 0,
          ),
          body: requests.isEmpty
              ? Center(
                  child: Text(
                    'No pending requests.',
                    style: AppTypography.secondary(context).copyWith(
                      color: colors.secondaryText.withAlpha(100),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return Dismissible(
                      key: Key(req.contactId),
                      background: _buildDismissBackground(colors.success, Icons.check, Alignment.centerLeft),
                      secondaryBackground: _buildDismissBackground(colors.error, Icons.block, Alignment.centerRight),
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
                        leading: CircleAvatar(
                          backgroundColor: colors.elevatedSurface,
                          child: Icon(Icons.person_outline, color: colors.secondaryText),
                        ),
                        title: Text(
                          'Unknown Sender',
                          style: AppTypography.section(context).copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: _buildSubtitle(req),
                        trailing: req.unreadCount > 0 ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: colors.ghostAccent, borderRadius: BorderRadius.circular(10)),
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
