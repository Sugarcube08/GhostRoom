import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';

mixin IdentityActions {
  static const String defaultDomain = 'ghost-room-chi.vercel.app';

  String getConnectUrl(String publicId) {
    return 'https://$defaultDomain/connect/$publicId';
  }

  String getCustomSchemeUrl(String publicId) {
    return 'ghostroom://connect/$publicId';
  }

  Future<void> copyConnectUrl(BuildContext context, String publicId) async {
    final url = getConnectUrl(publicId);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connect link copied: $url'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> shareIdentity(WidgetRef ref, {String? publicId}) async {
    final idService = ref.read(identityServiceProvider);
    final targetId = publicId ?? idService.currentIdentity?.publicId;
    if (targetId == null) return;

    final shareUrl = getConnectUrl(targetId);
    final appUrl = getCustomSchemeUrl(targetId);

    await SharePlus.instance.share(ShareParams(
      text: 'Connect with me on GhostRoom (End-to-End Encrypted & Sovereign):\n\n$shareUrl\n\nDeep Link: $appUrl\nPublic ID: $targetId',
      subject: 'GhostRoom Passport - $targetId',
    ));
  }
}
