import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class StabilityTracker {
  static final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.info,
  );
  static final Stopwatch _uptime = Stopwatch()..start();

  // Static counters for active controllers/widgets (forensics)
  static int activeVideoControllers = 0;
  static int activeMediaAttachmentBubbles = 0;
  static int activeFullScreenViews = 0;
  static int activeVoiceMessageBubbles = 0;
  static int activeMemoryImages = 0;
  static int activeConversationScreens = 0;

  static void logMemory(String point) {
    if (kReleaseMode) return;
    
    final rss = ProcessInfo.currentRss / (1024 * 1024);
    String extra = '';
    
    if (Platform.isLinux) {
      try {
        final file = File('/proc/self/smaps_rollup');
        if (file.existsSync()) {
          final lines = file.readAsLinesSync();
          int privateDirty = 0;
          int sharedDirty = 0;
          int pss = 0;
          for (final line in lines) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final key = parts[0].replaceAll(':', '').toLowerCase();
              final val = int.tryParse(parts[1]) ?? 0;
              if (key == 'private_dirty') {
                privateDirty = val;
              } else if (key == 'shared_dirty') {
                sharedDirty = val;
              } else if (key == 'pss') {
                pss = val;
              }
            }
          }
          extra = ' - PSS: ${(pss / 1024).toStringAsFixed(2)} MB - PrivateDirty: ${(privateDirty / 1024).toStringAsFixed(2)} MB - SharedDirty: ${(sharedDirty / 1024).toStringAsFixed(2)} MB';
        }
      } catch (_) {}
    }
    
    _logger.i('STABILITY_CHECK [$point] - Uptime: ${_uptime.elapsed.inSeconds}s - RAM: ${rss.toStringAsFixed(2)} MB$extra');
  }

  static void logEvent(String event, {Map<String, dynamic>? data}) {
    if (kReleaseMode) return;
    _logger.d('STABILITY_EVENT: $event ${data ?? ""}');
  }

  static void logResource(String type, String action) {
    if (kReleaseMode) return;
    _logger.d('RESOURCE: $type -> $action');
  }

  static void logComponentDiagnostics(String componentName, Map<String, dynamic> stats) {
    if (kReleaseMode) return;
    _logger.i('COMPONENT_STATS [$componentName] - Uptime: ${_uptime.elapsed.inSeconds}s - Stats: $stats');
  }
}
