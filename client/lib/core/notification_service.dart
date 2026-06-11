import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  Function(String?)? onNotificationTap;

  NotificationService();

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
        if (onNotificationTap != null) {
          onNotificationTap!(details.payload);
        }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    
    _initialized = true;
    debugPrint('NotificationService initialized.');
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('GHOST_LOG: FCM_NOTIFICATION_CREATION: START');
    final stopwatch = Stopwatch()..start();
    try {
      const androidDetails = AndroidNotificationDetails(
        'ghostroom_messages',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: LinuxNotificationDetails(),
      );

      await _notifications.show(
        DateTime.now().millisecond, // Unique ID
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('GHOST_LOG: FCM_NOTIFICATION_CREATION: SUCCESS (latency: ${stopwatch.elapsedMilliseconds}ms)');
    } catch (e) {
      debugPrint('GHOST_LOG: FCM_NOTIFICATION_CREATION: FAILURE error=$e (latency: ${stopwatch.elapsedMilliseconds}ms)');
    }
  }
}
