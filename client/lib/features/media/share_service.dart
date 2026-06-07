import 'package:share_plus/share_plus.dart';
import 'package:sodium/sodium_sumo.dart';
import 'attachment_envelope.dart';
import 'media_manager.dart';
import '../../core/network/relay_manager.dart';

class ShareService {
  final MediaManager _mediaManager;

  ShareService(this._mediaManager);

  Future<void> shareMedia({
    required AttachmentEnvelope envelope,
    required RelayProfile relay,
    required KeyPair myXidKeyPair,
  }) async {
    final file = await _mediaManager.getMedia(
      envelope: envelope,
      relay: relay,
      myXidKeyPair: myXidKeyPair,
    );
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: envelope.name,
    ));
  }
}
