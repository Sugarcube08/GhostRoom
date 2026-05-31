import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../chat/chat_screen.dart';
import '../invite/invite_screen.dart';
import '../spaces/space_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sodium/sodium.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class AnonymousRoomsScreen extends ConsumerWidget {
  const AnonymousRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRelay = ref.watch(activeRelayProvider);
    final recentRooms = ref.watch(recentRoomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('SPACES'),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntro(),
              const SizedBox(height: 48),
              const Text(
                'CREATE NEW SPACE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              _buildCreationCards(context, ref, activeRelay.value != null),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT SPACES',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
                  ),
                  TextButton(
                    onPressed: () => _showJoinOptions(context, ref),
                    child: const Text('JOIN VIA INVITE', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRecentRooms(recentRooms, context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Icon(Icons.blur_on, size: 32, color: Colors.white24),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Disposable. Anonymous.\nZero Footprint.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Spaces use symmetric encryption and temporary storage. No identities are used. Once a space expires, it is gone forever.',
            style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCreationCards(BuildContext context, WidgetRef ref, bool enabled) {
    return Row(
      children: [
        _DurationCard(
          label: 'SHORT',
          duration: '30 MIN',
          icon: Icons.timer_outlined,
          enabled: enabled,
          onTap: () => _createSpace(context, ref, 1800),
        ),
        const SizedBox(width: 12),
        _DurationCard(
          label: 'STANDARD',
          duration: '2 HR',
          icon: Icons.schedule,
          enabled: enabled,
          onTap: () => _createSpace(context, ref, 7200),
        ),
        const SizedBox(width: 12),
        _DurationCard(
          label: 'LONG',
          duration: '24 HR',
          icon: Icons.event_available,
          enabled: enabled,
          onTap: () => _createSpace(context, ref, 86400),
        ),
      ],
    );
  }

  Widget _buildRecentRooms(AsyncValue recentAsync, BuildContext context, WidgetRef ref) {
    return recentAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) return _buildEmptyHistory();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.white10, size: 20),
                title: Text(room['roomId'].toString().substring(0, 8), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text('Temporary Session', style: const TextStyle(fontSize: 10, color: Colors.white10)),
                trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.white10),
                onTap: () => _handleManualJoin(context, ref, room['roomId'], room['key']),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Text('No recent spaces found', style: TextStyle(color: Colors.white10, fontSize: 12)),
    );
  }

  void _showJoinOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('SCAN QR CODE'),
              onTap: () {
                Navigator.pop(sheetContext);
                _joinSpace(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('SELECT FROM GALLERY'),
              onTap: () {
                Navigator.pop(sheetContext);
                _joinFromGallery(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('ENTER LINK MANUALLY'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showManualEntry(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createSpace(BuildContext context, WidgetRef ref, int seconds) async {
    final relay = await ref.read(activeRelayProvider.future);
    if (relay == null) return;

    try {
      final config = await ref.read(spaceServiceProvider).createSpace(relay, expirySeconds: seconds);
      
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
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('SHOW INVITE QR'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(builder: (_) => InviteScreen(config: config)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('ENTER SPACE'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(config: config)));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _joinSpace(BuildContext context, WidgetRef ref) {
    bool detected = false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scannerContext) => Scaffold(
          appBar: AppBar(title: const Text('SCAN INVITE')),
          body: MobileScanner(
            onDetect: (capture) async {
              if (detected) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.startsWith('ghost://room/')) {
                  detected = true;
                  Navigator.pop(scannerContext);
                  await _handleInviteLink(context, ref, code);
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
      final captureFuture = scanner.barcodes.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout waiting for barcode results'),
      );
      
      final bool found = await scanner.analyzeImage(image.path);
      
      if (found) {
        final BarcodeCapture capture = await captureFuture;
        if (capture.barcodes.isNotEmpty) {
          final code = capture.barcodes.first.rawValue;
          if (code != null && code.startsWith('ghost://room/')) {
            if (context.mounted) {
              await _handleInviteLink(context, ref, code);
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not a valid Ghost Room invite.')),
              );
            }
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in image.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: $e')),
        );
      }
    } finally {
      scanner.dispose();
    }
  }

  void _showManualEntry(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Space'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Paste ghost://room/... link'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final link = controller.text;
              if (link.startsWith('ghost://room/')) {
                Navigator.pop(dialogContext);
                await _handleInviteLink(context, ref, link);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInviteLink(BuildContext context, WidgetRef ref, String link) async {
    try {
      final uri = Uri.parse(link.replaceFirst('ghost://', 'http://'));
      final roomId = uri.pathSegments.last;
      final rawKey = uri.queryParameters['key'];

      if (rawKey == null) return;

      final keyBase64 = rawKey.trim().replaceAll(" ", "+");
      final sodium = ref.read(sodiumProvider);
      final keyBytes = base64Decode(keyBase64);
      SecureKey.fromList(sodium, keyBytes);

      final activeRelay = ref.read(activeRelayProvider).value;
      await ref.read(relayManagerProvider).addRecentRoom(
        roomId,
        keyBase64,
        activeRelay?.label ?? 'Joined Relay',
      );
      
      ref.invalidate(recentRoomsProvider);

      if (context.mounted) {
        _handleManualJoin(context, ref, roomId, keyBase64);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid invite: $e')),
        );
      }
    }
  }

  void _handleManualJoin(BuildContext context, WidgetRef ref, String roomId, String keyBase64) {
    try {
      final sodium = ref.read(sodiumProvider);
      final keyBytes = base64Decode(keyBase64.trim().replaceAll(" ", "+"));
      final roomKey = SecureKey.fromList(sodium, keyBytes);

      final config = SpaceConfig(
        roomId: roomId,
        roomKey: roomKey,
        expiry: DateTime.now().add(const Duration(hours: 2)),
      );

      if (context.mounted) {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => ChatScreen(config: config))
        );
      }
    } catch (e) {
      debugPrint('GHOST_LOG: _handleManualJoin error: $e');
    }
  }
}

class _DurationCard extends StatelessWidget {
  final String label;
  final String duration;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DurationCard({
    required this.label,
    required this.duration,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(enabled ? 8 : 2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(5)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 24, color: Colors.white30),
                const SizedBox(height: 12),
                Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(duration, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
