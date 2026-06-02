import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';
import '../../core/providers.dart';
import 'relay_settings_screen.dart';

class IdentityVaultScreen extends ConsumerStatefulWidget {
  const IdentityVaultScreen({super.key});

  @override
  ConsumerState<IdentityVaultScreen> createState() => _IdentityVaultScreenState();
}

class _IdentityVaultScreenState extends ConsumerState<IdentityVaultScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<void> _saveQRToGallery(String publicId) async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        final downloadsDir = Directory('$home/Downloads/GhostRoom');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final file = File('${downloadsDir.path}/ghost_identity_${publicId.substring(0, 8)}.png');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Identity saved to: ${file.path}')));
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/ghost_identity_${publicId.substring(0, 8)}.png');
        await file.writeAsBytes(bytes);

        await Gal.putImage(file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity QR saved to gallery!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save QR: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityServiceProvider).currentIdentity;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('IDENTITY VAULT'),
        backgroundColor: const Color(0xFF080808),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          if (identity != null) _buildIdentityCard(context, identity),
          const SizedBox(height: 32),
          _buildSecurityScore(context, ref),
          const SizedBox(height: 16),
          _buildVaultSection(
            context,
            'RECOVERY & ASSETS',
            [
              VaultAction(
                icon: Icons.vpn_key_outlined,
                title: 'Show Recovery Seed',
                subtitle: 'The 24-word phrase for recovery',
                onTap: () => _showSeedReveal(context, ref),
              ),
              VaultAction(
                icon: Icons.backup_outlined,
                title: 'Secure Backup',
                subtitle: 'Manage encrypted data archives',
                onTap: () => _showBackupOptions(context, ref),
              ),
              VaultAction(
                icon: Icons.health_and_safety_outlined,
                title: 'Recovery Drill',
                subtitle: 'Test if you can still recover',
                onTap: () => _startRecoveryDrill(context),
              ),
            ],
          ),
          _buildVaultSection(
            context,
            'NETWORK & INFRASTRUCTURE',
            [
              VaultAction(
                icon: Icons.router_outlined,
                title: 'Relay Configuration',
                subtitle: 'Manage connected mailboxes',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelaySettingsScreen())),
              ),
              VaultAction(
                icon: Icons.analytics_outlined,
                title: 'System Diagnostics',
                subtitle: 'Check relay and storage status',
                onTap: () => _showDiagnostics(context, ref),
              ),
            ],
          ),
          _buildVaultSection(
            context,
            'PRIVACY & RISK',
            [
              VaultAction(
                icon: Icons.security,
                title: 'Advanced Privacy',
                subtitle: 'Screenshots and overlays',
                onTap: () {},
              ),
              VaultAction(
                icon: Icons.delete_forever,
                title: 'Wipe Vault',
                subtitle: 'Erase all identity and data locally',
                color: Colors.redAccent,
                onTap: () => _showPanicConfirm(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Center(
            child: Text(
              'GHOSTROOM V2.1.1 PREMIUM\nSTABILITY SPRINT ACTIVE',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, dynamic identity) {
    return FutureBuilder<String>(
      future: _getEncodedPackage(),
      builder: (context, snapshot) {
        final encodedPkg = snapshot.data ?? identity.publicId;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withAlpha(5)),
          ),
          child: Column(
            children: [
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: encodedPkg,
                    version: QrVersions.auto,
                    size: 140.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                identity.publicId,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                'FINGERPRINT: ${identity.fingerprint}',
                style: const TextStyle(fontSize: 9, color: Colors.white24, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _saveQRToGallery(identity.publicId), 
                    icon: const Icon(Icons.download, size: 16), 
                    label: const Text('SAVE QR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _shareIdentityLink(encodedPkg), 
                    icon: const Icon(Icons.share, size: 16), 
                    label: const Text('SHARE LINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Future<String> _getEncodedPackage() async {
    final relayManager = ref.read(relayManagerProvider);
    final relays = await relayManager.getRelays();
    final pkg = await ref.read(identityServiceProvider).createPackage(relays);
    return pkg.toEncodedString();
  }

  void _shareIdentityLink(String encodedPkg) {
    final link = 'ghostroom://identity/$encodedPkg';
    Share.share(
      'Connect with me on GhostRoom: $link',
      subject: 'GhostRoom Identity',
    );
  }

  Widget _buildSecurityScore(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.read(identityServiceProvider).isDrillRequired(),
      builder: (context, snapshot) {
        final drillDone = snapshot.data == false;
        final int score = drillDone ? 100 : 67;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('IDENTITY SECURITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(drillDone ? 'Maximum Protection' : 'Good Protection', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: (drillDone ? Colors.green : Colors.amber).withAlpha(30), borderRadius: BorderRadius.circular(12)),
                    child: Text('$score%', style: TextStyle(color: drillDone ? Colors.green : Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const _ScoreFactor(label: 'Seed', icon: Icons.check_circle, color: Colors.green),
                  const _ScoreFactor(label: 'Backup', icon: Icons.check_circle, color: Colors.green),
                  _ScoreFactor(label: 'Drill', icon: drillDone ? Icons.check_circle : Icons.pending_outlined, color: drillDone ? Colors.green : Colors.white24),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildVaultSection(BuildContext context, String title, List<VaultAction> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.5),
          ),
        ),
        ...actions.map((action) => ListTile(
          leading: Icon(action.icon, color: action.color ?? Colors.white70),
          title: Text(action.title, style: TextStyle(color: action.color ?? Colors.white)),
          subtitle: Text(action.subtitle, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          onTap: action.onTap,
        )),
      ],
    );
  }

  void _showSeedReveal(BuildContext context, WidgetRef ref) {
    final mnemonic = ref.read(identityServiceProvider).currentIdentity?.mnemonic;
    if (mnemonic == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('RECOVERY SEED'),
        content: Text(mnemonic, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  void _startRecoveryDrill(BuildContext context) {
     final idService = ref.read(identityServiceProvider);
     final mnemonic = idService.currentIdentity?.mnemonic;
     if (mnemonic == null) return;

     final words = mnemonic.split(' ');
     final List<int> drillIndices = [];
     while (drillIndices.length < 3) {
        final idx = (DateTime.now().microsecondsSinceEpoch % 24);
        if (!drillIndices.contains(idx)) drillIndices.add(idx);
     }
     drillIndices.sort();

     final Map<int, String> answers = {};

     showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
         builder: (context, setDialogState) => AlertDialog(
           backgroundColor: const Color(0xFF121212),
           title: const Text('RECOVERY DRILL'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text('Enter the following words from your seed phrase to verify you still have access.', style: TextStyle(fontSize: 12, color: Colors.white54)),
               const SizedBox(height: 24),
               ...drillIndices.map((idx) => Padding(
                 padding: const EdgeInsets.only(bottom: 16),
                 child: TextField(
                   onChanged: (val) => answers[idx] = val,
                   decoration: InputDecoration(labelText: 'Word #${idx + 1}'),
                   style: const TextStyle(fontFamily: 'monospace'),
                 ),
               )),
             ],
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
             ElevatedButton(
               onPressed: () async {
                 bool allCorrect = true;
                 for (final idx in drillIndices) {
                   if (answers[idx]?.trim().toLowerCase() != words[idx]) {
                     allCorrect = false;
                     break;
                   }
                 }
                 if (allCorrect) {
                   await idService.recordDrillSuccess();
                   if (context.mounted) {
                     Navigator.pop(context);
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drill successful! Security score updated.')));
                     setState(() {}); 
                   }
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification failed.')));
                 }
               }, 
               child: const Text('VERIFY')
             ),
           ],
         ),
       ),
     );
  }

  void _showDiagnostics(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SYSTEM DIAGNOSTICS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 32),
            _DiagRow(label: 'Identity Status', value: ref.read(identityServiceProvider).hasIdentity ? 'Active' : 'Missing', color: Colors.green),
            _DiagRow(label: 'WebSocket Connection', value: ref.read(webSocketServiceProvider).isConnected ? 'Connected' : 'Disconnected', color: Colors.blueAccent),
            _DiagRow(label: 'Auth Status', value: ref.read(webSocketServiceProvider).isAuthenticated ? 'Authenticated' : 'Pending', color: Colors.amber),
            const SizedBox(height: 32),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('CREATE ENCRYPTED BACKUP'),
            onTap: () {
              Navigator.pop(context);
              _showBackupDialog(context, ref);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EXPORT BACKUP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Choose a password...'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                await ref.read(backupServiceProvider).exportBackup(controller.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
            child: const Text('EXPORT'),
          ),
        ],
      ),
    );
  }

  void _showPanicConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SURE?'),
        content: const Text('This will erase all relays, keys, and local data. This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await ref.read(identityServiceProvider).wipeIdentity();
              await ref.read(contactServiceProvider).clearAll();
              
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('ERASE EVERYTHING', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ScoreFactor extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ScoreFactor({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DiagRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class VaultAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  VaultAction({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});
}
