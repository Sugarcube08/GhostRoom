import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class StabilityTracker {
  static final Logger _logger = Logger();
  static final Stopwatch _uptime = Stopwatch()..start();

  static void logMemory(String point) {
    if (kReleaseMode) return;
    
    final rss = ProcessInfo.currentRss / (1024 * 1024);
    _logger.i('STABILITY_CHECK [$point] - Uptime: ${_uptime.elapsed.inSeconds}s - RAM: ${rss.toStringAsFixed(2)} MB');
  }

  static void logEvent(String event, {Map<String, dynamic>? data}) {
    _logger.d('STABILITY_EVENT: $event ${data ?? ""}');
  }

  static void logResource(String type, String action) {
    _logger.d('RESOURCE: $type -> $action');
  }
}
