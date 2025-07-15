import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Create notification channel BEFORE configuring the service
  await createNotificationChannel();

  try {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false,
        // notificationChannelId: 'testdrive_channel',
        // initialNotificationTitle: 'Test Drive Active',
        // initialNotificationContent: 'Tracking your test drive...',
        // foregroundServiceNotificationId: 888,
        // foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  } catch (e) {
    print('Failed to configure background service: $e');
    // Handle the error, e.g., show a user notification or fallback to non-foreground mode
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Timer.periodic(const Duration(seconds: 1), (timer) async {
  //   if (service is AndroidServiceInstance) {
  //     if (await service.isForegroundService()) {
  //       service.setForegroundNotificationInfo(
  //         title: "Test Drive Active",
  //         content: "Tracking in progress...",
  //       );
  //     }
  //   }
  // });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

Future<void> createNotificationChannel() async {
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'testdrive_channel', // id
      'Test Drive Service', // title
      description:
          'This channel is used for test drive tracking notifications.',
      importance: Importance.low, // CHANGED: from low to high
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
