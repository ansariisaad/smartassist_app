import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> setupNotificationChannels() async {
    // Request notification permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Create notification channel for background service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'testdrive_channel', // Must match the ID in BackgroundService
      'Test Drive Tracking',
      description: 'Notifications for test drive tracking service',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print('✅ Notification channel created: testdrive_channel');
  }

  static Future<void> requestNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation
          .requestNotificationsPermission();
      print('📱 Notification permission granted: $granted');
    }
  }
}
