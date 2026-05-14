import 'package:flutter/material.dart';

class PrivacyOverlay extends StatefulWidget {
  final Widget child;

  const PrivacyOverlay({super.key, required this.child});

  @override
  State<PrivacyOverlay> createState() => _PrivacyOverlayState();
}

class _PrivacyOverlayState extends State<PrivacyOverlay> with WidgetsBindingObserver {
  bool _isPaused = false;

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
    print('GHOST_LOG: PrivacyOverlay lifecycle state changed to: $state');
    setState(() {
      // Inactive can happen during navigation transitions on some devices, 
      // or when a system dialog is shown. We only want to hide when fully backgrounded.
      _isPaused = state == AppLifecycleState.paused;
    });
    print('GHOST_LOG: PrivacyOverlay _isPaused: $_isPaused');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPaused)
          GestureDetector(
            onTap: () => print('GHOST_LOG: PrivacyOverlay tap intercepted (app paused)'),
            child: Container(
              color: Colors.black,
              child: const Center(
                child: Text(
                  'GHOST ROOM',
                  style: TextStyle(
                    color: Colors.white12,
                    fontSize: 32,
                    letterSpacing: 10,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
