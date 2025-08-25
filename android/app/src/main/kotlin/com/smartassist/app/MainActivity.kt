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
                // ✅ ADD: Missing battery optimization methods
                "isBatteryOptimizationDisabled" -> {
                    val isDisabled = isBatteryOptimizationDisabled()
                    result.success(isDisabled)
                }
                "requestBatteryOptimization" -> {
                    requestBatteryOptimization()
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

    // ✅ ADD: Battery optimization methods
    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // Battery optimization doesn't exist on older versions
        }
    }

    private fun requestBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent().apply {
                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                Log.d(TAG, "Opened battery optimization settings")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open battery optimization settings", e)
                // Fallback to general battery optimization settings
                try {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to open general battery optimization settings", e2)
                }
            }
        }
    }

    private fun startBackgroundService(eventId: String?, totalDistance: Double) {
        try {
            Log.d(TAG, "Starting Android background service for event: $eventId")
            
            // ✅ CRITICAL: Create notification channel BEFORE starting service
            NotificationHelper.createNotificationChannel(this)
            
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

    private fun openLocationSettings() {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            startActivity(intent)
            Log.d(TAG, "Opened location settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open location settings", e)
        }
    }

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



// package com.smartassist.app

// import io.flutter.embedding.android.FlutterFragmentActivity

// class MainActivity : FlutterFragmentActivity() // ✅ this is correct

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
        
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "startBackgroundService" -> {
//                     val eventId = call.argument<String>("eventId")
//                     val totalDistance = call.argument<Double>("totalDistance") ?: 0.0
//                     startBackgroundService(eventId, totalDistance)
//                     result.success(true)
//                 }
//                 "stopBackgroundService" -> {
//                     stopBackgroundService()
//                     result.success(true)
//                 } 
//                 "openLocationSettings" -> {
//                     openLocationSettings()
//                     result.success(true)
//                 }
//                 "openAppSettings" -> {
//                     openAppSettings()
//                     result.success(true)
//                 }

//                 "cancelNotification" -> {
//                     NotificationHelper.cancelNotification(this)
//                     result.success(true)
//                 }
//                 else -> {
//                     result.notImplemented()
//                 }
//             }
//         }
//     }

//     // ✅ NEW: Background service methods
//     private fun startBackgroundService(eventId: String?, totalDistance: Double) {
//         try {
//             Log.d(TAG, "Starting Android background service for event: $eventId")
            
//             val serviceIntent = Intent(this, TestDriveBackgroundService::class.java).apply {
//                 action = TestDriveBackgroundService.ACTION_START_TRACKING
//                 putExtra(TestDriveBackgroundService.EXTRA_EVENT_ID, eventId)
//                 putExtra(TestDriveBackgroundService.EXTRA_TOTAL_DISTANCE, totalDistance)
//             }
            
//             if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//                 startForegroundService(serviceIntent)
//             } else {
//                 startService(serviceIntent)
//             }
            
//             Log.d(TAG, "✅ Android background service started successfully")
//         } catch (e: Exception) {
//             Log.e(TAG, "❌ Failed to start Android background service", e)
//         }
//     }

//     private fun stopBackgroundService() {
//         try {
//             Log.d(TAG, "Stopping Android background service")
            
//             val serviceIntent = Intent(this, TestDriveBackgroundService::class.java).apply {
//                 action = TestDriveBackgroundService.ACTION_STOP_TRACKING
//             }
//             startService(serviceIntent)
            
//             Log.d(TAG, "✅ Android background service stop command sent")
//         } catch (e: Exception) {
//             Log.e(TAG, "❌ Failed to stop Android background service", e)
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

 