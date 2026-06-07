import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';

mixin IdentityActions {
  Future<void> shareIdentity(WidgetRef ref) async {
    final relayManager = ref.read(relayManagerProvider);
    final relays = await relayManager.getRelays();
    final pkg = await ref.read(identityServiceProvider).createPackage(relays);
    final encodedPkg = pkg.toEncodedString();
    
    final customLink = 'ghostroom://identity/$encodedPkg';
    final webLink = 'https://ghostroom.app/i/$encodedPkg';
    
    await SharePlus.instance.share(
      ShareParams(
        text: 'Connect with me on GhostRoom!\n\nApp Link: $customLink\nWeb Link: $webLink',
        subject: 'GhostRoom Identity',
      ),
    );
  }
}
