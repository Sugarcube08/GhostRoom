import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/network/relay_manager.dart';
import '../../design_system/colors.dart';
import 'package:uuid/uuid.dart';

class RelaySettingsScreen extends ConsumerStatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  ConsumerState<RelaySettingsScreen> createState() => _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends ConsumerState<RelaySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final relaysAsync = ref.watch(relayProfilesProvider);
    final activeRelayAsync = ref.watch(activeRelayProvider);
    
    final colors = AppColors.of(context);

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
                    Icon(Icons.check_circle, color: colors.success),
                  IconButton(
                    icon: Icon(Icons.delete, color: colors.error, size: 20),
                    onPressed: () => _showDeleteConfirm(context, relay),
                  ),
                ],
              ),
              onTap: () async {
                final manager = ref.read(relayManagerProvider);
                final ws = ref.read(webSocketServiceProvider);
                
                await manager.setActiveRelay(relay.id);
                if (!mounted) return;
                
                ref.invalidate(activeRelayProvider);
                // Connect to the new relay
                ws.connect(relay);
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
              final label = labelController.text.trim();
              final wsUrl = wsController.text.trim();
              final apiUrl = apiController.text.trim();
              
              if (label.isEmpty || wsUrl.isEmpty) return;

              final newRelay = RelayProfile(
                id: const Uuid().v4(),
                label: label,
                websocketUrl: wsUrl,
                apiUrl: apiUrl,
              );
              
              final manager = ref.read(relayManagerProvider);
              final ws = ref.read(webSocketServiceProvider);

              await manager.saveRelay(newRelay);
              await manager.setActiveRelay(newRelay.id);
              
              if (!dialogContext.mounted) return;
              
              ref.invalidate(relayProfilesProvider);
              ref.invalidate(activeRelayProvider);
              
              // Connect to the new relay
              ws.connect(newRelay);
              
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
      builder: (dialogContext) {
        final dialogColors = AppColors.of(dialogContext);
        return AlertDialog(
          backgroundColor: dialogColors.backgroundSecondary,
          title: const Text('Delete Relay?'),
          content: Text('Remove ${relay.label} from your profiles?'),
          actions: [
             TextButton(
               onPressed: () => Navigator.pop(dialogContext), 
               child: Text('Cancel', style: TextStyle(color: dialogColors.textMuted))
             ),
             TextButton(
              onPressed: () async {
                final manager = ref.read(relayManagerProvider);
                await manager.deleteRelay(relay.id);
                
                if (!dialogContext.mounted) return;

                ref.invalidate(relayProfilesProvider);
                ref.invalidate(activeRelayProvider);
                
                Navigator.pop(dialogContext);
              },
              child: Text('Delete', style: TextStyle(color: dialogColors.error)),
            ),
          ],
        );
      },
     );
  }
}

final relayProfilesProvider = FutureProvider<List<RelayProfile>>((ref) async {
  return ref.watch(relayManagerProvider).getRelays();
});
