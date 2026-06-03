import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/providers.dart';
import '../chat/chat_screen.dart';
import '../invite/invite_screen.dart';
import '../spaces/space_service.dart';
import '../contacts/contact_actions.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sodium/sodium.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';
import '../../design_system/spacing.dart';
import '../../design_system/components/components.dart';

class AnonymousRoomsScreen extends ConsumerWidget {
  const AnonymousRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRelay = ref.watch(activeRelayProvider);
    final recentRooms = ref.watch(recentRoomsProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPACES',
                      style: AppTypography.hero(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Temporary. Anonymous. Zero Footprint.',
                      style: AppTypography.secondary(context).copyWith(
                        color: colors.secondaryText.withAlpha(100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: _buildIntro(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.xl, AppSpacing.l, AppSpacing.m),
                child: Text(
                  'CREATE NEW SPACE',
                  style: AppTypography.caption(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.secondaryText.withAlpha(80),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: _buildCreationCards(context, ref, activeRelay.value != null),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.xl, AppSpacing.l, AppSpacing.m),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT SPACES',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.secondaryText.withAlpha(80),
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showJoinOptions(context, ref),
                      child: Text(
                        'JOIN VIA INVITE',
                        style: AppTypography.caption(context).copyWith(
                          color: colors.ghostAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: _buildRecentRooms(recentRooms, context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final colors = AppColors.of(context);
    return GhostSurface(
      type: GhostSurfaceType.secondary,
      padding: const EdgeInsets.all(AppSpacing.l),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.ghostAccent.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.blur_on, size: 24, color: colors.ghostAccent),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  'Disposable collaborative areas.',
                  style: AppTypography.section(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Spaces use symmetric encryption and temporary storage. No identities are used. Once a space expires, it is gone forever.',
            style: AppTypography.caption(context).copyWith(
              color: colors.secondaryText.withAlpha(100),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreationCards(BuildContext context, WidgetRef ref, bool enabled) {
    return Row(
      children: [
        _DurationCard(
          label: 'SHORT',
          duration: '30 MIN',
          icon: Icons.timer_outlined,
          enabled: enabled,
          onTap: () => _createSpace(context, ref, 1800),
        ),
        const SizedBox(width: AppSpacing.m),
        _DurationCard(
          label: 'STANDARD',
          duration: '2 HR',
          icon: Icons.schedule,
          enabled: enabled,
          onTap: () => _createSpace(context, ref, 7200),
        ),
        const SizedBox(width: AppSpacing.m),
        _DurationCard(
          label: 'LONG',
          duration: '24 HR',
          icon: Icons.event_available,
          enabled: enabled,
          onTap: () => _createSpace(context, ref, 86400),
        ),
      ],
    );
  }

  Widget _buildRecentRooms(AsyncValue recentAsync, BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return recentAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Text('No recent spaces found', style: TextStyle(color: Colors.white10, fontSize: 12)))));
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final room = rooms[index];
              return GhostCard(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                type: GhostSurfaceType.secondary,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history, color: colors.secondaryText.withAlpha(50), size: 20),
                  title: Text(
                    'Space ${room['roomId'].toString().substring(0, 8).toUpperCase()}',
                    style: AppTypography.body(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Temporary Session', style: AppTypography.caption(context).copyWith(color: colors.secondaryText.withAlpha(80))),
                  trailing: Icon(Icons.chevron_right, size: 16, color: colors.secondaryText.withAlpha(50)),
                  onTap: () => _handleManualJoin(context, ref, room['roomId'], room['key']),
                ),
              );
            },
            childCount: rooms.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  // Same logic for space creation and joining...
  void _createSpace(BuildContext context, WidgetRef ref, int seconds) async {
    final activeRelayFuture = ref.read(activeRelayProvider.future);
    final spaceService = ref.read(spaceServiceProvider);
    final relayManager = ref.read(relayManagerProvider);
    final relay = await activeRelayFuture;
    if (relay == null) return;
    try {
      final config = await spaceService.createSpace(relay, expirySeconds: seconds);
      await relayManager.addRecentRoom(config.roomId, base64Encode(config.roomKey.extractBytes()), relay.label);
      if (context.mounted) {
        ref.invalidate(recentRoomsProvider);
        _showSpaceCreatedOptions(context, config);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSpaceCreatedOptions(BuildContext context, SpaceConfig config) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.secondaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.qr_code), title: const Text('SHOW INVITE QR'), onTap: () { Navigator.pop(sheetContext); Navigator.push(context, MaterialPageRoute(builder: (_) => InviteScreen(config: config))); }),
            ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('ENTER SPACE'), onTap: () { Navigator.pop(sheetContext); Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(config: config))); }),
          ],
        ),
      ),
    );
  }

  void _showJoinOptions(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.secondaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text('SCAN QR CODE'), onTap: () { Navigator.pop(sheetContext); _joinSpace(context, ref); }),
            ListTile(leading: const Icon(Icons.image_outlined), title: const Text('SELECT FROM GALLERY'), onTap: () { Navigator.pop(sheetContext); _joinFromGallery(context, ref); }),
            ListTile(leading: const Icon(Icons.link), title: const Text('ENTER LINK MANUALLY'), onTap: () { Navigator.pop(sheetContext); _showManualEntry(context, ref); }),
          ],
        ),
      ),
    );
  }

  void _joinSpace(BuildContext context, WidgetRef ref) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;
    if (!context.mounted) return;
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
    if (code != null && code.startsWith('ghost://room/') && context.mounted) await _handleInviteLink(context, ref, code);
  }

  void _joinFromGallery(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final scanner = MobileScannerController();
    try {
      final capture = await scanner.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final code = capture.barcodes.first.rawValue;
        if (code != null && code.startsWith('ghost://room/') && context.mounted) await _handleInviteLink(context, ref, code);
      }
    } catch (_) {} finally { scanner.dispose(); }
  }

  void _showManualEntry(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.secondaryBackground,
        title: const Text('Join Space'),
        content: GhostInput(controller: controller, hintText: 'Paste ghost://room/... link'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () async { final link = controller.text; if (link.startsWith('ghost://room/')) { Navigator.pop(dialogContext); await _handleInviteLink(context, ref, link); } }, child: const Text('Join')),
        ],
      ),
    );
  }

  Future<void> _handleInviteLink(BuildContext context, WidgetRef ref, String link) async {
    try {
      final uri = Uri.parse(link.replaceFirst('ghost://', 'http://'));
      final roomId = uri.pathSegments.last;
      final rawKey = uri.queryParameters['key'];
      if (rawKey == null) return;
      final keyBase64 = rawKey.trim().replaceAll(" ", "+");
      final sodium = ref.read(sodiumProvider);
      final keyBytes = base64Decode(keyBase64);
      SecureKey.fromList(sodium, keyBytes);
      final activeRelay = ref.read(activeRelayProvider).value;
      final relayManager = ref.read(relayManagerProvider);
      await relayManager.addRecentRoom(roomId, keyBase64, activeRelay?.label ?? 'Joined Relay');
      if (context.mounted) { ref.invalidate(recentRoomsProvider); _handleManualJoin(context, ref, roomId, keyBase64); }
    } catch (_) {}
  }

  void _handleManualJoin(BuildContext context, WidgetRef ref, String roomId, String keyBase64) {
    try {
      final sodium = ref.read(sodiumProvider);
      final keyBytes = base64Decode(keyBase64.trim().replaceAll(" ", "+"));
      final roomKey = SecureKey.fromList(sodium, keyBytes);
      final config = SpaceConfig(roomId: roomId, roomKey: roomKey, expiry: DateTime.now().add(const Duration(hours: 2)));
      if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(config: config)));
    } catch (_) {}
  }
}

class _DurationCard extends StatelessWidget {
  final String label;
  final String duration;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DurationCard({
    required this.label,
    required this.duration,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GhostCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        type: GhostSurfaceType.secondary,
        borderRadius: BorderRadius.circular(20),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Column(
            children: [
              Icon(icon, size: 28, color: colors.ghostAccent.withAlpha(150)),
              const SizedBox(height: 12),
              Text(
                label,
                style: AppTypography.caption(context).copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: colors.secondaryText.withAlpha(100),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                duration,
                style: AppTypography.section(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
