import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers.dart';
import 'conversation_service.dart';
import 'message.dart';
import 'conversation_state.dart';
import '../contacts/contact.dart';
import '../contacts/contact_actions.dart';
import 'conversation_screen.dart';
import 'requests_screen.dart';
import 'widgets/chats_header.dart';
import 'widgets/conversation_list_item.dart';
import '../../design_system/colors.dart';
import '../../design_system/spacing.dart';
import '../../design_system/typography.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> with ContactActions {
  Conversation? _selectedConversation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 900;
        
        return ListenableBuilder(
          listenable: Listenable.merge([
            Hive.box<Message>('messages').listenable(),
            Hive.box<Contact>('contacts').listenable(),
            Hive.box<ConversationState>('conversation_states').listenable(),
          ]),
          builder: (context, _) {
            final conversationService = ref.read(conversationServiceProvider);
            final conversations = conversationService.getConversations();
            final requests = conversationService.getRequests();

            final Widget chatList = Scaffold(
              backgroundColor: colors.primaryBackground,
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const ChatsHeader(alias: 'Ghost'),
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.l),
                                child: Row(
                                  children: [
                                    _buildRequestsIcon(context, requests.length),
                                    const SizedBox(width: AppSpacing.s),
                                    IconButton(
                                      icon: const Icon(Icons.person_add_alt_1_outlined),
                                      onPressed: () => showAddOptions(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (conversations.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(context),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final conv = conversations[index];
                                return ConversationListItem(
                                  conversation: conv,
                                  onTap: () {
                                    if (isWide) {
                                      setState(() => _selectedConversation = conv);
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ConversationScreen(conversation: conv),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                              childCount: conversations.length,
                            ),
                          ),
                        // Add spacer to prevent hiding behind nav bar
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ),
                  ),
                ),
              ),
            );

            if (!isWide) return chatList;

            return Row(
              children: [
                SizedBox(
                  width: 350,
                  child: chatList,
                ),
                VerticalDivider(width: 1, color: colors.hairline),
                Expanded(
                  child: _selectedConversation == null
                      ? _buildNoSelectionState(context)
                      : ConversationScreen(
                          key: ValueKey(_selectedConversation!.contactId),
                          conversation: _selectedConversation!,
                          onBack: () => setState(() => _selectedConversation = null),
                        ),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildRequestsIcon(BuildContext context, int count) {
    final colors = AppColors.of(context);
    
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(count > 0 ? Icons.mail_lock_outlined : Icons.mail_outline),
          if (count > 0)
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primaryBackground, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 9 ? '9+' : count.toString(),
                  style: TextStyle(
                    color: colors.backgroundPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsScreen()));
      },
    );
  }

  Widget _buildNoSelectionState(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: colors.secondaryText.withAlpha(10)),
            const SizedBox(height: 24),
            Text(
              'Select a conversation to start messaging',
              style: AppTypography.secondary(context).copyWith(
                color: colors.secondaryText.withAlpha(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: colors.secondaryText.withAlpha(20)),
          const SizedBox(height: 24),
          Text(
            'Secure channel established.',
            style: AppTypography.section(context).copyWith(
              color: colors.secondaryText.withAlpha(50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No active conversations yet.',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(
              color: colors.secondaryText.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }
}
