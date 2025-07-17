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
    // Read API key from Info.plist (configured via .xcconfig)
    guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: path),
          let apiKey = plist["GoogleMapsAPIKey"] as? String,
          !apiKey.isEmpty else {
        print("❌ Google Maps API key not found")
        return false
    } 
    GMSServices.provideAPIKey(apiKey)
    GeneratedPluginRegistrant.register(with: self)  // ✅ Registers plugins

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// import UIKit
// import Flutter
// import GoogleMaps
// import FirebaseCore

// @main
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     FirebaseApp.configure()  // ✅ Initializes Firebase
//     GMSServices.provideAPIKey("AIzaSyCaFZ4RXQIy86v9B24wz5l0vgDKbQSP5LE")  // ✅ Google Maps API key
//     GeneratedPluginRegistrant.register(with: self)  // ✅ Registers plugins

//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }

