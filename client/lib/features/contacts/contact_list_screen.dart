import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers.dart';
import '../contacts/contact.dart';
import '../settings/identity_actions.dart';
import 'contact_actions.dart';
import 'my_passport_screen.dart';
import 'contact_detail_screen.dart';
import 'widgets/my_passport_card.dart';
import 'widgets/contact_list_item.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen>
    with ContactActions, IdentityActions {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return ValueListenableBuilder(
      valueListenable: Hive.box<Contact>('contacts').listenable(),
      builder: (context, _, _) {
        final contacts = ref.watch(contactServiceProvider).getAllContacts();
        final identity = ref.watch(identityServiceProvider).currentIdentity;

        return Scaffold(
          backgroundColor: colors.primaryBackground,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.xl,
                    ),
                    child: Text(
                      'CONNECTIONS',
                      style: AppTypography.hero(context),
                    ),
                  ),
                ),
                if (identity != null)
                  SliverToBoxAdapter(
                    child: MyPassportCard(
                      identity: identity,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyPassportScreen()),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.m,
                    ),
                    child: Row(
                      children: [
                        _buildQuickAction(
                          context,
                          icon: Icons.qr_code_scanner,
                          label: 'SCAN',
                          onTap: () => openScanner(context),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        _buildQuickAction(
                          context,
                          icon: Icons.file_download_outlined,
                          label: 'IMPORT',
                          onTap: () => showAddOptions(context),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        _buildQuickAction(
                          context,
                          icon: Icons.share_outlined,
                          label: 'SHARE',
                          onTap: () => shareIdentity(ref),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.s),
                    child: Text(
                      'YOUR NETWORK',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.secondaryText.withAlpha(80),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                if (contacts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final contact = contacts[index];
                          return ContactListItem(
                            contact: contact,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ContactDetailScreen(contact: contact),
                                ),
                              );
                            },
                          );
                        },
                        childCount: contacts.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: colors.ghostAccent,
            foregroundColor: Colors.white,
            onPressed: () => showAddOptions(context),
            child: const Icon(Icons.person_add_alt_1),
          ),
        );
      },
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GhostSurface(
        type: GhostSurfaceType.secondary,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          child: Column(
            children: [
              Icon(icon, color: colors.ghostAccent, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.diversity_3_outlined,
              size: 64,
              color: colors.secondaryText.withAlpha(20),
            ),
            const SizedBox(height: 24),
            Text(
              'The Social Graph is Local.',
              style: AppTypography.section(context).copyWith(
                color: colors.secondaryText.withAlpha(80),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'GhostRoom does not store your contacts in the cloud. Exchange identities in person or via secure channels.',
              textAlign: TextAlign.center,
              style: AppTypography.caption(context).copyWith(
                color: colors.secondaryText.withAlpha(50),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
