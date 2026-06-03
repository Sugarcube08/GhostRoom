import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/chat_screens.dart';
import '../../features/spaces/anonymous_rooms_screen.dart';
import '../../features/settings/identity_vault_screen.dart';
import '../../features/contacts/contact_list_screen.dart';
import '../../design_system/colors.dart';
import '../../design_system/components/components.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _currentIndex = 0;

  final List<GhostNavItem> _navItems = const [
    GhostNavItem(
      outlineIcon: Icons.chat_bubble_outline,
      solidIcon: Icons.chat_bubble,
      label: 'Messages',
    ),
    GhostNavItem(
      outlineIcon: Icons.people_outline,
      solidIcon: Icons.people,
      label: 'Contacts',
    ),
    GhostNavItem(
      outlineIcon: Icons.blur_on_outlined,
      solidIcon: Icons.blur_on,
      label: 'Spaces',
    ),
    GhostNavItem(
      outlineIcon: Icons.shield_outlined,
      solidIcon: Icons.shield,
      label: 'Vault',
    ),
  ];

  final List<Widget> _screens = [
    const ChatsScreen(),
    const ContactListScreen(),
    const AnonymousRoomsScreen(),
    const IdentityVaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: colors.primaryBackground,
        body: Row(
          children: [
            GhostNavigationRail(
              items: _navItems,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
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
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: GhostNavigationBar(
            items: _navItems,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}
