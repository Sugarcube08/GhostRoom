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
import '../../features/chat/conversation_screen.dart';
import '../../features/chat/requests_screen.dart';
import '../../features/chat/conversation_service.dart';
import '../../main.dart' show navigatorKey;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dart:io';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _currentIndex = 0;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Check for updates on a slight delay to not block initial render
    _updateTimer = Timer(const Duration(seconds: 2), _checkForUpdates);
    
    // Initialize FCM and notifications
    _initFcmAndNotifications();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _tokenRefreshSubscription?.cancel();
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    super.dispose();
  }

  void _initFcmAndNotifications() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    final notifService = ref.read(notificationServiceProvider);
    notifService.init().then((_) {
    }).catchError((e) {
    });

    notifService.onNotificationTap = (payload) {
      if (payload == null) return;

      if (payload == 'requests') {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => const RequestsScreen(),
        ));
      } else {
        final convService = ref.read(conversationServiceProvider);
        final convs = convService.getConversations();
        var targetConv = convs.where((c) => c.contactId == payload).firstOrNull;

        if (targetConv == null) {
          final contactService = ref.read(contactServiceProvider);
          final contact = contactService.getContact(payload);
          targetConv = Conversation(
            contact: contact,
            contactId: payload,
            alias: contact?.alias ?? 'Secure Contact',
            messages: [],
            lastActivityAt: DateTime.now(),
          );
        }

        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => ConversationScreen(conversation: targetConv!),
        ));
      }
    };

    // Token registration & refresh
    FirebaseMessaging.instance.requestPermission().then((settings) {
      FirebaseMessaging.instance.getToken().then((token) {
        if (token != null) {
          ref.read(chatRepositoryProvider).registerDeviceToken(token);
        }
      }).catchError((_) {
        // Ignore
      });
    }).catchError((_) {
      // Ignore
    });

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      ref.read(chatRepositoryProvider).registerDeviceToken(token);
    }, onError: (_) {
      // Ignore
    });

    _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
      // ignore: avoid_print
      if (message.data['event'] == 'sync_required') {
        ref.read(chatRepositoryProvider).sync();
      }
    });

    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // ignore: avoid_print
      ref.read(chatRepositoryProvider).sync();
    });
  }

  void _checkForUpdates() async {
    if (!mounted) return;
    final updateService = ref.read(updateServiceProvider);
    final manifest = await updateService.checkForUpdate();
    
    if (manifest != null && mounted) {
      final syncBox = Hive.box('sync_metadata');
      final dismissedVersion = syncBox.get('dismissed_update_version') as String?;
      if (dismissedVersion == manifest.version) {
        return; // Already dismissed this version
      }

      // ignore: avoid_print
      // ignore: avoid_print
      _showUpdateDialog(manifest);
    }
  }

  void _showUpdateDialog(UpdateManifest manifest) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).backgroundSecondary,
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
            onPressed: () {
              Hive.box('sync_metadata').put('dismissed_update_version', manifest.version);
              Navigator.pop(context);
            },
            child: Text('LATER', style: TextStyle(color: AppColors.of(context).textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              var version = manifest.version.trim();
              if (!version.toLowerCase().startsWith('v')) {
                version = 'v$version';
              }
              final url = 'https://github.com/Sugarcube08/GhostRoom/releases/tag/$version';
              
              // ignore: avoid_print
              // ignore: avoid_print
              try {
                final success = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                if (success) {
                  // ignore: avoid_print
                } else {
                  // ignore: avoid_print
                  // ignore: avoid_print
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to open the update link automatically. Please visit github.com/Sugarcube08/GhostRoom to update.')),
                    );
                  }
                }
              } catch (e) {
                // ignore: avoid_print
                // ignore: avoid_print
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not launch browser: $e')),
                  );
                }
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).accent,
              foregroundColor: AppColors.of(context).backgroundPrimary,
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
