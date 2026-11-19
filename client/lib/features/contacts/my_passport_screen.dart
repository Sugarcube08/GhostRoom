import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

    final connectUrl = getConnectUrl(identity.publicId);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: AppBar(
        title: const Text('DIGITAL PASSPORT'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth > 500 ? 500 : constraints.maxWidth;
          final bool isNarrow = constraints.maxWidth < 360;

          return SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.l),
                    FutureBuilder<IdentityPackage>(
                      future: idService.createPackage([]),
                      builder: (context, snapshot) {
                        return Column(
                          children: [
                            RepaintBoundary(
                              key: _qrKey,
                              child: GhostSurface(
                                type: GhostSurfaceType.elevated,
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(AppSpacing.m),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: QrImageView(
                                        data: connectUrl,
                                        version: QrVersions.auto,
                                        size: isNarrow ? 170 : 210,
                                        gapless: false,
                                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SelectableText(
                                        identity.publicId,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.section(context).copyWith(
                                          fontFamily: 'monospace',
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.s),
                                    Text(
                                      'PUBLIC IDENTITY ID',
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
                              'SHAREABLE CONNECT URL',
                              connectUrl,
                              isMonospace: true,
                              onCopy: () => copyConnectUrl(context, identity.publicId),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            _buildInfoSection(
                              context,
                              'SAFETY FINGERPRINT',
                              identity.fingerprint,
                              isMonospace: true,
                              onCopy: () {
                                Clipboard.setData(ClipboardData(text: identity.fingerprint));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Safety fingerprint copied to clipboard.')),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.l),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                              child: Text(
                                'Anyone with this link or QR code can securely initiate an end-to-end encrypted channel with you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: colors.textMuted, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.l),
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GhostButton(
                                    label: 'COPY LINK',
                                    icon: Icons.copy,
                                    type: GhostButtonType.secondary,
                                    onPressed: () => copyConnectUrl(context, identity.publicId),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.m),
                                Expanded(
                                  child: GhostButton(
                                    label: 'SHARE LINK',
                                    icon: Icons.share,
                                    type: GhostButtonType.accent,
                                    onPressed: () => shareIdentity(ref),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.m),
                            GhostButton(
                              label: 'DOWNLOAD QR PASSPORT',
                              icon: Icons.download,
                              type: GhostButtonType.secondary,
                              width: double.infinity,
                              onPressed: () => _saveQRToGallery(identity.publicId),
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
        },
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String label,
    String value, {
    bool isMonospace = false,
    VoidCallback? onCopy,
  }) {
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.m),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.body(context).copyWith(
                    fontFamily: isMonospace ? 'monospace' : null,
                    fontWeight: isMonospace ? FontWeight.bold : null,
                    fontSize: isMonospace ? 12 : null,
                    color: colors.primaryText.withAlpha(220),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 16, color: colors.ghostAccent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
