// package com.smartassist.app

// import io.flutter.embedding.android.FlutterFragmentActivity

// class MainActivity : FlutterFragmentActivity() // ✅ this is correct

// 📁 android/app/src/main/kotlin/com/smartassist/app/MainActivity.kt
package com.smartassist.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.content.Context

class MainActivity: FlutterFragmentActivity() { 
    private val CHANNEL = "testdrive_native_service"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    val eventId = call.argument<String>("eventId")
                    val totalDistance = call.argument<Double>("totalDistance") ?: 0.0
                    startBackgroundService(eventId, totalDistance)
                    result.success(true)
                }
                "stopBackgroundService" -> {
                    stopBackgroundService()
                    result.success(true)
                } 
                "openLocationSettings" -> {
                    openLocationSettings()
                    result.success(true)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }

                "cancelNotification" -> {
                    NotificationHelper.cancelNotification(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ✅ NEW: Background service methods
    private fun startBackgroundService(eventId: String?, totalDistance: Double) {
        try {
            Log.d(TAG, "Starting Android background service for event: $eventId")
            
            val serviceIntent = Intent(this, TestDriveBackgroundService::class.java).apply {
                action = TestDriveBackgroundService.ACTION_START_TRACKING
                putExtra(TestDriveBackgroundService.EXTRA_EVENT_ID, eventId)
                putExtra(TestDriveBackgroundService.EXTRA_TOTAL_DISTANCE, totalDistance)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            
            Log.d(TAG, "✅ Android background service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start Android background service", e)
        }
    }

    private fun stopBackgroundService() {
        try {
            Log.d(TAG, "Stopping Android background service")
            
            val serviceIntent = Intent(this, TestDriveBackgroundService::class.java).apply {
                action = TestDriveBackgroundService.ACTION_STOP_TRACKING
            }
            startService(serviceIntent)
            
            Log.d(TAG, "✅ Android background service stop command sent")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to stop Android background service", e)
        }
    } 

    // ✅ Location settings helper
    private fun openLocationSettings() {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            startActivity(intent)
            Log.d(TAG, "Opened location settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open location settings", e)
        }
    }
    

    // ✅ App settings helper
    private fun openAppSettings() {
        try {
            val intent = Intent().apply {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
            Log.d(TAG, "Opened app settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app settings", e)
        }
    }
}


// 📁 android/app/src/main/kotlin/com/smartassist/app/MainActivity.kt
// package com.smartassist.app

// import io.flutter.embedding.android.FlutterFragmentActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel
// import android.content.Intent
// import android.net.Uri
// import android.os.Build
// import android.os.PowerManager
// import android.provider.Settings
// import android.util.Log
// import android.content.Context

// class MainActivity: FlutterFragmentActivity() { 
//     private val CHANNEL = "testdrive_native_service"
//     private val TAG = "MainActivity"

//     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)
        
//         // ✅ Only add method channel - no need for NotificationHelper if using simplified approach
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "requestBatteryOptimization" -> {
//                     requestBatteryOptimizationExemption()
//                     result.success(true)
//                 }
//                 "isBatteryOptimizationDisabled" -> {
//                     val isDisabled = isBatteryOptimizationDisabled()
//                     result.success(isDisabled)
//                 }
//                 "openLocationSettings" -> {
//                     openLocationSettings()
//                     result.success(true)
//                 }
//                 "openAppSettings" -> {
//                     openAppSettings()
//                     result.success(true)
//                 }
//                 else -> {
//                     result.notImplemented()
//                 }
//             }
//         }
//     }

//     // ✅ Battery optimization helper
//     private fun requestBatteryOptimizationExemption() {
//         try {
//             if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                 val intent = Intent().apply {
//                     action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//                     data = Uri.parse("package:$packageName")
//                 }
//                 startActivity(intent)
//                 Log.d(TAG, "Battery optimization exemption requested")
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to request battery optimization exemption", e)
//         }
//     }

//     private fun isBatteryOptimizationDisabled(): Boolean {
//         return try {
//             if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                 val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
//                 powerManager.isIgnoringBatteryOptimizations(packageName)
//             } else {
//                 true // Not applicable for older versions
//             }
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to check battery optimization status", e)
//             false
//         }
//     }

//     // ✅ Location settings helper
//     private fun openLocationSettings() {
//         try {
//             val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
//             startActivity(intent)
//             Log.d(TAG, "Opened location settings")
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to open location settings", e)
//         }
//     }

//     // ✅ App settings helper
//     private fun openAppSettings() {
//         try {
//             val intent = Intent().apply {
//                 action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
//                 data = Uri.fromParts("package", packageName, null)
//             }
//             startActivity(intent)
//             Log.d(TAG, "Opened app settings")
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to open app settings", e)
//         }
//     }
// }