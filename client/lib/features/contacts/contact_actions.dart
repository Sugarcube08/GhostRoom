import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';
import '../chat/conversation_service.dart';
import '../chat/conversation_state.dart';
import '../chat/conversation_screen.dart';

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
                'IMPORTANT: Direct Messages require cryptographic identity exchange. To send E2EE messages, please scan the recipient\'s Passport QR code.', 
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

  void handleDeepLinkUri(BuildContext context, Uri uri) {
    debugPrint('GhostRoom handling deep link URI: $uri');

    // 1. Custom scheme: ghostroom://
    if (uri.scheme == 'ghostroom') {
      if (uri.host == 'identity') {
        final payload = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (payload != null) {
          processScannedData(context, payload);
          return;
        }
      }
      if (uri.host == 'connect') {
        final publicId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (publicId != null && publicId.isNotEmpty) {
          showContactVerificationModal(context, publicId: publicId);
          return;
        }
      }
      if (uri.pathSegments.contains('connect')) {
        final idx = uri.pathSegments.indexOf('connect');
        if (idx + 1 < uri.pathSegments.length) {
          showContactVerificationModal(context, publicId: uri.pathSegments[idx + 1]);
          return;
        }
      }
      if (uri.pathSegments.contains('u')) {
        final idx = uri.pathSegments.indexOf('u');
        if (idx + 1 < uri.pathSegments.length) {
          showContactVerificationModal(context, publicId: uri.pathSegments[idx + 1]);
          return;
        }
      }
    }

    // 2. HTTPS / HTTP: https://ghost-room-chi.vercel.app/connect/<publicId> or /u/<publicId>
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (uri.pathSegments.isNotEmpty) {
        final first = uri.pathSegments.first;
        if ((first == 'connect' || first == 'u') && uri.pathSegments.length > 1) {
          final publicId = uri.pathSegments[1];
          showContactVerificationModal(context, publicId: publicId);
          return;
        }
        if (first == 'i' && uri.pathSegments.length > 1) {
          processScannedData(context, uri.pathSegments[1]);
          return;
        }
      }
      if (uri.queryParameters.containsKey('id')) {
        final publicId = uri.queryParameters['id']!;
        showContactVerificationModal(context, publicId: publicId);
        return;
      }
    }
  }

  void processScannedData(BuildContext context, String rawData) async {
    final clean = rawData.trim();
    if (clean.isEmpty) return;

    // 1. Is it a URI / deep link?
    final uri = Uri.tryParse(clean);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ghostroom')) {
      handleDeepLinkUri(context, uri);
      return;
    }

    // 2. Is it an encoded identity package?
    if (clean.contains('ghostroom://identity/') ||
        clean.contains('/i/') ||
        clean.startsWith('ey') ||
        (clean.startsWith('{') && clean.contains('eid'))) {
      try {
        final idService = ref.read(identityServiceProvider);
        final pkg = IdentityPackage.fromEncodedString(clean);
        final isValid = idService.verifyPackage(pkg);
        if (!isValid) throw Exception('Identity package signature verification failed');

        final eidBytes = base64Decode(pkg.eid);
        final publicId = idService.derivePublicId(eidBytes);
        showContactVerificationModal(context, publicId: publicId, package: pkg);
        return;
      } catch (e) {
        debugPrint('Package decode error: $e');
      }
    }

    // 3. Raw public ID string
    final cleanId = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (cleanId.length >= 8) {
      showContactVerificationModal(context, publicId: cleanId);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unrecognized identity format. Please scan a valid GhostRoom Passport QR or Link.')),
      );
    }
  }

  void showContactVerificationModal(
    BuildContext context, {
    required String publicId,
    IdentityPackage? package,
  }) async {
    final idService = ref.read(identityServiceProvider);
    final myIdentity = idService.currentIdentity;
    if (myIdentity != null && myIdentity.publicId == publicId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is your own GhostRoom Passport.')),
        );
      }
      return;
    }

    final contactService = ref.read(contactServiceProvider);
    final existingContact = contactService.getContact(publicId);

    // Compute or retrieve fingerprint
    String fingerprint = 'Pending Key Exchange';
    bool isCryptographicallySigned = false;

    if (package != null) {
      try {
        final eidBytes = base64Decode(package.eid);
        final xidBytes = base64Decode(package.xid);
        fingerprint = idService.calculateFingerprint(eidBytes, xidBytes);
        isCryptographicallySigned = true;
      } catch (_) {}
    } else if (existingContact != null && existingContact.fingerprint.isNotEmpty) {
      fingerprint = existingContact.fingerprint;
      isCryptographicallySigned = fingerprint != 'Unverified' && fingerprint != 'Pending Key Exchange';
    }

    final aliasController = TextEditingController(
      text: existingContact?.alias ?? 'Peer ${publicId.length > 8 ? publicId.substring(0, 8) : publicId}',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final colors = AppColors.of(modalContext);
        return Container(
          decoration: BoxDecoration(
            color: colors.primaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: colors.hairline, width: 1),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.l,
            right: AppSpacing.l,
            top: AppSpacing.l,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCryptographicallySigned
                          ? colors.accent.withAlpha(25)
                          : colors.hairline.withAlpha(50),
                      border: Border.all(
                        color: isCryptographicallySigned ? colors.accent : colors.hairline,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCryptographicallySigned ? Icons.verified_user : Icons.link,
                          size: 13,
                          color: isCryptographicallySigned ? colors.accent : colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCryptographicallySigned
                              ? 'CRYPTOGRAPHICALLY VERIFIED'
                              : (existingContact != null ? 'EXISTING CONTACT' : 'PEER INVITATION'),
                          style: AppTypography.caption(modalContext).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: isCryptographicallySigned ? colors.accent : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                existingContact != null ? 'VERIFY CONTACT IDENTITY' : 'ADD CONTACT & VERIFY',
                style: AppTypography.title(modalContext).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Verify the peer\'s public identity and safety numbers before initiating end-to-end encrypted sessions.',
                style: AppTypography.caption(modalContext).copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.l),
              // Public ID Box
              Text(
                'PUBLIC ID',
                style: AppTypography.caption(modalContext).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              GhostSurface(
                type: GhostSurfaceType.secondary,
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        publicId,
                        style: AppTypography.body(modalContext).copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: publicId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Public ID copied to clipboard.')),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy, size: 16, color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              // Safety Fingerprint Box
              Text(
                'SAFETY FINGERPRINT',
                style: AppTypography.caption(modalContext).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              GhostSurface(
                type: GhostSurfaceType.secondary,
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Text(
                  fingerprint,
                  style: AppTypography.body(modalContext).copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isCryptographicallySigned ? colors.accent : colors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              // Alias Input
              GhostInput(
                controller: aliasController,
                labelText: 'Contact Alias',
                hintText: 'Enter a name for this contact...',
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'CANCEL',
                      type: GhostButtonType.secondary,
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    flex: 2,
                    child: GhostButton(
                      label: existingContact != null ? 'OPEN CHAT' : 'CONFIRM & ADD',
                      type: GhostButtonType.accent,
                      onPressed: () async {
                        final alias = aliasController.text.trim().isNotEmpty
                            ? aliasController.text.trim()
                            : (existingContact?.alias ?? 'Peer ${publicId.length > 8 ? publicId.substring(0, 8) : publicId}');

                        final updatedContact = Contact(
                          publicId: publicId,
                          alias: alias,
                          eid: package?.eid ?? existingContact?.eid ?? '',
                          xid: package?.xid ?? existingContact?.xid ?? '',
                          fingerprint: fingerprint,
                          createdAt: existingContact?.createdAt ?? DateTime.now(),
                          preferredRelay: package?.relays.isNotEmpty == true
                              ? package!.relays.first
                              : existingContact?.preferredRelay,
                        );

                        await contactService.saveContact(updatedContact);

                        if (modalContext.mounted) {
                          Navigator.pop(modalContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Contact "$alias" verified & added.')),
                          );

                          // Open Conversation
                          final conv = Conversation(
                            contact: updatedContact,
                            contactId: updatedContact.publicId,
                            alias: updatedContact.alias,
                            messages: const [],
                            unreadCount: 0,
                            mode: ConversationMode.normal,
                            lastActivityAt: DateTime.now(),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(conversation: conv),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
