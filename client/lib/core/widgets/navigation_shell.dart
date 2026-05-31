import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/chat_screens.dart';
import '../../features/spaces/anonymous_rooms_screen.dart';
import '../../features/settings/settings_screen.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ChatsScreen(),
    const RequestsScreen(),
    const AnonymousRoomsScreen(),
    const SettingsScreen(),
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
        backgroundColor: const Color(0xFF0A0A0A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white24,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'MESSAGES',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_lock_outlined),
            activeIcon: Icon(Icons.mail_lock),
            label: 'REQUESTS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.blur_on_outlined),
            activeIcon: Icon(Icons.blur_on),
            label: 'ANONYMOUS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'IDENTITY',
          ),
        ],
      ),
    );
  }
}
