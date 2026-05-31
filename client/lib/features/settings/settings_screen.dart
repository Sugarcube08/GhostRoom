import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../../core/providers.dart';
import 'relay_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IDENTITY'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          if (identity != null) _buildIdentityHeader(context, identity),
          const SizedBox(height: 32),
          _buildSectionHeader('CONTROL CENTER'),
          ListTile(
            leading: const Icon(Icons.router_outlined),
            title: const Text('Relay Configuration'),
            subtitle: const Text('Manage your relay servers'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelaySettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Migration'),
            subtitle: const Text('Export contacts and identity'),
            onTap: () => _showBackupOptions(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy'),
            subtitle: const Text('Screenshot protection & overlay'),
            onTap: () {},
          ),
          const Divider(color: Colors.white10, height: 48),
          _buildSectionHeader('DANGER ZONE'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('PANIC WIPE', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Erase everything immediately'),
            onTap: () => _showPanicConfirm(context, ref),
          ),
          const SizedBox(height: 48),
          const Center(
            child: Text(
              'GHOSTROOM V2.1\nDURABLE ANONYMOUS MAILBOX',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader(BuildContext context, dynamic identity) {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: QrImageView(
              data: identity.publicId,
              version: QrVersions.auto,
              size: 200.0,
              gapless: false,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          identity.publicId,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: identity.publicId));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Public ID copied')));
          },
          child: const Text(
            'COPY PUBLIC ID',
            style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'FINGERPRINT: ${identity.fingerprint}',
            style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
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
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('SHOW RECOVERY SEED'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement secure seed reveal
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('RESTORE FROM BACKUP'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement restore flow
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
