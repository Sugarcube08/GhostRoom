import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyProtectionService extends WindowListener {
  final _blurController = StreamController<bool>.broadcast();
  Stream<bool> get onBlurRequested => _blurController.stream;

  bool _isProtectionEnabled = false;

  PrivacyProtectionService() {
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  Future<void> enableScreenshotProtection() async {
    if (!kIsWeb && Platform.isLinux) return;
    if (_isProtectionEnabled) return;
    _isProtectionEnabled = true;

    try {
      // screen_protector handles iOS, Android (FLAG_SECURE), Windows and macOS
      await ScreenProtector.preventScreenshotOn();
      
      debugPrint('GHOST_LOG: Screenshot protection ENABLED');
    } catch (e) {
      debugPrint('GHOST_ERROR: Failed to enable screenshot protection: $e');
    }
  }

  Future<void> disableScreenshotProtection() async {
    if (!kIsWeb && Platform.isLinux) return;
    if (!_isProtectionEnabled) return;
    _isProtectionEnabled = false;

    try {
      await ScreenProtector.preventScreenshotOff();
      
      debugPrint('GHOST_LOG: Screenshot protection DISABLED');
    } catch (e) {
      debugPrint('GHOST_ERROR: Failed to disable screenshot protection: $e');
    }
  }

  // WindowListener overrides for Desktop focus detection
  @override
  void onWindowBlur() {
    debugPrint('GHOST_LOG: Window lost focus - Triggering Privacy Blur');
    _blurController.add(true);
  }

  @override
  void onWindowFocus() {
    debugPrint('GHOST_LOG: Window regained focus - Removing Privacy Blur');
    _blurController.add(false);
  }

  @override
  void onWindowMinimize() {
    _blurController.add(true);
  }

  @override
  void onWindowRestore() {
    _blurController.add(false);
  }

  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    _blurController.close();
  }
}

final privacyProtectionProvider = Provider<PrivacyProtectionService>((ref) {
  final service = PrivacyProtectionService();
  ref.onDispose(() => service.dispose());
  return service;
});
