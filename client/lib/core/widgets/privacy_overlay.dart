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
    setState(() {
      _isPaused = state == AppLifecycleState.paused || state == AppLifecycleState.inactive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPaused)
          Container(
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
      ],
    );
  }
}
