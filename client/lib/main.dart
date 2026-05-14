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
    if (state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
       // Clear recent rooms when app is closed/detached
       ref.read(relayManagerProvider).clearRecentRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ghost Room',
      theme: GhostTheme.darkTheme,
      builder: (context, child) => PrivacyOverlay(child: child!),
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
    // Initialize identity
    await ref.read(cryptoServiceProvider).initIdentity();

    await Future.delayed(const Duration(seconds: 2));
    
    // Auto-connect to active relay if available
    final relay = await ref.read(activeRelayProvider.future);
    if (relay != null) {
      ref.read(webSocketServiceProvider).connect(relay);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GHOST ROOM',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w100,
                letterSpacing: 8.0,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white, strokeWidth: 1),
          ],
        ),
      ),
    );
  }
}
