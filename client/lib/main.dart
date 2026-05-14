import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium.dart';
import 'core/theme/veil_theme.dart';
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
      child: const VeilApp(),
    ),
  );
}

class VeilApp extends ConsumerWidget {
  const VeilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Veil',
      theme: VeilTheme.darkTheme,
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
              'VEIL',
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
