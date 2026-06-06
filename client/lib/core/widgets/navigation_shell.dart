import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/chat/chat_screens.dart';
import '../../features/spaces/anonymous_rooms_screen.dart';
import '../../features/settings/identity_vault_screen.dart';
import '../../features/contacts/contact_list_screen.dart';
import '../../design_system/colors.dart';
import '../../design_system/components/components.dart';
import '../providers.dart';
import '../network/update_service.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check for updates on a slight delay to not block initial render
    Future.delayed(const Duration(seconds: 2), _checkForUpdates);
  }

  void _checkForUpdates() async {
    if (!mounted) return;
    final updateService = ref.read(updateServiceProvider);
    final manifest = await updateService.checkForUpdate();
    
    if (manifest != null && mounted) {
      _showUpdateDialog(manifest);
    }
  }

  void _showUpdateDialog(UpdateManifest manifest) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).secondaryBackground,
        title: const Text('UPDATE AVAILABLE', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version of GhostRoom (${manifest.version}) is ready.'),
            const SizedBox(height: 16),
            const Text('Download the latest release from GitHub to continue with optimized performance and security.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('LATER', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              // Ensure we use the correct GitHub releases URL from manifest or fallback
              final url = manifest.releaseUrl.isNotEmpty 
                ? manifest.releaseUrl 
                : 'https://github.com/Sugarcube08/GhostRoom/releases';
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).ghostAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('UPDATE NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bool isDesktop = MediaQuery.of(context).size.width > 600;
    final int requestCount = ref.watch(requestCountProvider);

    final List<GhostNavItem> navItems = [
      GhostNavItem(
        outlineIcon: Icons.chat_bubble_outline,
        solidIcon: Icons.chat_bubble,
        label: 'Messages',
        badgeCount: requestCount,
      ),
      const GhostNavItem(
        outlineIcon: Icons.people_outline,
        solidIcon: Icons.people,
        label: 'Contacts',
      ),
      const GhostNavItem(
        outlineIcon: Icons.blur_on_outlined,
        solidIcon: Icons.blur_on,
        label: 'Spaces',
      ),
      const GhostNavItem(
        outlineIcon: Icons.shield_outlined,
        solidIcon: Icons.shield,
        label: 'Vault',
      ),
    ];

    final List<Widget> screens = [
      const ChatsScreen(),
      const ContactListScreen(),
      const AnonymousRoomsScreen(),
      const IdentityVaultScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: colors.primaryBackground,
        body: Row(
          children: [
            GhostNavigationRail(
              items: navItems,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      extendBody: true, // Pushes content behind the bottom nav bar
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: GhostNavigationBar(
            items: navItems,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}
