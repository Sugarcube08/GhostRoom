import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';
import 'core/theme/ghost_theme.dart';
import 'core/providers.dart';
import 'core/widgets/privacy_overlay.dart';
import 'core/widgets/navigation_shell.dart';
import 'features/home/onboarding_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    await Hive.initFlutter();
    
    final sodium = await SodiumSumoInit.init();
    
    final container = ProviderContainer(
      overrides: [
        sodiumProvider.overrideWithValue(sodium),
      ],
    );

    // Pre-initialize services with error handling
    try {
      await container.read(identityServiceProvider).initIdentity();
      await container.read(contactServiceProvider).init();
      await container.read(chatRepositoryProvider).init();
    } catch (e) {
      debugPrint('GHOST_FATAL: Service initialization error: $e');
    }

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const GhostRoomApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('GHOST_CRASH: $error');
    debugPrint(stack.toString());
  });
}

class GhostRoomApp extends ConsumerStatefulWidget {
  const GhostRoomApp({super.key});

  @override
  ConsumerState<GhostRoomApp> createState() => _GhostRoomAppState();
}

class _GhostRoomAppState extends ConsumerState<GhostRoomApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ghost Room',
      theme: GhostTheme.darkTheme,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return PrivacyOverlay(child: child);
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
    _init();
  }

  Future<void> _init() async {
    try {
      debugPrint('GHOST_LOG: SplashScreen checking identity...');
      final idService = ref.read(identityServiceProvider);
      
      // Secondary check for persistence
      if (!idService.hasIdentity) {
        await idService.initIdentity();
      }

      if (!idService.hasIdentity) {
        debugPrint('GHOST_LOG: Identity not found. Navigating to Onboarding.');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
        return;
      }

      // Auto-connect to relay if available
      final relay = await ref.read(activeRelayProvider.future);
      if (relay != null) {
        ref.read(relayManagerProvider).wakeUpRelay(relay);
        final ws = ref.read(webSocketServiceProvider);
        ws.connect(relay);
        
        ws.onInboxMessages((envelopes) {
          ref.read(chatRepositoryProvider).processEnvelopes(envelopes);
        });
      }

      debugPrint('GHOST_LOG: Identity verified. Entering app.');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NavigationShell()),
        );
      }
    } catch (e) {
      debugPrint('GHOST_ERROR: SplashScreen init failed: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
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
