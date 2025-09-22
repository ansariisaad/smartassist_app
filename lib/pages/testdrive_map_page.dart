import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/services/testdrive_srv.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/testdrive/background_srv_manager.dart';
import 'package:smartassist/utils/testdrive/permission_handler_testdrive.dart';
import 'package:smartassist/utils/testdrive/testdrive_locationtracker.dart';
import 'package:smartassist/widgets/feedback.dart';
import 'package:smartassist/widgets/testdrive_summary.dart';

class TestdriveMapPage extends StatefulWidget {
  final String eventId;
  final String leadId;

  const TestdriveMapPage({super.key, required this.eventId, required this.leadId});

  @override
  State<TestdriveMapPage> createState() => _TestdriveMapPageState();
}

class _TestdriveMapPageState extends State<TestdriveMapPage>
    with WidgetsBindingObserver {
  // Core components
  late GoogleMapController mapController;
  late TestDriveLocationTracker locationTracker;

  // Map markers and polylines
  Marker? startMarker;
  Marker? userMarker;
  Marker? endMarker;
  late Polyline routePolyline;

  // Drive state
  bool isDriveEnded = false;
  bool isLoading = true;
  bool isSubmitting = false;
  String error = '';

  // Drive timing
  DateTime? driveStartTime;
  DateTime? driveEndTime;
  DateTime? pauseStartTime;
  int totalPausedDuration = 0;
  bool isDrivePaused = false;

  // Exit handling
  DateTime? _lastBackPressTime;
  final int _exitTimeInMillis = 2000;

  @override
  void initState() {
    super.initState();
    driveStartTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    // Initialize location tracker
    locationTracker = TestDriveLocationTracker(
      onLocationUpdate: _handleLocationUpdate,
      onError: _handleLocationError,
      onStateChange: _handleStateChange,
    );

    // Initialize background service
    TestDriveBackgroundServiceManager.initialize();
    TestDriveBackgroundServiceManager.setupiOSLocationListener(
      _handleiOSLocationUpdate,
    );

    // Initialize route polyline
    routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: [],
      color: AppColors.colorsBlue,
      width: 5,
    );

    // Start permission flow
    _requestLocationPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!isDriveEnded && locationTracker.isTracking) {
          TestDriveBackgroundServiceManager.startNativeService(
            widget.eventId,
            locationTracker.totalDistance,
          );
        }
        break;
      case AppLifecycleState.resumed:
        TestDriveBackgroundServiceManager.stopNativeService();
        break;
      default:
        break;
    }
  }

  // Request location permissions using utility
  Future<void> _requestLocationPermissions() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    final result = await TestDrivePermissionHandler.requestLocationPermissions(
      context,
    );

    if (result.isGranted) {
      await _initializeTestDrive();
    } else if (result.isPermanentlyDenied) {
      TestDrivePermissionHandler.showPermanentlyDeniedDialog(
        context,
        onExitPressed: () => Navigator.of(context).pop(),
      );
    } else if (result.hasError) {
      if (result.errorMessage!.contains('Location services')) {
        TestDrivePermissionHandler.showLocationServiceDialog(
          context,
          onExitPressed: () => Navigator.of(context).pop(),
        );
      } else {
        TestDrivePermissionHandler.showPermissionDialog(
          context,
          onGrantPressed: () async {
            Navigator.of(context).pop();
            await _requestLocationPermissions();
          },
          onCancelPressed: () {
            Navigator.of(context).pop();
            _showExitOrRetryDialog();
          },
        );
      }
    } else {
      TestDrivePermissionHandler.showExitOrRetryDialog(
        context,
        onExitPressed: () => Navigator.of(context).pop(),
        onRetryPressed: () async {
          Navigator.of(context).pop();
          await _requestLocationPermissions();
        },
      );
    }
  }

  // Initialize test drive after permissions granted
  Future<void> _initializeTestDrive() async {
    try {
      // Get current location and start tracking
      final position = await locationTracker.getCurrentLocation();
      final currentLocation = LatLng(position.latitude, position.longitude);

      // Create start marker
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

        isLoading = false;
      });

      // Start API call to begin test drive
      await _startTestDriveAPI(currentLocation);

      // Start location tracking
      await locationTracker.startTracking(initialLocation: currentLocation);
    } catch (e) {
      setState(() {
        error = 'Failed to initialize test drive: $e';
        isLoading = false;
      });
    }
  }

  // Start test drive via API
  Future<void> _startTestDriveAPI(LatLng startLocation) async {
    final result = await TestDriveApiService.startTestDrive(
      eventId: widget.eventId,
      startLocation: startLocation,
    );

    if (!result.isSuccess) {
      setState(() {
        error = result.errorMessage ?? 'Failed to start test drive';
      });
    }
  }

  // Handle location updates from tracker
  void _handleLocationUpdate(LatLng location, double totalDistance) {
    if (!mounted) return;

    setState(() {
      // Update user marker with appropriate color
      final position = locationTracker.debugState;
      final isStationary = position['isStationary'] ?? false;

      userMarker = Marker(
        markerId: const MarkerId('user'),
        position: location,
        infoWindow: InfoWindow(
          title: isStationary
              ? 'Stationary (GPS Protected)'
              : 'Current Location',
          snippet: 'Total: ${locationTracker.formattedDistance}',
        ),
        icon: isStationary
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

      // Update polyline
      routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: locationTracker.routePoints,
        color: AppColors.colorsBlue,
        width: 5,
      );
    });

    // Update camera
    if (mapController != null) {
      mapController.animateCamera(CameraUpdate.newLatLng(location));
    }
  }

  // Handle location tracking errors
  void _handleLocationError(String error) {
    if (!mounted) return;

    setState(() {
      this.error = error;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  // Handle state changes from tracker
  void _handleStateChange(Map<String, dynamic> state) {
    // Can be used for additional UI updates based on tracking state
    print('Tracker state: $state');
  }

  // Handle iOS location updates from background service
  void _handleiOSLocationUpdate(Map<String, dynamic> data) {
    if (!mounted || isDriveEnded) return;

    final latitude = data['latitude'] as double;
    final longitude = data['longitude'] as double;
    final newLocation = LatLng(latitude, longitude);

    setState(() {
      userMarker = Marker(
        markerId: const MarkerId('user'),
        position: newLocation,
        infoWindow: InfoWindow(
          title: 'Current Location (Background)',
          snippet: 'Distance: ${data['distance']?.toStringAsFixed(2)} km',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    });

    if (mapController != null) {
      mapController.animateCamera(CameraUpdate.newLatLng(newLocation));
    }
  }

  // Calculate drive duration accounting for pauses
  int _calculateDuration() {
    if (driveStartTime == null) return 0;

    DateTime endTime = driveEndTime ?? DateTime.now();
    int totalElapsed = endTime.difference(driveStartTime!).inSeconds;
    int activeDrivingTime = totalElapsed - totalPausedDuration;

    if (isDrivePaused && pauseStartTime != null) {
      int currentPauseDuration = DateTime.now()
          .difference(pauseStartTime!)
          .inSeconds;
      activeDrivingTime -= currentPauseDuration;
    }

    return (activeDrivingTime / 60).round();
  }

  // End test drive with feedback
  Future<void> _endTestDriveWithFeedback() async {
    if (isSubmitting) return;

    setState(() => isSubmitting = true);

    try {
      await _captureAndUploadImage();
      await _endTestDriveAPI(sendFeedback: false);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                Feedbackscreen(leadId: widget.leadId, eventId: widget.eventId),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to end test drive: $e');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // End test drive and navigate to summary
  Future<void> _endTestDriveToSummary() async {
    if (isSubmitting) return;

    setState(() => isSubmitting = true);

    try {
      await _captureAndUploadImage();
      await _endTestDriveAPI(sendFeedback: true);

      if (mounted) {
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
      _showError('Failed to end test drive: $e');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // End test drive via API
  Future<void> _endTestDriveAPI({bool sendFeedback = false}) async {
    // Stop tracking
    locationTracker.stopTracking();
    TestDriveBackgroundServiceManager.stopBackgroundService();

    // Get final location
    LatLng? endLocation = locationTracker.lastValidLocation;
    if (endLocation == null && userMarker != null) {
      endLocation = userMarker!.position;
    }

    final result = await TestDriveApiService.endTestDrive(
      eventId: widget.eventId,
      distance: locationTracker.totalDistance,
      duration: _calculateDuration(),
      endLocation: endLocation,
      routePoints: locationTracker.routePoints,
      sendFeedback: sendFeedback,
    );

    if (!result.isSuccess) {
      throw Exception(result.errorMessage ?? 'Failed to end test drive');
    }

    setState(() {
      isDriveEnded = true;
      driveEndTime = DateTime.now();

      if (endLocation != null) {
        endMarker = Marker(
          markerId: const MarkerId('end'),
          position: endLocation,
          infoWindow: const InfoWindow(title: 'End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }
    });
  }

  // Capture and upload map screenshot
  Future<void> _captureAndUploadImage() async {
    try {
      if (mapController == null) return;

      await Future.delayed(const Duration(milliseconds: 1000));

      Uint8List? image;
      for (int i = 0; i < 3; i++) {
        try {
          image = await mapController.takeSnapshot();
          if (image != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          print('Screenshot attempt ${i + 1} failed: $e');
        }
      }

      if (image == null) {
        throw Exception('Failed to capture map screenshot');
      }

      final result = await TestDriveApiService.uploadMapImage(
        eventId: widget.eventId,
        imageData: image,
      );

      if (!result.isSuccess) {
        print('Failed to upload map image: ${result.errorMessage}');
      }
    } catch (e) {
      print('Error capturing/uploading image: $e');
      // Don't throw - image upload is not critical
    }
  }

  // Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Exit dialog
  void _showExitOrRetryDialog() {
    TestDrivePermissionHandler.showExitOrRetryDialog(
      context,
      onExitPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
      onRetryPressed: () {
        Navigator.of(context).pop();
        _requestLocationPermissions();
      },
    );
  }

  // Build stationary indicator
  Widget _buildStationaryIndicator() {
    Map<String, dynamic> state = locationTracker.debugState;
    bool isStationary = state['isStationary'] ?? false;

    if (!isStationary) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle, size: 16, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            'Stationary - GPS Protected',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // Handle back press with confirmation
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) >
            Duration(milliseconds: _exitTimeInMillis)) {
      _lastBackPressTime = now;
      _showExitConfirmation();
      return false;
    }
    return true;
  }

  // Show exit confirmation dialog
  void _showExitConfirmation() {
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
                'Exit Test Drive',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorsBlue,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to exit the test drive?',
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
                        onPressed: () => Navigator.pop(context),
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
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => BottomNavigation(),
                            ),
                            (route) => false,
                          );
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locationTracker.dispose();
    TestDriveBackgroundServiceManager.dispose();
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
                      onPressed: _requestLocationPermissions,
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

                  // Drive Stats Container
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
                                  'Distance: ${locationTracker.formattedDistance}',
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
                            // _buildStationaryIndicator(),
                            // if (isDrivePaused)
                            //   Padding(
                            //     padding: const EdgeInsets.only(top: 8.0),
                            //     child: Text(
                            //       'Drive Paused',
                            //       style: GoogleFonts.poppins(
                            //         fontSize: 12,
                            //         fontWeight: FontWeight.w500,
                            //         color: Colors.orange,
                            //       ),
                            //     ),
                            //   ),
                          ],
                        ),
                      ),
                    ),

                  // Action Buttons
                  if (!isDriveEnded)
                    Positioned(
                      bottom: 40,
                      left: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // End Drive & Submit Feedback Now
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : _endTestDriveWithFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.colorsBlueButton,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      'End Test Drive & Submit Feedback Now',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // End Drive & Submit Feedback Later
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : _endTestDriveToSummary,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSubmitting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      'End Test Drive & Submit Feedback Later',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
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
}
