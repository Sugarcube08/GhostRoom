import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class StabilityTracker {
  static final Logger _logger = Logger();
  static final Stopwatch _uptime = Stopwatch()..start();

  // Static counters for active controllers/widgets (forensics)
  static int activeVideoControllers = 0;
  static int activeMediaAttachmentBubbles = 0;
  static int activeFullScreenViews = 0;
  static int activeVoiceMessageBubbles = 0;
  static int activeMemoryImages = 0;

  static void logMemory(String point) {
    if (kReleaseMode) return;
    
    final rss = ProcessInfo.currentRss / (1024 * 1024);
    _logger.i('STABILITY_CHECK [$point] - Uptime: ${_uptime.elapsed.inSeconds}s - RAM: ${rss.toStringAsFixed(2)} MB');
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
