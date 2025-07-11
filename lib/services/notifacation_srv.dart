import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance.setupFlutterNotificatioins();
  await NotificationService.instance.showNotification(message);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // request pesmission
    await _requestPermission();

    // setup message handlers
    await _setupMessageHandlers();

    // Get FCM token
    final token = await _messaging.getToken();
    print('FCM Token : $token');
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      // provisional: false,
      provisional: Platform.isIOS ? true : false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('permission status: ${settings.authorizationStatus}');
  }

  Future<void> setupFlutterNotificatioins() async {
    if (_isFlutterLocalNotificationsInitialized) {
      return;
    }

    // android setup

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High importance Channel',
      description: 'this channel is for importance notificaion.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // icon notification
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ios setup

    final InitializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        print("Received local notification: $title, $body");
      },
    );

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: InitializationSettingsDarwin,
    );

    // flutter notification setup

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high importance channel',
            'High Importance Channel',
            channelDescription:
                'This Channel is used for importance notifications and more.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  Future<void> _setupMessageHandlers() async {
    // foreground message
    FirebaseMessaging.onMessage.listen((message) {
      showNotification(message);
    });

    // background message

    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    if (message.data['type'] == 'chat') {
      // open chat screen
    }
  }
}

// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   print("Background message received: ${message.notification?.title}");
//   await NotificationService.instance.setupFlutterNotificatioins();
//   await NotificationService.instance.showNotification(message);
// }

// class NotificationService {
//   NotificationService._();
//   static final NotificationService instance = NotificationService._();

//   final _messaging = FirebaseMessaging.instance;
//   final _localNotifications = FlutterLocalNotificationsPlugin();
//   bool _isFlutterLocalNotificationsInitialized = false;

//   Future<void> initialize() async {
//     try {
//       print("Initializing notifications...");
//       FirebaseMessaging.onBackgroundMessage(
//         _firebaseMessagingBackgroundHandler,
//       );

//       // Request permissions
//       await _requestPermission();

//       // Setup message handlers
//       await _setupMessageHandlers();

//       // Get FCM token
//       final token = await _messaging.getToken();
//       print('FCM Token: $token');
//       print("Notification initialization complete");
//     } catch (e) {
//       print("Notification initialization failed: $e");
//     }
//   }

//   Future<void> _requestPermission() async {
//     try {
//       print("Requesting notification permissions...");
//       final settings = await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//         provisional: true, // Enable provisional for iOS
//         announcement: false,
//         carPlay: false,
//         criticalAlert: false,
//       );
//       print('Permission status: ${settings.authorizationStatus}');
//       if (settings.authorizationStatus != AuthorizationStatus.authorized &&
//           settings.authorizationStatus != AuthorizationStatus.provisional) {
//         print("Notification permissions denied or not determined");
//       }
//     } catch (e) {
//       print("Error requesting permissions: $e");
//     }
//   }

//   Future<void> setupFlutterNotificatioins() async {
//     if (_isFlutterLocalNotificationsInitialized) {
//       print("Local notifications already initialized");
//       return;
//     }

//     try {
//       // Android setup
//       const channel = AndroidNotificationChannel(
//         'high_importance_channel',
//         'High Importance Channel',
//         description: 'This channel is for important notifications.',
//         importance: Importance.high,
//       );

//       await _localNotifications
//           .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin
//           >()
//           ?.createNotificationChannel(channel);

//       // iOS setup
//       final initializationSettingsDarwin = DarwinInitializationSettings(
//         requestAlertPermission: true,
//         requestBadgePermission: true,
//         requestSoundPermission: true,
//         onDidReceiveLocalNotification: (id, title, body, payload) async {
//           print("Received local notification: $title, $body");
//         },
//       );

//       final initializationSettings = InitializationSettings(
//         android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//         iOS: initializationSettingsDarwin,
//       );

//       await _localNotifications.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: (NotificationResponse details) {
//           print("Notification tapped: ${details.payload}");
//           // Handle navigation
//         },
//       );

//       _isFlutterLocalNotificationsInitialized = true;
//       print("Local notifications initialized successfully");
//     } catch (e) {
//       print("Failed to initialize local notifications: $e");
//     }
//   }

//   Future<void> showNotification(RemoteMessage message) async {
//     try {
//       RemoteNotification? notification = message.notification;
//       AndroidNotification? android = message.notification?.android;

//       print(
//         "Showing notification: ${notification?.title}, ${notification?.body}",
//       );

//       if (notification != null) {
//         await _localNotifications.show(
//           notification.hashCode,
//           notification.title,
//           notification.body,
//           NotificationDetails(
//             android: android != null
//                 ? AndroidNotificationDetails(
//                     'high_importance_channel',
//                     'High Importance Channel',
//                     channelDescription:
//                         'This channel is used for important notifications.',
//                     importance: Importance.high,
//                     priority: Priority.high,
//                     icon: '@mipmap/ic_launcher',
//                   )
//                 : null,
//             iOS: DarwinNotificationDetails(
//               presentAlert: true,
//               presentBadge: true,
//               presentSound: true,
//               sound: 'default',
//               badgeNumber: 1,
//             ),
//           ),
//           payload: message.data.toString(),
//         );
//       }
//     } catch (e) {
//       print("Error showing notification: $e");
//     }
//   }

//   Future<void> _setupMessageHandlers() async {
//     try {
//       // Foreground messages
//       FirebaseMessaging.onMessage.listen((message) {
//         print("Foreground message received: ${message.notification?.title}");
//         showNotification(message);
//       });

//       // Background messages
//       FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

//       // Terminated state
//       final initialMessage = await _messaging.getInitialMessage();
//       if (initialMessage != null) {
//         print(
//           "Initial message received: ${initialMessage.notification?.title}",
//         );
//         _handleBackgroundMessage(initialMessage);
//       }
//     } catch (e) {
//       print("Error setting up message handlers: $e");
//     }
//   }

//   void _handleBackgroundMessage(RemoteMessage message) {
//     print("Handling background message: ${message.notification?.title}");
//     if (message.data['type'] == 'chat') {
//       // Navigate to chat screen
//     }
//   }
// }
