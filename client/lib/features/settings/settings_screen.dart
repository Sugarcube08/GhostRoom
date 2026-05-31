import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'relay_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        children: [
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
            onTap: () => _showBackupDialog(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy'),
            subtitle: const Text('Screenshot protection & overlay'),
            onTap: () {},
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('PANIC WIPE', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Erase everything immediately'),
            onTap: () => _showPanicConfirm(context, ref),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'GHOSTROOM V2.0.1\nDURABLE ANONYMOUS MAILBOX',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2),
            ),
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
              // Updated to use identityService.wipeIdentity
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
