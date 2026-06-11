import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'core/theme/ghost_theme.dart';
import 'core/providers.dart';

import 'core/widgets/navigation_shell.dart';
import 'features/home/onboarding_screen.dart';
import 'core/app_initializer.dart';
import 'core/stability_tracker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'dart:convert';
import 'core/crypto/identity_service.dart';
import 'features/contacts/contact_actions.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'features/contacts/contact.dart';
import 'features/chat/message.dart';
import 'features/chat/conversation_state.dart';
import 'core/network/relay_manager.dart';
import 'core/storage/storage_directory_helper.dart';
import 'core/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> ghostRoomBackgroundHandler(RemoteMessage message) async {
  final stopwatch = Stopwatch()..start();
  // ignore: avoid_print
  print("BACKGROUND_HANDLER_STARTED");
  // ignore: avoid_print
  print("FCM_BACKGROUND_HANDLER_ENTERED");
  // ignore: avoid_print
  print("FCM_MESSAGE_DATA=${message.data}");
  debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: START data=${message.data}');

  if (message.data['event'] != 'sync_required') {
    debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: FAILURE error=Ignored non-sync background event (latency: ${stopwatch.elapsedMilliseconds}ms)');
    // ignore: avoid_print
    print("BACKGROUND_HANDLER_FINISHED");
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  
  // Show manual background notification immediately for terminated/killed state
  try {
    final ns = NotificationService();
    await ns.init();
    await ns.showNotification(
      title: 'GhostRoom',
      body: 'New secure message received',
      id: 999,
    );
    // ignore: avoid_print
    print("BACKGROUND_NOTIFICATION_CREATED");
  } catch (e) {
    debugPrint('GHOST_LOG: Failed to create background notification: $e');
  }

  try {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('GHOST_LOG: Firebase.initializeApp() failed or already initialized: $e');
    }

    final sodium = await SodiumSumoInit.init();
    await StorageDirectoryHelper.migrateIfNeeded();
    final hiveDir = await StorageDirectoryHelper.getHiveDirectory();
    Hive.init(hiveDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ContactAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MessageAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(MessageTypeAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ConversationModeAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ConversationStateAdapter());

    final storage = const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true));
    String? existingKey = await storage.read(key: 'hive_encryption_key');
    if (existingKey == null) {
      debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: FAILURE error=No encryption key found (latency: ${stopwatch.elapsedMilliseconds}ms)');
      return;
    }
    final encryptionKey = base64.decode(existingKey);

    // Open Hive boxes
    await Future.wait([
      Hive.openBox<Message>('messages'),
      Hive.openBox<ConversationState>('conversation_states'),
      Hive.openBox('sync_metadata'),
      Hive.openBox('processed_envelopes'),
      Hive.openBox<Contact>('contacts', encryptionCipher: HiveAesCipher(encryptionKey)),
      Hive.openBox<String>('blocked_identities'),
      Hive.openBox<Map>('offline_send_queue'),
      Hive.openBox<bool>('pending_deletions'),
      Hive.openBox<Uint8List>('thumbnail_cache'),
      Hive.openBox<dynamic>('media_cache_index'),
    ]);

    final idService = IdentityService(sodium, storage);
    await idService.initIdentity();
    if (!idService.hasIdentity) {
      debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: FAILURE error=No identity found (latency: ${stopwatch.elapsedMilliseconds}ms)');
      return;
    }

    final relayManager = RelayManager(storage);
    final relay = await relayManager.getActiveRelay();
    if (relay == null) {
      debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: FAILURE error=No active relay (latency: ${stopwatch.elapsedMilliseconds}ms)');
      return;
    }

    final completer = Completer<void>();
    final tempContainer = ProviderContainer(
      overrides: [
        sodiumProvider.overrideWithValue(sodium),
        secureStorageProvider.overrideWithValue(storage),
        identityServiceProvider.overrideWithValue(idService),
        relayManagerProvider.overrideWithValue(relayManager),
      ],
    );

    // Initialize notification service for the background isolate
    final notifService = tempContainer.read(notificationServiceProvider);
    await notifService.init();

    final chatRepo = tempContainer.read(chatRepositoryProvider);
    await chatRepo.init();

    final wsService = tempContainer.read(webSocketServiceProvider);

    wsService.onInboxMessages((messages) async {
      debugPrint('GHOST_LOG: Background sync received messages: ${messages.length}');
      if (messages.isNotEmpty) {
        await chatRepo.processEnvelopes(messages);
      }
      debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: SUCCESS (latency: ${stopwatch.elapsedMilliseconds}ms)');
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Connect & Wait for challenge and identity verification
    await relayManager.wakeUpRelay(relay);
    wsService.connect(relay);

    // Complete after 8 seconds timeout as safety
    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: FAILURE error=Background sync timed out (latency: ${stopwatch.elapsedMilliseconds}ms)');
        completer.complete();
      }
    });

    await completer.future;

    wsService.disconnect();
    tempContainer.dispose();
    debugPrint('GHOST_LOG: Background sync handler finished successfully.');
    // ignore: avoid_print
    print("BACKGROUND_HANDLER_FINISHED");
  } catch (err) {
    debugPrint('GHOST_LOG: FCM_BACKGROUND_WAKEUP: FAILURE error=$err (latency: ${stopwatch.elapsedMilliseconds}ms)');
    // ignore: avoid_print
    print("BACKGROUND_HANDLER_FINISHED");
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(ghostRoomBackgroundHandler);
      } catch (e) {
        debugPrint('GHOST_LOG: Firebase initialization failed: $e');
      }
    }
    
    // Memory discipline: limit image cache size to prevent unbounded RAM growth
    PaintingBinding.instance.imageCache.maximumSize = 20;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 10 * 1024 * 1024; // 10MB
    
    // Global Error Handlers
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('GHOST_FLUTTER_ERROR: ${details.exception}');
      StabilityTracker.logEvent('Flutter_Error', data: {'error': details.exception.toString()});
      if (kDebugMode) {
        print(details.stack);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('GHOST_PLATFORM_ERROR: $error');
      debugPrint(stack.toString());
      StabilityTracker.logEvent('Platform_Error', data: {'error': error.toString()});
      return true; // Error handled
    };

    final sodium = await SodiumSumoInit.init();
    await StorageDirectoryHelper.migrateIfNeeded();
    final hiveDir = await StorageDirectoryHelper.getHiveDirectory();
    Hive.init(hiveDir.path);
    
    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        sodiumProvider.overrideWithValue(sodium),
        appInitializerProvider.overrideWith((ref) => AppInitializer(container)),
      ],
    );

    // Initial kick-off (non-blocking here, SplashScreen handles wait)
    unawaited(container.read(appInitializerProvider).initialize());

    // Periodic Memory Monitor (P0 Stability)
    if (!kReleaseMode) {
      Timer.periodic(const Duration(seconds: 60), (_) {
        StabilityTracker.logMemory('Periodic_Monitor');
        try {
          final cache = PaintingBinding.instance.imageCache;
          debugPrint('GHOST_LOG: IMAGE_CACHE entries=${cache.currentSize} bytes=${cache.currentSizeBytes}');
          debugPrint(
            'GHOST_LOG: ACTIVE_WIDGETS '
            'activeVideoControllers=${StabilityTracker.activeVideoControllers} '
            'activeMediaAttachmentBubbles=${StabilityTracker.activeMediaAttachmentBubbles} '
            'activeFullScreenViews=${StabilityTracker.activeFullScreenViews} '
            'activeVoiceMessageBubbles=${StabilityTracker.activeVoiceMessageBubbles} '
            'activeMemoryImages=${StabilityTracker.activeMemoryImages} '
            'activeConversationScreens=${StabilityTracker.activeConversationScreens}'
          );
        } catch (_) {}
        try {
          container.read(identityServiceProvider).logMemoryUsage();
          container.read(chatRepositoryProvider).logMemoryUsage();
          container.read(mediaManagerProvider).logMemoryUsage();
          container.read(webSocketServiceProvider).logMemoryUsage();
        } catch (e) {
          debugPrint('GHOST_ERROR: Periodic monitor failed to log component memory: $e');
        }
      });
    }

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const GhostApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('GHOST_ZONED_CRASH: $error');
    debugPrint(stack.toString());
    StabilityTracker.logEvent('Zoned_Crash', data: {'error': error.toString()});
  });
}

class GhostApp extends ConsumerStatefulWidget {
  const GhostApp({super.key});

  @override
  ConsumerState<GhostApp> createState() => _GhostAppState();
}

class _GhostAppState extends ConsumerState<GhostApp> with WidgetsBindingObserver, ContactActions {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    
    // Check for initial link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('GHOST_LOG: Handling deep link: $uri');
    if (uri.scheme == 'ghostroom' && uri.host == 'identity') {
      final payload = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (payload != null) {
        // Find the current navigator state and show a preview dialog
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Future.microtask(() {
            if (context.mounted) _showDeepLinkPreview(context, payload);
          });
        }
      }
    }
  }

  void _showDeepLinkPreview(BuildContext context, String payload) {
    try {
      final pkg = IdentityPackage.fromEncodedString(payload);
      final idService = ref.read(identityServiceProvider);
      final eidBytes = base64Decode(pkg.eid);
      final publicId = idService.derivePublicId(eidBytes);

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text('NEW IDENTITY LINK'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('An identity package was shared via deep link.', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              Text(publicId, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 8),
              const Text('Would you like to view and add this contact?', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                processScannedData(context, payload);
              }, 
              child: const Text('ADD CONTACT')
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('GHOST_ERROR: Failed to parse deep link payload: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    StabilityTracker.logEvent('System_Memory_Pressure');
    debugPrint('GHOST_WARNING: System reporting memory pressure!');
    // Clear image cache on memory pressure
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Ghost Room',
      theme: GhostTheme.lightTheme,
      darkTheme: GhostTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        
        // Add a global error widget
        ErrorWidget.builder = (details) => Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 24),
                  const Text('CRITICAL UI ERROR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  const SizedBox(height: 16),
                  Text(details.exception.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace')),
                  if (!kReleaseMode) ...[
                    const SizedBox(height: 16),
                    Text(details.stack.toString(), style: const TextStyle(color: Colors.white24, fontSize: 8, fontFamily: 'monospace')),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    onPressed: () => debugPrint('Retry or Restart logic here'),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        );

        return child;
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    final initializer = ref.read(appInitializerProvider);
    
    // Wait for initializer to finish if it's already running
    while (initializer.status == InitializationStatus.initializing || 
           initializer.status == InitializationStatus.idle) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    if (initializer.status == InitializationStatus.failure) {
      _showInitializationError(initializer.errorMessage ?? 'Unknown fatal error during startup.');
      return;
    }

    final idService = ref.read(identityServiceProvider);
    if (!idService.hasIdentity) {
      // Check if we should have had an identity
      final flagFile = await StorageDirectoryHelper.getIdentityFlagFile();
      if (await flagFile.exists()) {
        if (mounted) {
          _showIdentityMissingDialog();
        }
        return;
      }
    }

    // Initialization success, proceed to identity check
    _proceedToApp();
  }

  void _showIdentityMissingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Identity Warning'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your identity data was found but couldn\'t be loaded. '
              'Your system keyring might be locked, or data may have been cleared.',
              style: TextStyle(color: Colors.white70)
            ),
            SizedBox(height: 16),
            Text(
              'You can try restarting the app or restore from your 24-word seed phrase.',
              style: TextStyle(color: Colors.white54, fontSize: 12)
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showResetConfirmDialog();
            },
            child: const Text('RESET', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRecoverDialog();
            },
            child: const Text('RECOVER'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(appInitializerProvider).status = InitializationStatus.idle;
              _checkInitialization();
            },
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  void _showRecoverDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('RECOVER IDENTITY'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'Enter your 24-word seed phrase...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final seed = controller.text.trim();
              if (seed.isEmpty) return;
              try {
                final idService = ref.read(identityServiceProvider);
                final appInit = ref.read(appInitializerProvider);

                await idService.restoreIdentity(seed);
                if (!context.mounted) return;
                
                Navigator.pop(dialogContext); // Close recovery dialog
                appInit.status = InitializationStatus.idle;
                await appInit.initialize();
                
                if (!mounted) return;
                _checkInitialization();
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Recovery failed: $e')),
                );
              }
            },
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('RESET ALL LOCAL DATA?'),
        content: const Text(
          'This action is irreversible. All local contacts, messages, and key rings will be wiped. '
          'You will start fresh as a new installation.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final idService = ref.read(identityServiceProvider);
              final contactService = ref.read(contactServiceProvider);
              final chatRepo = ref.read(chatRepositoryProvider);
              final relayManager = ref.read(relayManagerProvider);
              final appInit = ref.read(appInitializerProvider);

              Navigator.pop(dialogContext); // Close confirm
              
              // Wipe local DBs & Secure Storage
              await idService.wipeIdentity();
              await contactService.clearAll();
              await chatRepo.dangerouslyClearAll();
              await relayManager.panicWipe();
              
              // Reset status & re-run initialization
              appInit.status = InitializationStatus.idle;
              await appInit.initialize();
              
              if (!mounted) return;
              _checkInitialization();
            },
            child: const Text('RESET', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showInitializationError(String message) {
    final isKeyringError = message.contains('Secure storage') || message.contains('keyring');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(isKeyringError ? 'Identity Found' : 'STARTUP FAILURE'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKeyringError 
                    ? 'Secure storage unavailable' 
                    : 'GhostRoom could not initialize core services.', 
                style: const TextStyle(color: Colors.white70)
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _showResetConfirmDialog();
              },
              child: Text(
                isKeyringError ? 'RESET IDENTITY' : 'WIPE DATA', 
                style: const TextStyle(color: Colors.redAccent)
              ),
            ),
            if (isKeyringError)
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _showRecoverDialog();
                },
                child: const Text('RECOVER'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                ref.read(appInitializerProvider).status = InitializationStatus.idle;
                ref.read(appInitializerProvider).initialize(); // Start initialization again
                _checkInitialization(); // Re-run state checking
              },
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _proceedToApp() async {
    try {
      final idService = ref.read(identityServiceProvider);
      
      if (!idService.hasIdentity) {
        debugPrint('GHOST_LOG: Identity not found. Navigating to Onboarding.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            );
          }
        });
        return;
      }

      // Auto-connect to relay if available
      final activeRelayFuture = ref.read(activeRelayProvider.future);
      final relayManager = ref.read(relayManagerProvider);
      final wsService = ref.read(webSocketServiceProvider);

      final relay = await activeRelayFuture;
      if (mounted && relay != null) {
        relayManager.wakeUpRelay(relay);
        wsService.connect(relay);
        // Listeners are now handled by ChatRepository
      }

      if (!mounted) return;
      debugPrint('GHOST_LOG: Identity verified. Entering app.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NavigationShell()),
          );
        }
      });
    } catch (e) {
      debugPrint('GHOST_ERROR: SplashScreen proceed failed: $e');
      if (mounted) {
        _showInitializationError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/banner.png', height: 120, fit: BoxFit.contain),
            const SizedBox(height: 64),
            const CircularProgressIndicator(color: Colors.white10, strokeWidth: 1),
          ],
        ),
      ),
    );
  }
}
