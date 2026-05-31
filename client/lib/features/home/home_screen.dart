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

import '../contacts/contact_list_screen.dart';
import '../chat/chat_screens.dart';

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
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              debugPrint('GHOST_LOG: Settings icon pressed');
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const SettingsScreen())
              );
            },
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

  Widget _buildRelayStatus(AsyncValue activeRelay) {
    return activeRelay.when(
      data: (relay) => Column(
        children: [
          Image.asset(
            'assets/images/banner.png',
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 32),
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
      error: (_, _) => const Icon(Icons.error_outline, color: Colors.red),
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
      debugPrint('GHOST_LOG: GalleryScan starting for: ${image.path}');
      
      // We don't need to await 'start()' for analyzeImage, but we need to listen
      final captureFuture = scanner.barcodes.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout waiting for barcode results'),
      );
      
      final bool found = await scanner.analyzeImage(image.path);
      debugPrint('GHOST_LOG: GalleryScan analyzeImage returned: $found');
      
      if (found) {
        final BarcodeCapture capture = await captureFuture;
        debugPrint('GHOST_LOG: GalleryScan detected ${capture.barcodes.length} barcodes.');
        
        if (capture.barcodes.isNotEmpty) {
          final code = capture.barcodes.first.rawValue;
          debugPrint('GHOST_LOG: GalleryScan raw value: $code');
          
          if (code != null && code.startsWith('ghost://room/')) {
            if (context.mounted) {
              debugPrint('GHOST_LOG: GalleryScan valid invite found. Handling...');
              await _handleInviteLink(context, ref, code);
            } else {
              debugPrint('GHOST_LOG: GalleryScan context NOT mounted after scan');
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
      debugPrint('GHOST_LOG: GalleryScan error: $e');
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
    debugPrint('GHOST_LOG: _handleInviteLink processing: $link');
    try {
      final uri = Uri.parse(link.replaceFirst('ghost://', 'http://'));
      final roomId = uri.pathSegments.last;
      final rawKey = uri.queryParameters['key'];

      if (rawKey == null) {
        debugPrint('GHOST_LOG: _handleInviteLink error: No key found');
        return;
      }

      // Consolidate key cleaning
      final keyBase64 = rawKey.trim().replaceAll(" ", "+");
      
      // Verify key is valid base64 before saving
      final sodium = ref.read(sodiumProvider);
      final keyBytes = base64Decode(keyBase64);
      // We create the roomKey just to verify it works
      SecureKey.fromList(sodium, keyBytes);

      debugPrint('GHOST_LOG: _handleInviteLink RoomID: $roomId');
      
      // Save to recent - AWAIT this to avoid race condition with invalidation
      final activeRelay = ref.read(activeRelayProvider).value;
      await ref.read(relayManagerProvider).addRecentRoom(
        roomId,
        keyBase64,
        activeRelay?.label ?? 'Joined Relay',
      );
      
      // Refresh the UI list
      ref.invalidate(recentRoomsProvider);

      if (context.mounted) {
        _handleManualJoin(context, ref, roomId, keyBase64);
      }
    } catch (e) {
      debugPrint('GHOST_LOG: _handleInviteLink error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid invite: $e')),
        );
      }
    }
  }

  void _handleManualJoin(BuildContext context, WidgetRef ref, String roomId, String keyBase64) {
    debugPrint('GHOST_LOG: _handleManualJoin starting for roomId: $roomId');
    try {
      final sodium = ref.read(sodiumProvider);
      debugPrint('GHOST_LOG: _handleManualJoin sodium ready');
      
      final keyBytes = base64Decode(keyBase64.trim().replaceAll(" ", "+"));
      debugPrint('GHOST_LOG: _handleManualJoin key decoded, length: ${keyBytes.length}');
      
      final roomKey = SecureKey.fromList(sodium, keyBytes);
      debugPrint('GHOST_LOG: _handleManualJoin roomKey created');

      final config = SpaceConfig(
        roomId: roomId,
        roomKey: roomKey,
        expiry: DateTime.now().add(const Duration(hours: 2)),
      );

      if (context.mounted) {
        debugPrint('GHOST_LOG: _handleManualJoin navigating to ChatScreen...');
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) {
            debugPrint('GHOST_LOG: ChatScreen builder called');
            return ChatScreen(config: config);
          })
        ).then((_) => debugPrint('GHOST_LOG: Navigator.push completed'))
         .catchError((err) => debugPrint('GHOST_LOG: Navigator.push error: $err'));
      } else {
        debugPrint('GHOST_LOG: _handleManualJoin context not mounted');
      }
    } catch (e, stack) {
      debugPrint('GHOST_LOG: _handleManualJoin error: $e');
      debugPrint('GHOST_LOG: _handleManualJoin stack: $stack');
    }
  }
}
