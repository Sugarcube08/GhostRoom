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
        title: const Text('ANONYMOUS ROOMS'),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIntro(),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: activeRelay.value != null ? () => _createSpace(context, ref) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('CREATE TEMPORARY ROOM'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: activeRelay.value != null ? () => _showJoinOptions(context, ref) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: const Text('JOIN VIA INVITE'),
              ),
              const SizedBox(height: 48),
              _buildRecentRooms(recentRooms, context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return const Column(
      children: [
        Icon(Icons.blur_on, size: 80, color: Colors.white10),
        SizedBox(height: 24),
        Text(
          'Disposable Spaces',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Anonymous, ephemeral, and local-only history.\nPerfect for transient conversations.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 13),
        ),
      ],
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
              'RECENT ROOMS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            ...rooms.map((room) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, color: Colors.white10, size: 20),
              title: Text(room['roomId'].toString().substring(0, 8), style: const TextStyle(fontSize: 14)),
              subtitle: Text(room['relayLabel'] ?? 'Unknown Relay', style: const TextStyle(fontSize: 10, color: Colors.white10)),
              trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.white10),
              onTap: () => _handleManualJoin(context, ref, room['roomId'], room['key']),
            )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
