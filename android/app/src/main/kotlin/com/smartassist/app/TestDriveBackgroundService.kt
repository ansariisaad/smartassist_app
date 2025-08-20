// 📁 android/app/src/main/kotlin/com/smartassist/app/TestDriveBackgroundService.kt
package com.smartassist.app

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat

class TestDriveBackgroundService : Service() {
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val TAG = "TestDriveService"

    companion object {
        const val ACTION_START_TRACKING = "START_TRACKING"
        const val ACTION_STOP_TRACKING = "STOP_TRACKING"
        const val EXTRA_EVENT_ID = "event_id"
        const val EXTRA_TOTAL_DISTANCE = "total_distance"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        // ✅ CRITICAL: Start foreground IMMEDIATELY in onCreate()
        startForegroundServiceImmediately()
        
        // Create notification channel
        NotificationHelper.createNotificationChannel(this)
        
        // Acquire wake lock to prevent CPU sleep
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "TestDrive::LocationTracking"
        )
        wakeLock?.acquire(10*60*1000L /*10 minutes*/)
        
        // Initialize Flutter engine in background thread
        Thread {
            initializeFlutterEngine()
        }.start()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service start command received")
        
        // ✅ CRITICAL: Ensure we're foreground before processing
        startForegroundServiceImmediately()
        
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
                // Default action - already handled by startForegroundServiceImmediately()
                Log.d(TAG, "Service started as foreground")
            }
        }
        
        return START_STICKY
    }

    // ✅ NEW: Immediate foreground service start 
    private fun startForegroundServiceImmediately() {
        try {
            val notification = NotificationHelper.createNotification(
                this,
                "Test Drive Service", 
                "Initializing location tracking..."
            )
            
            startForeground(NotificationHelper.NOTIFICATION_ID, notification)
            Log.d(TAG, "✅ Started as foreground service immediately")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start foreground service immediately", e)
            // ✅ ADD THIS: Create a simple fallback notification
            val simpleNotification = NotificationCompat.Builder(this, "testdrive_tracking")
                .setContentTitle("Test Drive Service")
                .setContentText("Location tracking active")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .build()
            startForeground(888, simpleNotification)
        }
    }

    private fun initializeFlutterEngine() {
        try {
            Log.d(TAG, "Initializing Flutter engine...")
            flutterEngine = FlutterEngine(this)
            
            // Start Dart execution with your background service entry point
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // Set up method channel for communication
            methodChannel = MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                "testdrive_background_service"
            )
            
            Log.d(TAG, "✅ Flutter engine initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize Flutter engine", e)
        }
    }

    // ✅ REMOVE: Delete the old startForegroundService method since we handle it in onCreate now

    private fun startTracking(eventId: String?, totalDistance: Double) {
        Log.d(TAG, "Starting tracking for event: $eventId")
        
        // Update notification to show tracking started
        updateNotification("Test Drive Active", "Location tracking started...")
        
        // Wait for Flutter engine to be ready before sending command
        Thread {
            var attempts = 0
            while (methodChannel == null && attempts < 20) {
                Thread.sleep(500) // Wait 500ms
                attempts++
            }
            
            if (methodChannel != null) {
                Log.d(TAG, "Sending tracking command to Flutter")
                methodChannel?.invokeMethod("start_tracking", mapOf(
                    "eventId" to eventId,
                    "totalDistance" to totalDistance
                ))
            } else {
                Log.e(TAG, "❌ Flutter engine not ready after 10 seconds")
            }
        }.start()
    }

    private fun stopTracking() {
        Log.d(TAG, "Stopping tracking")
        
        // Send stop command to Flutter
        methodChannel?.invokeMethod("stop_tracking", null)
        
        // Stop foreground service
        stopForeground(true)
        stopSelf()
    }

    private fun updateNotification(title: String, content: String) {
        try {
            val notification = NotificationHelper.createNotification(this, title, content)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NotificationHelper.NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        
        // Release wake lock
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        
        // Clean up Flutter engine
        flutterEngine?.destroy()
        flutterEngine = null
        methodChannel = null
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // We don't support binding
    }
}