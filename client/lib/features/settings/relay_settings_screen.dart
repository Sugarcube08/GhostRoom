import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/network/relay_manager.dart';
import 'package:uuid/uuid.dart';

class RelaySettingsScreen extends ConsumerStatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  ConsumerState<RelaySettingsScreen> createState() => _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends ConsumerState<RelaySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    debugPrint('GHOST_LOG: RelaySettingsScreen building');
    final relaysAsync = ref.watch(relayProfilesProvider);
    final activeRelayAsync = ref.watch(activeRelayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RELAY CONFIGURATION'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRelayDialog(context),
          ),
        ],
      ),
      body: relaysAsync.when(
        data: (relays) => ListView.builder(
          itemCount: relays.length,
          itemBuilder: (context, index) {
            final relay = relays[index];
            final isActive = activeRelayAsync.value?.id == relay.id;

            return ListTile(
              title: Text(relay.label),
              subtitle: Text(relay.websocketUrl),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive)
                    const Icon(Icons.check_circle, color: Colors.white),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    onPressed: () => _showDeleteConfirm(context, relay),
                  ),
                ],
              ),
              onTap: () async {
                await ref.read(relayManagerProvider).setActiveRelay(relay.id);
                ref.invalidate(activeRelayProvider);
                // Connect to the new relay
                ref.read(webSocketServiceProvider).connect(relay);
              },
              onLongPress: () => _showDeleteConfirm(context, relay),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showAddRelayDialog(BuildContext context) {
    final labelController = TextEditingController();
    final wsController = TextEditingController();
    final apiController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Relay'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: labelController, decoration: const InputDecoration(hintText: 'Nickname')),
              const SizedBox(height: 8),
              TextField(
                controller: wsController, 
                decoration: const InputDecoration(
                  hintText: 'Relay URL (http://192.168.1.x:3000)',
                  helperText: 'Use your machine IP for local dev',
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: apiController, decoration: const InputDecoration(hintText: 'API URL (https://...)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newRelay = RelayProfile(
                id: const Uuid().v4(),
                label: labelController.text,
                websocketUrl: wsController.text,
                apiUrl: apiController.text,
              );
              await ref.read(relayManagerProvider).saveRelay(newRelay);
              
              // Auto-select the newly added relay
              await ref.read(relayManagerProvider).setActiveRelay(newRelay.id);
              
              ref.invalidate(relayProfilesProvider);
              ref.invalidate(activeRelayProvider);
              
              // Connect to the new relay
              ref.read(webSocketServiceProvider).connect(newRelay);
              
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, RelayProfile relay) {
     showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Relay?'),
        content: Text('Remove ${relay.label} from your profiles?'),
        actions: [
           TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
           TextButton(
            onPressed: () async {
              await ref.read(relayManagerProvider).deleteRelay(relay.id);
              ref.invalidate(relayProfilesProvider);
              ref.invalidate(activeRelayProvider);
              
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
     );
  }
}

final relayProfilesProvider = FutureProvider<List<RelayProfile>>((ref) async {
  return ref.watch(relayManagerProvider).getRelays();
});
