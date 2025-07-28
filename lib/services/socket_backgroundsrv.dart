import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

 
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: 'testdrive_channel',
        initialNotificationTitle: 'Test Drive Service',
        initialNotificationContent: 'Preparing test drive tracking...',
        foregroundServiceNotificationId: 888,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // CRITICAL: Start foreground service immediately
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Start foreground service immediately to prevent timeout
    service.invoke('update_notification', {
      'title': 'Test Drive Service',
      'content': 'Initializing...',
    });

    IO.Socket? socket;
    StreamSubscription<Position>? positionSubscription;
    String? eventId;
    double totalDistance = 0.0;
    List<Map<String, double>> routePoints = [];
    Timer? heartbeatTimer;
    Timer? reconnectTimer;
    bool isServiceRunning = false;

    // Listen for start command from main app
    service.on('start_tracking').listen((event) async {
      if (isServiceRunning) return;

      print('🚀 Background service: Starting tracking');
      isServiceRunning = true;

      eventId = event!['eventId'];
      totalDistance = event['totalDistance']?.toDouble() ?? 0.0;

      // Set as foreground service immediately
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }

      // Initialize socket in background
      socket = await _initBackgroundSocket(service, eventId!);

      // Start location tracking in background
      positionSubscription = await _startBackgroundLocationTracking(
        service,
        socket,
        eventId!,
        totalDistance,
        routePoints,
      );

      // Start heartbeat to keep service alive
      heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        service.invoke('update_notification', {
          'title': 'Test Drive Active',
          'content': 'Distance: ${totalDistance.toStringAsFixed(2)} km',
        });
        print(
          '💓 Background service heartbeat - Distance: ${totalDistance.toStringAsFixed(2)} km',
        );
      });

      // Show active notification
      service.invoke('update_notification', {
        'title': 'Test Drive Active',
        'content': 'Tracking your drive in background',
      });
    });

    // Listen for stop command
    service.on('stop_tracking').listen((event) {
      print('🛑 Background service: Stopping tracking');
      isServiceRunning = false;
      positionSubscription?.cancel();
      heartbeatTimer?.cancel();
      reconnectTimer?.cancel();
      socket?.disconnect();
      socket?.dispose();

      // Set as background before stopping
      if (service is AndroidServiceInstance) {
        service.setAsBackgroundService();
      }

      service.stopSelf();
    });

    // Listen for data requests from main app
    service.on('get_data').listen((event) {
      service.invoke('data_response', {
        'totalDistance': totalDistance,
        'routePoints': routePoints,
        'isRunning': isServiceRunning,
      });
    });

    // Handle service being killed
    service.on('service_killed').listen((event) {
      print('⚰️ Background service killed');
      isServiceRunning = false;
      positionSubscription?.cancel();
      heartbeatTimer?.cancel();
      reconnectTimer?.cancel();
    });
  }

  @pragma('vm:entry-point')
  static Future<IO.Socket?> _initBackgroundSocket(
    ServiceInstance service,
    String eventId,
  ) async {
    try {
      final socket = IO.io('https://api.smartassistapp.in', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 20,
        'reconnectionDelay': 3000,
        'reconnectionDelayMax': 30000,
        'timeout': 20000,
        'forceNew': true,
      });

      socket.onConnect((_) {
        print('🔌 Background socket connected');
        socket.emit('joinTestDrive', {'eventId': eventId});
        service.invoke('socket_status', {'connected': true});
      });

      socket.onDisconnect((reason) {
        print('🔌 Background socket disconnected: $reason');
        service.invoke('socket_status', {'connected': false});

        // Auto-reconnect with exponential backoff
        Timer(Duration(seconds: 5), () {
          if (!socket.connected) {
            print('🔄 Attempting socket reconnection...');
            socket.connect();
          }
        });
      });

      socket.onConnectError((data) {
        print('❌ Background socket connection error: $data');
        service.invoke('socket_status', {
          'connected': false,
          'error': data.toString(),
        });
      });

      socket.onReconnect((attemptNumber) {
        print('🔄 Socket reconnected on attempt: $attemptNumber');
        socket.emit('joinTestDrive', {'eventId': eventId});
      });

      socket.connect();
      return socket;
    } catch (e) {
      print('❌ Background socket init error: $e');
      service.invoke('socket_status', {
        'connected': false,
        'error': e.toString(),
      });
      return null;
    }
  }

  @pragma('vm:entry-point')
  static Future<StreamSubscription<Position>> _startBackgroundLocationTracking(
    ServiceInstance service,
    IO.Socket? socket,
    String eventId,
    double totalDistance,
    List<Map<String, double>> routePoints,
  ) async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 5 meters minimum distance
      timeLimit: Duration(seconds: 10),
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        try {
          final newPoint = {
            'latitude': position.latitude,
            'longitude': position.longitude,
          };

          // Calculate distance if we have previous points
          if (routePoints.isNotEmpty) {
            final lastPoint = routePoints.last;
            double segmentDistance =
                Geolocator.distanceBetween(
                  lastPoint['latitude']!,
                  lastPoint['longitude']!,
                  position.latitude,
                  position.longitude,
                ) /
                1000.0; // Convert to km

            if (segmentDistance > 0.001) {
              // Only if moved more than 1 meter
              totalDistance += segmentDistance;
            }
          }

          routePoints.add(newPoint);

          // Send to socket if connected
          if (socket != null && socket.connected) {
            socket.emit('updateLocation', {
              'eventId': eventId,
              'newCoordinates': newPoint,
              'totalDistance': totalDistance,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }

          // Update main app
          service.invoke('location_update', {
            'position': newPoint,
            'totalDistance': totalDistance,
            'routePoints': routePoints,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          // Update notification with current stats
          service.invoke('update_notification', {
            'title': 'Test Drive Active',
            'content':
                'Distance: ${totalDistance.toStringAsFixed(2)} km • ${DateTime.now().toString().substring(11, 16)}',
          });

          print(
            '📍 Background location update: ${totalDistance.toStringAsFixed(3)} km',
          );
        } catch (e) {
          print('❌ Error processing background location: $e');
        }
      },
      onError: (error) {
        print('❌ Background location stream error: $error');
        service.invoke('location_error', {'error': error.toString()});

        // Restart location tracking after error
        Future.delayed(Duration(seconds: 10), () {
          _startBackgroundLocationTracking(
            service,
            socket,
            eventId,
            totalDistance,
            routePoints,
          );
        });
      },
      cancelOnError: false,
    );
  }
}

// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;

// class BackgroundService {
//   static Future<void> initializeService() async {
//     final service = FlutterBackgroundService();

//     await service.configure(
//       iosConfiguration: IosConfiguration(
//         autoStart: false,
//         onForeground: onStart,
//         onBackground: onIosBackground,
//       ),
//       androidConfiguration: AndroidConfiguration(
//         onStart: onStart,
//         autoStart: false,
//         isForegroundMode: true,
//         autoStartOnBoot: false,
//       ),
//     );
//   }

//   static Future<bool> onIosBackground(ServiceInstance service) async {
//     WidgetsFlutterBinding.ensureInitialized();
//     DartPluginRegistrant.ensureInitialized();
//     return true;
//   }

//   static void onStart(ServiceInstance service) async {
//     DartPluginRegistrant.ensureInitialized();

//     IO.Socket? socket;
//     StreamSubscription<Position>? positionSubscription;
//     String? eventId;
//     double totalDistance = 0.0;
//     List<Map<String, double>> routePoints = [];

//     // Listen for start command from main app
//     service.on(' ').listen((event) async {
//       eventId = event!['eventId'];
//       totalDistance = event['totalDistance'] ?? 0.0;

//       // Initialize socket in background
//       await _initBackgroundSocket(socket, service, eventId!);

//       // Start location tracking in background
//       positionSubscription = await _startBackgroundLocationTracking(
//         service,
//         socket,
//         eventId!,
//         totalDistance,
//         routePoints,
//       );

//       // Show notification
//       service.invoke('update_notification', {
//         'title': 'Test Drive Active',
//         'content': 'Tracking your drive in background',
//       });
//     });

//     // Listen for stop command
//     service.on('stop_tracking').listen((event) {
//       positionSubscription?.cancel();
//       socket?.disconnect();
//       service.stopSelf();
//     });

//     // Listen for data requests from main app
//     service.on('get_data').listen((event) {
//       service.invoke('data_response', {
//         'totalDistance': totalDistance,
//         'routePoints': routePoints,
//       });
//     });
//   }

//   static Future<void> _initBackgroundSocket(
//     IO.Socket? socket,
//     ServiceInstance service,
//     String eventId,
//   ) async {
//     try {
//       socket = IO.io('https://api.smartassistapp.in', <String, dynamic>{
//         'transports': ['websocket'],
//         'autoConnect': false,
//         'reconnection': true,
//         'reconnectionAttempts': 10,
//         'reconnectionDelay': 3000,
//         'reconnectionDelayMax': 10000,
//         'timeout': 15000,
//         'forceNew': true,
//       });

//       socket.onConnect((_) {
//         print('Background socket connected');
//         socket!.emit('joinTestDrive', {'eventId': eventId});
//         service.invoke('socket_status', {'connected': true});
//       });

//       socket.onDisconnect((reason) {
//         print('Background socket disconnected: $reason');
//         service.invoke('socket_status', {'connected': false});

//         // Auto-reconnect after delay
//         Timer(Duration(seconds: 5), () {
//           if (socket != null && !socket.connected) {
//             socket.connect();
//           }
//         });
//       });

//       socket.onConnectError((data) {
//         print('Background socket connection error: $data');
//         service.invoke('socket_status', {
//           'connected': false,
//           'error': data.toString(),
//         });
//       });

//       socket.connect();
//     } catch (e) {
//       print('Background socket init error: $e');
//       service.invoke('socket_status', {
//         'connected': false,
//         'error': e.toString(),
//       });
//     }
//   }

//   static Future<StreamSubscription<Position>> _startBackgroundLocationTracking(
//     ServiceInstance service,
//     IO.Socket? socket,
//     String eventId,
//     double totalDistance,
//     List<Map<String, double>> routePoints,
//   ) async {
//     const LocationSettings locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 10,
//     );

//     return Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen((Position position) {
//       final newPoint = {
//         'latitude': position.latitude,
//         'longitude': position.longitude,
//       };

//       // Calculate distance if we have previous points
//       if (routePoints.isNotEmpty) {
//         final lastPoint = routePoints.last;
//         double segmentDistance =
//             Geolocator.distanceBetween(
//               lastPoint['latitude']!,
//               lastPoint['longitude']!,
//               position.latitude,
//               position.longitude,
//             ) /
//             1000.0; // Convert to km

//         if (segmentDistance > 0.001) {
//           // Only if moved more than 1 meter
//           totalDistance += segmentDistance;
//         }
//       }

//       routePoints.add(newPoint);

//       // Send to socket if connected
//       if (socket != null && socket.connected) {
//         socket.emit('updateLocation', {
//           'eventId': eventId,
//           'newCoordinates': newPoint,
//           'totalDistance': totalDistance,
//         });
//       }

//       // Update main app
//       service.invoke('location_update', {
//         'position': newPoint,
//         'totalDistance': totalDistance,
//         'routePoints': routePoints,
//       });

//       // Update notification
//       service.invoke('update_notification', {
//         'title': 'Test Drive Active',
//         'content': 'Distance: ${totalDistance.toStringAsFixed(2)} km',
//       });
//     });
//   }
// }
