import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smartassist/utils/testdrive_notification_helper.dart';

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

    // Start foreground service immediately
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    IO.Socket? socket;
    StreamSubscription<Position>? positionSubscription;
    String? eventId;
    double totalDistance = 0.0;
    List<Map<String, double>> routePoints = [];
    Timer? heartbeatTimer;
    Timer? notificationTimer;
    bool isServiceRunning = false;
    LatLng? lastValidLocation;
    DateTime? lastLocationTime;
    DateTime? driveStartTime;

    // Initialize with Google Maps style notification
    await _updateNotification(service, totalDistance, 0);

    // Listen for start command from main app
    service.on('start_tracking').listen((event) async {
      if (isServiceRunning) return;

      print('🚀 Background service: Starting tracking');
      isServiceRunning = true;
      driveStartTime = DateTime.now();

      eventId = event!['eventId'];
      totalDistance = event['totalDistance']?.toDouble() ?? 0.0;

      // Set as foreground service immediately
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }

      // Initialize socket
      socket = await _initBackgroundSocket(service, eventId!);

      // Start location tracking with improved accuracy
      positionSubscription = await _startAccurateLocationTracking(
        service,
        socket,
        eventId!,
        totalDistance,
        routePoints,
        lastValidLocation,
        lastLocationTime,
      );

      // Update notification every 5 seconds like Google Maps
      notificationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        int duration = driveStartTime != null
            ? DateTime.now().difference(driveStartTime!).inMinutes
            : 0;
        _updateNotification(service, totalDistance, duration);
      });

      // Heartbeat for service health
      heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        print(
          '💓 Background service heartbeat - Distance: ${totalDistance.toStringAsFixed(1)} km',
        );
      });
    });

    // Listen for stop command
    service.on('stop_tracking').listen((event) {
      print('🛑 Background service: Stopping tracking');
      isServiceRunning = false;
      positionSubscription?.cancel();
      heartbeatTimer?.cancel();
      notificationTimer?.cancel();
      socket?.disconnect();
      socket?.dispose();

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
  }

  @pragma('vm:entry-point')
  static Future<void> _updateNotification(
    ServiceInstance service,
    double distance,
    int duration,
  ) async {
    // Use the NotificationHelper to show persistent notification
    try {
      await NotificationHelper.showTestDriveNotification(
        distance: distance,
        duration: duration,
      );
    } catch (e) {
      print('❌ Error updating notification: $e');
      // Fallback to service notification
      String distanceText = _formatDistanceForNotification(distance);
      String durationText = duration > 0 ? '${duration}m' : 'Starting...';

      service.invoke('update_notification', {
        'title': 'Test Drive Active',
        'content': '$distanceText • $durationText • Tap to return',
      });
    }
  }

  @pragma('vm:entry-point')
  static String _formatDistanceForNotification(double distance) {
    if (distance < 0.01) {
      return '0.0 km';
    } else if (distance < 1.0) {
      return '${distance.toStringAsFixed(2)} km';
    } else if (distance < 10.0) {
      return '${distance.toStringAsFixed(1)} km';
    } else {
      return '${distance.round()} km';
    }
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
      });

      socket.onDisconnect((reason) {
        print('🔌 Background socket disconnected: $reason');
        // Auto-reconnect
        Timer(Duration(seconds: 5), () {
          if (!socket.connected) {
            socket.connect();
          }
        });
      });

      socket.connect();
      return socket;
    } catch (e) {
      print('❌ Background socket init error: $e');
      return null;
    }
  }

  @pragma('vm:entry-point')
  static Future<StreamSubscription<Position>> _startAccurateLocationTracking(
    ServiceInstance service,
    IO.Socket? socket,
    String eventId,
    double totalDistance,
    List<Map<String, double>> routePoints,
    LatLng? lastValidLocation,
    DateTime? lastLocationTime,
  ) async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // Highest accuracy
      distanceFilter: 3, // 3 meters minimum movement
      timeLimit: Duration(seconds: 8),
    );

    return Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        try {
          LatLng currentLocation = LatLng(
            position.latitude,
            position.longitude,
          );

          // Validate location update using improved algorithm
          if (!_isValidLocationUpdate(
            position,
            lastValidLocation,
            lastLocationTime,
          )) {
            return; // Skip invalid location
          }

          final newPoint = {
            'latitude': position.latitude,
            'longitude': position.longitude,
          };

          // Calculate distance with improved accuracy
          if (lastValidLocation != null) {
            double segmentDistance = _calculateAccurateDistance(
              lastValidLocation!,
              currentLocation,
            );

            if (segmentDistance >= 0.005) {
              // 5 meters minimum
              totalDistance += segmentDistance;
              lastValidLocation = currentLocation;
              lastLocationTime = DateTime.now();

              print(
                '✅ Valid segment: ${(segmentDistance * 1000).toStringAsFixed(0)}m, Total: ${totalDistance.toStringAsFixed(2)} km',
              );
            } else {
              return; // Skip small movements
            }
          } else {
            lastValidLocation = currentLocation;
            lastLocationTime = DateTime.now();
          }

          routePoints.add(newPoint);

          // Send to socket
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
        } catch (e) {
          print('❌ Error processing background location: $e');
        }
      },
      onError: (error) {
        print('❌ Background location stream error: $error');
      },
      cancelOnError: false,
    );
  }

  @pragma('vm:entry-point')
  static bool _isValidLocationUpdate(
    Position position,
    LatLng? lastLocation,
    DateTime? lastTime,
  ) {
    // Check GPS accuracy (stricter for better results)
    if (position.accuracy > 15.0) {
      return false;
    }

    if (lastLocation == null || lastTime == null) {
      return true;
    }

    LatLng currentLocation = LatLng(position.latitude, position.longitude);
    double distance = _calculateAccurateDistance(lastLocation, currentLocation);

    // Check minimum distance (5 meters)
    if (distance < 0.005) {
      return false;
    }

    // Check for GPS jumps (unrealistic speed)
    double timeElapsed = DateTime.now()
        .difference(lastTime)
        .inSeconds
        .toDouble();
    if (timeElapsed > 0) {
      double speed = (distance / timeElapsed) * 3600; // km/h
      if (speed > 120.0) {
        // 120 km/h max
        return false;
      }
    }

    return true;
  }

  @pragma('vm:entry-point')
  static double _calculateAccurateDistance(LatLng point1, LatLng point2) {
    // Use Geolocator's built-in distance calculation (Haversine formula)
    double distanceInMeters = Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );

    return distanceInMeters / 1000.0; // Convert to kilometers
  }
}

// import 'dart:async';
// import 'dart:ui';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:google_maps_flutter/google_maps_flutter.dart';

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
//         notificationChannelId: 'testdrive_channel',
//         initialNotificationTitle: 'Test Drive Service',
//         initialNotificationContent: 'Preparing test drive tracking...',
//         foregroundServiceNotificationId: 888,
//       ),
//     );
//   }

//   @pragma('vm:entry-point')
//   static Future<bool> onIosBackground(ServiceInstance service) async {
//     WidgetsFlutterBinding.ensureInitialized();
//     DartPluginRegistrant.ensureInitialized();
//     return true;
//   }

//   @pragma('vm:entry-point')
//   static void onStart(ServiceInstance service) async {
//     DartPluginRegistrant.ensureInitialized();

//     // Start foreground service immediately
//     if (service is AndroidServiceInstance) {
//       service.on('setAsForeground').listen((event) {
//         service.setAsForegroundService();
//       });
//       service.on('setAsBackground').listen((event) {
//         service.setAsBackgroundService();
//       });
//     }

//     IO.Socket? socket;
//     StreamSubscription<Position>? positionSubscription;
//     String? eventId;
//     double totalDistance = 0.0;
//     List<Map<String, double>> routePoints = [];
//     Timer? heartbeatTimer;
//     Timer? notificationTimer;
//     bool isServiceRunning = false;
//     LatLng? lastValidLocation;
//     DateTime? lastLocationTime;
//     DateTime? driveStartTime;

//     // Initialize with Google Maps style notification
//     _updateNotification(service, totalDistance, 0);

//     // Listen for start command from main app
//     service.on('start_tracking').listen((event) async {
//       if (isServiceRunning) return;

//       print('🚀 Background service: Starting tracking');
//       isServiceRunning = true;
//       driveStartTime = DateTime.now();

//       eventId = event!['eventId'];
//       totalDistance = event['totalDistance']?.toDouble() ?? 0.0;

//       // Set as foreground service immediately
//       if (service is AndroidServiceInstance) {
//         service.setAsForegroundService();
//       }

//       // Initialize socket
//       socket = await _initBackgroundSocket(service, eventId!);

//       // Start location tracking with improved accuracy
//       positionSubscription = await _startAccurateLocationTracking(
//         service,
//         socket,
//         eventId!,
//         totalDistance,
//         routePoints,
//         lastValidLocation,
//         lastLocationTime,
//       );

//       // Update notification every 5 seconds like Google Maps
//       notificationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
//         int duration = driveStartTime != null
//             ? DateTime.now().difference(driveStartTime!).inMinutes
//             : 0;
//         _updateNotification(service, totalDistance, duration);
//       });

//       // Heartbeat for service health
//       heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
//         print(
//           '💓 Background service heartbeat - Distance: ${totalDistance.toStringAsFixed(1)} km',
//         );
//       });
//     });

//     // Listen for stop command
//     service.on('stop_tracking').listen((event) {
//       print('🛑 Background service: Stopping tracking');
//       isServiceRunning = false;
//       positionSubscription?.cancel();
//       heartbeatTimer?.cancel();
//       notificationTimer?.cancel();
//       socket?.disconnect();
//       socket?.dispose();

//       if (service is AndroidServiceInstance) {
//         service.setAsBackgroundService();
//       }

//       service.stopSelf();
//     });

//     // Listen for data requests from main app
//     service.on('get_data').listen((event) {
//       service.invoke('data_response', {
//         'totalDistance': totalDistance,
//         'routePoints': routePoints,
//         'isRunning': isServiceRunning,
//       });
//     });
//   }

//   @pragma('vm:entry-point')
//   static void _updateNotification(
//     ServiceInstance service,
//     double distance,
//     int duration,
//   ) {
//     String distanceText = _formatDistanceForNotification(distance);
//     String durationText = duration > 0 ? '${duration}m' : 'Starting...';

//     service.invoke('update_notification', {
//       'title': 'Test Drive Active',
//       'content': '$distanceText • $durationText • Tap to return',
//     });
//   }

//   @pragma('vm:entry-point')
//   static String _formatDistanceForNotification(double distance) {
//     if (distance < 0.01) {
//       return '0.0 km';
//     } else if (distance < 1.0) {
//       return '${distance.toStringAsFixed(2)} km';
//     } else if (distance < 10.0) {
//       return '${distance.toStringAsFixed(1)} km';
//     } else {
//       return '${distance.round()} km';
//     }
//   }

//   @pragma('vm:entry-point')
//   static Future<IO.Socket?> _initBackgroundSocket(
//     ServiceInstance service,
//     String eventId,
//   ) async {
//     try {
//       final socket = IO.io('https://api.smartassistapp.in', <String, dynamic>{
//         'transports': ['websocket'],
//         'autoConnect': false,
//         'reconnection': true,
//         'reconnectionAttempts': 20,
//         'reconnectionDelay': 3000,
//         'reconnectionDelayMax': 30000,
//         'timeout': 20000,
//         'forceNew': true,
//       });

//       socket.onConnect((_) {
//         print('🔌 Background socket connected');
//         socket.emit('joinTestDrive', {'eventId': eventId});
//       });

//       socket.onDisconnect((reason) {
//         print('🔌 Background socket disconnected: $reason');
//         // Auto-reconnect
//         Timer(Duration(seconds: 5), () {
//           if (!socket.connected) {
//             socket.connect();
//           }
//         });
//       });

//       socket.connect();
//       return socket;
//     } catch (e) {
//       print('❌ Background socket init error: $e');
//       return null;
//     }
//   }

//   @pragma('vm:entry-point')
//   static Future<StreamSubscription<Position>> _startAccurateLocationTracking(
//     ServiceInstance service,
//     IO.Socket? socket,
//     String eventId,
//     double totalDistance,
//     List<Map<String, double>> routePoints,
//     LatLng? lastValidLocation,
//     DateTime? lastLocationTime,
//   ) async {
//     const LocationSettings locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.bestForNavigation, // Highest accuracy
//       distanceFilter: 3, // 3 meters minimum movement
//       timeLimit: Duration(seconds: 8),
//     );

//     return Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen(
//       (Position position) {
//         try {
//           LatLng currentLocation = LatLng(
//             position.latitude,
//             position.longitude,
//           );

//           // Validate location update using improved algorithm
//           if (!_isValidLocationUpdate(
//             position,
//             lastValidLocation,
//             lastLocationTime,
//           )) {
//             return; // Skip invalid location
//           }

//           final newPoint = {
//             'latitude': position.latitude,
//             'longitude': position.longitude,
//           };

//           // Calculate distance with improved accuracy
//           if (lastValidLocation != null) {
//             double segmentDistance = _calculateAccurateDistance(
//               lastValidLocation!,
//               currentLocation,
//             );

//             if (segmentDistance >= 0.005) {
//               // 5 meters minimum
//               totalDistance += segmentDistance;
//               lastValidLocation = currentLocation;
//               lastLocationTime = DateTime.now();

//               print(
//                 '✅ Valid segment: ${(segmentDistance * 1000).toStringAsFixed(0)}m, Total: ${totalDistance.toStringAsFixed(2)} km',
//               );
//             } else {
//               return; // Skip small movements
//             }
//           } else {
//             lastValidLocation = currentLocation;
//             lastLocationTime = DateTime.now();
//           }

//           routePoints.add(newPoint);

//           // Send to socket
//           if (socket != null && socket.connected) {
//             socket.emit('updateLocation', {
//               'eventId': eventId,
//               'newCoordinates': newPoint,
//               'totalDistance': totalDistance,
//               'timestamp': DateTime.now().millisecondsSinceEpoch,
//             });
//           }

//           // Update main app
//           service.invoke('location_update', {
//             'position': newPoint,
//             'totalDistance': totalDistance,
//             'routePoints': routePoints,
//             'timestamp': DateTime.now().millisecondsSinceEpoch,
//           });
//         } catch (e) {
//           print('❌ Error processing background location: $e');
//         }
//       },
//       onError: (error) {
//         print('❌ Background location stream error: $error');
//       },
//       cancelOnError: false,
//     );
//   }

//   @pragma('vm:entry-point')
//   static bool _isValidLocationUpdate(
//     Position position,
//     LatLng? lastLocation,
//     DateTime? lastTime,
//   ) {
//     // Check GPS accuracy (stricter for better results)
//     if (position.accuracy > 15.0) {
//       return false;
//     }

//     if (lastLocation == null || lastTime == null) {
//       return true;
//     }

//     LatLng currentLocation = LatLng(position.latitude, position.longitude);
//     double distance = _calculateAccurateDistance(lastLocation, currentLocation);

//     // Check minimum distance (5 meters)
//     if (distance < 0.005) {
//       return false;
//     }

//     // Check for GPS jumps (unrealistic speed)
//     double timeElapsed = DateTime.now()
//         .difference(lastTime)
//         .inSeconds
//         .toDouble();
//     if (timeElapsed > 0) {
//       double speed = (distance / timeElapsed) * 3600; // km/h
//       if (speed > 120.0) {
//         // 120 km/h max
//         return false;
//       }
//     }

//     return true;
//   }

//   @pragma('vm:entry-point')
//   static double _calculateAccurateDistance(LatLng point1, LatLng point2) {
//     // Use Geolocator's built-in distance calculation (Haversine formula)
//     double distanceInMeters = Geolocator.distanceBetween(
//       point1.latitude,
//       point1.longitude,
//       point2.latitude,
//       point2.longitude,
//     );

//     return distanceInMeters / 1000.0; // Convert to kilometers
//   }
// }
