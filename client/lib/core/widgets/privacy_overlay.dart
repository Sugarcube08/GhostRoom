import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import '../security/privacy_protection_service.dart';

class PrivacyOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const PrivacyOverlay({super.key, required this.child});

  @override
  ConsumerState<PrivacyOverlay> createState() => _PrivacyOverlayState();
}

class _PrivacyOverlayState extends ConsumerState<PrivacyOverlay> with WidgetsBindingObserver {
  bool _isPaused = false;
  bool _isBlurred = false;
  StreamSubscription<bool>? _blurSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to desktop blur events
    Future.microtask(() {
      if (!mounted) return;
      _blurSubscription = ref.read(privacyProtectionProvider).onBlurRequested.listen((blur) {
        if (mounted) {
          setState(() => _isBlurred = blur);
        }
      });
    });
  }

  @override
  void dispose() {
    _blurSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isLinux) return;
    if (!mounted) return;
    setState(() {
      _isPaused = state == AppLifecycleState.paused || state == AppLifecycleState.inactive;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return widget.child;
    }
    final showOverlay = _isPaused || _isBlurred;

    return Stack(
      children: [
        widget.child,
        if (showOverlay)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: Colors.black.withAlpha(150),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.security,
                          color: Colors.white24,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'GHOSTROOM PROTECTED',
                          style: TextStyle(
                            color: Colors.white.withAlpha(50),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CONTENT HIDDEN FOR PRIVACY',
                          style: TextStyle(
                            color: Colors.white.withAlpha(30),
                            fontSize: 10,
                            letterSpacing: 2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

