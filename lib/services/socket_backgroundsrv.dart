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
      ),
    );
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    IO.Socket? socket;
    StreamSubscription<Position>? positionSubscription;
    String? eventId;
    double totalDistance = 0.0;
    List<Map<String, double>> routePoints = [];

    // Listen for start command from main app
    service.on('start_tracking').listen((event) async {
      eventId = event!['eventId'];
      totalDistance = event['totalDistance'] ?? 0.0;

      // Initialize socket in background
      await _initBackgroundSocket(socket, service, eventId!);

      // Start location tracking in background
      await _startBackgroundLocationTracking(
        service,
        socket,
        eventId!,
        totalDistance,
        routePoints,
        positionSubscription,
      );

      // Show notification
      service.invoke('update_notification', {
        'title': 'Test Drive Active',
        'content': 'Tracking your drive in background',
      });
    });

    // Listen for stop command
    service.on('stop_tracking').listen((event) {
      positionSubscription?.cancel();
      socket?.disconnect();
      service.stopSelf();
    });

    // Listen for data requests from main app
    service.on('get_data').listen((event) {
      service.invoke('data_response', {
        'totalDistance': totalDistance,
        'routePoints': routePoints,
      });
    });
  }

  static Future<void> _initBackgroundSocket(
    IO.Socket? socket,
    ServiceInstance service,
    String eventId,
  ) async {
    try {
      socket = IO.io('https://api.smartassistapp.in', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 3000,
        'reconnectionDelayMax': 10000,
        'timeout': 15000,
        'forceNew': true,
      });

      socket.onConnect((_) {
        print('Background socket connected');
        socket!.emit('joinTestDrive', {'eventId': eventId});
        service.invoke('socket_status', {'connected': true});
      });

      socket.onDisconnect((reason) {
        print('Background socket disconnected: $reason');
        service.invoke('socket_status', {'connected': false});

        // Auto-reconnect after delay
        Timer(Duration(seconds: 5), () {
          if (socket != null && !socket.connected) {
            socket.connect();
          }
        });
      });

      socket.onConnectError((data) {
        print('Background socket connection error: $data');
        service.invoke('socket_status', {
          'connected': false,
          'error': data.toString(),
        });
      });

      socket.connect();
    } catch (e) {
      print('Background socket init error: $e');
      service.invoke('socket_status', {
        'connected': false,
        'error': e.toString(),
      });
    }
  }

  static Future<void> _startBackgroundLocationTracking(
    ServiceInstance service,
    IO.Socket? socket,
    String eventId,
    double totalDistance,
    List<Map<String, double>> routePoints,
    StreamSubscription<Position>? positionSubscription,
  ) async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
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
              });
            }

            // Update main app
            service.invoke('location_update', {
              'position': newPoint,
              'totalDistance': totalDistance,
              'routePoints': routePoints,
            });

            // Update notification
            service.invoke('update_notification', {
              'title': 'Test Drive Active',
              'content': 'Distance: ${totalDistance.toStringAsFixed(2)} km',
            });
          },
        );
  }
}
