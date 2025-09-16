import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/feedback.dart';
import 'package:smartassist/widgets/testdrive_summary.dart';
import 'package:geolocator/geolocator.dart';

// Improved distance calculation with better accuracy
class DistanceCalculator {
  // Minimum distance threshold to avoid GPS noise (increased for accuracy)
  static const double MIN_DISTANCE_THRESHOLD = 0.010; // 10 meters minimum
  static const double MAX_SPEED_THRESHOLD =
      150.0; // 150 km/h max realistic speed
  static const double MIN_ACCURACY_THRESHOLD = 20.0; // 20 meters max accuracy

  // Calculate distance using Haversine formula for better accuracy
  static double calculateDistanceHaversine(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (pi / 180.0);
    double lat2Rad = point2.latitude * (pi / 180.0);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180.0);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180.0);

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in kilometers
  }

  // Validate if location update should be counted
  static bool isValidLocationUpdate(
    Position position,
    LatLng? lastLocation,
    DateTime? lastTime,
  ) {
    // Check GPS accuracy
    if (position.accuracy > MIN_ACCURACY_THRESHOLD) {
      print('❌ Location accuracy too low: ${position.accuracy}m');
      return false;
    }

    if (lastLocation == null || lastTime == null) {
      return true; // First location is always valid
    }

    LatLng currentLocation = LatLng(position.latitude, position.longitude);

    // Calculate distance moved
    double distance = calculateDistanceHaversine(lastLocation, currentLocation);

    // Check minimum distance threshold
    if (distance < MIN_DISTANCE_THRESHOLD) {
      print('❌ Distance too small: ${(distance * 1000).toStringAsFixed(1)}m');
      return false;
    }

    // Check for unrealistic speed (GPS jumps)
    double timeElapsed = DateTime.now()
        .difference(lastTime)
        .inSeconds
        .toDouble();
    if (timeElapsed > 0) {
      double speed = (distance / timeElapsed) * 3600; // km/h
      if (speed > MAX_SPEED_THRESHOLD) {
        print('❌ Unrealistic speed detected: ${speed.toStringAsFixed(1)} km/h');
        return false;
      }
    }

    return true;
  }
}

class StartDriveMap extends StatefulWidget {
  final String eventId;
  final String leadId;
  const StartDriveMap({super.key, required this.eventId, required this.leadId});

  @override
  State<StartDriveMap> createState() => _StartDriveMapState();
}

class _StartDriveMapState extends State<StartDriveMap>
    with WidgetsBindingObserver {
  late GoogleMapController mapController;

  Marker? startMarker;
  Marker? userMarker;
  Marker? endMarker;
  late Polyline routePolyline;
  List<LatLng> routePoints = [];

  bool isDriveEnded = false;
  bool isLoading = true;
  String error = '';
  double totalDistance = 0.0;
  bool _backgroundServiceStarted = false;
  Timer? _serviceHealthCheck;

  // Enhanced duration tracking
  DateTime? driveStartTime;
  DateTime? driveEndTime;
  DateTime? pauseStartTime;
  int totalPausedDuration = 0;
  bool isDrivePaused = false;

  StreamSubscription<Position>? positionStreamSubscription;
  bool isSubmitting = false;
  bool _isBackgroundServiceActive = false;
  LatLng? _lastValidLocation;
  DateTime? _lastLocationTime;
  double _totalDistanceAccumulator = 0.0;
  Timer? _locationUpdateTimer;
  bool _isBackgroundServiceStarting = false;
  static const platform = MethodChannel('testdrive_native_service');
  static const iosChannel = MethodChannel('testdrive_ios_service');

  // Enhanced constants for better accuracy
  static const double MIN_DISTANCE_THRESHOLD = 0.001; // 1 meter in km
  static const double MAX_SPEED_THRESHOLD =
      200.0; // 200 km/h max realistic speed
  static const double MIN_ACCURACY_THRESHOLD = 50.0; // 50 meters max accuracy
  static const int MAX_LOCATION_AGE = 10; // seconds
  static const int LOCATION_UPDATE_INTERVAL = 3; // seconds

  // exit popup
  DateTime? _lastBackPressTime;
  final int _exitTimeInMillis = 2000;

  String? isFromTestdrive;

  @override
  void initState() {
    super.initState();
    driveStartTime = DateTime.now();
    totalDistance = 0.0;
    WidgetsBinding.instance.addObserver(this);
    // _requestBatteryOptimization();
    _setupiOSLocationListener();
    _initializeBackgroundService();
    _determinePosition(); // This starts the permission flow
    _startServiceHealthCheck();

    routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: routePoints,
      color: AppColors.colorsBlue,
      width: 5,
    );
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      final bool isDisabled = await platform.invokeMethod(
        'isBatteryOptimizationDisabled',
      );
      if (!isDisabled) {
        _showBatteryOptimizationDialog();
      }
    } catch (e) {
      print('❌ Failed to check battery optimization: $e');
    }
  }

  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Battery Optimization',
            style: AppFont.dropDowmLabel(context),
          ),
          content: Text(
            'To ensure accurate test drive tracking in the background, please disable battery optimization for this app.',
            style: AppFont.smallText12(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await platform.invokeMethod('requestBatteryOptimization');
                } catch (e) {
                  print('❌ Failed to request battery optimization: $e');
                }
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _startServiceHealthCheck() {
    _serviceHealthCheck = Timer.periodic(Duration(seconds: 60), (timer) {
      if (_backgroundServiceStarted) {
        _checkBackgroundServiceHealth();
      }
    });
  }

  void _checkBackgroundServiceHealth() {
    final service = FlutterBackgroundService();
    service.invoke('get_data');
    service.on('data_response').listen((event) {
      bool isRunning = event?['isRunning'] ?? false;
      if (!isRunning && !isDriveEnded) {
        print('⚠️ Background service not running, attempting restart');
        _restartBackgroundService();
      }
    });
  }

  void _restartBackgroundService() {
    if (!isDriveEnded) {
      _startBackgroundService();
    }
  }

  // Missing complete iOS handling:
  Future<void> _handleiOSPermissions() async {
    print('📍 Handling iOS permissions...');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current iOS permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('📍 iOS permission after request: $permission');
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          error =
              'Location permissions are denied. Please allow access to your location.';
          isLoading = false;
        });
        _showPermissionDialog();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          error =
              'Location permissions are permanently denied. Please enable them in app settings.';
          isLoading = false;
        });
        _showPermanentlyDeniedDialog();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        print(
          '✅ iOS basic permission granted, requesting always permission...',
        );
        await _requestiOSAlwaysPermission();
        await _getiOSLocation();
      }
    } catch (e) {
      print('❌ Error handling iOS permissions: $e');
      setState(() {
        error = 'Error handling iOS permissions: $e';
        isLoading = false;
      });
    }
  }

  // Missing platform-specific instructions in _showPermissionDialog():
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Permission Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This app needs location access to track your test drive.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              if (Platform.isIOS) ...[
                Text(
                  'iOS Instructions:\n'
                  '• Tap "Grant Permission" below\n'
                  '• Choose "Allow While Using App" first\n'
                  '• Later you\'ll be asked to "Change to Always Allow" for background tracking',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ] else if (Platform.isAndroid) ...[
                Text(
                  'Android Instructions:\n'
                  '• Tap "Grant Permission" below\n'
                  '• Choose "While using the app" or "Only this time"\n'
                  '• You can change this later in settings',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showExitOrRetryDialog(); // Add this
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (Platform.isIOS) {
                  await _handleiOSPermissions();
                } else if (Platform.isAndroid) {
                  await _handleAndroidPermissions();
                }
              },
              child: Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAndroidPermissions() async {
    print('📍 Handling Android permissions...');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current Android permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('📍 Android permission after request: $permission');
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          error =
              'Location permissions are denied. Please allow access to your location.';
          isLoading = false;
        });
        _showPermissionDialog();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          error =
              'Location permissions are permanently denied. Please enable them in app settings.';
          isLoading = false;
        });
        _showPermanentlyDeniedDialog();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        print('✅ Android basic permission granted');
        await _tryRequestAndroidBackgroundPermission();
        await _getAndroidLocation();
      }
    } catch (e) {
      print('❌ Error handling Android permissions: $e');
      setState(() {
        error = 'Error handling Android permissions: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _getAndroidLocation() async {
    try {
      print('✅ Getting Android location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );
      print(
        '📍 Android location obtained: ${position.latitude}, ${position.longitude}',
      );
      _handleLocationObtained(position);
    } catch (e) {
      print('❌ Error getting Android location: $e');
      setState(() {
        error = 'Error getting Android location: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _getiOSLocation() async {
    try {
      print('✅ Getting iOS location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );
      print(
        '📍 iOS location obtained: ${position.latitude}, ${position.longitude}',
      );
      _handleLocationObtained(position);
    } catch (e) {
      print('❌ Error getting iOS location: $e');
      setState(() {
        error = 'Error getting iOS location: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'testdrive_tracking',
        initialNotificationTitle: 'Test Drive Service',
        initialNotificationContent: 'Preparing location tracking...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    print('🚀 Background service started');

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Test Drive Service',
        content: 'Initializing...',
      );
      service.setAsForegroundService();
      print('✅ Set as foreground service immediately');
    }

    String? eventId;
    double totalDistance = 0.0;

    service.on('start_tracking').listen((event) async {
      if (event != null) {
        eventId = event['eventId'];
        totalDistance = event['totalDistance']?.toDouble() ?? 0.0;

        print('📍 Starting background tracking for: $eventId');

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Test Drive Active',
            content: 'Tracking location...',
          );
        }

        Timer.periodic(Duration(seconds: 10), (timer) async {
          try {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            print(
              '📍 Background location: ${position.latitude}, ${position.longitude}',
            );

            service.invoke('location_update', {
              'position': {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
              'totalDistance': totalDistance,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          } catch (e) {
            print('❌ Background location error: $e');
          }
        });
      }
    });

    service.on('stop_tracking').listen((event) {
      print('🛑 Stopping background service');
      service.stopSelf();
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('🔄 App lifecycle state: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!isDriveEnded) {
          _startNativeBackgroundService();
        }
        break;
      case AppLifecycleState.resumed:
        _stopNativeBackgroundService();
        if (!isDriveEnded) {
          _startLocationTracking();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _startNativeBackgroundService() async {
    try {
      print('🚀 Starting native background service');

      if (Platform.isAndroid) {
        await platform.invokeMethod('startBackgroundService', {
          'eventId': widget.eventId,
          'totalDistance': totalDistance,
        });
      } else if (Platform.isIOS) {
        await iosChannel.invokeMethod('startTracking', {
          'eventId': widget.eventId,
          'distance': totalDistance,
        });
      }

      if (positionStreamSubscription != null) {
        positionStreamSubscription!.cancel();
        positionStreamSubscription = null;
      }

      print('✅ Native background service started');
    } catch (e) {
      print('❌ Failed to start native background service: $e');
    }
  }

  void _setupiOSLocationListener() {
    if (Platform.isIOS) {
      iosChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'location_update':
            if (mounted && !isDriveEnded) {
              try {
                final arguments = call.arguments as Map<dynamic, dynamic>;
                final latitude = arguments['latitude'] as double;
                final longitude = arguments['longitude'] as double;
                final distance = arguments['distance'] as double;
                final duration = arguments['duration'] as int;
                final accuracy = arguments['accuracy'] as double;

                print(
                  '📍 iOS location update: $latitude, $longitude, distance: $distance km',
                );

                setState(() {
                  final newLocation = LatLng(latitude, longitude);

                  userMarker = Marker(
                    markerId: const MarkerId('user'),
                    position: newLocation,
                    infoWindow: InfoWindow(
                      title: 'Current Location',
                      snippet: 'Accuracy: ${accuracy.toStringAsFixed(1)}m',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                  );

                  if (distance > totalDistance &&
                      distance < totalDistance + 0.5) {
                    totalDistance = distance;
                    _totalDistanceAccumulator = distance;
                  }

                  if (routePoints.isEmpty ||
                      _calculateAccurateDistance(
                            routePoints.last,
                            newLocation,
                          ) >
                          0.005) {
                    routePoints.add(newLocation);
                  }

                  _lastValidLocation = newLocation;
                  _lastLocationTime = DateTime.now();
                });

                if (mapController != null) {
                  mapController.animateCamera(
                    CameraUpdate.newLatLng(LatLng(latitude, longitude)),
                  );
                }
              } catch (e) {
                print('❌ Error processing iOS location update: $e');
              }
            }
            break;
        }
      });
    }
  }

  // ✅ FIXED: Better permission handling that doesn't exit screen immediately
  Future<void> _determinePosition() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      // Check current permission first
      LocationPermission currentPermission = await Geolocator.checkPermission();
      if (currentPermission == LocationPermission.whileInUse ||
          currentPermission == LocationPermission.always) {
        print('✅ Already have permission: $currentPermission');
        await _getCurrentLocation();
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          error =
              'Location services are disabled. Please enable location services.';
          isLoading = false;
        });
        _showLocationServiceDialog();
        return;
      }

      // Platform-specific permission handling
      if (Platform.isIOS) {
        await _handleiOSPermissions();
      } else if (Platform.isAndroid) {
        await _handleAndroidPermissions();
      }
    } catch (e) {
      print('❌ Error in _determinePosition: $e');
      setState(() {
        error = 'Error setting up location tracking: $e';
        isLoading = false;
      });
    }
  }

  // ✅ FIXED: Permission denied dialog that doesn't exit screen
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Colors.orange),
              SizedBox(width: 8),
              Text('Location Permission Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This app needs location access to track your test drive accurately.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Please grant location permission to continue with the test drive.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Show option to exit or retry
                _showExitOrRetryDialog();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Retry permission request
                await Future.delayed(Duration(milliseconds: 500));
                _determinePosition();
              },
              child: Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  // ✅ NEW: Exit or retry dialog when user cancels permission
  void _showExitOrRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Required'),
          content: Text(
            'Test drive tracking requires location access. Would you like to try again or exit?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit the test drive screen
              },
              child: Text('Exit Test Drive'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _determinePosition(); // Retry
              },
              child: Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_off, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Location Services Disabled',
                style: AppFont.dropDowmLabel(context),
              ),
            ],
          ),
          content: Text(
            'Location services are turned off. Please enable location services to track your test drive.',
            style: AppFont.smallText12(context),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit the screen
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
                // Show retry option
                Future.delayed(Duration(seconds: 2), () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Tap "Try Again" after enabling location services',
                        ),
                        action: SnackBarAction(
                          label: 'Try Again',
                          onPressed: () => _determinePosition(),
                        ),
                      ),
                    );
                  }
                });
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.red),
              SizedBox(width: 8),
              Text('Permission Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location permission was permanently denied. Please enable it manually in app settings.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              if (Platform.isIOS) ...[
                Text(
                  'Steps:\n1. Tap "Open Settings"\n2. Find this app\n3. Tap "Location"\n4. Choose "Always" or "While Using App"',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ] else if (Platform.isAndroid) ...[
                Text(
                  'Steps:\n1. Tap "Open Settings"\n2. Go to "Permissions"\n3. Tap "Location"\n4. Choose "Allow only while using the app"',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit the screen
              },
              child: Text('Exit'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
                // Show retry option
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'After enabling permissions, tap "Try Again"',
                    ),
                    duration: Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Try Again',
                      onPressed: () => _determinePosition(),
                    ),
                  ),
                );
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestiOSAlwaysPermission() async {
    if (Platform.isIOS) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse) {
          _showAlwaysPermissionDialog();
        }
        await iosChannel.invokeMethod('requestAlwaysPermission');
        print('✅ iOS always permission requested');
      } catch (e) {
        print('❌ Failed to request iOS always permission: $e');
      }
    }
  }

  void _showAlwaysPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Background Location'),
          content: Text(
            'For the best test drive tracking experience, please choose "Change to Always Allow" when prompted. This allows accurate tracking even when the app is minimized.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tryRequestAndroidBackgroundPermission() async {
    if (!Platform.isAndroid) return;

    try {
      if (await Permission.locationAlways.status.isDenied) {
        print('📍 Requesting Android background location permission...');
        PermissionStatus backgroundPermission = await Permission.locationAlways
            .request();
        print(
          '📍 Android background location permission: $backgroundPermission',
        );

        if (backgroundPermission.isDenied) {
          print(
            '⚠️ Android background location denied, but continuing with foreground only',
          );
          _showBackgroundPermissionInfo();
        } else if (backgroundPermission.isGranted) {
          print('✅ Android background location granted');
        }
      }
    } catch (e) {
      print('❌ Error requesting Android background permission: $e');
    }
  }

  void _showBackgroundPermissionInfo() {
    if (mounted) {
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'For best tracking when app is minimized, enable "Allow all the time" in location settings',
              ),
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  await openAppSettings();
                },
              ),
            ),
          );
        }
      });
    }
  }

  int _calculateDuration() {
    if (driveStartTime == null) return 0;

    DateTime endTime = driveEndTime ?? DateTime.now();
    int totalElapsed = endTime.difference(driveStartTime!).inSeconds;

    // Subtract paused duration
    int activeDrivingTime = totalElapsed - totalPausedDuration;

    // If currently paused, subtract current pause duration
    if (isDrivePaused && pauseStartTime != null) {
      int currentPauseDuration = DateTime.now()
          .difference(pauseStartTime!)
          .inSeconds;
      activeDrivingTime -= currentPauseDuration;
    }

    return (activeDrivingTime / 60).round(); // Convert to minutes
  }

  Future<void> _stopNativeBackgroundService() async {
    try {
      print('🛑 Stopping native background service');

      if (Platform.isAndroid) {
        await platform.invokeMethod('stopBackgroundService');
      } else if (Platform.isIOS) {
        await iosChannel.invokeMethod('stopTracking');
      }

      print('✅ Native background service stopped');
    } catch (e) {
      print('❌ Failed to stop native background service: $e');
    }
  }

  void _startBackgroundService() {
    if (_backgroundServiceStarted || isDriveEnded) return;

    try {
      print('🚀 Starting background service');
      final service = FlutterBackgroundService();

      service.isRunning().then((isRunning) {
        if (!isRunning) {
          service.startService();
          Future.delayed(Duration(seconds: 2), () {
            service.invoke('start_tracking', {
              'eventId': widget.eventId,
              'totalDistance': totalDistance,
              'driveStartTime': driveStartTime?.millisecondsSinceEpoch,
              'totalPausedDuration': totalPausedDuration,
            });
          });
        } else {
          service.invoke('start_tracking', {
            'eventId': widget.eventId,
            'totalDistance': totalDistance,
            'driveStartTime': driveStartTime?.millisecondsSinceEpoch,
            'totalPausedDuration': totalPausedDuration,
          });
        }
      });

      _backgroundServiceStarted = true;

      // Stop foreground location tracking
      if (positionStreamSubscription != null) {
        positionStreamSubscription!.cancel();
        positionStreamSubscription = null;
      }

      print('✅ Background service started successfully');
    } catch (e) {
      print('❌ Failed to start background service: $e');
      _backgroundServiceStarted = false;
    }
  }

  Future<void> _startTestDrive(LatLng currentLocation) async {
    try {
      final url = Uri.parse(
        'https://api.smartassistapp.in/api/events/${widget.eventId}/start-drive',
      );
      final token = await Storage.getToken();

      final requestBody = {
        'start_location': {
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📤 Sending JSON: ${json.encode(requestBody)}');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(Duration(seconds: 5));

      print('Starting test drive for event: ${widget.eventId}');
      print('📩 Response body: ${response.body}');

      print('Starting test drive for event: ${widget.eventId}');
      if (response.statusCode == 200) {
        print('Test drive started successfully');
        _startLocationTracking();
      } else {
        throw Exception('Failed to start test drive: ${response.statusCode}');
      }
    } catch (e) {
      print('Error starting test drive: $e');
      if (mounted) {
        setState(() {
          error = 'Error starting test drive: $e';
        });
      }
    }
  }

  void _processLocationUpdate(Position position) {
    if (!mounted || isDriveEnded || isDrivePaused) return;

    final LatLng newLocation = LatLng(position.latitude, position.longitude);
    final DateTime now = DateTime.now();

    // Use improved validation
    if (!_isValidLocationUpdate(newLocation, position, now)) {
      print('❌ Location update rejected: accuracy=${position.accuracy}m');
      return;
    }

    setState(() {
      userMarker = Marker(
        markerId: const MarkerId('user'),
        position: newLocation,
        infoWindow: InfoWindow(
          title: 'Current Location',
          snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(1)}m',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

      if (_lastValidLocation != null) {
        double segmentDistance = _calculateAccurateDistance(
          _lastValidLocation!,
          newLocation,
        );

        // Only add distance if movement is significant (5+ meters)
        if (segmentDistance >= 0.005) {
          _totalDistanceAccumulator += segmentDistance;
          totalDistance = _totalDistanceAccumulator;
          routePoints.add(newLocation);

          print(
            '✅ Valid movement: ${(segmentDistance * 1000).toStringAsFixed(0)}m, Total: ${totalDistance.toStringAsFixed(2)} km',
          );
        } else {
          print(
            '⏸️ Movement too small: ${(segmentDistance * 1000).toStringAsFixed(1)}m',
          );
          return; // Don't update markers for tiny movements
        }
      } else {
        routePoints.add(newLocation);
      }

      _lastValidLocation = newLocation;
      _lastLocationTime = now;
    });

    if (mapController != null) {
      mapController.animateCamera(CameraUpdate.newLatLng(newLocation));
    }
  }

  bool _isValidLocationUpdate(
    LatLng newLocation,
    Position position,
    DateTime now,
  ) {
    // More lenient accuracy check for Android
    double maxAccuracy = Platform.isAndroid
        ? 30.0
        : 15.0; // 30m for Android, 15m for iOS

    if (position.accuracy > maxAccuracy) {
      print(
        '❌ Location accuracy too low: ${position.accuracy}m (max: ${maxAccuracy}m)',
      );
      return false;
    }

    // Check location age
    if (position.timestamp != null) {
      int locationAge = now.difference(position.timestamp!).inSeconds;
      if (locationAge > 10) {
        print('❌ Location too old: ${locationAge}s');
        return false;
      }
    }

    if (_lastValidLocation == null || _lastLocationTime == null) {
      print('✅ First location - accepted');
      return true;
    }

    // Check for unrealistic speed
    double distance = _calculateAccurateDistance(
      _lastValidLocation!,
      newLocation,
    );
    double timeElapsed = now
        .difference(_lastLocationTime!)
        .inSeconds
        .toDouble();

    if (timeElapsed > 0) {
      double speed = (distance / timeElapsed) * 3600; // km/h
      if (speed > 150.0) {
        print('❌ Unrealistic speed: ${speed.toStringAsFixed(1)} km/h');
        return false;
      }
    }

    // Smaller minimum movement for better tracking
    double minMovement = Platform.isAndroid
        ? 0.003
        : 0.005; // 3m for Android, 5m for iOS

    if (distance >= minMovement) {
      print('✅ Valid movement: ${(distance * 1000).toStringAsFixed(1)}m');
      return true;
    } else {
      print(
        '⏸️ Movement too small: ${(distance * 1000).toStringAsFixed(1)}m (min: ${(minMovement * 1000).toStringAsFixed(0)}m)',
      );
      return false;
    }
  }

  void _startLocationTracking() {
    try {
      // Platform-specific location settings
      LocationSettings locationSettings;

      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy:
              LocationAccuracy.high, // Not bestForNavigation to save battery
          distanceFilter: 3, // 3 meters for Android
          timeLimit: Duration(seconds: 10), // Longer timeout for Android
          forceLocationManager: false, // Use Google Play Services
        );
      } else {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 1, // 1 meter for iOS
          pauseLocationUpdatesAutomatically: false,
          timeLimit: Duration(seconds: 8),
        );
      }

      positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              if (!isDrivePaused) {
                _processLocationUpdate(position);
              }
            },
            onError: (error) {
              print('Location stream error: $error');
              Future.delayed(Duration(seconds: 5), () {
                if (!isDriveEnded && mounted) {
                  print('Retrying location tracking...');
                  _startLocationTracking();
                }
              });
            },
          );
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  double _calculateAccurateDistance(LatLng point1, LatLng point2) {
    double distanceInMeters = Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );

    return distanceInMeters / 1000.0; // Convert to kilometers
  }

  void _handleDriveEnded(double distance, int duration) {
    if (mounted) {
      setState(() {
        driveEndTime = DateTime.now();

        if (userMarker != null) {
          endMarker = Marker(
            markerId: const MarkerId('end'),
            position: userMarker!.position,
            infoWindow: const InfoWindow(title: 'End'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          );
        }

        isDriveEnded = true;
        totalDistance = distance > 0 ? distance : totalDistance;

        if (positionStreamSubscription != null) {
          positionStreamSubscription!.cancel();
        }
      });
    }
  }

  // Format distance for display with appropriate precision
  String _formatDistance(double distance) {
    if (distance < 0.01) {
      return '0.0 km';
    } else if (distance < 0.1) {
      return '${(distance * 1000).round()} m'; // Show meters for small distances
    } else if (distance < 1.0) {
      return '${distance.toStringAsFixed(2)} km'; // 2 decimals under 1km
    } else if (distance < 10.0) {
      return '${distance.toStringAsFixed(1)} km'; // 1 decimal under 10km
    } else {
      return '${distance.round()} km'; // Whole numbers for long distances
    }
  }

  void _handleLocationObtained(Position position) {
    final LatLng currentLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    if (mounted) {
      setState(() {
        startMarker = Marker(
          markerId: const MarkerId('start'),
          position: currentLocation,
          infoWindow: const InfoWindow(title: 'Start'),
        );

        userMarker = Marker(
          markerId: const MarkerId('user'),
          position: currentLocation,
          infoWindow: const InfoWindow(title: 'User'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        );

        routePoints.add(currentLocation);
        _lastValidLocation = currentLocation;
        _lastLocationTime = DateTime.now();
        isLoading = false;
      });

      // Start the test drive
      _startTestDrive(currentLocation);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('📍 Getting current location...');

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      print(
        '📍 Location obtained: ${position.latitude}, ${position.longitude}',
      );
      _handleLocationObtained(position);
    } catch (e) {
      print('❌ Error getting current location: $e');
      setState(() {
        error = 'Failed to get current location: $e';
        isLoading = false;
      });
    }
  }

  void _cleanupResources() {
    try {
      _locationUpdateTimer?.cancel();

      if (_isBackgroundServiceActive) {
        final service = FlutterBackgroundService();
        service.invoke('stop_tracking');
        _isBackgroundServiceActive = false;
      }

      if (positionStreamSubscription != null) {
        positionStreamSubscription!.cancel();
        positionStreamSubscription = null;
      }
    } catch (e) {
      print("Error during resource cleanup: $e");
    }
  }

  @override
  void dispose() {
    _serviceHealthCheck?.cancel();
    _locationUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // Stop background service when disposing
    if (_backgroundServiceStarted) {
      final service = FlutterBackgroundService();
      service.invoke('stop_tracking');
    }

    if (Platform.isIOS) {
      _stopNativeBackgroundService();
      // ✅ ADDED: Cancel iOS notifications
      iosChannel.invokeMethod('cancelNotification').catchError((e) {
        print('Error canceling iOS notifications: $e');
      });
    }

    if (Platform.isAndroid) {
      platform.invokeMethod('cancelNotification');
    }

    _cleanupResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: isLoading
            ? const Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )
            : error.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _determinePosition,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [ 
                  GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: startMarker?.position ?? const LatLng(0, 0),
                      zoom: 16,
                    ),
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    markers: {
                      if (startMarker != null) startMarker!,
                      if (userMarker != null) userMarker!,
                      if (isDriveEnded && endMarker != null) endMarker!,
                    },
                    polylines: {routePolyline},
                  ),

                  // Drive Stats Container (positioned at top)
                  if (!isDriveEnded)
                    Positioned(
                      top: 50,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Distance: ${_formatDistance(totalDistance)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Duration: ${_calculateDuration()} mins',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (isDrivePaused)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Drive Paused',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Floating Buttons at Bottom
                  if (!isDriveEnded)
                    Positioned(
                      bottom: 40,
                      left: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // First Button - Submit Feedback Now
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      try {
                                        await _captureAndUploadImage().catchError((
                                          e,
                                        ) {
                                          print(
                                            "Screenshot capture/upload failed: $e",
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not capture map image: $e',
                                              ),
                                            ),
                                          );
                                        });
                                        await _submitEndDrive();
                                      } catch (e) {
                                        print("Error ending drive: $e");
                                        Get.snackbar(
                                          'Error',
                                          'Error ending drive: $e',
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: AppColors.colorsBlueButton,
                                elevation: 0,
                              ),
                              child: isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      'End Test Drive & Submit Feedback Now',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Second Button - Submit Feedback Later
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      try {
                                        await _captureAndUploadImage().catchError((
                                          e,
                                        ) {
                                          print(
                                            "Screenshot capture/upload failed: $e",
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not capture map image: $e',
                                              ),
                                            ),
                                          );
                                        });
                                        await _submitEndDriveNavigate();
                                      } catch (e) {
                                        print("Error ending drive: $e");
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error ending drive: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.black,
                                elevation: 0,
                              ),
                              child: isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      'End Test Drive & Submit Feedback Later',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _submitEndDrive() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      await _handleEndDrive(sendFeedback: false);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Submission failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _submitEndDriveNavigate() async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      await _handleEndDriveNavigatesummary();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Submission failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<void> _handleEndDrive({bool sendFeedback = false}) async {
    setState(() {
      isLoading = true;
    });

    try {
      // End any active pause
      if (isDrivePaused) {
        // _resumeDrive();
      }

      bool screenshotSuccess = false;
      try {
        await _captureAndUploadImage().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print("Screenshot operation timed out");
            return;
          },
        );
        screenshotSuccess = true;
      } catch (e) {
        print("Screenshot process failed: $e");
      }

      await _endTestDrive(sendFeedback: sendFeedback);
      _cleanupResources();

      if (!screenshotSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Map image could not be captured, but drive data was saved successfully',
            ),
          ),
        );
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                Feedbackscreen(leadId: widget.leadId, eventId: widget.eventId),
          ),
        );
      }
    } catch (e) {
      print("Error in end drive process: $e");
      if (mounted) {
        Get.snackbar('Error', 'Error ending drive end: $e');
      }
      _cleanupResources();
    }
  }

  Future<void> _handleEndDriveNavigatesummary() async {
    setState(() {
      isLoading = true;
    });

    try {
      // End any active pause
      if (isDrivePaused) {
        // _resumeDrive();
      }

      bool screenshotSuccess = false;
      try {
        await _captureAndUploadImage().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print("Screenshot operation timed out");
            return;
          },
        );
        screenshotSuccess = true;
      } catch (e) {
        print("Screenshot process failed: $e");
      }

      await _endTestDrive(sendFeedback: true);
      _cleanupResources();

      if (!screenshotSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Map image could not be captured, but drive data was saved successfully',
            ),
          ),
        );
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TestdriveOverview(
              isFromCompletdTimeline: false,
              eventId: widget.eventId,
              leadId: widget.leadId,
              isFromTestdrive: true,
              isFromCompletedEventId: '',
              isFromCompletedLeadId: '',
            ),
          ),
        );
      }
    } catch (e) {
      print("Error in end drive process: $e");
      if (mounted) {
        Get.snackbar('Error', 'Error ending drive: $e');
      }
      _cleanupResources();
    }
  }

  // ✅ SIMPLIFIED: Only send data to API, no socket communication
  Future<void> _endTestDrive({bool sendFeedback = false}) async {
    try {
      final uri = Uri.parse(
        'https://api.smartassistapp.in/api/events/${widget.eventId}/end-drive',
      );
      final url = uri.replace(
        queryParameters: {'send_feedback': sendFeedback.toString()},
      );

      final token = await Storage.getToken();

      // Calculate final duration ensuring pauses are accounted for
      int finalDuration = _calculateDuration();

      // ✅ FIXED: Get current location for end coordinates
      LatLng? endLocation;
      if (_lastValidLocation != null) {
        endLocation = _lastValidLocation;
      } else if (userMarker != null) {
        endLocation = userMarker!.position;
      } else if (routePoints.isNotEmpty) {
        endLocation = routePoints.last;
      }

      final requestBody = {
        'distance': totalDistance,
        'duration': finalDuration,
        'end_location': endLocation != null
            ? {
                'latitude': endLocation.latitude,
                'longitude': endLocation.longitude,
              }
            : {},
        'routePoints': routePoints
            .map(
              (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
            .toList(),
      };

      print('📤 Sending JSON: ${json.encode(requestBody)}'); // compact one-line

      // If you want pretty-printed JSON (multiline & indented):
      const encoder = JsonEncoder.withIndent('  ');
      print('📤 Sending JSON (pretty):\n${encoder.convert(requestBody)}');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 5));

      print('📩 Response status: ${response.statusCode}');
      print('📩 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('Test drive ended successfully');
        print('Duration: $finalDuration minutes');
        print('Total paused time: ${totalPausedDuration}s');
        print('Send feedback: $sendFeedback');
        _handleDriveEnded(totalDistance, finalDuration);
      } else {
        throw Exception('Failed to end drive: ${response.statusCode}');
      }
    } catch (e) {
      print('Error ending drive: $e');
      throw e;
    }
  }

  Future<void> _captureAndUploadImage() async {
    try {
      if (mapController == null) {
        print("Map controller is not initialized");
        return;
      }

      await Future.delayed(const Duration(milliseconds: 1000));

      Uint8List? image;
      for (int i = 0; i < 3; i++) {
        try {
          image = await mapController.takeSnapshot();
          if (image != null) break;
          print('Snapshot attempt ${i + 1} failed, retrying...');
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          print('Snapshot attempt ${i + 1} error: $e');
        }
      }

      if (image == null) {
        print("Failed to capture map screenshot after retries");
        return;
      }

      print('Snapshot size: ${image.lengthInBytes} bytes');

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/map_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath)..writeAsBytesSync(image);

      final uploadSuccess = await _uploadImage(file);
      if (!uploadSuccess) {
        print("Image upload failed");
      } else {
        print("Image uploaded successfully");
      }
    } catch (e) {
      print("Error capturing/uploading map image: $e");
      rethrow;
    }
  }

  Future<bool> _uploadImage(File file) async {
    final url = Uri.parse(
      'https://api.smartassistapp.in/api/events/${widget.eventId}/upload-map',
    );
    final token = await Storage.getToken();

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType('image', 'png'),
          ),
        );

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException("Image upload timed out");
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('Upload Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        String? uploadedUrl;
        if (responseData['data'] is String) {
          uploadedUrl = responseData['data'];
        } else {
          uploadedUrl =
              responseData['data']?['map_img'] ?? responseData['map_img'];
        }
        print('Uploaded Map Image URL: $uploadedUrl');
        return true;
      } else {
        print('Failed to upload image: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return false;
    } finally {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting temporary file: $e');
      }
    }
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) >
            Duration(milliseconds: _exitTimeInMillis)) {
      _lastBackPressTime = now;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Exit Testdrive',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorsBlue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to exit from Testdrive?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.colorsBlue,
                            side: const BorderSide(color: AppColors.colorsBlue),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            try {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => BottomNavigation(),
                                ),
                                (route) => false,
                              );
                            } catch (e) {
                              print("Navigation error: $e");
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => BottomNavigation(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.colorsBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Exit',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          );
        },
      );
      return false;
    }
    return true;
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/utils/bottom_navigation.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/feedback.dart';
// import 'package:smartassist/widgets/testdrive_summary.dart';
// // import 'package:smartassist/widgets/testdrive_summary.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:geolocator/geolocator.dart';
// // import 'package:get/get.dart';

// // Improved distance calculation with better accuracy
// class DistanceCalculator {
//   // Minimum distance threshold to avoid GPS noise (increased for accuracy)
//   static const double MIN_DISTANCE_THRESHOLD = 0.010; // 10 meters minimum
//   static const double MAX_SPEED_THRESHOLD =
//       150.0; // 150 km/h max realistic speed
//   static const double MIN_ACCURACY_THRESHOLD = 20.0; // 20 meters max accuracy

//   // Calculate distance using Haversine formula for better accuracy
//   static double calculateDistanceHaversine(LatLng point1, LatLng point2) {
//     const double earthRadius = 6371.0; // Earth's radius in kilometers

//     double lat1Rad = point1.latitude * (pi / 180.0);
//     double lat2Rad = point2.latitude * (pi / 180.0);
//     double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180.0);
//     double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180.0);

//     double a =
//         sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
//         cos(lat1Rad) *
//             cos(lat2Rad) *
//             sin(deltaLngRad / 2) *
//             sin(deltaLngRad / 2);
//     double c = 2 * atan2(sqrt(a), sqrt(1 - a));

//     return earthRadius * c; // Distance in kilometers
//   }

//   // Validate if location update should be counted
//   static bool isValidLocationUpdate(
//     Position position,
//     LatLng? lastLocation,
//     DateTime? lastTime,
//   ) {
//     // Check GPS accuracy
//     if (position.accuracy > MIN_ACCURACY_THRESHOLD) {
//       print('❌ Location accuracy too low: ${position.accuracy}m');
//       return false;
//     }

//     if (lastLocation == null || lastTime == null) {
//       return true; // First location is always valid
//     }

//     LatLng currentLocation = LatLng(position.latitude, position.longitude);

//     // Calculate distance moved
//     double distance = calculateDistanceHaversine(lastLocation, currentLocation);

//     // Check minimum distance threshold
//     if (distance < MIN_DISTANCE_THRESHOLD) {
//       print('❌ Distance too small: ${(distance * 1000).toStringAsFixed(1)}m');
//       return false;
//     }

//     // Check for unrealistic speed (GPS jumps)
//     double timeElapsed = DateTime.now()
//         .difference(lastTime)
//         .inSeconds
//         .toDouble();
//     if (timeElapsed > 0) {
//       double speed = (distance / timeElapsed) * 3600; // km/h
//       if (speed > MAX_SPEED_THRESHOLD) {
//         print('❌ Unrealistic speed detected: ${speed.toStringAsFixed(1)} km/h');
//         return false;
//       }
//     }

//     return true;
//   }
// }

// class StartDriveMap extends StatefulWidget {
//   final String eventId;
//   final String leadId;
//   const StartDriveMap({super.key, required this.eventId, required this.leadId});

//   @override
//   State<StartDriveMap> createState() => _StartDriveMapState();
// }

// class _StartDriveMapState extends State<StartDriveMap>
//     with WidgetsBindingObserver {
//   late GoogleMapController mapController;

  // Marker? startMarker;
  // Marker? userMarker;
  // Marker? endMarker;
  // late Polyline routePolyline;
  // List<LatLng> routePoints = [];
  // IO.Socket? socket;
  // bool isDriveEnded = false;
  // bool isLoading = true;
  // String error = '';
  // double totalDistance = 0.0;
  // bool _backgroundServiceStarted = false;
  // Timer? _serviceHealthCheck;

//   // Enhanced duration tracking
//   DateTime? driveStartTime;
//   DateTime? driveEndTime;
//   DateTime? pauseStartTime;
//   int totalPausedDuration = 0; // in seconds
//   bool isDrivePaused = false;

//   StreamSubscription<Position>? positionStreamSubscription;
//   bool isSubmitting = false;
//   bool _isBackgroundServiceActive = false;
//   LatLng? _lastValidLocation;
//   DateTime? _lastLocationTime;
//   double _totalDistanceAccumulator = 0.0;
//   Timer? _locationUpdateTimer;
//   Timer? _connectionHealthTimer;
//   int _socketReconnectAttempts = 0;

//   bool _isBackgroundServiceStarting = false;

//   static const platform = MethodChannel('testdrive_native_service');
//   static const iosChannel = MethodChannel('testdrive_ios_service');

//   // Enhanced constants for better accuracy
//   static const double MIN_DISTANCE_THRESHOLD = 0.001; // 1 meter in km
//   static const double MAX_SPEED_THRESHOLD =
//       200.0; // 200 km/h max realistic speed
//   static const double MIN_ACCURACY_THRESHOLD = 50.0; // 50 meters max accuracy
//   static const int MAX_LOCATION_AGE = 10; // seconds
//   static const int SOCKET_RECONNECT_MAX_ATTEMPTS = 10;
//   static const int LOCATION_UPDATE_INTERVAL = 3; // seconds

//   // exit popup
//   DateTime? _lastBackPressTime;
//   final int _exitTimeInMillis = 2000;

//   String? isFromTestdrive;

  // @override
  // void initState() {
  //   super.initState();
  //   driveStartTime = DateTime.now();
  //   totalDistance = 0.0;
  //   WidgetsBinding.instance.addObserver(this);
  //   _setupiOSLocationListener();
  //   _initializeBackgroundService();
  //   _determinePosition();
  //   _startServiceHealthCheck();
  //   _startConnectionHealthCheck();

  //   routePolyline = Polyline(
  //     polylineId: const PolylineId('route'),
  //     points: routePoints,
  //     color: AppColors.colorsBlue,
  //     width: 5,
  //   );
  // }

//   void _startServiceHealthCheck() {
//     _serviceHealthCheck = Timer.periodic(Duration(seconds: 60), (timer) {
//       if (_backgroundServiceStarted) {
//         _checkBackgroundServiceHealth();
//       }
//     });
//   }

//   void _checkBackgroundServiceHealth() {
//     final service = FlutterBackgroundService();

//     service.invoke('get_data');

//     // Listen for response
//     service.on('data_response').listen((event) {
//       bool isRunning = event?['isRunning'] ?? false;
//       if (!isRunning && !isDriveEnded) {
//         print('⚠️ Background service not running, attempting restart');
//         _restartBackgroundService();
//       }
//     });
//   }

//   void _restartBackgroundService() {
//     if (!isDriveEnded) {
//       _startBackgroundService();
//     }
//   }

//   void _startConnectionHealthCheck() {
//     _connectionHealthTimer = Timer.periodic(Duration(seconds: 30), (timer) {
//       if (!isDriveEnded && socket != null && !socket!.connected) {
//         print(
//           'Connection health check: Socket disconnected, attempting reconnect...',
//         );
//         _reconnectSocket();
//       }
//     });
//   }

//   void _reconnectSocket() {
//     if (_socketReconnectAttempts < SOCKET_RECONNECT_MAX_ATTEMPTS) {
//       _socketReconnectAttempts++;
//       print('Reconnect attempt $_socketReconnectAttempts');

//       Future.delayed(Duration(seconds: 2 * _socketReconnectAttempts), () {
//         if (socket != null && !socket!.connected && !isDriveEnded) {
//           socket!.connect();
//         }
//       });
//     } else {
//       print('Max reconnection attempts reached. Switching to offline mode.');
//     }
//   }

//   // Enhanced duration calculation with pause handling
//   int _calculateDuration() {
//     if (driveStartTime == null) return 0;

//     DateTime endTime = driveEndTime ?? DateTime.now();
//     int totalElapsed = endTime.difference(driveStartTime!).inSeconds;

//     // Subtract paused duration
//     int activeDrivingTime = totalElapsed - totalPausedDuration;

//     // If currently paused, subtract current pause duration
//     if (isDrivePaused && pauseStartTime != null) {
//       int currentPauseDuration = DateTime.now()
//           .difference(pauseStartTime!)
//           .inSeconds;
//       activeDrivingTime -= currentPauseDuration;
//     }

//     return (activeDrivingTime / 60).round(); // Convert to minutes
//   }

//   void _pauseDrive() {
//     if (!isDrivePaused) {
//       setState(() {
//         isDrivePaused = true;
//         pauseStartTime = DateTime.now();
//       });

//       // Stop location tracking
//       if (positionStreamSubscription != null) {
//         positionStreamSubscription!.pause();
//       }

//       print('Drive paused at ${pauseStartTime}');
//     }
//   }

//   void _resumeDrive() {
//     if (isDrivePaused && pauseStartTime != null) {
//       // Add pause duration to total
//       totalPausedDuration += DateTime.now()
//           .difference(pauseStartTime!)
//           .inSeconds;

//       setState(() {
//         isDrivePaused = false;
//         pauseStartTime = null;
//       });

//       // Resume location tracking
//       if (positionStreamSubscription != null) {
//         positionStreamSubscription!.resume();
//       }

//       print('Drive resumed. Total paused time: ${totalPausedDuration}s');
//     }
//   }

//   Future<void> _initializeBackgroundService() async {
//     final service = FlutterBackgroundService();

//     await service.configure(
//       androidConfiguration: AndroidConfiguration(
//         onStart: onStart,
//         autoStart: false,
//         isForegroundMode: true,
//         notificationChannelId: 'testdrive_tracking',
//         initialNotificationTitle: 'Test Drive Service',
//         initialNotificationContent: 'Preparing location tracking...',
//         foregroundServiceNotificationId: 888,
//         foregroundServiceTypes: [AndroidForegroundType.location],
//       ),
//       iosConfiguration: IosConfiguration(
//         autoStart: false,
//         onForeground: onStart,
//         onBackground: onIosBackground,
//       ),
//     );
//   }

//   @pragma('vm:entry-point')
//   static void onStart(ServiceInstance service) async {
//     DartPluginRegistrant.ensureInitialized();

//     print('🚀 Background service started');

//     // ✅ CRITICAL: Start foreground immediately
//     if (service is AndroidServiceInstance) {
//       service.setForegroundNotificationInfo(
//         title: 'Test Drive Service',
//         content: 'Initializing...',
//       );
//       service.setAsForegroundService();
//       print('✅ Set as foreground service immediately');
//     }

//     String? eventId;
//     double totalDistance = 0.0;

//     // Listen for start command
//     service.on('start_tracking').listen((event) async {
//       if (event != null) {
//         eventId = event['eventId'];
//         totalDistance = event['totalDistance']?.toDouble() ?? 0.0;

//         print('📍 Starting background tracking for: $eventId');

//         // Update notification
//         if (service is AndroidServiceInstance) {
//           service.setForegroundNotificationInfo(
//             title: 'Test Drive Active',
//             content: 'Tracking location...',
//           );
//         }

//         // Simple periodic location updates (no complex location streaming)
//         Timer.periodic(Duration(seconds: 10), (timer) async {
//           try {
//             Position position = await Geolocator.getCurrentPosition(
//               desiredAccuracy: LocationAccuracy.high,
//             );

//             print(
//               '📍 Background location: ${position.latitude}, ${position.longitude}',
//             );

//             // Send location update to main app
//             service.invoke('location_update', {
//               'position': {
//                 'latitude': position.latitude,
//                 'longitude': position.longitude,
//               },
//               'totalDistance': totalDistance,
//               'timestamp': DateTime.now().millisecondsSinceEpoch,
//             });
//           } catch (e) {
//             print('❌ Background location error: $e');
//           }
//         });
//       }
//     });

//     // Listen for stop command
//     service.on('stop_tracking').listen((event) {
//       print('🛑 Stopping background service');
//       service.stopSelf();
//     });
//   }

//   @pragma('vm:entry-point')
//   static Future<bool> onIosBackground(ServiceInstance service) async {
//     WidgetsFlutterBinding.ensureInitialized();
//     DartPluginRegistrant.ensureInitialized();
//     return true;
//   }

//   // @override
//   // void didChangeAppLifecycleState(AppLifecycleState state) {
//   //   super.didChangeAppLifecycleState(state);
//   //   print('🔄 App lifecycle state: $state');

//   //   switch (state) {
//   //     case AppLifecycleState.paused:
//   //     case AppLifecycleState.detached:
//   //     case AppLifecycleState.hidden:
//   //       if (!isDriveEnded && !_isBackgroundServiceStarting) {
//   //         _isBackgroundServiceStarting = true;
//   //         _startNativeBackgroundService().then((_) {
//   //           _isBackgroundServiceStarting = false;
//   //         });
//   //       }
//   //       if (!isDriveEnded) {
//   //         // ✅ Use native service instead of Flutter background service
//   //         _startNativeBackgroundService();
//   //       }
//   //       break;
//   //     case AppLifecycleState.resumed:
//   //       // ✅ Stop native service when app resumes
//   //       _stopNativeBackgroundService();
//   //       // Restart foreground tracking
//   //       if (!isDriveEnded) {
//   //         _initializeSocket();
//   //         _startLocationTracking();
//   //       }
//   //       break;
//   //     default:
//   //       break;
//   //   }
//   // }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     print('🔄 App lifecycle state: $state');

//     switch (state) {
//       case AppLifecycleState.paused:
//       case AppLifecycleState.detached:
//       case AppLifecycleState.hidden:
//         if (!isDriveEnded && !_isBackgroundServiceStarting) {
//           _isBackgroundServiceStarting = true;
//           _startNativeBackgroundService()
//               .then((_) {
//                 _isBackgroundServiceStarting = false;
//               })
//               .catchError((e) {
//                 print('❌ Error starting background service: $e');
//                 _isBackgroundServiceStarting = false;
//               });
//         }
//         break;
//       case AppLifecycleState.resumed:
//         _stopNativeBackgroundService().catchError((e) {
//           print('❌ Error stopping background service: $e');
//         });
//         if (!isDriveEnded) {
//           Future.delayed(Duration(milliseconds: 500), () {
//             if (!isDriveEnded && mounted) {
//               _initializeSocket();
//               _startLocationTracking();
//             }
//           });
//         }
//         break;
//       default:
//         break;
//     }
//   }

//   // ✅ Updated: Start native background service for both platforms
//   Future<void> _startNativeBackgroundService() async {
//     try {
//       print('🚀 Starting native background service');

//       if (Platform.isAndroid) {
//         await platform.invokeMethod('startBackgroundService', {
//           'eventId': widget.eventId,
//           'totalDistance': totalDistance,
//         });
//       } else if (Platform.isIOS) {
//         // ✅ NEW: Use iOS-specific channel
//         await iosChannel.invokeMethod('startTracking', {
//           'eventId': widget.eventId,
//           'distance': totalDistance,
//         });
//       }

//       // Stop foreground tracking to avoid conflicts
//       if (positionStreamSubscription != null) {
//         positionStreamSubscription!.cancel();
//         positionStreamSubscription = null;
//       }

//       // Disconnect foreground socket
//       if (socket != null && socket!.connected) {
//         socket!.disconnect();
//       }

//       print('✅ Native background service started');
//     } catch (e) {
//       print('❌ Failed to start native background service: $e');
//     }
//   }

//   // ✅ Updated: Stop native background service for both platforms
//   Future<void> _stopNativeBackgroundService() async {
//     try {
//       print('🛑 Stopping native background service');

//       if (Platform.isAndroid) {
//         await platform.invokeMethod('stopBackgroundService');
//       } else if (Platform.isIOS) {
//         // ✅ NEW: Use iOS-specific channel
//         await iosChannel.invokeMethod('stopTracking');
//         await iosChannel.invokeMethod('cancelNotification');
//       }

//       print('✅ Native background service stopped');
//     } catch (e) {
//       print('❌ Failed to stop native background service: $e');
//     }
//   }
//   // In your StartDriveMap widget, fix the background service handling:

//   void _startBackgroundService() {
//     if (_backgroundServiceStarted || isDriveEnded) return;

//     try {
//       print('🚀 Starting background service');
//       final service = FlutterBackgroundService();

//       // Check if service is already running
//       service.isRunning().then((isRunning) {
//         if (!isRunning) {
//           // Start the service
//           service.startService();

//           // Wait a moment for service to initialize
//           Future.delayed(Duration(seconds: 2), () {
//             // Send the start tracking command
//             service.invoke('start_tracking', {
//               'eventId': widget.eventId,
//               'totalDistance': totalDistance,
//               'driveStartTime': driveStartTime?.millisecondsSinceEpoch,
//               'totalPausedDuration': totalPausedDuration,
//             });
//           });
//         } else {
//           // Service already running, just send start tracking
//           service.invoke('start_tracking', {
//             'eventId': widget.eventId,
//             'totalDistance': totalDistance,
//             'driveStartTime': driveStartTime?.millisecondsSinceEpoch,
//             'totalPausedDuration': totalPausedDuration,
//           });
//         }
//       });

//       _backgroundServiceStarted = true;

//       // Stop foreground location tracking
//       if (positionStreamSubscription != null) {
//         positionStreamSubscription!.cancel();
//         positionStreamSubscription = null;
//       }

//       // Disconnect foreground socket
//       if (socket != null && socket!.connected) {
//         socket!.disconnect();
//       }

//       print('✅ Background service started successfully');
//     } catch (e) {
//       print('❌ Failed to start background service: $e');
//       _backgroundServiceStarted = false;
//     }
//   }

//   // ✅ NEW: Set up iOS location update listener
//   void _setupiOSLocationListener() {
//     if (Platform.isIOS) {
//       iosChannel.setMethodCallHandler((call) async {
//         switch (call.method) {
//           case 'location_update':
//             if (mounted && !isDriveEnded) {
//               try {
//                 final arguments = call.arguments as Map<dynamic, dynamic>;
//                 final latitude = arguments['latitude'] as double;
//                 final longitude = arguments['longitude'] as double;
//                 final distance = arguments['distance'] as double;
//                 final duration = arguments['duration'] as int;
//                 final accuracy = arguments['accuracy'] as double;

//                 print(
//                   '📍 iOS location update: $latitude, $longitude, distance: $distance km',
//                 );

//                 setState(() {
//                   final newLocation = LatLng(latitude, longitude);

//                   // Update user marker
//                   userMarker = Marker(
//                     markerId: const MarkerId('user'),
//                     position: newLocation,
//                     infoWindow: InfoWindow(
//                       title: 'Current Location',
//                       snippet: 'Accuracy: ${accuracy.toStringAsFixed(1)}m',
//                     ),
//                     icon: BitmapDescriptor.defaultMarkerWithHue(
//                       BitmapDescriptor.hueAzure,
//                     ),
//                   );

//                   // Update distance if it's reasonable
//                   if (distance > totalDistance &&
//                       distance < totalDistance + 0.5) {
//                     totalDistance = distance;
//                     _totalDistanceAccumulator = distance;
//                   }

//                   // Add to route points
//                   if (routePoints.isEmpty ||
//                       _calculateAccurateDistance(
//                             routePoints.last,
//                             newLocation,
//                           ) >
//                           0.005) {
//                     routePoints.add(newLocation);
//                     _updatePolyline();
//                   }

//                   _lastValidLocation = newLocation;
//                   _lastLocationTime = DateTime.now();
//                 });

//                 // Move camera to current location
//                 if (mapController != null) {
//                   mapController.animateCamera(
//                     CameraUpdate.newLatLng(LatLng(latitude, longitude)),
//                   );
//                 }

//                 // Send to socket if connected
//                 if (socket != null && socket!.connected) {
//                   socket!.emit('updateLocation', {
//                     'eventId': widget.eventId,
//                     'newCoordinates': {
//                       'latitude': latitude,
//                       'longitude': longitude,
//                     },
//                     'totalDistance': totalDistance,
//                     'duration': _calculateDuration(),
//                     'timestamp': DateTime.now().millisecondsSinceEpoch,
//                   });
//                 }
//               } catch (e) {
//                 print('❌ Error processing iOS location update: $e');
//               }
//             }
//             break;
//         }
//       });
//     }
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       print('📍 Getting current location...');

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: Duration(seconds: 15),
//       );

//       print(
//         '📍 Location obtained: ${position.latitude}, ${position.longitude}',
//       );
//       _handleLocationObtained(position);
//     } catch (e) {
//       print('❌ Error getting current location: $e');
//       setState(() {
//         error = 'Failed to get current location: $e';
//         isLoading = false;
//       });
//     }
//   }

//   // Replace your existing _determinePosition method with this:
//   Future<void> _determinePosition() async {
//     setState(() {
//       isLoading = true;
//       error = '';
//     });

//     try {
//       LocationPermission currentPermission = await Geolocator.checkPermission();
//       if (currentPermission == LocationPermission.whileInUse ||
//           currentPermission == LocationPermission.always) {
//         print('✅ Already have permission: $currentPermission');
//         await _getCurrentLocation();
//         return;
//       }
//       // First check if location services are enabled (works on both platforms)
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         setState(() {
//           error =
//               'Location services are disabled. Please enable location services in your device settings.';
//           isLoading = false;
//         });
//         _showLocationServiceDialog();
//         return;
//       }

//       // ✅ SEPARATED: Platform-specific permission handling
//       if (Platform.isIOS) {
//         await _handleiOSPermissions();
//       } else if (Platform.isAndroid) {
//         await _handleAndroidPermissions();
//       }
//     } catch (e) {
//       print('❌ Error in _determinePosition: $e');
//       setState(() {
//         error = 'Error getting location: $e';
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _handleiOSPermissions() async {
//     print('📍 Handling iOS permissions...');

//     try {
//       // Use Geolocator for iOS permission checking (more reliable)
//       LocationPermission permission = await Geolocator.checkPermission();
//       print('📍 Current iOS permission status: $permission');

//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         print('📍 iOS permission after request: $permission');
//       }

//       if (permission == LocationPermission.denied) {
//         setState(() {
//           error =
//               'Location permissions are denied. Please allow access to your location.';
//           isLoading = false;
//         });
//         _showPermissionDialog();
//         return;
//       }

//       if (permission == LocationPermission.deniedForever) {
//         setState(() {
//           error =
//               'Location permissions are permanently denied. Please enable them in app settings.';
//           isLoading = false;
//         });
//         _showPermanentlyDeniedDialog();
//         return;
//       }

//       // If we have basic permission, request always permission for background
//       if (permission == LocationPermission.whileInUse ||
//           permission == LocationPermission.always) {
//         print(
//           '✅ iOS basic permission granted, requesting always permission...',
//         );
//         await _requestiOSAlwaysPermission();

//         // Get current location
//         await _getiOSLocation();
//       }
//     } catch (e) {
//       print('❌ Error handling iOS permissions: $e');
//       setState(() {
//         error = 'Error handling iOS permissions: $e';
//         isLoading = false;
//       });
//     }
//   }

//   // ✅ NEW: Android-specific permission handling
//   Future<void> _handleAndroidPermissions() async {
//     print('📍 Handling Android permissions...');

//     try {
//       // ✅ FIXED: Use Geolocator for Android permission checking (same as iOS)
//       LocationPermission permission = await Geolocator.checkPermission();
//       print('📍 Current Android permission status: $permission');

//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         print('📍 Android permission after request: $permission');
//       }

//       if (permission == LocationPermission.denied) {
//         setState(() {
//           error =
//               'Location permissions are denied. Please allow access to your location.';
//           isLoading = false;
//         });
//         _showPermissionDialog();
//         return;
//       }

//       if (permission == LocationPermission.deniedForever) {
//         setState(() {
//           error =
//               'Location permissions are permanently denied. Please enable them in app settings.';
//           isLoading = false;
//         });
//         _showPermanentlyDeniedDialog();
//         return;
//       }

//       // ✅ If we have basic permission, try to get background permission
//       if (permission == LocationPermission.whileInUse ||
//           permission == LocationPermission.always) {
//         print('✅ Android basic permission granted');

//         // ✅ OPTIONAL: Try to get background permission for Android 10+
//         await _tryRequestAndroidBackgroundPermission();

//         // Get current location
//         await _getAndroidLocation();
//       }
//     } catch (e) {
//       print('❌ Error handling Android permissions: $e');
//       setState(() {
//         error = 'Error handling Android permissions: $e';
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _tryRequestAndroidBackgroundPermission() async {
//     if (!Platform.isAndroid) return;

//     try {
//       // Only try background permission if Android version supports it
//       if (await Permission.locationAlways.status.isDenied) {
//         print('📍 Requesting Android background location permission...');
//         PermissionStatus backgroundPermission = await Permission.locationAlways
//             .request();
//         print(
//           '📍 Android background location permission: $backgroundPermission',
//         );

//         if (backgroundPermission.isDenied) {
//           print(
//             '⚠️ Android background location denied, but continuing with foreground only',
//           );
//           // Show info dialog but don't block the flow
//           _showBackgroundPermissionInfo();
//         } else if (backgroundPermission.isGranted) {
//           print('✅ Android background location granted');
//         }
//       }
//     } catch (e) {
//       print('❌ Error requesting Android background permission: $e');
//       // Don't block the flow for background permission errors
//     }
//   }

//   void _showBackgroundPermissionInfo() {
//     // Only show this once per session
//     if (mounted) {
//       Future.delayed(Duration(seconds: 1), () {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                 'For best tracking when app is minimized, enable "Allow all the time" in location settings',
//               ),
//               duration: Duration(seconds: 4),
//               action: SnackBarAction(
//                 label: 'Settings',
//                 onPressed: () async {
//                   await openAppSettings();
//                 },
//               ),
//             ),
//           );
//         }
//       });
//     }
//   }

//   // ✅ NEW: Get location for iOS
//   Future<void> _getiOSLocation() async {
//     try {
//       print('✅ Getting iOS location...');

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: Duration(seconds: 15),
//       );

//       print(
//         '📍 iOS location obtained: ${position.latitude}, ${position.longitude}',
//       );
//       _handleLocationObtained(position);

//       // Initialize socket after successful location
//       print('🔌 Initializing socket connection...');
//       _initializeSocket();
//     } catch (e) {
//       print('❌ Error getting iOS location: $e');
//       setState(() {
//         error = 'Error getting iOS location: $e';
//         isLoading = false;
//       });
//     }
//   }

//   // ✅ NEW: Get location for Android
//   Future<void> _getAndroidLocation() async {
//     try {
//       print('✅ Getting Android location...');

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: Duration(seconds: 15),
//       );

//       print(
//         '📍 Android location obtained: ${position.latitude}, ${position.longitude}',
//       );
//       _handleLocationObtained(position);

//       // Initialize socket after successful location
//       print('🔌 Initializing socket connection...');
//       _initializeSocket();
//     } catch (e) {
//       print('❌ Error getting Android location: $e');
//       setState(() {
//         error = 'Error getting Android location: $e';
//         isLoading = false;
//       });
//     }
//   }

//   // Show dialog when location services are disabled
//   void _showLocationServiceDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.location_off, color: Colors.red),
//               SizedBox(width: 8),
//               Text(
//                 'Location Services Disable',
//                 style: AppFont.dropDowmLabel(context),
//               ),
//             ],
//           ),
//           content: Text(
//             'Location services are turned off. Please enable location services to use test drive tracking.',
//             style: AppFont.smallText12(context),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 // Open location settings
//                 await Geolocator.openLocationSettings();
//                 // Wait a bit then retry
//                 Future.delayed(Duration(seconds: 2), () {
//                   _determinePosition();
//                 });
//               },
//               child: Text('Open Settings'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//   // Show dialog for location permission
//   // void _showPermissionDialog() {
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (BuildContext context) {
//   //       return AlertDialog(
//   //         title: Row(
//   //           children: [
//   //             Icon(Icons.location_on, color: Colors.orange),
//   //             SizedBox(width: 8),
//   //             Text('Location Permission Required'),
//   //           ],
//   //         ),
//   //         content: Column(
//   //           mainAxisSize: MainAxisSize.min,
//   //           crossAxisAlignment: CrossAxisAlignment.start,
//   //           children: [
//   //             Text(
//   //               'This app needs location access to track your test drive.',
//   //               style: TextStyle(fontSize: 16),
//   //             ),
//   //             SizedBox(height: 12),
//   //             Text(
//   //               '• Allow location access in the next dialog\n'
//   //               '• For best results, choose "Allow all the time"',
//   //               style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//   //             ),
//   //           ],
//   //         ),
//   //         actions: [
//   //           TextButton(
//   //             onPressed: () {
//   //               Navigator.of(context).pop();
//   //             },
//   //             child: Text('Cancel'),
//   //           ),
//   //           ElevatedButton(
//   //             onPressed: () async {
//   //               Navigator.of(context).pop();
//   //               _determinePosition(); // Retry permission request
//   //             },
//   //             child: Text('Grant Permission'),
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }

//   // Updated permission dialog for iOS
//   void _showPermissionDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.location_on, color: Colors.orange),
//               SizedBox(width: 8),
//               Text('Location Permission Required'),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'This app needs location access to track your test drive.',
//                 style: TextStyle(fontSize: 16),
//               ),
//               SizedBox(height: 12),
//               if (Platform.isIOS) ...[
//                 Text(
//                   'iOS Instructions:\n'
//                   '• Tap "Grant Permission" below\n'
//                   '• Choose "Allow While Using App" first\n'
//                   '• Later you\'ll be asked to "Change to Always Allow" for background tracking',
//                   style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                 ),
//               ] else if (Platform.isAndroid) ...[
//                 Text(
//                   'Android Instructions:\n'
//                   '• Tap "Grant Permission" below\n'
//                   '• Choose "While using the app" or "Only this time"\n'
//                   '• You can change this later in settings',
//                   style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                 ),
//               ],
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 Navigator.of(context).pop();

//                 // ✅ Retry with platform-specific handling
//                 if (Platform.isIOS) {
//                   await _handleiOSPermissions();
//                 } else if (Platform.isAndroid) {
//                   await _handleAndroidPermissions();
//                 }
//               },
//               child: Text('Grant Permission'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // ✅ UPDATED: iOS always permission request (unchanged but cleaner)
//   Future<void> _requestiOSAlwaysPermission() async {
//     if (Platform.isIOS) {
//       try {
//         // ✅ First check current status
//         LocationPermission permission = await Geolocator.checkPermission();

//         if (permission == LocationPermission.whileInUse) {
//           // ✅ Show user a dialog explaining why we need always permission
//           _showAlwaysPermissionDialog();
//         }

//         await iosChannel.invokeMethod('requestAlwaysPermission');
//         print('✅ iOS always permission requested');
//       } catch (e) {
//         print('❌ Failed to request iOS always permission: $e');
//       }
//     }
//   }

//   void _showAlwaysPermissionDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Background Location'),
//           content: Text(
//             'For the best test drive tracking experience, please choose "Change to Always Allow" when prompted. This allows accurate tracking even when the app is minimized.',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // ✅ UPDATED: Platform-specific permanently denied dialog
//   void _showPermanentlyDeniedDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Row(
//             children: [
//               Icon(Icons.settings, color: Colors.red),
//               SizedBox(width: 8),
//               Text('Permission Required'),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Location permission has been permanently denied. Please enable it manually in settings.',
//                 style: TextStyle(fontSize: 16),
//               ),
//               SizedBox(height: 12),
//               if (Platform.isIOS) ...[
//                 Text(
//                   'iOS Steps:\n'
//                   '1. Tap "Open Settings" below\n'
//                   '2. Find this app in the list\n'
//                   '3. Tap "Location"\n'
//                   '4. Choose "Always" or "While Using App"',
//                   style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                 ),
//               ] else if (Platform.isAndroid) ...[
//                 Text(
//                   'Android Steps:\n'
//                   '1. Tap "Open Settings" below\n'
//                   '2. Go to "Permissions"\n'
//                   '3. Tap "Location"\n'
//                   '4. Choose "Allow only while using the app"',
//                   style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                 ),
//               ],
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 Navigator.of(context).pop();
//                 await openAppSettings();

//                 // Show instruction to retry
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       'After enabling permissions, tap "Try Again"',
//                     ),
//                     duration: Duration(seconds: 4),
//                     action: SnackBarAction(
//                       label: 'Try Again',
//                       onPressed: () {
//                         _determinePosition();
//                       },
//                     ),
//                   ),
//                 );
//               },
//               child: Text('Open Settings'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // Update your _handleLocationObtained method to include notification check:
//   void _handleLocationObtained(Position position) {
//     final LatLng currentLocation = LatLng(
//       position.latitude,
//       position.longitude,
//     );

//     if (mounted) {
//       setState(() {
//         startMarker = Marker(
//           markerId: const MarkerId('start'),
//           position: currentLocation,
//           infoWindow: const InfoWindow(title: 'Start'),
//         );

//         userMarker = Marker(
//           markerId: const MarkerId('user'),
//           position: currentLocation,
//           infoWindow: const InfoWindow(title: 'User'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueAzure,
//           ),
//         );

//         routePoints.add(currentLocation);
//         _updatePolyline();
//         _lastValidLocation = currentLocation;
//         _lastLocationTime = DateTime.now();
//         isLoading = false;
//       });

//       // Initialize socket (moved here from _determinePosition)
//       print('🔌 Socket connection initialized');

//       // Start the test drive
//       _startTestDrive(currentLocation);
//     }
//   }

//   void _updatePolyline() {
//     routePolyline = Polyline(
//       polylineId: const PolylineId('route'),
//       points: routePoints,
//       color: AppColors.colorsBlue,
//       width: 6,
//       patterns: [],
//       jointType: JointType.round,
//       endCap: Cap.roundCap,
//       startCap: Cap.roundCap,
//     );
//   }

//   void _initializeSocket() {
//     try {
//       socket = IO.io('https://api.smartassistapp.in', <String, dynamic>{
//         'transports': ['websocket'],
//         'autoConnect': false,
//         'reconnection': true,
//         'reconnectionAttempts': SOCKET_RECONNECT_MAX_ATTEMPTS,
//         'reconnectionDelay': 2000,
//         'reconnectionDelayMax': 10000,
//         'timeout': 15000,
//         'forceNew': true,
//       });

//       socket!.onConnect((_) {
//         print('Connected to socket');
//         _socketReconnectAttempts = 0; // Reset counter on successful connection
//         socket!.emit('joinTestDrive', {'eventId': widget.eventId});
//       });

//       socket!.onConnectError((data) {
//         print('Connection error: $data');
//         _reconnectSocket();
//       });

//       socket!.onError((data) {
//         print('Socket error: $data');
//       });

//       socket!.on('disconnect', (reason) {
//         print('Socket disconnected: $reason');
//         if (!isDriveEnded && reason != 'client namespace disconnect') {
//           _reconnectSocket();
//         }
//       });

//       socket!.on('connect_timeout', (_) {
//         print('Socket connection timeout');
//         _reconnectSocket();
//       });

//       socket!.on('reconnect', (attemptNumber) {
//         print('Socket reconnected after $attemptNumber attempts');
//         _socketReconnectAttempts = 0;
//         socket!.emit('joinTestDrive', {'eventId': widget.eventId});
//       });

//       socket!.on('locationUpdated', (data) {
//         if (mounted && !_isBackgroundServiceActive && !isDrivePaused) {
//           try {
//             if (data?['newCoordinates'] != null) {
//               LatLng serverLocation = LatLng(
//                 data['newCoordinates']['latitude'],
//                 data['newCoordinates']['longitude'],
//               );

//               if (_isValidServerLocation(serverLocation)) {
//                 setState(() {
//                   userMarker = Marker(
//                     markerId: const MarkerId('user'),
//                     position: serverLocation,
//                     infoWindow: const InfoWindow(title: 'Server Location'),
//                     icon: BitmapDescriptor.defaultMarkerWithHue(
//                       BitmapDescriptor.hueAzure,
//                     ),
//                   );

//                   if (data['totalDistance'] != null) {
//                     double serverDistance =
//                         double.tryParse(data['totalDistance'].toString()) ??
//                         0.0;
//                     if (serverDistance > totalDistance &&
//                         serverDistance < totalDistance + 0.5) {
//                       totalDistance = serverDistance;
//                       _totalDistanceAccumulator = serverDistance;
//                     }
//                   }

//                   if (mapController != null) {
//                     mapController.animateCamera(
//                       CameraUpdate.newLatLng(serverLocation),
//                     );
//                   }
//                 });
//               }
//             }
//           } catch (e) {
//             print('Error processing server location update: $e');
//           }
//         }
//       });

//       socket!.on('testDriveEnded', (data) {
//         if (mounted) {
//           try {
//             double finalDistance = data['totalDistance'] != null
//                 ? double.tryParse(data['totalDistance'].toString()) ??
//                       totalDistance
//                 : totalDistance;

//             int finalDuration = data['duration'] != null
//                 ? data['duration'] is int
//                       ? data['duration']
//                       : int.tryParse(data['duration'].toString()) ??
//                             _calculateDuration()
//                 : _calculateDuration();

//             _handleDriveEnded(finalDistance, finalDuration);
//           } catch (e) {
//             print('Error processing testDriveEnded: $e');
//           }
//         }
//       });

//       socket!.connect();
//     } catch (e) {
//       print('Socket initialization error: $e');
//       if (mounted) {
//         setState(() {
//           error = 'Error connecting to server: $e';
//         });
//       }
//     }
//   }

//   bool _isValidServerLocation(LatLng serverLocation) {
//     if (_lastValidLocation == null) return true;

//     double distance = _calculateDistanceImproved(
//       _lastValidLocation!,
//       serverLocation,
//     );
//     return distance > 0.005; // 5 meters minimum difference
//   }

//   void _sendLocationUpdate(LatLng location) {
//     if (socket != null && socket!.connected && !isDrivePaused) {
//       try {
//         socket!.emit('updateLocation', {
//           'eventId': widget.eventId,
//           'newCoordinates': {
//             'latitude': location.latitude,
//             'longitude': location.longitude,
//           },
//           'totalDistance': totalDistance,
//           'duration': _calculateDuration(),
//           'timestamp': DateTime.now().millisecondsSinceEpoch,
//         });
//       } catch (e) {
//         print('Error sending location update: $e');
//       }
//     } else if (!socket!.connected) {
//       print('Socket not connected, queuing location update...');
//       // You could implement a queue for offline updates here
//     }
//   }

//   void _cleanupResources() {
//     try {
//       _connectionHealthTimer?.cancel();
//       _locationUpdateTimer?.cancel();
//       _serviceHealthCheck?.cancel();

//       if (_isBackgroundServiceActive) {
//         final service = FlutterBackgroundService();
//         service.invoke('stop_tracking');
//         _isBackgroundServiceActive = false;
//       }

//       if (socket != null) {
//         socket!.disconnect();
//         socket!.dispose();
//         socket = null;
//       }

//       if (positionStreamSubscription != null) {
//         positionStreamSubscription!.cancel();
//         positionStreamSubscription = null;
//       }

//       if (Platform.isAndroid) {
//         platform.invokeMethod('stopBackgroundService').catchError((e) {
//           print('Error stopping Android service: $e');
//         });
//       } else if (Platform.isIOS) {
//         iosChannel.invokeMethod('stopTracking').catchError((e) {
//           print('Error stopping iOS service: $e');
//         });
//       }
//     } catch (e) {
//       print("Error during resource cleanup: $e");
//     }
//   }

//   Future<void> _startTestDrive(LatLng currentLocation) async {
//     try {
//       final url = Uri.parse(
//         'https://api.smartassistapp.in/api/events/${widget.eventId}/start-drive',
//       );
//       final token = await Storage.getToken();

//       final response = await http
//           .post(
//             url,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $token',
//             },
//             body: json.encode({
//               'startCoordinates': {
//                 'latitude': currentLocation.latitude,
//                 'longitude': currentLocation.longitude,
//               },
//               'timestamp': DateTime.now().toIso8601String(),
//             }),
//           )
//           .timeout(Duration(seconds: 15));

//       print('Starting test drive for event: ${widget.eventId}');

//       if (response.statusCode == 200) {
//         print('Test drive started successfully');
//         _startLocationTracking();
//       } else {
//         throw Exception('Failed to start test drive: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error starting test drive: $e');
//       if (mounted) {
//         setState(() {
//           error = 'Error starting test drive: $e';
//         });
//       }
//     }
//   }

//   // void _startLocationTracking() {
//   //   try {
//   //     const LocationSettings locationSettings = LocationSettings(
//   //       accuracy: LocationAccuracy.bestForNavigation,
//   //       distanceFilter: 1, // 1 meter
//   //       timeLimit: Duration(seconds: 8),
//   //     );

//   //     positionStreamSubscription =
//   //         Geolocator.getPositionStream(
//   //           locationSettings: locationSettings,
//   //         ).listen(
//   //           (Position position) {
//   //             if (!isDrivePaused) {
//   //               _processLocationUpdate(position);
//   //             }
//   //           },
//   //           onError: (error) {
//   //             print('Location stream error: $error');
//   //             Future.delayed(Duration(seconds: 5), () {
//   //               if (!isDriveEnded && mounted) {
//   //                 _startLocationTracking();
//   //               }
//   //             });
//   //           },
//   //         );
//   //   } catch (e) {
//   //     print('Error starting location tracking: $e');
//   //   }
//   // }

//   void _processLocationUpdate(Position position) {
//     if (!mounted || isDriveEnded || isDrivePaused) return;

//     final LatLng newLocation = LatLng(position.latitude, position.longitude);
//     final DateTime now = DateTime.now();

//     // Use improved validation
//     if (!_isValidLocationUpdate(newLocation, position, now)) {
//       print('❌ Location update rejected: accuracy=${position.accuracy}m');
//       return;
//     }

//     setState(() {
//       userMarker = Marker(
//         markerId: const MarkerId('user'),
//         position: newLocation,
//         infoWindow: InfoWindow(
//           title: 'Current Location',
//           snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(1)}m',
//         ),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
//       );

//       if (_lastValidLocation != null) {
//         double segmentDistance = _calculateAccurateDistance(
//           _lastValidLocation!,
//           newLocation,
//         );

//         // Only add distance if movement is significant (5+ meters)
//         if (segmentDistance >= 0.005) {
//           _totalDistanceAccumulator += segmentDistance;
//           totalDistance = _totalDistanceAccumulator;
//           routePoints.add(newLocation);
//           _updatePolyline();

//           print(
//             '✅ Valid movement: ${(segmentDistance * 1000).toStringAsFixed(0)}m, Total: ${totalDistance.toStringAsFixed(2)} km',
//           );
//         } else {
//           print(
//             '⏸️ Movement too small: ${(segmentDistance * 1000).toStringAsFixed(1)}m',
//           );
//           return; // Don't update markers for tiny movements
//         }
//       } else {
//         routePoints.add(newLocation);
//         _updatePolyline();
//       }

//       _lastValidLocation = newLocation;
//       _lastLocationTime = now;
//     });

//     if (mapController != null) {
//       mapController.animateCamera(CameraUpdate.newLatLng(newLocation));
//     }

//     _throttledLocationUpdate(newLocation);
//   }

//   // ✅ FIXED: Relaxed location validation for better Android performance
//   bool _isValidLocationUpdate(
//     LatLng newLocation,
//     Position position,
//     DateTime now,
//   ) {
//     // ✅ RELAXED: More lenient accuracy check for Android
//     double maxAccuracy = Platform.isAndroid
//         ? 30.0
//         : 15.0; // 30m for Android, 15m for iOS

//     if (position.accuracy > maxAccuracy) {
//       print(
//         '❌ Location accuracy too low: ${position.accuracy}m (max: ${maxAccuracy}m)',
//       );
//       return false;
//     }

//     // Check location age
//     if (position.timestamp != null) {
//       int locationAge = now.difference(position.timestamp!).inSeconds;
//       if (locationAge > 10) {
//         print('❌ Location too old: ${locationAge}s');
//         return false;
//       }
//     }

//     if (_lastValidLocation == null || _lastLocationTime == null) {
//       print('✅ First location - accepted');
//       return true;
//     }

//     // Check for unrealistic speed
//     double distance = _calculateAccurateDistance(
//       _lastValidLocation!,
//       newLocation,
//     );
//     double timeElapsed = now
//         .difference(_lastLocationTime!)
//         .inSeconds
//         .toDouble();

//     if (timeElapsed > 0) {
//       double speed = (distance / timeElapsed) * 3600; // km/h
//       if (speed > 150.0) {
//         // Increased from 120 to 150 km/h
//         print('❌ Unrealistic speed: ${speed.toStringAsFixed(1)} km/h');
//         return false;
//       }
//     }

//     // ✅ RELAXED: Smaller minimum movement for better tracking
//     double minMovement = Platform.isAndroid
//         ? 0.003
//         : 0.005; // 3m for Android, 5m for iOS

//     if (distance >= minMovement) {
//       print('✅ Valid movement: ${(distance * 1000).toStringAsFixed(1)}m');
//       return true;
//     } else {
//       print(
//         '⏸️ Movement too small: ${(distance * 1000).toStringAsFixed(1)}m (min: ${(minMovement * 1000).toStringAsFixed(0)}m)',
//       );
//       return false;
//     }
//   }

//   // ✅ UPDATED: Better location settings for Android
//   void _startLocationTracking() {
//     try {
//       // ✅ Platform-specific location settings
//       LocationSettings locationSettings;

//       if (Platform.isAndroid) {
//         locationSettings = AndroidSettings(
//           accuracy:
//               LocationAccuracy.high, // Not bestForNavigation to save battery
//           distanceFilter: 3, // 3 meters for Android
//           timeLimit: Duration(seconds: 10), // Longer timeout for Android
//           forceLocationManager: false, // Use Google Play Services
//         );
//       } else {
//         locationSettings = AppleSettings(
//           accuracy: LocationAccuracy.bestForNavigation,
//           activityType: ActivityType.automotiveNavigation,
//           distanceFilter: 1, // 1 meter for iOS
//           pauseLocationUpdatesAutomatically: false,
//           timeLimit: Duration(seconds: 8),
//         );
//       }

//       positionStreamSubscription =
//           Geolocator.getPositionStream(
//             locationSettings: locationSettings,
//           ).listen(
//             (Position position) {
//               if (!isDrivePaused) {
//                 _processLocationUpdate(position);
//               }
//             },
//             onError: (error) {
//               print('Location stream error: $error');
//               Future.delayed(Duration(seconds: 5), () {
//                 if (!isDriveEnded && mounted) {
//                   print('Retrying location tracking...');
//                   _startLocationTracking();
//                 }
//               });
//             },
//           );
//     } catch (e) {
//       print('Error starting location tracking: $e');
//     }
//   }

//   double _calculateAccurateDistance(LatLng point1, LatLng point2) {
//     double distanceInMeters = Geolocator.distanceBetween(
//       point1.latitude,
//       point1.longitude,
//       point2.latitude,
//       point2.longitude,
//     );

//     return distanceInMeters / 1000.0; // Convert to kilometers
//   }

//   double _calculateDistanceImproved(LatLng point1, LatLng point2) {
//     double distanceInMeters = Geolocator.distanceBetween(
//       point1.latitude,
//       point1.longitude,
//       point2.latitude,
//       point2.longitude,
//     );

//     return double.parse((distanceInMeters / 1000.0).toStringAsFixed(6));
//   }

//   void _throttledLocationUpdate(LatLng location) {
//     _locationUpdateTimer?.cancel();
//     _locationUpdateTimer = Timer(
//       Duration(seconds: LOCATION_UPDATE_INTERVAL),
//       () {
//         _sendLocationUpdate(location);
//       },
//     );
//   }

//   void _handleDriveEnded(double distance, int duration) {
//     if (mounted) {
//       setState(() {
//         driveEndTime = DateTime.now();

//         if (userMarker != null) {
//           endMarker = Marker(
//             markerId: const MarkerId('end'),
//             position: userMarker!.position,
//             infoWindow: const InfoWindow(title: 'End'),
//             icon: BitmapDescriptor.defaultMarkerWithHue(
//               BitmapDescriptor.hueRed,
//             ),
//           );
//         }

//         isDriveEnded = true;
//         totalDistance = distance > 0 ? distance : totalDistance;

//         if (positionStreamSubscription != null) {
//           positionStreamSubscription!.cancel();
//         }
//       });
//     }
//   }

//   // Format distance for display with appropriate precision
//   String _formatDistance(double distance) {
//     if (distance < 0.01) {
//       return '0.0 km';
//     } else if (distance < 0.1) {
//       return '${(distance * 1000).round()} m'; // Show meters for small distances
//     } else if (distance < 1.0) {
//       return '${distance.toStringAsFixed(2)} km'; // 2 decimals under 1km
//     } else if (distance < 10.0) {
//       return '${distance.toStringAsFixed(1)} km'; // 1 decimal under 10km
//     } else {
//       return '${distance.round()} km'; // Whole numbers for long distances
//     }
//   }

//   @override
//   void dispose() {
//     _serviceHealthCheck?.cancel();
//     _locationUpdateTimer?.cancel();
//     _connectionHealthTimer?.cancel();
//     WidgetsBinding.instance.removeObserver(this);

//     // Stop background service when disposing
//     if (_backgroundServiceStarted) {
//       final service = FlutterBackgroundService();
//       service.invoke('stop_tracking');
//     }

//     // ✅ NEW: Stop iOS native service
//     // if (Platform.isIOS) {
//     //   _stopNativeBackgroundService();
//     // }

//     if (Platform.isIOS) {
//       _stopNativeBackgroundService();
//       // ✅ ADDED: Cancel iOS notifications
//       iosChannel.invokeMethod('cancelNotification').catchError((e) {
//         print('Error canceling iOS notifications: $e');
//       });
//     }

//     if (Platform.isAndroid) {
//       platform.invokeMethod('cancelNotification');
//     }

//     _cleanupResources();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: _onWillPop,
//       child: Scaffold(
//         body: isLoading
//             ? const Center(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 16),
//                     Text(
//                       'Getting your location...',
//                       style: TextStyle(fontSize: 16),
//                     ),
//                   ],
//                 ),
//               )
//             : error.isNotEmpty
//             ? Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(
//                       Icons.error_outline,
//                       color: Colors.red,
//                       size: 48,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       error,
//                       style: const TextStyle(color: Colors.red, fontSize: 16),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 24),
//                     ElevatedButton(
//                       onPressed: _determinePosition,
//                       child: const Text('Try Again'),
//                     ),
//                   ],
//                 ),
//               )
//             : Stack(
//                 children: [
//                   // Fullscreen Google Map
//                   GoogleMap(
//                     onMapCreated: (GoogleMapController controller) {
//                       mapController = controller;
//                     },
//                     initialCameraPosition: CameraPosition(
//                       target: startMarker?.position ?? const LatLng(0, 0),
//                       zoom: 16,
//                     ),
//                     myLocationEnabled: true,
//                     zoomControlsEnabled: false,
//                     mapToolbarEnabled: false,
//                     compassEnabled: false,
//                     markers: {
//                       if (startMarker != null) startMarker!,
//                       if (userMarker != null) userMarker!,
//                       if (isDriveEnded && endMarker != null) endMarker!,
//                     },
//                     polylines: {routePolyline},
//                   ),

//                   // Drive Stats Container (positioned at top)
//                   if (!isDriveEnded)
//                     Positioned(
//                       top: 50,
//                       left: 16,
//                       right: 16,
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 8,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   'Distance: ${_formatDistance(totalDistance)}',
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                                 Text(
//                                   'Duration: ${_calculateDuration()} mins',
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             if (isDrivePaused)
//                               Padding(
//                                 padding: const EdgeInsets.only(top: 8.0),
//                                 child: Text(
//                                   'Drive Paused',
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w500,
//                                     color: Colors.orange,
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),

//                   // Floating Buttons at Bottom
//                   if (!isDriveEnded)
//                     Positioned(
//                       bottom: 40,
//                       left: 16,
//                       right: 16,
//                       child: Column(
//                         children: [
//                           // First Button - Submit Feedback Now
//                           Container(
//                             width: double.infinity,
//                             height: 56,
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(12),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   blurRadius: 12,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: ElevatedButton(
//                               onPressed: isSubmitting
//                                   ? null
//                                   : () async {
//                                       try {
//                                         await _captureAndUploadImage().catchError((
//                                           e,
//                                         ) {
//                                           print(
//                                             "Screenshot capture/upload failed: $e",
//                                           );
//                                           ScaffoldMessenger.of(
//                                             context,
//                                           ).showSnackBar(
//                                             SnackBar(
//                                               content: Text(
//                                                 'Could not capture map image: $e',
//                                               ),
//                                             ),
//                                           );
//                                         });
//                                         await _submitEndDrive();
//                                       } catch (e) {
//                                         print("Error ending drive: $e");
//                                         //   ScaffoldMessenger.of(
//                                         //     context,
//                                         //   ).showSnackBar(
//                                         //     SnackBar(
//                                         //       content: Text(
//                                         //         'Error ending drive: $e',
//                                         //       ),
//                                         //     ),
//                                         //   );
//                                         // }
//                                         Get.snackbar(
//                                           'Error',
//                                           'Error ending drive: $e',
//                                         );
//                                       }
//                                     },
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 16,
//                                 ),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 backgroundColor: AppColors.colorsBlueButton,
//                                 elevation: 0,
//                               ),
//                               child: isSubmitting
//                                   ? const CircularProgressIndicator(
//                                       color: Colors.white,
//                                       strokeWidth: 2,
//                                     )
//                                   : Text(
//                                       'End Test Drive & Submit Feedback Now',
//                                       style: GoogleFonts.poppins(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w600,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                             ),
//                           ),

//                           const SizedBox(height: 12),

//                           // Second Button - Submit Feedback Later
//                           Container(
//                             width: double.infinity,
//                             height: 56,
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(12),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   blurRadius: 12,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: ElevatedButton(
//                               onPressed: isSubmitting
//                                   ? null
//                                   : () async {
//                                       try {
//                                         await _captureAndUploadImage().catchError((
//                                           e,
//                                         ) {
//                                           print(
//                                             "Screenshot capture/upload failed: $e",
//                                           );
//                                           ScaffoldMessenger.of(
//                                             context,
//                                           ).showSnackBar(
//                                             SnackBar(
//                                               content: Text(
//                                                 'Could not capture map image: $e',
//                                               ),
//                                             ),
//                                           );
//                                         });
//                                         await _submitEndDriveNavigate();
//                                       } catch (e) {
//                                         print("Error ending drive: $e");
//                                         ScaffoldMessenger.of(
//                                           context,
//                                         ).showSnackBar(
//                                           SnackBar(
//                                             content: Text(
//                                               'Error ending drive: $e',
//                                             ),
//                                           ),
//                                         );
//                                       }
//                                     },
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 16,
//                                 ),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 backgroundColor: Colors.black,
//                                 elevation: 0,
//                               ),
//                               child: isSubmitting
//                                   ? const CircularProgressIndicator(
//                                       color: Colors.white,
//                                       strokeWidth: 2,
//                                     )
//                                   : Text(
//                                       'End Test Drive & Submit Feedback Later',
//                                       style: GoogleFonts.poppins(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w600,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//       ),
//     );
//   }

//   Future<void> _submitEndDrive() async {
//     if (isSubmitting) return;

//     setState(() {
//       isSubmitting = true;
//     });

//     try {
//       await _handleEndDrive(sendFeedback: false);
//     } catch (e) {
//       Get.snackbar(
//         'Error',
//         'Submission failed: ${e.toString()}',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isSubmitting = false);
//       }
//     }
//   }

//   Future<void> _submitEndDriveNavigate() async {
//     if (isSubmitting) return;

//     setState(() {
//       isSubmitting = true;
//     });

//     try {
//       await _handleEndDriveNavigatesummary();
//     } catch (e) {
//       Get.snackbar(
//         'Error',
//         'Submission failed: ${e.toString()}',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isSubmitting = false);
//       }
//     }
//   }

//   Future<void> _handleEndDrive({bool sendFeedback = false}) async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       // End any active pause
//       if (isDrivePaused) {
//         _resumeDrive();
//       }

//       bool screenshotSuccess = false;
//       try {
//         await _captureAndUploadImage().timeout(
//           const Duration(seconds: 10),
//           onTimeout: () {
//             print("Screenshot operation timed out");
//             return;
//           },
//         );
//         screenshotSuccess = true;
//       } catch (e) {
//         print("Screenshot process failed: $e");
//       }

//       await _endTestDrive(sendFeedback: sendFeedback);
//       _cleanupResources();

//       if (!screenshotSuccess && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'Map image could not be captured, but drive data was saved successfully',
//             ),
//           ),
//         );
//       }

//       if (mounted) {
//         await Future.delayed(const Duration(milliseconds: 300));
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (context) =>
//                 Feedbackscreen(leadId: widget.leadId, eventId: widget.eventId),
//           ),
//         );
//       }
//     } catch (e) {
//       print("Error in end drive process: $e");
//       if (mounted) {
//         // ScaffoldMessenger.of(
//         //   context,
//         // ).showSnackBar(SnackBar(content: Text('Error ending test drive: $e')));
//         // setState(() {
//         //   isLoading = false;
//         // });
//         Get.snackbar('Error', 'Error ending drive end: $e');
//       }
//       _cleanupResources();
//     }
//   }

//   Future<void> _handleEndDriveNavigatesummary() async {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       // End any active pause
//       if (isDrivePaused) {
//         _resumeDrive();
//       }

//       bool screenshotSuccess = false;
//       try {
//         await _captureAndUploadImage().timeout(
//           const Duration(seconds: 5),
//           onTimeout: () {
//             print("Screenshot operation timed out");
//             return;
//           },
//         );
//         screenshotSuccess = true;
//       } catch (e) {
//         print("Screenshot process failed: $e");
//       }

//       await _endTestDrive(sendFeedback: true);
//       _cleanupResources();

//       if (!screenshotSuccess && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               'Map image could not be captured, but drive data was saved successfully',
//             ),
//           ),
//         );
//       }

//       if (mounted) {
//         await Future.delayed(const Duration(milliseconds: 300));
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (context) => TestdriveOverview(
//               isFromCompletdTimeline: false,
//               eventId: widget.eventId,
//               leadId: widget.leadId,
//               isFromTestdrive: true,
//               isFromCompletedEventId: '',
//               isFromCompletedLeadId: '',
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       print("Error in end drive process: $e");
//       if (mounted) {
//         // ScaffoldMessenger.of(
//         //   context,
//         // ).showSnackBar(SnackBar(content: Text('Error ending test drive: $e')));
//         // setState(() {
//         //   isLoading = false;
//         // });
//         Get.snackbar('Error', 'Error ending drive: $e');
//       }
//       _cleanupResources();
//     }
//   }

//   Future<void> _endTestDrive({bool sendFeedback = false}) async {
//     try {
//       final uri = Uri.parse(
//         'https://api.smartassistapp.in/api/events/${widget.eventId}/end-drive',
//       );
//       final url = uri.replace(
//         queryParameters: {'send_feedback': sendFeedback.toString()},
//       );

//       final token = await Storage.getToken();

//       // Calculate final duration ensuring pauses are accounted for
//       int finalDuration = _calculateDuration();

//       final response = await http
//           .post(
//             url,
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $token',
//             },
//             body: json.encode({
//               'totalDistance': totalDistance,
//               'duration': finalDuration,
//               'startTime': driveStartTime?.toIso8601String(),
//               'endTime': DateTime.now().toIso8601String(),
//               'totalPausedDuration': totalPausedDuration,
//               'routePoints': routePoints
//                   .map(
//                     (point) => {
//                       'latitude': point.latitude,
//                       'longitude': point.longitude,
//                     },
//                   )
//                   .toList(),
//             }),
//           )
//           .timeout(const Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         print('Test drive ended successfully');
//         print('Duration: $finalDuration minutes');
//         print('Total paused time: ${totalPausedDuration}s');
//         print('Send feedback: $sendFeedback');
//         _handleDriveEnded(totalDistance, finalDuration);
//       } else {
//         throw Exception('Failed to end drive: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error ending drive: $e');
//       throw e;
//     }
//   }

//   Future<void> _captureAndUploadImage() async {
//     try {
//       if (mapController == null) {
//         print("Map controller is not initialized");
//         return;
//       }

//       await Future.delayed(const Duration(milliseconds: 1000));

//       Uint8List? image;
//       for (int i = 0; i < 3; i++) {
//         try {
//           image = await mapController.takeSnapshot();
//           if (image != null) break;
//           print('Snapshot attempt ${i + 1} failed, retrying...');
//           await Future.delayed(const Duration(milliseconds: 500));
//         } catch (e) {
//           print('Snapshot attempt ${i + 1} error: $e');
//         }
//       }

//       if (image == null) {
//         print("Failed to capture map screenshot after retries");
//         return;
//       }

//       print('Snapshot size: ${image.lengthInBytes} bytes');

//       final directory = await getTemporaryDirectory();
//       final filePath =
//           '${directory.path}/map_image_${DateTime.now().millisecondsSinceEpoch}.png';
//       final file = File(filePath)..writeAsBytesSync(image);

//       final uploadSuccess = await _uploadImage(file);
//       if (!uploadSuccess) {
//         print("Image upload failed");
//       } else {
//         print("Image uploaded successfully");
//       }
//     } catch (e) {
//       print("Error capturing/uploading map image: $e");
//       rethrow;
//     }
//   }

//   Future<bool> _uploadImage(File file) async {
//     final url = Uri.parse(
//       'https://api.smartassistapp.in/api/events/${widget.eventId}/upload-map',
//     );
//     final token = await Storage.getToken();

//     try {
//       var request = http.MultipartRequest('POST', url)
//         ..headers['Authorization'] = 'Bearer $token'
//         ..files.add(
//           await http.MultipartFile.fromPath(
//             'file',
//             file.path,
//             contentType: MediaType('image', 'png'),
//           ),
//         );

//       var streamedResponse = await request.send().timeout(
//         const Duration(seconds: 15),
//         onTimeout: () {
//           throw TimeoutException("Image upload timed out");
//         },
//       );

//       final response = await http.Response.fromStream(streamedResponse);
//       print('Upload Response: ${response.body}');

//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//         String? uploadedUrl;
//         if (responseData['data'] is String) {
//           uploadedUrl = responseData['data'];
//         } else {
//           uploadedUrl =
//               responseData['data']?['map_img'] ?? responseData['map_img'];
//         }
//         print('Uploaded Map Image URL: $uploadedUrl');
//         return true;
//       } else {
//         print('Failed to upload image: ${response.statusCode}');
//         return false;
//       }
//     } catch (e) {
//       print('Error uploading image: $e');
//       return false;
//     } finally {
//       try {
//         if (await file.exists()) {
//           await file.delete();
//         }
//       } catch (e) {
//         print('Error deleting temporary file: $e');
//       }
//     }
//   }

//   Future<bool> _onWillPop() async {
//     final now = DateTime.now();
//     if (_lastBackPressTime == null ||
//         now.difference(_lastBackPressTime!) >
//             Duration(milliseconds: _exitTimeInMillis)) {
//       _lastBackPressTime = now;

//       showModalBottomSheet(
//         context: context,
//         backgroundColor: Colors.transparent,
//         builder: (BuildContext context) {
//           return Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(20),
//                 topRight: Radius.circular(20),
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 10,
//                   spreadRadius: 0,
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const SizedBox(height: 20),
//                 Text(
//                   'Exit Testdrive',
//                   style: GoogleFonts.poppins(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.colorsBlue,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   'Are you sure you want to exit from Testdrive?',
//                   style: GoogleFonts.poppins(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w400,
//                     color: Colors.black54,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.white,
//                             foregroundColor: AppColors.colorsBlue,
//                             side: const BorderSide(color: AppColors.colorsBlue),
//                             elevation: 0,
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                           ),
//                           child: Text(
//                             'Cancel',
//                             style: GoogleFonts.poppins(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 15),
//                       Expanded(
//                         child: ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             try {
//                               Navigator.of(context).pushAndRemoveUntil(
//                                 MaterialPageRoute(
//                                   builder: (context) => BottomNavigation(),
//                                 ),
//                                 (route) => false,
//                               );
//                             } catch (e) {
//                               print("Navigation error: $e");
//                               Navigator.of(context).push(
//                                 MaterialPageRoute(
//                                   builder: (context) => BottomNavigation(),
//                                 ),
//                               );
//                             }
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.colorsBlue,
//                             foregroundColor: Colors.white,
//                             elevation: 0,
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                           ),
//                           child: Text(
//                             'Exit',
//                             style: GoogleFonts.poppins(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 25),
//               ],
//             ),
//           );
//         },
//       );
//       return false;
//     }
//     return true;
//   }
// }
