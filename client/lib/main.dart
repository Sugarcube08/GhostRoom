import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium.dart';
import 'core/theme/ghost_theme.dart';
import 'core/providers.dart';
import 'core/widgets/privacy_overlay.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final sodium = await SodiumInit.init();

  runApp(
    ProviderScope(
      overrides: [
        sodiumProvider.overrideWithValue(sodium),
      ],
      child: const GhostRoomApp(),
    ),
  );
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op - we keep recent rooms for persistence
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
    debugPrint('GHOST_LOG: SplashScreen initializing...');
    try {
      final relayManager = ref.read(relayManagerProvider);
      await relayManager.clearRecentRooms();
      debugPrint('GHOST_LOG: Recent rooms cleared from storage.');
      ref.invalidate(recentRoomsProvider);
      // Give a tiny moment for the invalidation to propagate
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('GHOST_LOG: Error clearing recent rooms: $e');
    }

    // Initialize identity
    debugPrint('GHOST_LOG: Initializing identity...');
    await ref.read(cryptoServiceProvider).initIdentity();
    debugPrint('GHOST_LOG: Identity initialized.');

    await Future.delayed(const Duration(seconds: 1));
    
    // Auto-connect to active relay if available
    final relay = await ref.read(activeRelayProvider.future);
    final relayManager = ref.read(relayManagerProvider);
    if (relay != null) {
      // Wake up the relay before connecting
      await relayManager.wakeUpRelay(relay);
      
      debugPrint('GHOST_LOG: Auto-connecting to relay: ${relay.label}');
      ref.read(webSocketServiceProvider).connect(relay);
    }

    if (mounted) {
      debugPrint('GHOST_LOG: Navigating to HomeScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep dark background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/banner.png',
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white24, 
              strokeWidth: 1,
            ),
          ],
        ),
      ),
    );
  }
}
