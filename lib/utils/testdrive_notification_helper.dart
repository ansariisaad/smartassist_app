import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> setupNotificationChannels() async { 
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.actionId}');
      },
    );

    // Request notification permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Create HIGH PRIORITY notification channel for background service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'testdrive_channel',
      'Test Drive Tracking',
      description: 'Live tracking for test drive with distance updates',
      importance: Importance.high,
      // priority: Priority.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
      enableLights: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print('✅ High priority notification channel created');
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

      // Also request exact alarm permission if needed
      final bool? exactAlarmGranted = await androidImplementation
          .requestExactAlarmsPermission();
      print('⏰ Exact alarm permission granted: $exactAlarmGranted');
    }
  }

  // Create a persistent, ongoing notification like Google Maps
  static Future<void> showTestDriveNotification({
    required double distance,
    required int duration,
  }) async {
    String distanceText = _formatDistance(distance);
    String durationText = _formatDuration(duration);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'testdrive_channel',
          'Test Drive Tracking',
          channelDescription: 'Live tracking for test drive',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true, // Makes it persistent like Google Maps
          autoCancel: false, // Prevents dismissal by swipe
          showWhen: false, // Hide timestamp
          usesChronometer: false,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          category: AndroidNotificationCategory.navigation,
          visibility: NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2196F3), // Blue color
          styleInformation: BigTextStyleInformation(
            '$distanceText • $durationText\nTap to return to SmartAssist',
            htmlFormatBigText: false,
            contentTitle: 'Test Drive Active',
            htmlFormatContentTitle: false,
            summaryText: 'SmartAssist',
            htmlFormatSummaryText: false,
          ),
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      888, // Same ID as service notification
      'Test Drive Active',
      '$distanceText • $durationText',
      notificationDetails,
    );
  }

  // Format distance to show appropriate precision
  static String _formatDistance(double distance) {
    if (distance < 0.01) {
      return '0.0 km';
    } else if (distance < 0.1) {
      return '${(distance * 1000).round()} m';
    } else if (distance < 1.0) {
      return '${distance.toStringAsFixed(2)} km';
    } else if (distance < 10.0) {
      return '${distance.toStringAsFixed(1)} km';
    } else {
      return '${distance.round()} km';
    }
  }

  // Format duration in a readable way
  static String _formatDuration(int minutes) {
    if (minutes < 1) {
      return '0m';
    } else if (minutes < 60) {
      return '${minutes}m';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }

  static Future<void> cancelNotification() async {
    await _notifications.cancel(888);
  }
}

// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationHelper {
//   static final FlutterLocalNotificationsPlugin _notifications =
//       FlutterLocalNotificationsPlugin();

//   static Future<void> setupNotificationChannels() async {
//     // Request notification permissions for Android 13+
//     await _notifications
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.requestNotificationsPermission();

//     // Create notification channel for background service
//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'testdrive_channel', // Must match the ID in BackgroundService
//       'Test Drive Tracking',
//       description: 'Notifications for test drive tracking service',
//       importance: Importance.high,
//       playSound: false,
//       enableVibration: false,
//       showBadge: true,
//     );

//     await _notifications
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(channel);

//     print('✅ Notification channel created: testdrive_channel');
//   }

//   static Future<void> requestNotificationPermissions() async {
//     final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
//         _notifications
//             .resolvePlatformSpecificImplementation<
//               AndroidFlutterLocalNotificationsPlugin
//             >();

//     if (androidImplementation != null) {
//       final bool? granted = await androidImplementation
//           .requestNotificationsPermission();
//       print('📱 Notification permission granted: $granted');
//     }
//   }
// }
