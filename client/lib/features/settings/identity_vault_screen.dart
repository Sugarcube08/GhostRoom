import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers.dart';

import 'relay_settings_screen.dart';
import 'identity_actions.dart';
import '../contacts/my_passport_screen.dart';
import '../chat/requests_screen.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';

class IdentityVaultScreen extends ConsumerStatefulWidget {
  const IdentityVaultScreen({super.key});

  @override
  ConsumerState<IdentityVaultScreen> createState() => _IdentityVaultScreenState();
}

class _IdentityVaultScreenState extends ConsumerState<IdentityVaultScreen> with IdentityActions {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                          vertical: AppSpacing.xl,
                        ),
                        child: Text(
                          'IDENTITY VAULT',
                          style: AppTypography.hero(context),
                        ),
                      ),
                    ),
                    if (identity != null) ...[
                      SliverToBoxAdapter(child: _buildIdentityStatus(context)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.m),
                          child: _buildPassportHero(context, identity),
                        ),
                      ),
                    ],
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildVaultSection(
                            context,
                            'SECURITY & RECOVERY',
                            [
                              VaultAction(
                                icon: Icons.vpn_key_outlined,
                                title: 'Recovery Seed',
                                subtitle: 'Manage your 24-word phrase',
                                onTap: () => _showSeedReveal(context, ref),
                              ),
                              VaultAction(
                                icon: Icons.mail_lock_outlined,
                                title: 'Identity Links',
                                subtitle: 'Manage message requests',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsScreen())),
                              ),
                              VaultAction(
                                icon: Icons.backup_outlined,
                                title: 'Cloud Backup',
                                subtitle: 'Encrypted archives',
                                onTap: () => _showBackupOptions(context, ref),
                              ),

                              VaultAction(
                                icon: Icons.health_and_safety_outlined,
                                title: 'Recovery Drill',
                                subtitle: 'Test your access',
                                onTap: () => _startRecoveryDrill(context),
                              ),
                            ],
                          ),
                          _buildVaultSection(
                            context,
                            'INFRASTRUCTURE',
                            [
                              VaultAction(
                                icon: Icons.router_outlined,
                                title: 'Relay Nodes',
                                subtitle: 'Manage secure mailboxes',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelaySettingsScreen())),
                              ),
                              VaultAction(
                                icon: Icons.analytics_outlined,
                                title: 'Diagnostics',
                                subtitle: 'System health check',
                                onTap: () => _showDiagnostics(context, ref),
                              ),
                            ],
                          ),
                          _buildVaultSection(
                            context,
                            'DANGER ZONE',
                            [
                              VaultAction(
                                icon: Icons.delete_forever_outlined,
                                title: 'Wipe All Data',
                                subtitle: 'Irreversible local erase',
                                color: colors.error,
                                onTap: () => _showPanicConfirm(context, ref),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            'GHOSTROOM V3.0 PREMIUM\nZERO-KNOWLEDGE ARCHITECTURE',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 2),
                          ),
                        ),
                      ),
                    ),
                    // Bottom Nav spacing
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildIdentityStatus(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Row(
        children: [
          _buildStatusChip(context, 'PROTECTED', colors.success, Icons.verified_user),
          const SizedBox(width: 8),
          _buildStatusChip(context, 'BACKED UP', colors.ghostAccent, Icons.cloud_done),
          const SizedBox(width: 8),
          _buildStatusChip(context, 'RECOVERABLE', Colors.amber, Icons.sync_problem),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportHero(BuildContext context, dynamic identity) {
    final colors = AppColors.of(context);
    return GhostCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPassportScreen())),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      padding: const EdgeInsets.all(AppSpacing.l),
      type: GhostSurfaceType.elevated,
      borderRadius: BorderRadius.circular(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: identity.publicId, size: 48, gapless: false),
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DIGITAL PASSPORT', style: AppTypography.caption(context).copyWith(color: colors.ghostAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(identity.publicId, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.section(context).copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: colors.secondaryText.withAlpha(50)),
        ],
      ),
    );
  }

  Widget _buildVaultSection(BuildContext context, String title, List<VaultAction> actions) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.xl, AppSpacing.l, AppSpacing.m),
          child: Text(
            title,
            style: AppTypography.caption(context).copyWith(fontWeight: FontWeight.bold, color: colors.secondaryText.withAlpha(80), letterSpacing: 1.5),
          ),
        ),
        ...actions.map((action) => GhostCard(
          onTap: action.onTap,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
          type: GhostSurfaceType.secondary,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (action.color ?? colors.primaryText).withAlpha(10), shape: BoxShape.circle),
                child: Icon(action.icon, color: action.color ?? colors.secondaryText, size: 20),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.title, style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600, color: action.color)),
                    Text(action.subtitle, style: AppTypography.caption(context).copyWith(color: colors.secondaryText.withAlpha(100))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: colors.secondaryText.withAlpha(50)),
            ],
          ),
        )),
      ],
    );
  }

  // Same logic for Seed Reveal, Backup, Drill, Diagnostics, Panic Omitted but assume ported to Ghost UI
  void _showSeedReveal(BuildContext context, WidgetRef ref) {
    final mnemonic = ref.read(identityServiceProvider).currentIdentity?.mnemonic;
    if (mnemonic == null) return;
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.secondaryBackground,
        title: const Text('RECOVERY SEED'),
        content: Text(mnemonic, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }

  void _startRecoveryDrill(BuildContext context) {
    final idService = ref.read(identityServiceProvider);
    final mnemonic = idService.currentIdentity?.mnemonic;
    if (mnemonic == null) return;

    final words = mnemonic.split(' ');
    final List<int> drillIndices = [];
    while (drillIndices.length < 3) {
      final idx = (DateTime.now().microsecondsSinceEpoch % 24);
      if (!drillIndices.contains(idx)) drillIndices.add(idx);
    }
    drillIndices.sort();

    final Map<int, String> answers = {};
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.secondaryBackground,
          surfaceTintColor: Colors.transparent,
          title: Text('RECOVERY DRILL', style: AppTypography.section(context).copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the following words from your seed phrase to verify you still have access.',
                style: AppTypography.caption(context).copyWith(color: colors.secondaryText.withAlpha(150)),
              ),
              const SizedBox(height: 24),
              ...drillIndices.map((idx) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GhostInput(
                      onChanged: (val) => answers[idx] = val,
                      labelText: 'Word #${idx + 1}',
                    ),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: colors.secondaryText.withAlpha(100))),
            ),
            GhostButton(
              label: 'VERIFY',
              onPressed: () async {
                bool allCorrect = true;
                for (final idx in drillIndices) {
                  if (answers[idx]?.trim().toLowerCase() != words[idx]) {
                    allCorrect = false;
                    break;
                  }
                }
                if (allCorrect) {
                  final idService = ref.read(identityServiceProvider);
                  await idService.recordDrillSuccess();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drill successful! Security score updated.')));
                    setState(() {});
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification failed.')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDiagnostics(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.secondaryBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SYSTEM DIAGNOSTICS', style: AppTypography.section(context).copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 32),
            _buildDiagRow(label: 'Identity Status', value: ref.read(identityServiceProvider).hasIdentity ? 'Active' : 'Missing', color: colors.success),
            _buildDiagRow(label: 'WebSocket Connection', value: ref.read(webSocketServiceProvider).isConnected ? 'Connected' : 'Disconnected', color: colors.ghostAccent),
            _buildDiagRow(label: 'Auth Status', value: ref.read(webSocketServiceProvider).isAuthenticated ? 'Authenticated' : 'Pending', color: Colors.amber),
            const SizedBox(height: 32),
            GhostButton(
              label: 'CLOSE',
              width: double.infinity,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupOptions(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.secondaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.file_upload_outlined, color: colors.ghostAccent),
            title: const Text('CREATE ENCRYPTED BACKUP'),
            onTap: () {
              Navigator.pop(context);
              _showBackupDialog(context, ref);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.secondaryBackground,
        title: Text('EXPORT BACKUP', style: AppTypography.section(context).copyWith(fontWeight: FontWeight.bold)),
        content: GhostInput(
          controller: controller,
          hintText: 'Choose a password...',
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: TextStyle(color: colors.secondaryText.withAlpha(100)))),
          GhostButton(
            label: 'EXPORT',
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                final backupService = ref.read(backupServiceProvider);
                await backupService.exportBackup(controller.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPanicConfirm(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.secondaryBackground,
        title: Text('SURE?', style: AppTypography.section(context).copyWith(fontWeight: FontWeight.bold, color: colors.error)),
        content: Text(
          'This will erase all relays, keys, and local data. This action is irreversible.',
          style: AppTypography.body(context).copyWith(color: colors.secondaryText.withAlpha(150)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('CANCEL', style: TextStyle(color: colors.secondaryText.withAlpha(100)))),
          GhostButton(
            label: 'ERASE EVERYTHING',
            type: GhostButtonType.danger,
            onPressed: () async {
              final idService = ref.read(identityServiceProvider);
              final contactService = ref.read(contactServiceProvider);

              await idService.wipeIdentity();
              await contactService.clearAll();

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  Widget _buildDiagRow({required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class VaultAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  VaultAction({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});
}
