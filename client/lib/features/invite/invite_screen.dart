import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../spaces/space_service.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

class InviteScreen extends ConsumerWidget {
  final SpaceConfig config;

  const InviteScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyBase64 = base64Encode(config.roomKey.extractBytes());
    final encodedKey = Uri.encodeComponent(keyBase64);
    final inviteLink = 'ghost://room/${config.roomId}?key=$encodedKey';

    return Scaffold(
      appBar: AppBar(title: const Text('INVITE')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
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
                icon: const Icon(Icons.share),
                label: const Text('SHARE INVITE LINK'),
                onPressed: () => Share.share(inviteLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
