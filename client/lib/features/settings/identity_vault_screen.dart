import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers.dart';
import 'relay_settings_screen.dart';

class IdentityVaultScreen extends ConsumerWidget {
  const IdentityVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('IDENTITY VAULT'),
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          if (identity != null) _buildIdentityCard(context, identity),
          const SizedBox(height: 32),
          _buildStatusBanner(context),
          const SizedBox(height: 16),
          _buildVaultSection(
            context,
            'RECOVERY & ASSETS',
            [
              VaultAction(
                icon: Icons.vpn_key_outlined,
                title: 'Show Recovery Seed',
                subtitle: 'The 24-word phrase for recovery',
                onTap: () => _showSeedReveal(context, ref),
              ),
              VaultAction(
                icon: Icons.backup_outlined,
                title: 'Secure Backup',
                subtitle: 'Manage encrypted data archives',
                onTap: () => _showBackupOptions(context, ref),
              ),
              VaultAction(
                icon: Icons.qr_code_2,
                title: 'My ID Card',
                subtitle: 'Full-screen sharing card',
                onTap: () => _showFullIDCard(context, identity!),
              ),
            ],
          ),
          _buildVaultSection(
            context,
            'NETWORK & INFRASTRUCTURE',
            [
              VaultAction(
                icon: Icons.router_outlined,
                title: 'Relay Configuration',
                subtitle: 'Manage connected mailboxes',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelaySettingsScreen())),
              ),
              VaultAction(
                icon: Icons.sync,
                title: 'Full Database Sync',
                subtitle: 'Pull all available mail from relay',
                onTap: () {},
              ),
            ],
          ),
          _buildVaultSection(
            context,
            'PRIVACY & RISK',
            [
              VaultAction(
                icon: Icons.security,
                title: 'Advanced Privacy',
                subtitle: 'Screenshots and overlays',
                onTap: () {},
              ),
              VaultAction(
                icon: Icons.delete_forever,
                title: 'Wipe Vault',
                subtitle: 'Erase all identity and data locally',
                color: Colors.redAccent,
                onTap: () => _showPanicConfirm(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Center(
            child: Text(
              'GHOSTROOM V2.1 PREMIUM\nID: ENCRYPTED. DURABLE. SOVEREIGN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, dynamic identity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(5)),
      ),
      child: Column(
        children: [
          QrImageView(
            data: identity.publicId,
            version: QrVersions.auto,
            size: 140.0,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            identity.publicId,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'FINGERPRINT: ${identity.fingerprint}',
            style: const TextStyle(fontSize: 9, color: Colors.white24, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withAlpha(40)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.blueAccent, size: 20),
          SizedBox(width: 12),
          Text(
            'VAULT SECURED',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          Spacer(),
          Text(
            'BACKUP ACTIVE',
            style: TextStyle(fontSize: 10, color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultSection(BuildContext context, String title, List<VaultAction> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
          ),
        ),
        ...actions.map((action) => ListTile(
          leading: Icon(action.icon, color: action.color ?? Colors.white70),
          title: Text(action.title, style: TextStyle(color: action.color ?? Colors.white)),
          subtitle: Text(action.subtitle, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          onTap: action.onTap,
        )),
      ],
    );
  }

  void _showSeedReveal(BuildContext context, WidgetRef ref) {
    // TODO: Mandatory password/biometric check
    final mnemonic = ref.read(identityServiceProvider).currentIdentity?.mnemonic;
    if (mnemonic == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('RECOVERY SEED'),
        content: Text(mnemonic, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  void _showFullIDCard(BuildContext context, dynamic identity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF080808),
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('MY GHOSTROOM ID', style: TextStyle(letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
                  child: QrImageView(data: identity.publicId, version: QrVersions.auto, size: 280),
                ),
                const SizedBox(height: 48),
                Text(identity.publicId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Scan to add as contact', style: TextStyle(color: Colors.white24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBackupOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('CREATE ENCRYPTED BACKUP'),
            onTap: () {
              Navigator.pop(context);
              _showBackupDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('RESTORE FROM BACKUP'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EXPORT BACKUP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Choose a password...'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                await ref.read(backupServiceProvider).exportBackup(controller.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
            child: const Text('EXPORT'),
          ),
        ],
      ),
    );
  }

  void _showPanicConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SURE?'),
        content: const Text('This will erase all relays, keys, and local data. This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await ref.read(identityServiceProvider).wipeIdentity();
              await ref.read(contactServiceProvider).clearAll();
              
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('ERASE EVERYTHING', style: TextStyle(color: Colors.red)),
          ),
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
