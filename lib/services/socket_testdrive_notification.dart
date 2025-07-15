// import 'dart:async';
// import 'dart:io'; 
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 

// Future<void> createNotificationChannel() async {
//   if (Platform.isAndroid) {
//     const AndroidNotificationChannel channel = AndroidNotificationChannel(
//       'testdrive_channel', // id
//       'Test Drive Service', // title
//       description: 'This channel is used for test drive tracking notifications.',
//       importance: Importance.low,
//       enableVibration: false,
//       playSound: false,
//     );

//     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//         FlutterLocalNotificationsPlugin();

//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(channel);
//   }
// }

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> createNotificationChannel() async {
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'testdrive_channel', // id
      'Test Drive Service', // title
      description:
          'This channel is used for test drive tracking notifications.',
      importance: Importance.high, // CRITICAL: Changed from Importance.low
      enableVibration: false,
      playSound: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }
}
