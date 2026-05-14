import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'relay_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
              'GHOSTROOM MVP v0.0.1\nDISPOSABLE INFRASTRUCTURE',
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
      builder: (context) => AlertDialog(
        title: const Text('SURE?'),
        content: const Text('This will erase all relays, keys, and local data. This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await ref.read(relayManagerProvider).panicWipe();
              // In a real app, we'd probably restart or exit
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('ERASE EVERYTHING', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
