// 📁 android/app/src/main/kotlin/com/smartassist/app/TestDriveBackgroundService.kt
package com.smartassist.app

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import android.location.Location
import android.os.Looper
import com.google.android.gms.location.*
import androidx.core.content.ContextCompat
import android.Manifest

class TestDriveBackgroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private val TAG = "TestDriveService"
    
    // Location tracking variables
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private var isTracking = false
    private var currentEventId: String? = null

    companion object {
        const val ACTION_START_TRACKING = "START_TRACKING"
        const val ACTION_STOP_TRACKING = "STOP_TRACKING"
        const val EXTRA_EVENT_ID = "event_id"
        const val EXTRA_TOTAL_DISTANCE = "total_distance"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        // ✅ CRITICAL: Create notification channel FIRST
        NotificationHelper.createNotificationChannel(this)
        
        // ✅ SIMPLIFIED: Just start foreground immediately with simple notification
        startForegroundImmediately()
        
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "TestDrive::LocationTracking"
        )
        wakeLock?.acquire(30*60*1000L)
        
        // Initialize location client
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service start command received")
        
        // Ensure we're still foreground
        startForegroundImmediately()
        
        when (intent?.action) {
            ACTION_START_TRACKING -> {
                val eventId = intent.getStringExtra(EXTRA_EVENT_ID)
                val totalDistance = intent.getDoubleExtra(EXTRA_TOTAL_DISTANCE, 0.0)
                startTracking(eventId, totalDistance)
            }
            ACTION_STOP_TRACKING -> {
                stopTracking()
            }
            else -> {
                Log.d(TAG, "Service started as foreground")
            }
        }
        
        return START_STICKY
    }

    // ✅ SIMPLIFIED: Single method for foreground service
    private fun startForegroundImmediately() {
        try {
            val notification = NotificationCompat.Builder(this, NotificationHelper.CHANNEL_ID)
                .setContentTitle("Test Drive Service")
                .setContentText("Location tracking active")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation) // Use system icon
                .setOngoing(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
            
            startForeground(NotificationHelper.NOTIFICATION_ID, notification)
            Log.d(TAG, "✅ Started as foreground service")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start foreground service", e)
            // If that fails, try with even simpler notification
            try {
                val simpleNotification = NotificationCompat.Builder(this, "default")
                    .setContentTitle("Test Drive")
                    .setContentText("Tracking...")
                    .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                    .build()
                startForeground(888, simpleNotification)
                Log.d(TAG, "✅ Started with fallback notification")
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Even fallback notification failed", e2)
            }
        }
    }

    private fun startTracking(eventId: String?, totalDistance: Double) {
        Log.d(TAG, "Starting tracking for event: $eventId")
        currentEventId = eventId
        
        updateNotification("Test Drive Active", "Location tracking started...")
        
        if (isTracking) {
            Log.d(TAG, "Already tracking, ignoring duplicate start request")
            return
        }
        
        startLocationUpdates()
    }

    private fun startLocationUpdates() {
        try {
            // Check permissions
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != 
                android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Log.e(TAG, "Location permission not granted")
                return
            }

            val locationRequest = LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                10000L // 10 seconds interval
            ).apply {
                setMinUpdateDistanceMeters(5f) // 5 meters minimum distance
                setGranularity(Granularity.GRANULARITY_PERMISSION_LEVEL)
                setWaitForAccurateLocation(false)
            }.build()

            locationCallback = object : LocationCallback() {
                override fun onLocationResult(locationResult: LocationResult) {
                    super.onLocationResult(locationResult)
                    locationResult.lastLocation?.let { location ->
                        handleLocationUpdate(location)
                    }
                }
            }

            fusedLocationClient?.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            
            isTracking = true
            Log.d(TAG, "✅ Location updates started")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start location updates", e)
        }
    }

    private fun handleLocationUpdate(location: Location) {
        Log.d(TAG, "📍 Background location: ${location.latitude}, ${location.longitude}, accuracy: ${location.accuracy}m")
        
        // Update notification with current location
        updateNotification(
            "Test Drive Active", 
            "Lat: ${String.format("%.4f", location.latitude)}, Lng: ${String.format("%.4f", location.longitude)}"
        )
    }

    private fun stopTracking() {
        Log.d(TAG, "Stopping tracking")
        
        // Stop location updates
        if (isTracking) {
            locationCallback?.let {
                fusedLocationClient?.removeLocationUpdates(it)
            }
            isTracking = false
        }
        
        // ✅ IMPORTANT: Cancel notification before stopping
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NotificationHelper.NOTIFICATION_ID)
        
        stopForeground(true)
        stopSelf()
    }

    private fun updateNotification(title: String, content: String) {
        try {
            val notification = NotificationCompat.Builder(this, NotificationHelper.CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(content)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setOngoing(true)
                .setSilent(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
                
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NotificationHelper.NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        
        // Stop location tracking
        if (isTracking) {
            locationCallback?.let {
                fusedLocationClient?.removeLocationUpdates(it)
            }
        }
        
        // Release wake lock
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}


// 📁 android/app/src/main/kotlin/com/smartassist/app/TestDriveBackgroundService.kt
// package com.smartassist.app

// import android.app.Service
// import android.content.Intent
// import android.os.IBinder
// import android.os.PowerManager
// import android.util.Log
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.embedding.engine.dart.DartExecutor
// import io.flutter.plugin.common.MethodChannel
// import android.app.NotificationManager
// import android.content.Context
// import androidx.core.app.NotificationCompat

// class TestDriveBackgroundService : Service() { 
//     private var methodChannel: MethodChannel? = null
//     private var wakeLock: PowerManager.WakeLock? = null
//     private val TAG = "TestDriveService"

//     companion object {
//         const val ACTION_START_TRACKING = "START_TRACKING"
//         const val ACTION_STOP_TRACKING = "STOP_TRACKING"
//         const val EXTRA_EVENT_ID = "event_id"
//         const val EXTRA_TOTAL_DISTANCE = "total_distance"
//     }

//     override fun onCreate() {
//         super.onCreate()
//         Log.d(TAG, "Service created")
        
//         // ✅ CRITICAL: More robust foreground start
//         try {
//             startForegroundServiceImmediately()
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to start foreground immediately, retrying", e)
//             // ✅ Fallback for release builds
//             createSimpleForegroundNotification()
//         }
        
//         NotificationHelper.createNotificationChannel(this)
        
//         val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
//         wakeLock = powerManager.newWakeLock(
//             PowerManager.PARTIAL_WAKE_LOCK,
//             "TestDrive::LocationTracking"
//         )
//         wakeLock?.acquire(30*60*1000L) // ✅ Increased to 30 minutes
        
//         Thread {
//             initializeFlutterEngine()
//         }.start()
//     }

//     override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//         Log.d(TAG, "Service start command received")
        
//         // ✅ CRITICAL: Ensure we're foreground before processing
//         startForegroundServiceImmediately()
        
//         when (intent?.action) {
//             ACTION_START_TRACKING -> {
//                 val eventId = intent.getStringExtra(EXTRA_EVENT_ID)
//                 val totalDistance = intent.getDoubleExtra(EXTRA_TOTAL_DISTANCE, 0.0)
//                 startTracking(eventId, totalDistance)
//             }
//             ACTION_STOP_TRACKING -> {
//                 stopTracking()
//             }
//             else -> {
//                 // Default action - already handled by startForegroundServiceImmediately()
//                 Log.d(TAG, "Service started as foreground")
//             }
//         }
        
//         return START_STICKY
//     }

//     private fun createSimpleForegroundNotification() {
//         try {
//             val notification = NotificationCompat.Builder(this, "testdrive_tracking")
//                 .setContentTitle("Test Drive Active")
//                 .setContentText("Location tracking in progress")
//                 .setSmallIcon(android.R.drawable.ic_menu_mylocation)
//                 .setOngoing(true)
//                 .setSilent(true)
//                 .build()
            
//             startForeground(888, notification)
//             Log.d(TAG, "✅ Fallback foreground notification created")
//         } catch (e: Exception) {
//             Log.e(TAG, "❌ Failed to create fallback notification", e)
//         }
//     }

//     // ✅ NEW: Immediate foreground service start 
//     private fun startForegroundServiceImmediately() {
//         try {
//             val notification = NotificationHelper.createNotification(
//                 this,
//                 "Test Drive Service", 
//                 "Initializing location tracking..."
//             )
            
//             startForeground(NotificationHelper.NOTIFICATION_ID, notification)
//             Log.d(TAG, "✅ Started as foreground service immediately")
//         } catch (e: Exception) {
//             Log.e(TAG, "❌ Failed to start foreground service immediately", e)
//             // ✅ ADD THIS: Create a simple fallback notification
//             val simpleNotification = NotificationCompat.Builder(this, "testdrive_tracking")
//                 .setContentTitle("Test Drive Service")
//                 .setContentText("Location tracking active")
//                 .setSmallIcon(android.R.drawable.ic_menu_mylocation)
//                 .build()
//             startForeground(888, simpleNotification)
//         }
//     }

//     private fun initializeFlutterEngine() {
//         try {
//             Log.d(TAG, "Initializing Flutter engine...")
//             flutterEngine = FlutterEngine(this)
            
//             // Start Dart execution with your background service entry point
//             flutterEngine?.dartExecutor?.executeDartEntrypoint(
//                 DartExecutor.DartEntrypoint.createDefault()
//             )
            
//             // Set up method channel for communication
//             methodChannel = MethodChannel(
//                 flutterEngine!!.dartExecutor.binaryMessenger,
//                 "testdrive_background_service"
//             )
            
//             Log.d(TAG, "✅ Flutter engine initialized successfully")
//         } catch (e: Exception) {
//             Log.e(TAG, "❌ Failed to initialize Flutter engine", e)
//         }
//     }

//     // ✅ REMOVE: Delete the old startForegroundService method since we handle it in onCreate now

//     private fun startTracking(eventId: String?, totalDistance: Double) {
//         Log.d(TAG, "Starting tracking for event: $eventId")
        
//         // Update notification to show tracking started
//         updateNotification("Test Drive Active", "Location tracking started...")
        
//         // Wait for Flutter engine to be ready before sending command
//         Thread {
//             var attempts = 0
//             while (methodChannel == null && attempts < 20) {
//                 Thread.sleep(500) // Wait 500ms
//                 attempts++
//             }
            
//             if (methodChannel != null) {
//                 Log.d(TAG, "Sending tracking command to Flutter")
//                 methodChannel?.invokeMethod("start_tracking", mapOf(
//                     "eventId" to eventId,
//                     "totalDistance" to totalDistance
//                 ))
//             } else {
//                 Log.e(TAG, "❌ Flutter engine not ready after 10 seconds")
//             }
//         }.start()
//     }

//     private fun stopTracking() {
//         Log.d(TAG, "Stopping tracking")
        
//         // Send stop command to Flutter
//         methodChannel?.invokeMethod("stop_tracking", null)
        
//         // ✅ ADDED: Cancel notification before stopping
//         NotificationHelper.cancelNotification(this)
        
//         // Stop foreground service
//         stopForeground(true)
//         stopSelf()
//     }

//     private fun updateNotification(title: String, content: String) {
//         try {
//             val notification = NotificationHelper.createNotification(this, title, content)
//             val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//             notificationManager.notify(NotificationHelper.NOTIFICATION_ID, notification)
//         } catch (e: Exception) {
//             Log.e(TAG, "Failed to update notification", e)
//         }
//     }

//     override fun onDestroy() {
//         super.onDestroy()
//         Log.d(TAG, "Service destroyed")
        
//         // Release wake lock
//         wakeLock?.let {
//             if (it.isHeld) {
//                 it.release()
//             }
//         }
        
//         // Clean up Flutter engine
//         flutterEngine?.destroy()
//         flutterEngine = null
//         methodChannel = null
//     }

//     override fun onBind(intent: Intent?): IBinder? {
//         return null // We don't support binding
//     }
// }