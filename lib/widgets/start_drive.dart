import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/home_screen.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/feedback.dart';
import 'package:smartassist/widgets/testdrive_overview.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';

class StartDriveMap extends StatefulWidget {
  final String eventId;
  final String leadId;
  const StartDriveMap({super.key, required this.eventId, required this.leadId});

  @override
  State<StartDriveMap> createState() => _StartDriveMapState();
}

class _StartDriveMapState extends State<StartDriveMap> {
  late GoogleMapController mapController;
  Marker? startMarker;
  Marker? userMarker;
  Marker? endMarker;
  late Polyline routePolyline;
  List<LatLng> routePoints = [];
  IO.Socket? socket;
  bool isDriveEnded = false;
  bool isLoading = true;
  String error = '';
  double totalDistance = 0;
  int driveDuration = 0;
  StreamSubscription<Position>? positionStreamSubscription;
  DateTime? startTime;
  bool isSubmitting = false;

  // exit popup
  DateTime? _lastBackPressTime;
  final int _exitTimeInMillis = 2000;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now(); // Track when drive started
    // _screenshotController = ScreenshotController();
    _determinePosition();

    routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: routePoints,
      color: Colors.blue,
      width: 5,
    );
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        error =
            'Location services are disabled. Please enable location services in your device settings.';
        isLoading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          error =
              'Location permissions are denied. Please allow access to your location.';
          isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        error =
            'Location permissions are permanently denied. Please enable them in app settings.';
        isLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _handleLocationObtained(position);
    } catch (e) {
      setState(() {
        error = 'Error getting location: $e';
        isLoading = false;
      });
    }
  }

  void _handleLocationObtained(Position position) {
    final LatLng currentLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    if (mounted) {
      setState(() {
        // Initialize start marker at current location
        startMarker = Marker(
          markerId: const MarkerId('start'),
          position: currentLocation,
          infoWindow: const InfoWindow(title: 'Start'),
        );

        // Initialize user marker at current location
        userMarker = Marker(
          markerId: const MarkerId('user'),
          position: currentLocation,
          infoWindow: const InfoWindow(title: 'User'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        );

        // Add the first point to route
        routePoints.add(currentLocation);

        // Update the polyline
        _updatePolyline();

        isLoading = false;
      });

      // Now that we have location, initialize socket and start the drive
      _initializeSocket();
      _startTestDrive(currentLocation);
    }
  }

  void _updatePolyline() {
    routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: routePoints,
      color: Colors.blue,
      width: 5,
    );
  }

  // Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // Convert to km
  }

  Timer? _throttleTimer;

  // Initialize the Socket.IO connection
  void _initializeSocket() {
    try {
      socket = IO.io('wss://api.smartassistapp.in', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      socket!.onConnect((_) {
        print('Connected to socket');
        socket!.emit('joinTestDrive', {'eventId': widget.eventId});
      });

      socket!.onConnectError((data) {
        print('Connection error: $data');
        if (socket != null && !socket!.connected) {
          socket!.connect();
        }
      });

      socket!.onError((data) {
        print('Socket error: $data');
      });

      socket!.on('disconnect', (_) {
        print('Socket disconnected');
        if (!isDriveEnded && socket != null) {
          socket!.connect();
        }
      });

      socket!.on('locationUpdated', (data) {
        if (mounted) {
          if (data == null || data['newCoordinates'] == null) {
            print('Received invalid location update data');
            return;
          }

          // Throttle updates to once every 3 seconds
          if (_throttleTimer?.isActive ?? false) return;
          _throttleTimer = Timer(const Duration(seconds: 3), () {});

          try {
            setState(() {
              LatLng newCoordinates = LatLng(
                data['newCoordinates']['latitude'],
                data['newCoordinates']['longitude'],
              );

              userMarker = Marker(
                markerId: const MarkerId('user'),
                position: newCoordinates,
                infoWindow: const InfoWindow(title: 'User'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              );

              if (routePoints.isNotEmpty) {
                LatLng lastPoint = routePoints.last;
                double segmentDistance = _calculateDistance(
                  lastPoint,
                  newCoordinates,
                );
                totalDistance += segmentDistance;
              }

              routePoints.add(newCoordinates);
              _updatePolyline();

              if (data['totalDistance'] != null) {
                totalDistance =
                    double.tryParse(data['totalDistance'].toString()) ??
                    totalDistance;
              }

              if (mapController != null) {
                mapController.animateCamera(
                  CameraUpdate.newLatLng(newCoordinates),
                );
              }
            });
          } catch (e) {
            print('Error processing location update: $e');
          }
        }
      });

      socket!.on('testDriveEnded', (data) {
        if (mounted) {
          try {
            double finalDistance = data['totalDistance'] != null
                ? double.tryParse(data['totalDistance'].toString()) ??
                      totalDistance
                : totalDistance;

            int finalDuration = data['duration'] != null
                ? data['duration'] is int
                      ? data['duration']
                      : int.tryParse(data['duration'].toString()) ??
                            _calculateDuration()
                : _calculateDuration();

            _handleDriveEnded(finalDistance, finalDuration);
          } catch (e) {
            print('Error processing testDriveEnded: $e');
          }
        }
      });

      socket!.connect();
    } catch (e) {
      print('Socket initialization error: $e');
      if (mounted) {
        setState(() {
          error = 'Error connecting to server: $e';
        });
      }
    }
  }

  int _calculateDuration() {
    if (startTime == null) return 0;

    final now = DateTime.now();
    final difference = now.difference(startTime!);
    return (difference.inSeconds / 60).round(); // Convert to minutes
  }

  // Make the API call to start the test drive with dynamic coordinates
  Future<void> _startTestDrive(LatLng currentLocation) async {
    try {
      final url = Uri.parse(
        'https://api.smartassistapp.in/api/events/${widget.eventId}/start-drive',
      );
      final token = await Storage.getToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'startCoordinates': {
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
          },
        }),
      );

      print('Starting test drive for event: ${widget.eventId}');

      if (response.statusCode == 200) {
        print('Test drive started successfully');
        // Start location tracking
        _startLocationTracking();
      } else {
        print('Failed to start test drive: ${response.statusCode}');
        if (mounted) {
          setState(() {
            error = 'Failed to start test drive: ${response.statusCode}';
          });
        }
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

  // Listen for location changes and update backend
  void _startLocationTracking() {
    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Increase to 50 meters
      );

      positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position position) {
            final LatLng newLocation = LatLng(
              position.latitude,
              position.longitude,
            );

            if (mounted && userMarker != null) {
              setState(() {
                userMarker = Marker(
                  markerId: const MarkerId('user'),
                  position: newLocation,
                  infoWindow: const InfoWindow(title: 'User'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                );

                if (routePoints.isNotEmpty) {
                  LatLng lastPoint = routePoints.last;
                  double segmentDistance = _calculateDistance(
                    lastPoint,
                    newLocation,
                  );
                  totalDistance += segmentDistance;
                }

                routePoints.add(newLocation);
                _updatePolyline();
              });
            }

            _sendLocationUpdate(newLocation);
          });
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  // Update location to backend
  void _sendLocationUpdate(LatLng location) {
    if (socket != null && socket!.connected) {
      socket!.emit('updateLocation', {
        'eventId': widget.eventId,
        'newCoordinates': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'totalDistance': totalDistance, // Also send current calculated distance
      });
    } else {
      print('Socket not connected, trying to reconnect...');
      if (socket != null) {
        socket!.connect();
      }
    }
  }

  // Handle when drive ends
  void _handleDriveEnded(double distance, int duration) {
    if (mounted) {
      setState(() {
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
        driveDuration = duration > 0 ? duration : _calculateDuration();

        // Ensure we clean up location tracking
        if (positionStreamSubscription != null) {
          positionStreamSubscription!.cancel();
        }
      });
    }
  }

  Future<void> _submitEndDrive() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });

    try {
      await _handleEndDrive();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Submission failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isSubmitting = false);
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
      setState(() => isSubmitting = false);
    }
  }

  // Improved end drive function with more resilient error handling
  Future<void> _handleEndDrive({bool sendFeedback = false}) async {
    setState(() {
      isLoading = true;
    });

    try {
      // First upload the drive summary - most reliable method
      // await _uploadDriveSummary();

      // Then try the screenshot but don't block on failure
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
        // Continue with the process
      }

      // Finally end the drive with API call - pass sendFeedback parameter
      await _endTestDrive(sendFeedback: sendFeedback);

      // Clean up resources
      _cleanupResources();

      // Show feedback to user about screenshot if it failed
      if (!screenshotSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Map image could not be captured, but drive data was saved successfully',
            ),
          ),
        );
      }

      // Navigate to feedback screen
      if (mounted) {
        // Add a small delay to let any UI updates complete
        await Future.delayed(Duration(milliseconds: 300));

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error ending test drive: $e')));
        setState(() {
          isLoading = false;
        });
      }

      _cleanupResources();
    }
  }

  Future<void> _handleEndDriveNavigatesummary() async {
    setState(() {
      isLoading = true;
    });

    try {
      // First upload the drive summary - most reliable method
      // await _uploadDriveSummary();

      // Then try the screenshot but don't block on failure
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
        // Continue with the process
      }

      // Finally end the drive with API call - pass sendFeedback as false
      await _endTestDrive(sendFeedback: true);

      // Clean up resources
      _cleanupResources();

      // Show feedback to user about screenshot if it failed
      if (!screenshotSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Map image could not be captured, but drive data was saved successfully',
            ),
          ),
        );
      }

      // Navigate to TestdriveOverview screen
      if (mounted) {
        // Add a small delay to let any UI updates complete
        await Future.delayed(Duration(milliseconds: 300));

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TestdriveOverview(
              eventId: widget.eventId,
              leadId: widget.leadId,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error in end drive process: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error ending test drive: $e')));
        setState(() {
          isLoading = false;
        });
      }

      _cleanupResources();
    }
  }

  // Dedicated method for resource cleanup
  void _cleanupResources() {
    try {
      if (socket != null) {
        socket!.disconnect();
        socket = null;
      }
      if (positionStreamSubscription != null) {
        positionStreamSubscription!.cancel();
        positionStreamSubscription = null;
      }
      if (mapController != null) {
        // No need to explicitly dispose mapController as it's handled by the GoogleMap widget
      }
    } catch (e) {
      print("Error during resource cleanup: $e");
    }
  }

  // Handle Google Map creation
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _endTestDrive({bool sendFeedback = false}) async {
    try {
      // Build the URL with query parameter
      final uri = Uri.parse(
        'https://api.smartassistapp.in/api/events/${widget.eventId}/end-drive',
      );
      final url = uri.replace(
        queryParameters: {'send_feedback': sendFeedback.toString()},
      );

      final token = await Storage.getToken();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'totalDistance': totalDistance,
          'duration': _calculateDuration(),
        }),
      );

      if (response.statusCode == 200) {
        print('Test drive ended successfully');
        print('Duration: ${_calculateDuration()}');
        print('Send feedback: $sendFeedback');
        _handleDriveEnded(totalDistance, _calculateDuration());
      } else {
        throw Exception('Failed to end drive: ${response.statusCode}');
      }
    } catch (e) {
      print('Error ending drive: $e');
      throw e; // Re-throw to be caught by caller
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    if (socket != null && socket!.connected) {
      socket!.disconnect();
    }
    if (positionStreamSubscription != null) {
      positionStreamSubscription!.cancel();
    }
    super.dispose();
  }

  // @override
  // void dispose() {
  //   // Clean up resources
  //   if (socket != null && socket!.connected) {
  //     socket!.disconnect();
  //   }

  //   if (positionStreamSubscription != null) {
  //     positionStreamSubscription!.cancel();
  //   }

  //   super.dispose();
  // }

  // ScreenshotController _screenshotController = ScreenshotController();

  // Improved screenshot capture function with better error handling
  Future<void> _captureAndUploadImage() async {
    try {
      if (mapController == null) {
        print("Map controller is not initialized");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is not ready for screenshot')),
        );
        return;
      }

      // Increase delay to ensure map is rendered
      await Future.delayed(const Duration(milliseconds: 1000));

      // Retry snapshot up to 3 times
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
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Could not capture map image')),
        // );
        return;
      }

      print('Snapshot size: ${image.lengthInBytes} bytes');

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/map_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath)..writeAsBytesSync(image);

      // Upload the image
      final uploadSuccess = await _uploadImage(file);
      if (!uploadSuccess) {
        print("Image upload failed");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload map image')),
        );
      } else {
        print("Image uploaded successfully");
      }
    } catch (e) {
      print("Error capturing/uploading map image: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing map image: $e')));
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
        // Handle both cases: data as string or map
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.backgroundLightGrey,
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text('Test Drive', style: AppFont.appbarfontgrey(context)),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_outlined,
              color: AppColors.iconGrey,
            ),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          elevation: 0,
        ),
        body: isLoading
            ? const Center(
                child: Column(
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
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
                ),
              )
            : Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLightGrey,
                    ),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SizedBox(
                                  height: 400,
                                  width: 400,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(10),
                                    ),

                                    child: GoogleMap(
                                      onMapCreated: _onMapCreated,
                                      initialCameraPosition: CameraPosition(
                                        target:
                                            startMarker?.position ??
                                            const LatLng(0, 0),
                                        zoom: 16,
                                      ),
                                      myLocationEnabled: true,
                                      zoomControlsEnabled:
                                          false, // Disable zoom buttons
                                      mapToolbarEnabled:
                                          false, // Disable toolbar
                                      compassEnabled: false, // Disable compass
                                      // gestureRecognizers:
                                      //     const <
                                      //       Factory<
                                      //         OneSequenceGestureRecognizer
                                      //       >
                                      //     >{}, // Disable gestures
                                      markers: {
                                        if (startMarker != null) startMarker!,
                                        if (userMarker != null) userMarker!,
                                        if (isDriveEnded && endMarker != null)
                                          endMarker!,
                                      },
                                      polylines: {routePolyline},
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                              if (!isDriveEnded)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Distance: ${totalDistance.toStringAsFixed(2)} km',
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
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              if (!isDriveEnded)
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    // Update the button onPressed handler
                                    onPressed: () async {
                                      try {
                                        // First try to capture and upload the image
                                        try {
                                          await _captureAndUploadImage();
                                        } catch (e) {
                                          // Log but don't block the flow if screenshot fails
                                          print(
                                            "Screenshot capture/upload failed: $e",
                                          );
                                          // Maybe show a toast notification
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not capture map image: $e',
                                              ),
                                            ),
                                          );
                                        }

                                        // Continue with ending the drive regardless of screenshot success
                                        await _submitEndDrive();
                                        // await _handleEndDrive();
                                      } catch (e) {
                                        // Handle errors with the end drive API call
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
                                    // onPressed: () {
                                    //   _endTestDrive();
                                    //   _captureAndUploadImage();
                                    // },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      backgroundColor:
                                          AppColors.colorsBlueButton,
                                    ),
                                    child: Text(
                                      'End Test Drive & Submit Feedback Now',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      // First try to capture and upload the image
                                      try {
                                        await _captureAndUploadImage();
                                      } catch (e) {
                                        // Log but don't block the flow if screenshot fails
                                        print(
                                          "Screenshot capture/upload failed: $e",
                                        );
                                        // Maybe show a toast notification
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not capture map image: $e',
                                            ),
                                          ),
                                        );
                                      }

                                      // Continue with ending the drive regardless of screenshot success
                                      await _submitEndDriveNavigate();
                                    } catch (e) {
                                      // Handle errors with the end drive API call
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
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    backgroundColor: Colors.black,
                                  ),
                                  child: Text(
                                    'End Test Drive & Submit Feedback Later',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) >
            Duration(milliseconds: _exitTimeInMillis)) {
      _lastBackPressTime = now;

      // Show a bottom slide dialog
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
                      // Cancel button (White)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Dismiss dialog
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
                      // Exit button (Blue)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // First close the bottom sheet
                            Navigator.pop(context);

                            try {
                              // Navigate to home screen and clear the stack
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(
                                    greeting: '',
                                    leadId: '',
                                  ),
                                ),
                                (route) => false,
                              );
                            } catch (e) {
                              print("Navigation error: $e");
                              // Fallback navigation
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(
                                    greeting: '',
                                    leadId: '',
                                  ),
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
