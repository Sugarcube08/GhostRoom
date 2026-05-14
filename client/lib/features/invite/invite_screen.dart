import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../spaces/space_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

class InviteScreen extends ConsumerStatefulWidget {
  final SpaceConfig config;

  const InviteScreen({super.key, required this.config});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _saveToGallery() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();

      // Save to temp file first (Gal needs a path or bytes depending on version,
      // but usually bytes or path. Let's use putUint8List if available or temporary file)
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/ghost_invite_${widget.config.roomId.substring(0, 8)}.png',
      ).create();
      await file.writeAsBytes(bytes);

      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to gallery!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyBase64 = base64Encode(widget.config.roomKey.extractBytes());
    final encodedKey = Uri.encodeComponent(keyBase64);
    final inviteLink = 'ghost://room/${widget.config.roomId}?key=$encodedKey';

    return Scaffold(
      appBar: AppBar(title: const Text('INVITE')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: inviteLink,
                    version: QrVersions.auto,
                    size: 250.0,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'SCAN TO JOIN',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              const Text(
                'This invite will expire with the space.',
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('SAVE TO GALLERY'),
                onPressed: _saveToGallery,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('SHARE INVITE LINK'),
                onPressed: () => Share.share(inviteLink),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
