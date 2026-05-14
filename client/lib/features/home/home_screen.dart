import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../settings/settings_screen.dart';
import '../chat/chat_screen.dart';
import '../invite/invite_screen.dart';
import '../spaces/space_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sodium/sodium.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRelay = ref.watch(activeRelayProvider);
    final recentRooms = ref.watch(recentRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GHOST ROOM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const SettingsScreen())
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRelayStatus(activeRelay),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: activeRelay.value != null ? () => _createSpace(context, ref) : null,
                child: const Text('CREATE PRIVATE SPACE'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: activeRelay.value != null ? () => _showJoinOptions(context, ref) : null,
                child: const Text('JOIN SPACE'),
              ),
              const SizedBox(height: 48),
              _buildRecentRooms(recentRooms, context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRooms(AsyncValue recentAsync, BuildContext context, WidgetRef ref) {
    return recentAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RECENT SPACES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            ...rooms.map((room) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(room['roomId'].toString().substring(0, 8)),
              subtitle: Text(room['relayLabel'] ?? 'Unknown Relay', style: const TextStyle(fontSize: 10)),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () => _handleManualJoin(context, ref, room['roomId'], room['key']),
            )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showJoinOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('SCAN QR CODE'),
              onTap: () {
                Navigator.pop(context);
                _joinSpace(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('SELECT FROM GALLERY'),
              onTap: () {
                Navigator.pop(context);
                _joinFromGallery(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('ENTER LINK MANUALLY'),
              onTap: () {
                Navigator.pop(context);
                _showManualEntry(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayStatus(AsyncValue activeRelay) {
    return activeRelay.when(
      data: (relay) => Column(
        children: [
          Icon(
            relay != null ? Icons.sensors : Icons.sensors_off,
            size: 48,
            color: relay != null ? Colors.white : Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            relay?.label ?? 'NO RELAY CONFIGURED',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          if (relay == null)
            const Text(
              'Please add a relay in settings to begin.',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Icon(Icons.error_outline, color: Colors.red),
    );
  }

  void _createSpace(BuildContext context, WidgetRef ref) async {
    final relay = await ref.read(activeRelayProvider.future);
    if (relay == null) return;

    try {
      final config = await ref.read(spaceServiceProvider).createSpace(relay);
      
      // Save to recent
      await ref.read(relayManagerProvider).addRecentRoom(
        config.roomId,
        base64Encode(config.roomKey.extractBytes()),
        relay.label,
      );
      ref.invalidate(recentRoomsProvider);

      if (context.mounted) {
        _showSpaceCreatedOptions(context, config);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showSpaceCreatedOptions(BuildContext context, SpaceConfig config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('SHOW INVITE QR'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => InviteScreen(config: config)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('ENTER SPACE'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(config: config)));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _joinSpace(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('SCAN INVITE')),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.startsWith('ghost://room/')) {
                  _handleInviteLink(context, ref, code);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _joinFromGallery(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final scanner = MobileScannerController();
    try {
      // In mobile_scanner 3.x, analyzeImage returns a bool and results are sent to the barcodes stream
      final found = await scanner.analyzeImage(image.path);
      if (found) {
        // We listen to the first result from the stream
        await for (final capture in scanner.barcodes) {
          if (capture.barcodes.isNotEmpty) {
            final code = capture.barcodes.first.rawValue;
            if (code != null && code.startsWith('ghost://room/')) {
              if (context.mounted) {
                _handleInviteLink(context, ref, code);
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error analyzing image: $e');
    } finally {
      scanner.dispose();
    }
  }

  void _showManualEntry(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Space'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Paste ghost://room/... link'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final link = controller.text;
              if (link.startsWith('ghost://room/')) {
                Navigator.pop(context);
                _handleInviteLink(context, ref, link);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _handleInviteLink(BuildContext context, WidgetRef ref, String link) {
    final uri = Uri.parse(link.replaceFirst('ghost://', 'http://'));
    final roomId = uri.pathSegments.last;
    final keyBase64 = uri.queryParameters['key'];

    if (keyBase64 == null) return;

    final sodium = ref.read(sodiumProvider);
    final keyBytes = base64Decode(keyBase64.trim().replaceAll(" ", ""));
    final roomKey = SecureKey.fromList(sodium, keyBytes);

    // Save to recent
    final activeRelay = ref.read(activeRelayProvider).value;
    ref.read(relayManagerProvider).addRecentRoom(
      roomId,
      keyBase64,
      activeRelay?.label ?? 'Joined Relay',
    );
    ref.invalidate(recentRoomsProvider);

    _handleManualJoin(context, ref, roomId, keyBase64);
  }

  void _handleManualJoin(BuildContext context, WidgetRef ref, String roomId, String keyBase64) {
    final sodium = ref.read(sodiumProvider);
    final keyBytes = base64Decode(keyBase64.trim().replaceAll(" ", ""));
    final roomKey = SecureKey.fromList(sodium, keyBytes);

    final config = SpaceConfig(
      roomId: roomId,
      roomKey: roomKey,
      expiry: DateTime.now().add(const Duration(hours: 2)),
    );

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(config: config)));
    }
  }
}
