import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartassist/config/route/route_name.dart';
import 'package:smartassist/pages/login_steps/biometric_screen.dart'
    as loginStep;
import 'package:smartassist/pages/login_steps/login_page.dart';
import 'package:smartassist/pages/login_steps/splash_screen.dart';
import 'package:smartassist/utils/bottom_navigation.dart'; 

// class Routes {
//   static Route<dynamic> generateRoute(RouteSettings settings) {
//     // Extract arguments if they exist
//     final args = settings.arguments;
//     switch (settings.name) {
//       case RoutesName.splashScreen:
//         return MaterialPageRoute(
//           builder: (context) => const SplashScreen(),
//         );
//       case RoutesName.biometricScreen:
//         // Check if args contains isFirstTime parameter
//         bool isFirstTime = false;
//         if (args is Map<String, dynamic> && args.containsKey('isFirstTime')) {
//           isFirstTime = args['isFirstTime'];
//         }

//         return MaterialPageRoute(
//           builder: (context) => BiometricScreen(isFirstTime: isFirstTime),
//         );
// //comment this
//       case RoutesName.home:
//         return MaterialPageRoute(
//           builder: (context) => BottomNavigation(),
//         );

//       //this
//       case RoutesName.login:
//         return MaterialPageRoute(
//           builder: (context) => LoginPage(
//             onLoginSuccess: () {
//               Get.off(() => BottomNavigation());
//             },
//             email: '',
//           ),
//         );

//       // Add settings screen route
//       case RoutesName.biometricSettings:
//         return MaterialPageRoute(
//           builder: (context) => const BiometricSettingsScreen(),
//         );

//       default:
//         return MaterialPageRoute(
//           builder: (context) => Scaffold(
//             body: Center(
//               child: Text('No route defined for ${settings.name}'),
//             ),
//           ),
//         );
//     }
//   }
// }

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extract arguments if they exist
    final args = settings.arguments;
    switch (settings.name) {
      case RoutesName.splashScreen:
        return MaterialPageRoute(builder: (context) => const SplashScreen());

      case RoutesName.biometricScreen:
        // Check if args contains isFirstTime parameter
        bool isFirstTime = false;
        if (args is Map<String, dynamic> && args.containsKey('isFirstTime')) {
          isFirstTime = args['isFirstTime'];
        }

        return MaterialPageRoute(
          builder: (context) =>
              loginStep.BiometricScreen(isFirstTime: isFirstTime),
        );

      case RoutesName.home:
        return MaterialPageRoute(builder: (context) => BottomNavigation());

      case RoutesName.login:
        return MaterialPageRoute(
          builder: (context) => LoginPage(
            onLoginSuccess: () {
              Get.off(() => BottomNavigation());
            },
            email: '',
          ),
        );

      // Add settings screen route
      case RoutesName.biometricSettings:
        return MaterialPageRoute(
          builder: (context) => loginStep.BiometricScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
