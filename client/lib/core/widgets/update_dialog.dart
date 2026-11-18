import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design_system/colors.dart';
import '../theme/brand_assets.dart';
import '../network/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateManifest manifest;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.manifest,
    required this.updateService,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateManifest manifest,
    required UpdateService updateService,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        manifest: manifest,
        updateService: updateService,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateStatus _status = UpdateStatus.available;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;
  PlatformAsset? _selectedAsset;

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.manifest.getAssetForCurrentPlatform();
  }

  void _startUpdate() async {
    setState(() {
      _status = UpdateStatus.downloading;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Connecting to release server...';
    });

    try {
      await widget.updateService.runAutoUpdate(
        manifest: widget.manifest,
        customAsset: _selectedAsset,
        onStatus: (status, progress, message) {
          if (!mounted) return;
          setState(() {
            _status = status;
            _progress = progress;
            _statusMessage = message;
          });
        },
      );

      if (mounted) {
        setState(() {
          _status = UpdateStatus.completed;
          _statusMessage =
              'Installation triggered. Complete setup in system installer.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = UpdateStatus.error;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  void _fallbackToBrowser() async {
    final uri = Uri.parse(widget.manifest.releaseUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final availableAssets =
        widget.manifest.getAvailableAssetsForCurrentPlatform();
    final activeAsset = _selectedAsset ??
        (availableAssets.isNotEmpty
            ? availableAssets.first
            : widget.manifest.getAssetForCurrentPlatform());

    return AlertDialog(
      backgroundColor: colors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderPrimary),
      ),
      icon: const GhostRoomMark(size: 38),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'UPDATE AVAILABLE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version and platform pill
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.accent.withAlpha(80)),
                  ),
                  child: Text(
                    'v${widget.manifest.version}',
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeAsset?.displayName ??
                        widget.manifest.targetPlatformName,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Package Format Selector (when multiple formats are available and in available state)
            if (availableAssets.length > 1 &&
                _status == UpdateStatus.available) ...[
              Text(
                'Release Package Format:',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderPrimary),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PlatformAsset>(
                    value: availableAssets.contains(_selectedAsset)
                        ? _selectedAsset
                        : availableAssets.first,
                    isExpanded: true,
                    dropdownColor: colors.backgroundSecondary,
                    items: availableAssets.map((asset) {
                      return DropdownMenuItem<PlatformAsset>(
                        value: asset,
                        child: Text(
                          '${asset.displayName} (${asset.formattedSize})',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (selected) {
                      if (selected != null) {
                        setState(() => _selectedAsset = selected);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Changelog or description
            if (widget.manifest.changelog != null &&
                widget.manifest.changelog!.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderPrimary),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.manifest.changelog!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Text(
                'A newer version of GhostRoom is ready with critical security, protocol, and stability enhancements.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
            ],

            // Active progress indicators
            if (_status == UpdateStatus.downloading ||
                _status == UpdateStatus.verifying ||
                _status == UpdateStatus.installing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: colors.backgroundPrimary,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ] else if (_status == UpdateStatus.completed) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.success.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.success.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: colors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(color: colors.success, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_status == UpdateStatus.error) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.error.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Update failed',
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (activeAsset != null && activeAsset.sha256.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 14, color: colors.success),
                    const SizedBox(width: 4),
                    Text(
                      'SHA-256 Verified Release (${activeAsset.formattedSize})',
                      style: TextStyle(color: colors.success, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
      actions: [
        if (_status != UpdateStatus.downloading &&
            _status != UpdateStatus.verifying &&
            _status != UpdateStatus.installing) ...[
          TextButton(
            onPressed: () {
              Hive.box('sync_metadata')
                  .put('dismissed_update_version', widget.manifest.version);
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: Text('LATER', style: TextStyle(color: colors.textMuted)),
          ),
        ],
        if (_status == UpdateStatus.error) ...[
          TextButton(
            onPressed: _fallbackToBrowser,
            child: const Text('OPEN IN BROWSER'),
          ),
          ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.backgroundPrimary,
            ),
            child: const Text('RETRY'),
          ),
        ] else if (_status == UpdateStatus.completed) ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.success,
              foregroundColor: colors.backgroundPrimary,
            ),
            child: const Text('DONE'),
          ),
        ] else if (_status == UpdateStatus.available) ...[
          ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.backgroundPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('UPDATE NOW',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
