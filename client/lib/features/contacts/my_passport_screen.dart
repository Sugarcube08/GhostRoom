import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers.dart';
import '../../core/crypto/identity_service.dart';
import '../settings/identity_actions.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';

class MyPassportScreen extends ConsumerStatefulWidget {
  const MyPassportScreen({super.key});

  @override
  ConsumerState<MyPassportScreen> createState() => _MyPassportScreenState();
}

class _MyPassportScreenState extends ConsumerState<MyPassportScreen> with IdentityActions {
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
    final idService = ref.watch(identityServiceProvider);
    final identity = idService.currentIdentity;
    final colors = AppColors.of(context);

    if (identity == null) {
      return Scaffold(
        backgroundColor: colors.primaryBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: AppBar(
        title: const Text('DIGITAL PASSPORT'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.l),
              FutureBuilder<IdentityPackage>(
                future: idService.createPackage([]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final pkgString = snapshot.data!.toEncodedString();
                  return Column(
                    children: [
                      RepaintBoundary(
                        key: _qrKey,
                        child: GhostSurface(
                          type: GhostSurfaceType.elevated,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          borderRadius: BorderRadius.circular(32),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.m),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: QrImageView(
                                  data: pkgString,
                                  version: QrVersions.auto,
                                  size: 200,
                                  gapless: false,
                                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                identity.publicId,
                                textAlign: TextAlign.center,
                                style: AppTypography.section(context).copyWith(
                                  fontFamily: 'monospace',
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s),
                              Text(
                                'GHOSTROOM ID',
                                style: AppTypography.caption(context).copyWith(
                                  color: colors.ghostAccent,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildInfoSection(
                        context,
                        'SAFETY FINGERPRINT',
                        identity.fingerprint,
                        isMonospace: true,
                      ),
                      const SizedBox(height: AppSpacing.l),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                        child: Text(
                          'Scan this passport to establish a secure, end-to-end encrypted channel. Your identity is local and sovereign.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white38, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      Row(
                        children: [
                          Expanded(
                            child: GhostButton(
                              label: 'DOWNLOAD',
                              icon: Icons.download,
                              type: GhostButtonType.secondary,
                              onPressed: () => _saveQRToGallery(identity.publicId),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: GhostButton(
                              label: 'SHARE LINK',
                              icon: Icons.share,
                              type: GhostButtonType.primary,
                              onPressed: () => shareIdentity(ref),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String label, String value, {bool isMonospace = false}) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colors.secondaryText.withAlpha(100),
            ),
          ),
        ),
        GhostSurface(
          type: GhostSurfaceType.secondary,
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Text(
            value,
            style: AppTypography.body(context).copyWith(
              fontFamily: isMonospace ? 'monospace' : null,
              fontWeight: isMonospace ? FontWeight.bold : null,
              fontSize: isMonospace ? 12 : null,
              color: colors.primaryText.withAlpha(200),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
