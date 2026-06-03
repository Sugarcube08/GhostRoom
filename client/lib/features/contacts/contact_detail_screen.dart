import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'contact.dart';
import '../chat/conversation_service.dart';
import '../chat/conversation_screen.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';

class ContactDetailScreen extends ConsumerWidget {
  final Contact contact;
  const ContactDetailScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    
    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: AppBar(
        title: const Text('CONTACT'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showRenameDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GhostAvatar(alias: contact.alias, size: 80),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'ALIAS',
                style: AppTypography.caption(context).copyWith(
                  color: colors.secondaryText.withAlpha(100),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                contact.alias,
                style: AppTypography.title(context),
              ),
              const SizedBox(height: 48),
              Text(
                'PUBLIC ID',
                style: AppTypography.caption(context).copyWith(
                  color: colors.secondaryText.withAlpha(100),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                contact.publicId,
                style: AppTypography.body(context).copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 48),
              Text(
                'SAFETY NUMBERS',
                style: AppTypography.caption(context).copyWith(
                  color: colors.secondaryText.withAlpha(100),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GhostSurface(
                padding: const EdgeInsets.all(AppSpacing.m),
                type: GhostSurfaceType.secondary,
                child: Text(
                  contact.fingerprint,
                  style: AppTypography.body(context).copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: colors.ghostAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              GhostButton(
                label: 'OPEN SECURE CHANNEL',
                type: GhostButtonType.primary,
                width: double.infinity,
                onPressed: () {
                  final conv = Conversation(
                    contact: contact,
                    contactId: contact.publicId,
                    alias: contact.alias,
                    messages: [],
                    lastActivityAt: DateTime.now(),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConversationScreen(conversation: conv),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () => _deleteContact(context, ref),
                  child: Text(
                    'DELETE CONTACT',
                    style: AppTypography.caption(context).copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: contact.alias);
    final colors = AppColors.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.secondaryBackground,
        title: const Text('RENAME CONTACT'),
        content: GhostInput(
          controller: controller,
          hintText: 'Enter new alias...',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(contactServiceProvider)
                  .updateAlias(contact.publicId, controller.text);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context); // Go back to list to refresh
              }
            },
            child: const Text('RENAME'),
          ),
        ],
      ),
    );
  }

  void _deleteContact(BuildContext context, WidgetRef ref) async {
    await ref.read(contactServiceProvider).deleteContact(contact.publicId);
    if (context.mounted) Navigator.pop(context);
  }
}
