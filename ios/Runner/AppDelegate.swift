// import Flutter
// import UIKit
// import GoogleMaps  
// import FirebaseCore

// @main
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     FirebaseApp.configure()
//     GMSServices.provideAPIKey("AIzaSyCaFZ4RXQIy86v9B24wz5l0vgDKbQSP5LE")
//     GeneratedPluginRegistrant.register(with: self)
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }

import UIKit
import Flutter
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()  // ✅ Initializes Firebase
    GMSServices.provideAPIKey("AIzaSyCaFZ4RXQIy86v9B24wz5l0vgDKbQSP5LE")  // ✅ Google Maps API key
    GeneratedPluginRegistrant.register(with: self)  // ✅ Registers plugins

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

