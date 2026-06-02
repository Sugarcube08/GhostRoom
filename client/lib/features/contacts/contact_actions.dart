import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../../core/providers.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';

mixin ContactActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  void openScanner(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!context.mounted) return;

    if (status.isGranted) {
      final result = await Navigator.push<String>(
        context, 
        MaterialPageRoute(builder: (_) => const QRScannerScreen())
      );
      if (result != null && context.mounted) {
        processScannedData(context, result);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan QR codes.'))
      );
    }
  }

  void showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('SCAN PASSPORT'),
            onTap: () {
              Navigator.pop(context);
              openScanner(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('PASTE IDENTITY PACKAGE'),
            onTap: () {
              Navigator.pop(context);
              showManualImport(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('ENTER PUBLIC ID MANUALLY'),
            onTap: () {
              Navigator.pop(context);
              showManualIdEntry(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void showManualIdEntry(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('MANUAL ENTRY'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IMPORTANT: Manual entry only works for V1 Ephemeral Spaces. To send E2EE Direct Messages, you MUST scan the recipient\'s Identity Package QR code.', 
              style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter Public ID...',
                helperText: 'e.g. ABCD-EFGH...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              
              final contact = Contact(
                publicId: id,
                alias: 'Manual Contact',
                eid: '', 
                xid: '', 
                fingerprint: 'Unverified',
                createdAt: DateTime.now(),
              );
              await ref.read(contactServiceProvider).saveContact(contact);
              if (!context.mounted) return;
              
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact Added')));
            }, 
            child: const Text('ADD')
          ),
        ],
      ),
    );
  }

  void showManualImport(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('IMPORT PACKAGE'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Paste Identity Package string...'),
          maxLines: 4,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              final data = controller.text.trim();
              if (data.isNotEmpty) {
                processScannedData(context, data);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
  }

  void processScannedData(BuildContext context, String data) async {
    try {
      final idService = ref.read(identityServiceProvider);
      final pkg = IdentityPackage.fromEncodedString(data);
      final isValid = idService.verifyPackage(pkg);
      if (!isValid) throw Exception('Invalid package signature');

      final eidBytes = base64Decode(pkg.eid);
      final xidBytes = base64Decode(pkg.xid);
      
      final publicId = idService.derivePublicId(eidBytes);
      final fingerprint = idService.calculateFingerprint(eidBytes, xidBytes);

      final contact = Contact(
        publicId: publicId,
        alias: 'New Contact',
        eid: pkg.eid,
        xid: pkg.xid,
        fingerprint: fingerprint,
        createdAt: DateTime.now(),
        preferredRelay: pkg.relays.isNotEmpty ? pkg.relays.first : null,
      );

      await ref.read(contactServiceProvider).saveContact(contact);
      if (!context.mounted) return;
      
      // Removed the unconditional Navigator.pop(context) which caused double-pops
      // If we are in a dialog (like showManualImport), we handle the pop there.
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact Added')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isStopping = false;

  Future<void> _stopAndPop([String? result]) async {
    if (_isStopping) return;
    _isStopping = true;
    await controller.stop();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _stopAndPop(result as String?);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SCAN PASSPORT'),
          leading: BackButton(
            onPressed: () => _stopAndPop(),
          ),
        ),
        body: MobileScanner(
          controller: controller,
          onDetect: (capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                await _stopAndPop(barcode.rawValue);
                break;
              }
            }
          },
        ),
      ),
    );
  }
}
