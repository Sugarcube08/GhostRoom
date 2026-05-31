import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/chat_screens.dart';
import '../../features/spaces/anonymous_rooms_screen.dart';
import '../../features/settings/identity_vault_screen.dart';
import '../../features/contacts/contact_list_screen.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ChatsScreen(),
    const ContactListScreen(),
    const AnonymousRoomsScreen(),
    const IdentityVaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF080808),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white24,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'MESSAGES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'CONTACTS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.blur_on_outlined),
            activeIcon: Icon(Icons.blur_on),
            label: 'SPACES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'VAULT',
          ),
        ],
      ),
    );
  }
}
