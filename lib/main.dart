import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartassist/config/environment/environment.dart';
import 'package:smartassist/config/route/route.dart';
import 'package:smartassist/config/route/route_name.dart';
import 'package:smartassist/services/notifacation_srv.dart';
import 'package:smartassist/utils/connection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await Environment.init();
    Environment.validateConfig();
    await GetStorage.init();
    // Request location permissions
    await _requestLocationPermissions();
    // Request necessary permissions
    // await _requestPermissions();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitDown,
      DeviceOrientation.portraitUp,
    ]);

    print("Firebase initialized successfully!");
  } catch (e) {
    print("Initialization failed: $e");
  }

  await Hive.initFlutter();

  try {
    await NotificationService.instance.initialize();
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    if (apnsToken != null) {
      print('🔔 APNs Token retrieved: $apnsToken');
    } else {
      print(
        '❌ APNs Token is null - make sure you are testing on a real iOS device',
      );
    }
    // Get FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('📱 FCM Token: $fcmToken');
  } catch (e) {
    print("Notification initialization failed: $e");
  }

  await ConnectionService().initialize();
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _requestLocationPermissions() async {
  try {
    // First check current permission status
    PermissionStatus currentStatus = await Permission.location.status;
    print('📍 Current location permission status: $currentStatus');

    // Only request if not already granted
    if (!currentStatus.isGranted) {
      // Don't open settings immediately - give user a chance to grant
      if (currentStatus.isPermanentlyDenied) {
        print('❌ Location permission permanently denied');
        return;
      }

      // Request location permission
      PermissionStatus locationStatus = await Permission.location.request();
      print('📍 Location permission request result: $locationStatus');

      if (locationStatus.isPermanentlyDenied) {
        print('❌ Location permission permanently denied after request');
        return;
      }

      if (!locationStatus.isGranted) {
        print('❌ Location permission denied');
        return;
      }
    }

    print('✅ Location permission granted');

    if (Platform.isAndroid) {
      PermissionStatus backgroundStatus =
          await Permission.locationAlways.status;
      print('📍 Background location permission status: $backgroundStatus');

      // Only request background location if foreground is granted and background isn't permanently denied
      if (!backgroundStatus.isGranted &&
          !backgroundStatus.isPermanentlyDenied) {}
    }

    // Cross-check with Geolocator (this might be causing the settings navigation)
    LocationPermission geolocatorPermission =
        await Geolocator.checkPermission();
    print('📍 Geolocator permission status: $geolocatorPermission');

    if (geolocatorPermission == LocationPermission.denied) {
      geolocatorPermission = await Geolocator.requestPermission();
      print('📍 Geolocator permission after request: $geolocatorPermission');

      // Handle geolocator permission results without forcing settings
      if (geolocatorPermission == LocationPermission.deniedForever) {
        print('❌ Geolocator permission permanently denied');
        // Don't automatically open settings
      }
    }
  } catch (e) {
    print('❌ Error requesting location permissions: $e');
  }
}

// Future<void> _requestLocationPermissions() async {
//   try {
//     // First check current permission status
//     PermissionStatus currentStatus = await Permission.location.status;
//     print('📍 Current location permission status: $currentStatus');

//     // Only request if not already granted
//     if (!currentStatus.isGranted) {
//       // if (currentStatus.isPermanentlyDenied) {
//       //   print('❌ Location permission permanently denied - opening settings');
//       //   await openAppSettings();
//       //   return;
//       // }

//       // Request location permission
//       PermissionStatus locationStatus = await Permission.location.request();
//       print('📍 Location permission request result: $locationStatus');

//       // if (locationStatus.isPermanentlyDenied) {
//       //   print('❌ Location permission permanently denied after request');
//       //   await openAppSettings();
//       //   return;
//       // }

//       if (!locationStatus.isGranted) {
//         print('❌ Location permission denied');
//         return;
//       }
//     }

//     print('✅ Location permission granted');

//     // Now handle background location (Android 10+)
//     if (Platform.isAndroid) {
//       PermissionStatus backgroundStatus =
//           await Permission.locationAlways.status;
//       print('📍 Background location permission status: $backgroundStatus');

//       if (!backgroundStatus.isGranted &&
//           !backgroundStatus.isPermanentlyDenied) {
//         PermissionStatus backgroundLocationStatus = await Permission
//             .locationAlways
//             .request();
//         print(
//           '📍 Background location permission result: $backgroundLocationStatus',
//         );

//         if (backgroundLocationStatus.isPermanentlyDenied) {
//           print('❌ Background location permission permanently denied');
//           // Optionally show dialog explaining why this is needed
//         }
//       }
//     }

//     // Cross-check with Geolocator
//     LocationPermission geolocatorPermission =
//         await Geolocator.checkPermission();
//     print('📍 Geolocator permission status: $geolocatorPermission');

//     if (geolocatorPermission == LocationPermission.denied) {
//       geolocatorPermission = await Geolocator.requestPermission();
//       print('📍 Geolocator permission after request: $geolocatorPermission');
//     }
//   } catch (e) {
//     print('❌ Error requesting location permissions: $e');
//   }
// }

// Alternative approach with better user experience
Future<bool> _requestLocationPermissionsWithDialog() async {
  try {
    PermissionStatus status = await Permission.location.status;

    if (status.isGranted) {
      print('✅ Location permission already granted');
      return true;
    }

    if (status.isDenied) {
      // Show explanation dialog before requesting
      bool shouldRequest = await _showPermissionDialog();
      if (!shouldRequest) return false;

      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      // Show dialog explaining how to enable in settings
      bool openSettings = await _showSettingsDialog();
      if (openSettings) {
        await openAppSettings();
      }
      return false;
    }

    return status.isGranted;
  } catch (e) {
    print('❌ Error in permission request: $e');
    return false;
  }
}

// Helper method to show permission explanation dialog
Future<bool> _showPermissionDialog() async {
  // Implement your dialog here
  // Return true if user agrees to grant permission
  return true;
}

// Helper method to show settings dialog
Future<bool> _showSettingsDialog() async {
  // Implement your dialog here explaining how to enable in settings
  // Return true if user wants to open settings
  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          builder: (context, widget) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: widget!,
            );
          },
          initialRoute: RoutesName.splashScreen,
          // home: ProfileScreen(), //remove this
          onGenerateRoute: Routes.generateRoute,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFFFFF)),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}


// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:flutter/services.dart';
// import 'package:smartassist/config/environment/environment.dart';
// import 'package:smartassist/config/route/route.dart';
// import 'package:smartassist/config/route/route_name.dart';
// import 'package:smartassist/services/notifacation_srv.dart';
// import 'package:smartassist/utils/connection_service.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     await Firebase.initializeApp(); 
//     await Environment.init();
//     Environment.validateConfig(); 
//     print("🔍 Environment loaded: ${Environment.googleMapsApiKey}");
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitDown,
//       DeviceOrientation.portraitUp,
//     ]);
//     print("Firebase initialized successfully!");
//   } catch (e) {
//     print("Firebase initialization failed: $e");
//   }

//   await Hive.initFlutter(); 
//   try {
//     await NotificationService.instance.initialize(); // Initialize Notifications
//     final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
//     if (apnsToken != null) {
//       print('🔔 APNs Token retrieved: $apnsToken');
//     } else {
//       print(
//         '❌ APNs Token is null - make sure you are testing on a real iOS device',
//       );
//     }
//     // Get FCM token
//     final fcmToken = await FirebaseMessaging.instance.getToken();
//     print('📱 FCM Token: $fcmToken');
//   } catch (e) {
//     print("Firebase initialization failed: $e");
//   }
//   // Initialize connection service
//   await ConnectionService().initialize();

//   runApp(const ProviderScope(child: MyApp()));
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//       designSize: const Size(375, 812),
//       minTextAdapt: true,
//       splitScreenMode: true,
//       builder: (context, child) {
//         return GetMaterialApp(
//           builder: (context, widget) {
//             return MediaQuery(
//               data: MediaQuery.of(
//                 context,
//               ).copyWith(textScaler: const TextScaler.linear(1.0)),
//               child: widget!,
//             );
//           },
//           initialRoute: RoutesName.splashScreen,
//           // home: ProfileScreen(), //remove this
//           onGenerateRoute: Routes.generateRoute,
//           theme: ThemeData(
//             scaffoldBackgroundColor: const Color(0xFFFFFFFF),
//             appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFFFFF)),
//           ),
//           debugShowCheckedModeBanner: false,
//         );
//       },
//     );
//   }
// }
