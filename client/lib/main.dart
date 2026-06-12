import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'core/theme/ghost_theme.dart';
import 'core/providers.dart';
import 'design_system/colors.dart';

import 'core/widgets/navigation_shell.dart';
import 'features/home/onboarding_screen.dart';
import 'core/app_initializer.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
class BackgroundRelayManager extends RelayManager {
  final RelayProfile _cachedRelay;
  BackgroundRelayManager(super.storage, this._cachedRelay);

  @override
  Future<RelayProfile?> getActiveRelay() async {
    return _cachedRelay;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['event'] != 'sync_required') {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // STEP 1: Firebase Initialization
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // ignore: avoid_print
  }

  // STEP 2 & 3: Identity & DB Loading from Background Cache
  // ignore: avoid_print
  
  late final Uint8List encryptionKey;
  late final RelayProfile relay;
  late final IdentityService idService;
  late final BackgroundRelayManager relayManager;
  late final SodiumSumo sodium;

  try {
    final cacheFile = await StorageDirectoryHelper.getBackgroundCacheFile();
    if (!await cacheFile.exists()) {
      // ignore: avoid_print
      return;
    }

    final cacheContent = await cacheFile.readAsString();
    final cacheData = jsonDecode(cacheContent);
    final String? hiveKeyBase64 = cacheData['hive_encryption_key'];
    if (hiveKeyBase64 == null) {
      // ignore: avoid_print
      return;
    }
    encryptionKey = base64.decode(hiveKeyBase64);

    relay = RelayProfile(
      id: cacheData['active_relay_id'] ?? 'default',
      label: cacheData['active_relay_label'] ?? 'Default Relay',
      websocketUrl: cacheData['active_relay_websocket_url'] ?? '',
      apiUrl: cacheData['active_relay_api_url'] ?? '',
      token: cacheData['active_relay_token'],
    );

    sodium = await SodiumSumoInit.init();
    await StorageDirectoryHelper.migrateIfNeeded();
    final hiveDir = await StorageDirectoryHelper.getHiveDirectory();
    Hive.init(hiveDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ContactAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MessageAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(MessageTypeAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ConversationModeAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ConversationStateAdapter());

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

    final fcmMessageId = message.data['message_id'];
    final syncBox = Hive.box('sync_metadata');
    if (fcmMessageId != null) {
      await syncBox.put('notified_$fcmMessageId', true);
    }

    final storage = const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true));
    idService = IdentityService(sodium, storage);
    
    // Load identity from cache (bypasses Keystore/SecureStorage)
    final loaded = await idService.loadIdentityFromCache();
    if (!loaded || !idService.hasIdentity) {
      // ignore: avoid_print
      return;
    }

    relayManager = BackgroundRelayManager(storage, relay);
  } catch (e) {
    return;
  }

  final tempContainer = ProviderContainer(
    overrides: [
      sodiumProvider.overrideWithValue(sodium),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true))),
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
  final completer = Completer<void>();
  bool syncSucceeded = false;

  // STEP 4: WebSocket Sync Start
  try {
    wsService.onInboxMessages((messages) async {
      if (messages.isNotEmpty) {
        await chatRepo.processEnvelopes(messages, enableNotification: false);
      }
      syncSucceeded = true;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Connect & Wait for challenge and identity verification
    await relayManager.wakeUpRelay(relay);
    wsService.connect(relay);

    // Complete after 5 seconds timeout as safety
    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
  } catch (_) {
  }

  // STEP 6: Direct HTTP Delivery Receipt Fallback if WebSocket sync failed or timed out
  try {
    final fcmMessageId = message.data['message_id'];
    if (fcmMessageId != null) {
      if (!syncSucceeded) {
        await chatRepo.sendDeliveryReceipt(fcmMessageId);
      }
    }
  } catch (_) {
  }

  try {
    // Grace period: Wait 1.5 seconds to ensure all outgoing TCP packets (such as message ACKs)
    // are fully flushed to the relay server before we close the socket connection.
    await Future.delayed(const Duration(milliseconds: 1500));

    wsService.disconnect();
    tempContainer.dispose();
  } catch (_) {
  }
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      } catch (_) {
        // Ignore
      }
    }
    
    // Memory discipline: limit image cache size to prevent unbounded RAM growth
    PaintingBinding.instance.imageCache.maximumSize = 20;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 10 * 1024 * 1024; // 10MB
    
    // Global Error Handlers
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
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

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const GhostApp(),
      ),
    );
  }, (error, stack) {
    // Ignore
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
        builder: (dialogContext) {
          final dialogColors = AppColors.of(dialogContext);
          return AlertDialog(
            backgroundColor: dialogColors.backgroundSecondary,
            title: const Text('NEW IDENTITY LINK'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('An identity package was shared via deep link.', style: TextStyle(color: dialogColors.textSecondary)),
                const SizedBox(height: 16),
                Text(publicId, style: TextStyle(fontWeight: FontWeight.bold, color: dialogColors.accent)),
                const SizedBox(height: 8),
                Text('Would you like to view and add this contact?', style: TextStyle(fontSize: 12, color: dialogColors.textPrimary)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext), 
                child: Text('CANCEL', style: TextStyle(color: dialogColors.textMuted))
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  processScannedData(context, payload);
                }, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: dialogColors.accent,
                  foregroundColor: dialogColors.backgroundPrimary,
                ),
                child: const Text('ADD CONTACT')
              ),
            ],
          );
        },
      );
    } catch (_) {
      // Ignore
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
        ErrorWidget.builder = (details) => Builder(
          builder: (context) {
            final colors = AppColors.of(context);
            return Scaffold(
              backgroundColor: colors.backgroundPrimary,
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.error, size: 64),
                      const SizedBox(height: 24),
                      Text('CRITICAL UI ERROR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colors.textPrimary)),
                      const SizedBox(height: 16),
                      Text(details.exception.toString(), textAlign: TextAlign.center, style: TextStyle(color: colors.error, fontSize: 12, fontFamily: 'monospace')),
                      if (!kReleaseMode) ...[
                        const SizedBox(height: 16),
                        Text(details.stack.toString(), style: TextStyle(color: colors.textMuted, fontSize: 8, fontFamily: 'monospace')),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.surfaceSecondary,
                          foregroundColor: colors.textPrimary,
                        ),
                        onPressed: () {},
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
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
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundSecondary,
        title: const Text('Identity Warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your identity data was found but couldn\'t be loaded. '
              'Your system keyring might be locked, or data may have been cleared.',
              style: TextStyle(color: colors.textSecondary)
            ),
            const SizedBox(height: 16),
            Text(
              'You can try restarting the app or restore from your 24-word seed phrase.',
              style: TextStyle(color: colors.textMuted, fontSize: 12)
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showResetConfirmDialog();
            },
            child: Text('RESET', style: TextStyle(color: colors.error)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRecoverDialog();
            },
            child: Text('RECOVER', style: TextStyle(color: colors.accent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(appInitializerProvider).status = InitializationStatus.idle;
              _checkInitialization();
            },
            child: Text('RETRY', style: TextStyle(color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showRecoverDialog() {
    final colors = AppColors.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundSecondary,
        title: const Text('RECOVER IDENTITY'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: colors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'Enter your 24-word seed phrase...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('CANCEL', style: TextStyle(color: colors.textMuted)),
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
            child: Text('RESTORE', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundSecondary,
        title: const Text('RESET ALL LOCAL DATA?'),
        content: Text(
          'This action is irreversible. All local contacts, messages, and key rings will be wiped. '
          'You will start fresh as a new installation.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('CANCEL', style: TextStyle(color: colors.textMuted)),
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
            child: Text('RESET', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  void _showInitializationError(String message) {
    final colors = AppColors.of(context);
    final isKeyringError = message.contains('Secure storage') || message.contains('keyring');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(isKeyringError ? 'Identity Found' : 'STARTUP FAILURE'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKeyringError 
                    ? 'Secure storage unavailable' 
                    : 'GhostRoom could not initialize core services.', 
                style: TextStyle(color: colors.textSecondary)
              ),
              const SizedBox(height: 16),
              Text(message, style: TextStyle(color: colors.error, fontSize: 11, fontFamily: 'monospace')),
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
                style: TextStyle(color: colors.error)
              ),
            ),
            if (isKeyringError)
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _showRecoverDialog();
                },
                child: Text('RECOVER', style: TextStyle(color: colors.accent)),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                ref.read(appInitializerProvider).status = InitializationStatus.idle;
                ref.read(appInitializerProvider).initialize(); // Start initialization again
                _checkInitialization(); // Re-run state checking
              },
              child: Text('RETRY', style: TextStyle(color: colors.textPrimary)),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NavigationShell()),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        _showInitializationError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF0A0A0A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset('assets/images/banner.png', height: 120, fit: BoxFit.contain),
            ),
            const SizedBox(height: 64),
            CircularProgressIndicator(color: colors.textMuted.withAlpha(50), strokeWidth: 1),
          ],
        ),
      ),
    );
  }
}
