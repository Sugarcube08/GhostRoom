import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import '../../core/providers.dart';
import '../contacts/contact.dart';
import '../../core/crypto/identity_service.dart';
import '../../design_system/colors.dart';

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
      backgroundColor: AppColors.of(context).backgroundSecondary,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('SCAN PASSPORT'),
            onTap: () {
              Navigator.pop(sheetContext);
              openScanner(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('IMPORT FROM GALLERY'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final picker = ImagePicker();
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image == null) return;
              
              final scanner = MobileScannerController();
              try {
                final capture = await scanner.analyzeImage(image.path);
                if (capture != null && capture.barcodes.isNotEmpty) {
                  final result = capture.barcodes.first.rawValue;
                  if (result != null && context.mounted) {
                    processScannedData(context, result);
                    return;
                  }
                }
              } catch (e) {
                debugPrint('Gallery scan error: $e');
              } finally {
                scanner.dispose();
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No valid Identity QR found in image.'))
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('PASTE IDENTITY PACKAGE'),
            onTap: () {
              Navigator.pop(sheetContext);
              showManualImport(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('ENTER PUBLIC ID MANUALLY'),
            onTap: () {
              Navigator.pop(sheetContext);
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
      builder: (dialogContext) {
        final dialogColors = AppColors.of(dialogContext);
        return AlertDialog(
          backgroundColor: dialogColors.backgroundSecondary,
          title: const Text('MANUAL ENTRY'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IMPORTANT: Manual entry only works for V1 Ephemeral Spaces. To send E2EE Direct Messages, you MUST scan the recipient\'s Identity Package QR code.', 
                style: TextStyle(fontSize: 11, color: dialogColors.warning, fontWeight: FontWeight.bold)
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: Text('CANCEL', style: TextStyle(color: dialogColors.textMuted))
            ),
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
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact Added')));
                }
              }, 
              child: const Text('ADD')
            ),
          ],
        );
      },
    );
  }

  void showManualImport(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.of(dialogContext).backgroundSecondary,
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

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  MobileScannerController? controller;
  bool _isStopping = false;
  bool _isStarting = false;
  bool _hasError = false;
  bool _isStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);


    // On Linux or other unsupported platforms, fail gracefully immediately
    if (!kIsWeb && Platform.isLinux) {
      _hasError = true;
      return;
    }

    controller = MobileScannerController(
      autoStart: false,
    );
    _startScanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasError || controller == null) return;
    if (state == AppLifecycleState.paused) {
      _stopScanner();
    } else if (state == AppLifecycleState.resumed) {
      _startScanner();
    }
  }

  Future<void> _startScanner() async {
    final c = controller;
    if (c == null || _isStarting || _isStarted || _isStopping || !mounted) return;
    _isStarting = true;
    try {
      await c.start();
      _isStarted = true;
      if (mounted) setState(() => _hasError = false);
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _stopScanner() async {
    final c = controller;
    if (c == null || !_isStarted || _isStopping) return;
    _isStopping = true;
    try {
      await c.stop();
      _isStarted = false;
    } catch (_) {
      // Ignore
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _stopAndPop([String? result]) async {
    if (_isStopping) return;
    WidgetsBinding.instance.removeObserver(this);
    await _stopScanner();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_hasError || controller == null) {
      return Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppBar(title: const Text('SCAN ERROR')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 48),
              const SizedBox(height: 16),
              const Text('Camera failed to initialize.'),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _stopAndPop(result as String?);
      },
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppBar(
          title: const Text('SCAN PASSPORT'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(
            onPressed: () => _stopAndPop(),
          ),
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty) {
                }
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    await _stopAndPop(barcode.rawValue);
                    break;
                  } else {
                  }
                }
              },
            ),
            // Scanner Overlay
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.info.withAlpha(100), width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
