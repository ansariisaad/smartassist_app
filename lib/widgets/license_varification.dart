// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'dart:ui';
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as path;
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/license_preview.dart';
// import 'package:smartassist/widgets/start_drive.dart';
// import 'package:image/image.dart' as img;

// class LicenseVarification extends StatefulWidget {
//   final String eventId;
//   final String leadId;
//   const LicenseVarification({
//     super.key,
//     required this.eventId,
//     required this.leadId,
//   });

//   @override
//   State<LicenseVarification> createState() => _LicenseVarificationState();
// }

// class _LicenseVarificationState extends State<LicenseVarification> {
//   List<CameraDescription> cameras = [];
//   CameraController? cameraController;
//   File? _capturedImage;
//   bool _isCameraInitialized = false;
//   bool _isUploading = false;

//   // Define a map to store skip reasons
//   Map<String, String> skip = {'Overall Ambience': ''};

//   // Rectangle dimensions for the license frame
//   late double frameWidth;
//   late double frameHeight;
//   late Rect frameRect;

//   @override
//   void initState() {
//     super.initState();
//     _setupCameraController();
//   }

//   Future<void> _setupCameraController() async {
//     List<CameraDescription> _cameras = await availableCameras();
//     if (_cameras.isNotEmpty) {
//       cameraController = CameraController(
//         _cameras.first,
//         ResolutionPreset.high,
//       );
//       await cameraController!.initialize();
//       setState(() {
//         _isCameraInitialized = true;
//       });
//     }
//   }

//   Future<void> _captureImage() async {
//     if (!(cameraController?.value.isInitialized ?? false)) return;

//     // Take the picture
//     final XFile file = await cameraController!.takePicture();

//     // Calculate crop parameters
//     Size screenSize = MediaQuery.of(context).size;
//     Size previewSize = Size(
//       cameraController!.value.previewSize!.height,
//       cameraController!.value.previewSize!.width,
//     );

//     // Calculate the ratio between the actual image and what's displayed on screen
//     double scaleX = previewSize.width / screenSize.width;
//     double scaleY = previewSize.height / screenSize.height;

//     // Calculate coordinates for the rectangle in the image
//     double centerX = screenSize.width / 2;
//     double centerY = screenSize.height / 2;

//     frameWidth = MediaQuery.of(context).size.width * 0.85;
//     frameHeight = MediaQuery.of(context).size.width * 0.55;

//     double left = (centerX - frameWidth / 2) * scaleX;
//     double top = (centerY - frameHeight / 2) * scaleY;
//     double right = (centerX + frameWidth / 2) * scaleX;
//     double bottom = (centerY + frameHeight / 2) * scaleY;

//     // Ensure coordinates are within bounds
//     left = max(0, left);
//     top = max(0, top);
//     right = min(previewSize.width, right);
//     bottom = min(previewSize.height, bottom);

//     // Create Rect for cropping
//     frameRect = Rect.fromLTRB(left, top, right, bottom);

//     // Use image package to load and crop the image
//     final image = await img.decodeImageFile(file.path);
//     if (image == null) {
//       print("Failed to decode image");
//       return;
//     }

//     // Calculate crop dimensions based on the frame rectangle
//     final int cropX = (left).round();
//     final int cropY = (top).round();
//     final int cropWidth = (right - left).round();
//     final int cropHeight = (bottom - top).round();

//     // Crop the image
//     final img.Image croppedImage = img.copyCrop(
//       image,
//       x: cropX,
//       y: cropY,
//       width: cropWidth,
//       height: cropHeight,
//     );

//     // Save the cropped image
//     final Directory appDir = await getApplicationDocumentsDirectory();
//     final String imagePath = path.join(appDir.path, '${DateTime.now()}.png');
//     final File croppedFile = File(imagePath);
//     await croppedFile.writeAsBytes(img.encodePng(croppedImage));

//     setState(() {
//       _capturedImage = croppedFile;
//     });

//     // Navigate to preview screen with cropped image
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LicencePreview(
//           imageFile: croppedFile,
//           eventId: widget.eventId,
//           leadId: widget.leadId,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     cameraController?.dispose();
//     super.dispose();
//   }

//   Future<void> submitFeedback(String skipReason) async {
//     setState(() {
//       _isUploading = true;
//     });
//     try {
//       print('Event ID: ${widget.eventId}');
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? spId = prefs.getString('user_id');
//       final url = Uri.parse(
//         'https://api.smartassistapp.in/api/events/update/${widget.eventId}',
//       );
//       final token = await Storage.getToken();
//       skip['Overall Ambience'] = skipReason;
//       final requestBody = {
//         'sp_id': spId,
//         'skip_license': skip['Overall Ambience'],
//       };
//       print(requestBody);
//       final response = await http.put(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode(requestBody),
//       );
//       final responseData = jsonDecode(response.body);
//       print('API Response status: ${response.statusCode}');
//       print('API Response body: ${response.body}');
//       print(url.toString());
//       if (response.statusCode == 200) {
//         print('Feedback submitted successfully');
//         Get.snackbar('Success', 'License verification skipped successfully');
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) =>
//                 StartDriveMap(leadId: widget.leadId, eventId: widget.eventId),
//           ),
//         );
//       } else {
//         print(
//           'Failed to submit feedback : ${responseData['message'].toString()}',
//         );
//         Get.snackbar('Error', 'error due to ${responseData['message']}');
//       }
//     } catch (e) {
//       print('Exception occurred: ${e.toString()}');
//       Get.snackbar('Error', 'An error occurred: ${e.toString()}');
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }

//   // Future<void> submitFeedback(String skipReason) async {
//   //   setState(() {
//   //     _isUploading = true;
//   //   });

//   //   try {
//   //     print('Event ID: ${widget.eventId}');
//   //     SharedPreferences prefs = await SharedPreferences.getInstance();
//   //     String? spId = prefs.getString('user_id');
//   //     final url = Uri.parse(
//   //       'https://api.smartassistapp.in/api/events/update/${widget.eventId}',
//   //     );
//   //     final token = await Storage.getToken();

//   //     // Update the skip reason
//   //     skip['Overall Ambience'] = skipReason;

//   //     // Create the request body
//   //     final requestBody = {
//   //       'sp_id': spId,
//   //       'skip_license': skip['Overall Ambience'],
//   //     };

//   //     print(requestBody);

//   //     final response = await http.put(
//   //       url,
//   //       headers: {
//   //         'Content-Type': 'application/json',
//   //         'Authorization': 'Bearer $token',
//   //       },
//   //       body: json.encode(requestBody),
//   //     );

//   //     final responseData = jsonDecode(response.body);

//   //     // Print the response
//   //     print('API Response status: ${response.statusCode}');
//   //     print('API Response body: ${response.body}');
//   //     print(url.toString());
//   //     if (response.statusCode == 200) {
//   //       // Success handling
//   //       print('Feedback submitted successfully');
//   //       Get.snackbar(
//   //         'Success',
//   //         'License verification skipped successfully',
//   //         backgroundColor: Colors.green,
//   //         colorText: Colors.white,
//   //       );

//   //       // Navigate to FollowupsDetails screen
//   //       Navigator.push(
//   //         context,
//   //         MaterialPageRoute(
//   //           builder: (context) =>
//   //               StartDriveMap(leadId: widget.leadId, eventId: widget.eventId),
//   //         ),
//   //       );
//   //     } else {
//   //       // Error handling
//   //       print(
//   //         'Failed to submit feedback : ${responseData['message'].toString()}',
//   //       );
//   //       Get.snackbar(
//   //         'Error',
//   //         'error due to ${responseData['message']}',
//   //         backgroundColor: Colors.red,
//   //         colorText: Colors.white,
//   //       );
//   //     }
//   //   } catch (e) {
//   //     // Exception handling
//   //     print('Exception occurred: ${e.toString()}');
//   //     Get.snackbar(
//   //       'Error',
//   //       'An error occurred: ${e.toString()}',
//   //       backgroundColor: Colors.red,
//   //       colorText: Colors.white,
//   //     );
//   //   } finally {
//   //     setState(() {
//   //       _isUploading = false;
//   //     });
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     // Calculate rectangle dimensions
//     frameWidth = MediaQuery.of(context).size.width * 0.85;
//     frameHeight = MediaQuery.of(context).size.width * 0.55;

//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       appBar: AppBar(
//         leading: IconButton(
//           onPressed: () => Get.back(),
//           icon: const Icon(
//             size: 30,
//             Icons.keyboard_arrow_left_rounded,
//             color: Colors.white,
//           ),
//         ),
//         // backgroundColor: Colors.black,
//         title: Align(
//           alignment: Alignment.centerLeft,
//           child: Text('License', style: AppFont.appbarfontWhite(context)),
//         ),
//         backgroundColor: Colors.blue,
//         automaticallyImplyLeading: false,
//       ),
//       body: _isCameraInitialized
//           ? Stack(
//               children: [
//                 // Camera Preview
//                 SizedBox(
//                   child: FittedBox(
//                     fit: BoxFit.cover,
//                     child: SizedBox(
//                       width: cameraController!.value.previewSize!.height,
//                       height: cameraController!.value.previewSize!.width,
//                       child: CameraPreview(cameraController!),
//                     ),
//                   ),
//                 ),

//                 // Overlay with guidance
//                 Container(
//                   width: double.infinity,
//                   height: double.infinity,
//                   child: Stack(
//                     children: [
//                       // This creates the darkened areas around the rectangle
//                       ClipPath(
//                         clipper: InvertedRectangleClipper(
//                           center: Offset(
//                             MediaQuery.of(context).size.width / 2,
//                             MediaQuery.of(context).size.height / 2.4,
//                           ),
//                           width: frameWidth,
//                           height: frameHeight,
//                           borderRadius: 12,
//                         ),
//                         child: Container(
//                           width: double.infinity,
//                           height: double.infinity,
//                           color: Colors.black.withOpacity(0.5),
//                         ),
//                       ),

//                       // Border for the cutout
//                       Center(
//                         child: Container(
//                           margin: const EdgeInsets.only(bottom: 55),
//                           width: frameWidth,
//                           height: frameHeight,
//                           decoration: BoxDecoration(
//                             border: Border.all(
//                               color: AppColors.colorsBlue,
//                               width: 3,
//                             ),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       ),

//                       // Guidance text
//                       Positioned(
//                         top: MediaQuery.of(context).size.height * 0.25,
//                         left: 0,
//                         right: 0,
//                         child: const Text(
//                           'Align license within the frame',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),

//                       // Corner lines (for visual guidance)
//                       _buildCornerLines(),

//                       // Bottom controls
//                       Positioned(
//                         bottom: 30,
//                         left: 0,
//                         right: 0,
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             // Skip button
//                             ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.white.withOpacity(0.8),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 20,
//                                   vertical: 12,
//                                 ),
//                               ),
//                               onPressed: _showSkipDialog,
//                               child: const Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Text(
//                                     'Skip',
//                                     style: TextStyle(
//                                       color: Colors.black87,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   SizedBox(width: 5),
//                                   Icon(Icons.skip_next, color: Colors.black87),
//                                 ],
//                               ),
//                             ),

//                             // Capture button
//                             InkWell(
//                               onTap: () {
//                                 if (!_isUploading) {
//                                   _captureImage();
//                                 }
//                               },
//                               child: Container(
//                                 margin: const EdgeInsets.all(10),
//                                 width: 70,
//                                 height: 70,
//                                 decoration: BoxDecoration(
//                                   color: Colors.white,
//                                   shape: BoxShape.circle,
//                                   border: Border.all(
//                                     color: Colors.blue,
//                                     width: 3,
//                                   ),
//                                 ),
//                                 child: Center(
//                                   child: Container(
//                                     width: 60,
//                                     height: 60,
//                                     decoration: const BoxDecoration(
//                                       color: Colors.white,
//                                       shape: BoxShape.circle,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),

//                             // Placeholder to balance the row
//                             const SizedBox(width: 80),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             )
//           : const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(color: AppColors.colorsBlue),
//                   SizedBox(height: 16),
//                   Text(
//                     'Initializing camera...',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildCornerLines() {
//     final cornerSize = 20.0;
//     final centerWidget = Center(
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 55),
//         width: frameWidth,
//         height: frameHeight,
//         child: Stack(
//           children: [
//             // Top Left Corner
//             Positioned(
//               top: 0,
//               left: 0,
//               child: _buildCorner(cornerSize, isTopLeft: true),
//             ),
//             // Top Right Corner
//             Positioned(
//               top: 0,
//               right: 0,
//               child: _buildCorner(cornerSize, isTopRight: true),
//             ),
//             // Bottom Left Corner
//             Positioned(
//               bottom: 0,
//               left: 0,
//               child: _buildCorner(cornerSize, isBottomLeft: true),
//             ),
//             // Bottom Right Corner
//             Positioned(
//               bottom: 0,
//               right: 0,
//               child: _buildCorner(cornerSize, isBottomRight: true),
//             ),
//           ],
//         ),
//       ),
//     );

//     return centerWidget;
//   }

//   Widget _buildCorner(
//     double size, {
//     bool isTopLeft = false,
//     bool isTopRight = false,
//     bool isBottomLeft = false,
//     bool isBottomRight = false,
//   }) {
//     return Container(
//       width: size,
//       height: size,
//       child: CustomPaint(
//         painter: CornerPainter(
//           isTopLeft: isTopLeft,
//           isTopRight: isTopRight,
//           isBottomLeft: isBottomLeft,
//           isBottomRight: isBottomRight,
//           color: Colors.white,
//           lineWidth: 3,
//         ),
//       ),
//     );
//   }

//   // Show skip confirmation dialog
//   Future<void> _showSkipDialog() async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false, // User must tap button to close dialog
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(15),
//           ),
//           backgroundColor: Colors.white,
//           insetPadding: const EdgeInsets.all(10),
//           contentPadding: EdgeInsets.zero,
//           title: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Align(
//                 alignment: Alignment.bottomLeft,
//                 child: Text(
//                   textAlign: TextAlign.center,
//                   'Select reason to skip',
//                   style: AppFont.mediumText14(context),
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     submitFeedback(
//                       "License previously verified - trusted client",
//                     );
//                   },
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       'License previously verified - trusted client.',
//                       style: AppFont.mediumText14(context),
//                       textAlign: TextAlign.left,
//                     ),
//                   ),
//                 ),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     submitFeedback(
//                       "Test drive under sales associate supervision - license on file",
//                     );
//                   },
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       'Test drive under sales associate supervision - license on file.',
//                       style: AppFont.mediumText14(context),
//                       textAlign: TextAlign.left,
//                     ),
//                   ),
//                 ),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     submitFeedback(
//                       "Exception approved by management - premium client",
//                     );
//                   },
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       'Exception approved by management - premium client.',
//                       style: AppFont.mediumText14(context),
//                       textAlign: TextAlign.left,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text(
//                 'Cancel',
//                 style: TextStyle(color: AppColors.colorsBlue),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// // Custom painter for license corner lines
// class CornerPainter extends CustomPainter {
//   final bool isTopLeft;
//   final bool isTopRight;
//   final bool isBottomLeft;
//   final bool isBottomRight;
//   final Color color;
//   final double lineWidth;

//   CornerPainter({
//     this.isTopLeft = false,
//     this.isTopRight = false,
//     this.isBottomLeft = false,
//     this.isBottomRight = false,
//     this.color = Colors.white,
//     this.lineWidth = 2.0,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = lineWidth
//       ..strokeCap = StrokeCap.round;

//     if (isTopLeft) {
//       // Draw top line
//       canvas.drawLine(Offset(0, 0), Offset(size.width * 0.7, 0), paint);
//       // Draw left line
//       canvas.drawLine(Offset(0, 0), Offset(0, size.height * 0.7), paint);
//     } else if (isTopRight) {
//       // Draw top line
//       canvas.drawLine(
//         Offset(size.width * 0.3, 0),
//         Offset(size.width, 0),
//         paint,
//       );
//       // Draw right line
//       canvas.drawLine(
//         Offset(size.width, 0),
//         Offset(size.width, size.height * 0.7),
//         paint,
//       );
//     } else if (isBottomLeft) {
//       // Draw bottom line
//       canvas.drawLine(
//         Offset(0, size.height),
//         Offset(size.width * 0.7, size.height),
//         paint,
//       );
//       // Draw left line
//       canvas.drawLine(
//         Offset(0, size.height * 0.3),
//         Offset(0, size.height),
//         paint,
//       );
//     } else if (isBottomRight) {
//       // Draw bottom line
//       canvas.drawLine(
//         Offset(size.width * 0.3, size.height),
//         Offset(size.width, size.height),
//         paint,
//       );
//       // Draw right line
//       canvas.drawLine(
//         Offset(size.width, size.height * 0.3),
//         Offset(size.width, size.height),
//         paint,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) {
//     return true;
//   }
// }

// // Custom clipper to create the transparent rectangle in the middle
// class InvertedRectangleClipper extends CustomClipper<Path> {
//   final Offset center;
//   final double width;
//   final double height;
//   final double borderRadius;

//   InvertedRectangleClipper({
//     required this.center,
//     required this.width,
//     required this.height,
//     this.borderRadius = 0,
//   });

//   @override
//   Path getClip(Size size) {
//     final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

//     final cutoutLeft = center.dx - width / 2;
//     final cutoutTop = center.dy - height / 2;
//     final cutoutRight = center.dx + width / 2;
//     final cutoutBottom = center.dy + height / 2;

//     final cutoutPath = Path();

//     if (borderRadius > 0) {
//       cutoutPath.addRRect(
//         RRect.fromRectAndRadius(
//           Rect.fromLTRB(cutoutLeft, cutoutTop, cutoutRight, cutoutBottom),
//           Radius.circular(borderRadius),
//         ),
//       );
//     } else {
//       cutoutPath.addRect(
//         Rect.fromLTRB(cutoutLeft, cutoutTop, cutoutRight, cutoutBottom),
//       );
//     }

//     // Subtracts the cutout from the full size to create the inverted effect
//     return Path.combine(PathOperation.difference, path, cutoutPath);
//   }

//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => true;
// }

// // Don't forget to add this import at the top of your file:
// // import 'package:image/image.dart' as img;
// // import 'dart:math';
// // Custom painter for license corner lines

// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:camera/camera.dart';
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:path/path.dart' as path;
// // import 'package:path_provider/path_provider.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:smartassist/config/component/color/colors.dart';
// // import 'package:smartassist/config/component/font/font.dart';

// // import 'package:smartassist/utils/storage.dart';
// // import 'package:smartassist/widgets/license_preview.dart';
// // import 'package:smartassist/widgets/start_drive.dart';

// // class LicenseVarification extends StatefulWidget {
// //   final String eventId;
// //   final String leadId;
// //   const LicenseVarification(
// //       {super.key, required this.eventId, required this.leadId});

// //   @override
// //   State<LicenseVarification> createState() => _LicenseVarificationState();
// // }

// // class _LicenseVarificationState extends State<LicenseVarification> {
// //   List<CameraDescription> cameras = [];
// //   CameraController? cameraController;
// //   File? _capturedImage;
// //   bool _isCameraInitialized = false;
// //   bool _isUploading = false;

// //   // Define a map to store skip reasons
// //   Map<String, String> skip = {
// //     'Overall Ambience': '',
// //   };

// //   @override
// //   void initState() {
// //     super.initState();
// //     _setupCameraController();
// //   }

// //   Future<void> _setupCameraController() async {
// //     List<CameraDescription> _cameras = await availableCameras();
// //     if (_cameras.isNotEmpty) {
// //       cameraController =
// //           CameraController(_cameras.first, ResolutionPreset.high);
// //       await cameraController!.initialize();
// //       setState(() {
// //         _isCameraInitialized = true;
// //       });
// //     }
// //   }

// //   Future<void> _captureImage() async {
// //     if (!(cameraController?.value.isInitialized ?? false)) return;

// //     final XFile file = await cameraController!.takePicture();
// //     final Directory appDir = await getApplicationDocumentsDirectory();
// //     final String imagePath = path.join(appDir.path, '${DateTime.now()}.png');
// //     final File newImage = await File(file.path).copy(imagePath);

// //     setState(() {
// //       _capturedImage = newImage;
// //     });

// //     // Navigate to preview screen
// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (context) => LicencePreview(
// //           imageFile: newImage,
// //           eventId: widget.eventId,
// //           leadId: widget.leadId,
// //         ),
// //       ),
// //     );
// //   }

// //   @override
// //   void dispose() {
// //     cameraController?.dispose();
// //     super.dispose();
// //   }

// //   Future<void> submitFeedback(String skipReason) async {
// //     setState(() {
// //       _isUploading = true;
// //     });

// //     try {
// //       SharedPreferences prefs = await SharedPreferences.getInstance();
// //       String? spId = prefs.getString('user_id');
// //       final url = Uri.parse(
// //           'https://api.smartassistapp.in/api/events/update/${widget.eventId}');
// //       final token = await Storage.getToken();

// //       // Update the skip reason
// //       skip['Overall Ambience'] = skipReason;

// //       // Create the request body
// //       final requestBody = {
// //         'sp_id': spId,
// //         'skip_license': skip['Overall Ambience'],
// //       };

// //       // Print the data to console for debugging
// //       print('Submitting feedback data:');
// //       print(requestBody);

// //       final response = await http.put(url,
// //           headers: {
// //             'Content-Type': 'application/json',
// //             'Authorization': 'Bearer $token',
// //           },
// //           body: json.encode(requestBody));

// //       // Print the response
// //       print('API Response status: ${response.statusCode}');
// //       print('API Response body: ${response.body}');

// //       if (response.statusCode == 200) {
// //         // Success handling
// //         print('Feedback submitted successfully');
// //         Get.snackbar(
// //           'Success',
// //           'License verification skipped successfully',
// //           backgroundColor: Colors.green,
// //           colorText: Colors.white,
// //         );

// //         // Navigate to FollowupsDetails screen
// //         Navigator.push(
// //             context,
// //             MaterialPageRoute(
// //                 builder: (context) => StartDriveMap(
// //                       leadId: widget.leadId,
// //                       eventId: widget.eventId,
// //                     )));
// //       } else {
// //         // Error handling
// //         print('Failed to submit feedback');
// //         Get.snackbar(
// //           'Error',
// //           'Failed to skip license verification',
// //           backgroundColor: Colors.red,
// //           colorText: Colors.white,
// //         );
// //       }
// //     } catch (e) {
// //       // Exception handling
// //       print('Exception occurred: ${e.toString()}');
// //       Get.snackbar(
// //         'Error',
// //         'An error occurred: ${e.toString()}',
// //         backgroundColor: Colors.red,
// //         colorText: Colors.white,
// //       );
// //     } finally {
// //       setState(() {
// //         _isUploading = false;
// //       });
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.black,
// //       body: _isCameraInitialized
// //           ? Center(
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   SizedBox(
// //                     height: MediaQuery.sizeOf(context).height * 0.06,
// //                   ),
// //                   SizedBox(
// //                     child: FittedBox(
// //                       fit: BoxFit.cover,
// //                       child: SizedBox(
// //                         width: cameraController!.value.previewSize!.height,
// //                         height: cameraController!.value.previewSize!.width,
// //                         child: CameraPreview(cameraController!),
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 10),
// //                   Row(
// //                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //                     children: [
// //                       IconButton(
// //                           onPressed: () {
// //                             if (!_isUploading) {
// //                               _captureImage();
// //                             }
// //                           },
// //                           icon: Icon(
// //                             Icons.camera,
// //                             size: MediaQuery.sizeOf(context).height * 0.07,
// //                             color: Colors.white,
// //                           )),
// //                       Align(
// //                         alignment: Alignment.centerRight,
// //                         child: ElevatedButton(
// //                             style: ElevatedButton.styleFrom(
// //                               backgroundColor: AppColors.colorsBlue,
// //                               shape: RoundedRectangleBorder(
// //                                 borderRadius: BorderRadius.circular(5),
// //                               ),
// //                             ),
// //                             onPressed: _showSkipDialog,
// //                             child: Row(
// //                               children: [
// //                                 Text('Skip',
// //                                     style: AppFont.smallTextWhite(context)),
// //                                 const Icon(
// //                                   Icons.skip_next,
// //                                   color: Colors.white,
// //                                 )
// //                               ],
// //                             )),
// //                       )
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             )
// //           : const Center(child: CircularProgressIndicator()),
// //     );
// //   }

// //   // Show skip confirmation dialog
// //   Future<void> _showSkipDialog() async {
// //     return showDialog<void>(
// //       context: context,
// //       barrierDismissible: false, // User must tap button to close dialog
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(5),
// //           ),
// //           backgroundColor: Colors.white,
// //           insetPadding: const EdgeInsets.all(10),
// //           contentPadding: EdgeInsets.zero,
// //           title: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Align(
// //                 alignment: Alignment.bottomLeft,
// //                 child: Text(
// //                   textAlign: TextAlign.center,
// //                   'Select reason to skip',
// //                   style: AppFont.mediumText14(context),
// //                 ),
// //               ),
// //               const SizedBox(
// //                 height: 10,
// //               )
// //               // Divider(color: Colors.grey.shade300),
// //             ],
// //           ),
// //           content: SingleChildScrollView(
// //             child: ListBody(
// //               children: <Widget>[
// //                 Divider(height: 1, color: Colors.grey.shade200),
// //                 TextButton(
// //                     onPressed: () {
// //                       Navigator.of(context).pop();
// //                       submitFeedback(
// //                           "License previously verified - trusted client");
// //                     },
// //                     child: Align(
// //                       alignment: Alignment.centerLeft,
// //                       child: Text(
// //                         'License previously verified - trusted client.',
// //                         style: AppFont.mediumText14(context),
// //                         textAlign: TextAlign.left,
// //                       ),
// //                     )),
// //                 Divider(height: 1, color: Colors.grey.shade200),
// //                 TextButton(
// //                     onPressed: () {
// //                       Navigator.of(context).pop();
// //                       submitFeedback(
// //                           "Test drive under sales associate supervision - license on file");
// //                     },
// //                     child: Align(
// //                       alignment: Alignment.centerLeft,
// //                       child: Text(
// //                         'Test drive under sales associate supervision - license on file.',
// //                         style: AppFont.mediumText14(context),
// //                         textAlign: TextAlign.left,
// //                       ),
// //                     )),
// //                 Divider(height: 1, color: Colors.grey.shade200),
// //                 TextButton(
// //                     onPressed: () {
// //                       Navigator.of(context).pop();
// //                       submitFeedback(
// //                           "Exception approved by management - premium client");
// //                     },
// //                     child: Align(
// //                       alignment: Alignment.centerLeft,
// //                       child: Text(
// //                         'Exception approved by management - premium client.',
// //                         style: AppFont.mediumText14(context),
// //                         textAlign: TextAlign.left,
// //                       ),
// //                     )),
// //               ],
// //             ),
// //           ),
// //           actions: [
// //             TextButton(
// //               onPressed: () {
// //                 Navigator.of(context).pop();
// //               },
// //               child:const Text(
// //                 'Cancel',
// //                 style: TextStyle(color: AppColors.colorsBlue),
// //               ),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }
// // }
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/license_preview.dart';
import 'package:smartassist/widgets/start_drive.dart';
import 'package:image/image.dart' as img;

class LicenseVarification extends StatefulWidget {
  final String eventId;
  final String leadId;
  const LicenseVarification({
    super.key,
    required this.eventId,
    required this.leadId,
  });

  @override
  State<LicenseVarification> createState() => _LicenseVarificationState();
}

class _LicenseVarificationState extends State<LicenseVarification>
    with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  File? _capturedImage;
  bool _isCameraInitialized = false;
  bool _isUploading = false;
  bool _isCapturing = false;
  bool _isDisposed = false; // Add this flag

  // Define a map to store skip reasons
  Map<String, String> skip = {'Overall Ambience': ''};

  // Rectangle dimensions for the license frame
  late double frameWidth;
  late double frameHeight;
  late Rect frameRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCameraController();
  }

  @override
  void dispose() {
    print('LicenseVarification: dispose() called');
    _isDisposed = true; // Set disposal flag
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return; // Prevent operations after disposal

    final CameraController? cameraController = this.cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when the camera is not active
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera when app comes back to foreground
      _setupCameraController();
    }
  }

  Future<void> _disposeCamera() async {
    print('_disposeCamera called');
    final CameraController? cameraController = this.cameraController;
    if (cameraController != null) {
      this.cameraController = null;
      try {
        // Properly dispose of the camera controller
        await cameraController.dispose();
        print('Camera controller disposed successfully');
      } catch (e) {
        print('Error disposing camera controller: $e');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _setupCameraController() async {
    if (_isDisposed) return; // Prevent setup after disposal

    try {
      // Dispose existing controller first
      await _disposeCamera();

      // Small delay to ensure proper cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      List<CameraDescription> _cameras = await availableCameras();
      if (_cameras.isNotEmpty && !_isDisposed) {
        cameraController = CameraController(
          _cameras.first,
          ResolutionPreset
              .medium, // Use medium resolution to reduce memory usage
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await cameraController!.initialize();

        // Configure camera settings to reduce buffer usage
        await cameraController!.setFlashMode(FlashMode.off);

        // Set exposure mode to reduce processing overhead
        try {
          await cameraController!.setExposureMode(ExposureMode.auto);
          await cameraController!.setFocusMode(FocusMode.auto);
        } catch (e) {
          print('Error setting camera modes: $e');
        }

        if (!_isDisposed && mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _captureImage() async {
    if (!(cameraController?.value.isInitialized ?? false) ||
        _isCapturing ||
        _isDisposed) {
      print(
        'Cannot capture: camera not initialized or already capturing or disposed',
      );
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      print('Starting image capture...');

      // Take the picture with reduced quality to save memory
      final XFile file = await cameraController!.takePicture();
      print('Image captured successfully: ${file.path}');

      // Process image in background to avoid blocking UI
      await _processAndCropImage(file);
    } catch (e) {
      print('Error capturing image: $e');
      if (!_isDisposed && mounted) {
        Get.snackbar('Error', 'Failed to capture image: ${e.toString()}');
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _processAndCropImage(XFile file) async {
    try {
      // Calculate crop parameters
      Size screenSize = MediaQuery.of(context).size;
      Size previewSize = Size(
        cameraController!.value.previewSize!.height,
        cameraController!.value.previewSize!.width,
      );

      // Calculate the ratio between the actual image and what's displayed on screen
      double scaleX = previewSize.width / screenSize.width;
      double scaleY = previewSize.height / screenSize.height;

      // Calculate coordinates for the rectangle in the image
      double centerX = screenSize.width / 2;
      double centerY = screenSize.height / 2;

      frameWidth = MediaQuery.of(context).size.width * 0.85;
      frameHeight = MediaQuery.of(context).size.width * 0.55;

      double left = (centerX - frameWidth / 2) * scaleX;
      double top = (centerY - frameHeight / 2) * scaleY;
      double right = (centerX + frameWidth / 2) * scaleX;
      double bottom = (centerY + frameHeight / 2) * scaleY;

      // Ensure coordinates are within bounds
      left = max(0, left);
      top = max(0, top);
      right = min(previewSize.width, right);
      bottom = min(previewSize.height, bottom);

      // Create Rect for cropping
      frameRect = Rect.fromLTRB(left, top, right, bottom);

      // Load and decode image with memory optimization
      final imageBytes = await File(file.path).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        print("Failed to decode image");
        throw Exception("Failed to decode image");
      }

      print('Original image size: ${image.width}x${image.height}');

      // Calculate crop dimensions based on the frame rectangle
      final int cropX = (left).round();
      final int cropY = (top).round();
      final int cropWidth = (right - left).round();
      final int cropHeight = (bottom - top).round();

      print('Crop parameters: x=$cropX, y=$cropY, w=$cropWidth, h=$cropHeight');

      // Crop the image
      final img.Image croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Optimize image size and quality
      final img.Image resizedImage = img.copyResize(
        croppedImage,
        width: cropWidth > 800 ? 800 : cropWidth, // Limit max width
        height: cropHeight > 600 ? 600 : cropHeight, // Limit max height
      );

      // Save the processed image with reduced quality
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagePath = path.join(
        appDir.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final File croppedFile = File(imagePath);

      // Use JPEG with quality setting to reduce file size
      await croppedFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));

      // Clean up the original temporary file immediately
      try {
        await File(file.path).delete();
        print('Temporary file deleted: ${file.path}');
      } catch (e) {
        print('Error deleting temporary file: $e');
      }

      // Clear image from memory
      image.clear();
      croppedImage.clear();
      resizedImage.clear();

      if (!_isDisposed) {
        setState(() {
          _capturedImage = croppedFile;
        });

        // Navigate to preview screen with cropped image
        if (mounted) {
          // Dispose camera before navigation to free resources
          await _disposeCamera();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LicencePreview(
                imageFile: croppedFile,
                eventId: widget.eventId,
                leadId: widget.leadId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error processing image: $e');
      // Clean up the original file if processing failed
      try {
        await File(file.path).delete();
      } catch (deleteError) {
        print('Error deleting file after processing failure: $deleteError');
      }
      rethrow;
    }
  }

  Future<void> submitFeedback(String skipReason) async {
    if (_isDisposed) return;

    setState(() {
      _isUploading = true;
    });
    try {
      print('Event ID: ${widget.eventId}');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? spId = prefs.getString('user_id');
      final url = Uri.parse(
        'https://dev.smartassistapp.in/api/events/update/${widget.eventId}',
      );
      final token = await Storage.getToken();
      skip['Overall Ambience'] = skipReason;
      final requestBody = {
        'sp_id': spId,
        'skip_license': skip['Overall Ambience'],
      };
      print(requestBody);
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );
      final responseData = jsonDecode(response.body);
      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');
      print(url.toString());
      if (response.statusCode == 200) {
        print('Feedback submitted successfully');
        if (!_isDisposed && mounted) {
          Get.snackbar('Success', 'License verification skipped successfully');

          // Dispose camera before navigation
          await _disposeCamera();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StartDriveMap(leadId: widget.leadId, eventId: widget.eventId),
            ),
          );
        }
      } else {
        print(
          'Failed to submit feedback : ${responseData['message'].toString()}',
        );
        if (!_isDisposed && mounted) {
          Get.snackbar('Error', 'error due to ${responseData['message']}');
        }
      }
    } catch (e) {
      print('Exception occurred: ${e.toString()}');
      if (!_isDisposed && mounted) {
        Get.snackbar('Error', 'An error occurred: ${e.toString()}');
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

 
  // Future<void> submitFeedback(String skipReason) async {
  //   setState(() {
  //     _isUploading = true;
  //   });

  //   try {
  //     print('Event ID: ${widget.eventId}');
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     String? spId = prefs.getString('user_id');
  //     final url = Uri.parse(
  //       'https://dev.smartassistapp.in/api/events/update/${widget.eventId}',
  //     );
  //     final token = await Storage.getToken();

  //     // Update the skip reason
  //     skip['Overall Ambience'] = skipReason;

  //     // Create the request body
  //     final requestBody = {
  //       'sp_id': spId,
  //       'skip_license': skip['Overall Ambience'],
  //     };

  //     print(requestBody);

  //     final response = await http.put(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //       body: json.encode(requestBody),
  //     );

  //     final responseData = jsonDecode(response.body);

  //     // Print the response
  //     print('API Response status: ${response.statusCode}');
  //     print('API Response body: ${response.body}');
  //     print(url.toString());
  //     if (response.statusCode == 200) {
  //       // Success handling
  //       print('Feedback submitted successfully');
  //       Get.snackbar(
  //         'Success',
  //         'License verification skipped successfully',
  //         backgroundColor: Colors.green,
  //         colorText: Colors.white,
  //       );

  //       // Navigate to FollowupsDetails screen
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) =>
  //               StartDriveMap(leadId: widget.leadId, eventId: widget.eventId),
  //         ),
  //       );
  //     } else {
  //       // Error handling
  //       print(
  //         'Failed to submit feedback : ${responseData['message'].toString()}',
  //       );
  //       Get.snackbar(
  //         'Error',
  //         'error due to ${responseData['message']}',
  //         backgroundColor: Colors.red,
  //         colorText: Colors.white,
  //       );
  //     }
  //   } catch (e) {
  //     // Exception handling
  //     print('Exception occurred: ${e.toString()}');
  //     Get.snackbar(
  //       'Error',
  //       'An error occurred: ${e.toString()}',
  //       backgroundColor: Colors.red,
  //       colorText: Colors.white,
  //     );
  //   } finally {
  //     setState(() {
  //       _isUploading = false;
  //     });
  //   }
  // }

 
  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculate rectangle dimensions
    frameWidth = MediaQuery.of(context).size.width * 0.85;
    frameHeight = MediaQuery.of(context).size.width * 0.55;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            await _disposeCamera(); // Dispose camera before going back
            Get.back();
          },
          icon: const Icon(
            size: 30,
            Icons.keyboard_arrow_left_rounded,
            color: Colors.white,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text('License', style: AppFont.appbarfontWhite(context)),
        ),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                // Camera Preview with proper aspect ratio handling
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cameraController!.value.previewSize!.height,
                      height: cameraController!.value.previewSize!.width,
                      child: CameraPreview(cameraController!),
                    ),
                  ),
                ),

                // Overlay with guidance
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      // This creates the darkened areas around the rectangle
                      ClipPath(
                        clipper: InvertedRectangleClipper(
                          center: Offset(
                            MediaQuery.of(context).size.width / 2,
                            MediaQuery.of(context).size.height / 2.4,
                          ),
                          width: frameWidth,
                          height: frameHeight,
                          borderRadius: 12,
                        ),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),

                      // Border for the cutout
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 55),
                          width: frameWidth,
                          height: frameHeight,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.colorsBlue,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      // Guidance text
                      Positioned(
                        top: MediaQuery.of(context).size.height * 0.25,
                        left: 0,
                        right: 0,
                        child: const Text(
                          'Align license within the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Corner lines (for visual guidance)
                      _buildCornerLines(),

                      // Bottom controls
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Skip button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _isUploading ? null : _showSkipDialog,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Icon(Icons.skip_next, color: Colors.black87),
                                ],
                              ),
                            ),

                            // Capture button
                            InkWell(
                              onTap: () {
                                if (!_isUploading && !_isCapturing) {
                                  _captureImage();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.all(10),
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: _isCapturing
                                      ? Colors.grey
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: _isCapturing
                                      ? const CircularProgressIndicator(
                                          color: Colors.blue,
                                          strokeWidth: 2,
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            // Placeholder to balance the row
                            const SizedBox(width: 80),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.colorsBlue),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCornerLines() {
    final cornerSize = 20.0;
    final centerWidget = Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 55),
        width: frameWidth,
        height: frameHeight,
        child: Stack(
          children: [
            // Top Left Corner
            Positioned(
              top: 0,
              left: 0,
              child: _buildCorner(cornerSize, isTopLeft: true),
            ),
            // Top Right Corner
            Positioned(
              top: 0,
              right: 0,
              child: _buildCorner(cornerSize, isTopRight: true),
            ),
            // Bottom Left Corner
            Positioned(
              bottom: 0,
              left: 0,
              child: _buildCorner(cornerSize, isBottomLeft: true),
            ),
            // Bottom Right Corner
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildCorner(cornerSize, isBottomRight: true),
            ),
          ],
        ),
      ),
    );

    return centerWidget;
  }

  Widget _buildCorner(
    double size, {
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    return Container(
      width: size,
      height: size,
      child: CustomPaint(
        painter: CornerPainter(
          isTopLeft: isTopLeft,
          isTopRight: isTopRight,
          isBottomLeft: isBottomLeft,
          isBottomRight: isBottomRight,
          color: Colors.white,
          lineWidth: 3,
        ),
      ),
    );
  }

  // Show skip confirmation dialog
  Future<void> _showSkipDialog() async {
    if (_isDisposed) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(10),
          contentPadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  textAlign: TextAlign.center,
                  'Select reason to skip',
                  style: AppFont.mediumText14(context),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Divider(height: 1, color: Colors.grey.shade200),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    submitFeedback(
                      "License previously verified - trusted client",
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'License previously verified - trusted client.',
                      style: AppFont.mediumText14(context),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    submitFeedback(
                      "Test drive under sales associate supervision - license on file",
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Test drive under sales associate supervision - license on file.',
                      style: AppFont.mediumText14(context),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    submitFeedback(
                      "Exception approved by management - premium client",
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Exception approved by management - premium client.',
                      style: AppFont.mediumText14(context),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.colorsBlue),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom painter for license corner lines
class CornerPainter extends CustomPainter {
  final bool isTopLeft;
  final bool isTopRight;
  final bool isBottomLeft;
  final bool isBottomRight;
  final Color color;
  final double lineWidth;

  CornerPainter({
    this.isTopLeft = false,
    this.isTopRight = false,
    this.isBottomLeft = false,
    this.isBottomRight = false,
    this.color = Colors.white,
    this.lineWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    if (isTopLeft) {
      // Draw top line
      canvas.drawLine(Offset(0, 0), Offset(size.width * 0.7, 0), paint);
      // Draw left line
      canvas.drawLine(Offset(0, 0), Offset(0, size.height * 0.7), paint);
    } else if (isTopRight) {
      // Draw top line
      canvas.drawLine(
        Offset(size.width * 0.3, 0),
        Offset(size.width, 0),
        paint,
      );
      // Draw right line
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height * 0.7),
        paint,
      );
    } else if (isBottomLeft) {
      // Draw bottom line
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width * 0.7, size.height),
        paint,
      );
      // Draw left line
      canvas.drawLine(
        Offset(0, size.height * 0.3),
        Offset(0, size.height),
        paint,
      );
    } else if (isBottomRight) {
      // Draw bottom line
      canvas.drawLine(
        Offset(size.width * 0.3, size.height),
        Offset(size.width, size.height),
        paint,
      );
      // Draw right line
      canvas.drawLine(
        Offset(size.width, size.height * 0.3),
        Offset(size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Changed to false for better performance
  }
}

// Custom clipper to create the transparent rectangle in the middle
class InvertedRectangleClipper extends CustomClipper<Path> {
  final Offset center;
  final double width;
  final double height;
  final double borderRadius;

  InvertedRectangleClipper({
    required this.center,
    required this.width,
    required this.height,
    this.borderRadius = 0,
  });

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutLeft = center.dx - width / 2;
    final cutoutTop = center.dy - height / 2;
    final cutoutRight = center.dx + width / 2;
    final cutoutBottom = center.dy + height / 2;

    final cutoutPath = Path();

    if (borderRadius > 0) {
      cutoutPath.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cutoutLeft, cutoutTop, cutoutRight, cutoutBottom),
          Radius.circular(borderRadius),
        ),
      );
    } else {
      cutoutPath.addRect(
        Rect.fromLTRB(cutoutLeft, cutoutTop, cutoutRight, cutoutBottom),
      );
    }

    // Subtracts the cutout from the full size to create the inverted effect
    return Path.combine(PathOperation.difference, path, cutoutPath);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false; // Changed for better performance
}
 



// Don't forget to add this import at the top of your file:
// import 'package:image/image.dart' as img;
// import 'dart:math';
// Custom painter for license corner lines







// import 'dart:convert';
// import 'dart:io'; 
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart'; 
// import 'package:get/get.dart'; 
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as path;
// import 'package:path_provider/path_provider.dart'; 
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';

// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/license_preview.dart';
// import 'package:smartassist/widgets/start_drive.dart';

// class LicenseVarification extends StatefulWidget {
//   final String eventId;
//   final String leadId;
//   const LicenseVarification(
//       {super.key, required this.eventId, required this.leadId});

//   @override
//   State<LicenseVarification> createState() => _LicenseVarificationState();
// }

// class _LicenseVarificationState extends State<LicenseVarification> {
//   List<CameraDescription> cameras = [];
//   CameraController? cameraController;
//   File? _capturedImage;
//   bool _isCameraInitialized = false;
//   bool _isUploading = false;

//   // Define a map to store skip reasons
//   Map<String, String> skip = {
//     'Overall Ambience': '',
//   };

//   @override
//   void initState() {
//     super.initState();
//     _setupCameraController();
//   }

//   Future<void> _setupCameraController() async {
//     List<CameraDescription> _cameras = await availableCameras();
//     if (_cameras.isNotEmpty) {
//       cameraController =
//           CameraController(_cameras.first, ResolutionPreset.high);
//       await cameraController!.initialize();
//       setState(() {
//         _isCameraInitialized = true;
//       });
//     }
//   }

//   Future<void> _captureImage() async {
//     if (!(cameraController?.value.isInitialized ?? false)) return;

//     final XFile file = await cameraController!.takePicture();
//     final Directory appDir = await getApplicationDocumentsDirectory();
//     final String imagePath = path.join(appDir.path, '${DateTime.now()}.png');
//     final File newImage = await File(file.path).copy(imagePath);

//     setState(() {
//       _capturedImage = newImage;
//     });

//     // Navigate to preview screen
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LicencePreview(
//           imageFile: newImage,
//           eventId: widget.eventId,
//           leadId: widget.leadId,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     cameraController?.dispose();
//     super.dispose();
//   }

//   Future<void> submitFeedback(String skipReason) async {
//     setState(() {
//       _isUploading = true;
//     });

//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? spId = prefs.getString('user_id');
//       final url = Uri.parse(
//           'https://dev.smartassistapp.in/api/events/update/${widget.eventId}');
//       final token = await Storage.getToken();

//       // Update the skip reason
//       skip['Overall Ambience'] = skipReason;

//       // Create the request body
//       final requestBody = {
//         'sp_id': spId,
//         'skip_license': skip['Overall Ambience'],
//       };

//       // Print the data to console for debugging
//       print('Submitting feedback data:');
//       print(requestBody);

//       final response = await http.put(url,
//           headers: {
//             'Content-Type': 'application/json',
//             'Authorization': 'Bearer $token',
//           },
//           body: json.encode(requestBody));

//       // Print the response
//       print('API Response status: ${response.statusCode}');
//       print('API Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         // Success handling
//         print('Feedback submitted successfully');
//         Get.snackbar(
//           'Success',
//           'License verification skipped successfully',
//           backgroundColor: Colors.green,
//           colorText: Colors.white,
//         );

//         // Navigate to FollowupsDetails screen
//         Navigator.push(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => StartDriveMap(
//                       leadId: widget.leadId,
//                       eventId: widget.eventId,
//                     )));
//       } else {
//         // Error handling
//         print('Failed to submit feedback');
//         Get.snackbar(
//           'Error',
//           'Failed to skip license verification',
//           backgroundColor: Colors.red,
//           colorText: Colors.white,
//         );
//       }
//     } catch (e) {
//       // Exception handling
//       print('Exception occurred: ${e.toString()}');
//       Get.snackbar(
//         'Error',
//         'An error occurred: ${e.toString()}',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: _isCameraInitialized
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   SizedBox(
//                     height: MediaQuery.sizeOf(context).height * 0.06,
//                   ),
//                   SizedBox(
//                     child: FittedBox(
//                       fit: BoxFit.cover,
//                       child: SizedBox(
//                         width: cameraController!.value.previewSize!.height,
//                         height: cameraController!.value.previewSize!.width,
//                         child: CameraPreview(cameraController!),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       IconButton(
//                           onPressed: () {
//                             if (!_isUploading) {
//                               _captureImage();
//                             }
//                           },
//                           icon: Icon(
//                             Icons.camera,
//                             size: MediaQuery.sizeOf(context).height * 0.07,
//                             color: Colors.white,
//                           )),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: AppColors.colorsBlue,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(5),
//                               ),
//                             ),
//                             onPressed: _showSkipDialog,
//                             child: Row(
//                               children: [
//                                 Text('Skip',
//                                     style: AppFont.smallTextWhite(context)),
//                                 const Icon(
//                                   Icons.skip_next,
//                                   color: Colors.white,
//                                 )
//                               ],
//                             )),
//                       )
//                     ],
//                   ),
//                 ],
//               ),
//             )
//           : const Center(child: CircularProgressIndicator()),
//     );
//   }

//   // Show skip confirmation dialog
//   Future<void> _showSkipDialog() async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false, // User must tap button to close dialog
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(5),
//           ),
//           backgroundColor: Colors.white,
//           insetPadding: const EdgeInsets.all(10),
//           contentPadding: EdgeInsets.zero,
//           title: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Align(
//                 alignment: Alignment.bottomLeft,
//                 child: Text(
//                   textAlign: TextAlign.center,
//                   'Select reason to skip',
//                   style: AppFont.mediumText14(context),
//                 ),
//               ),
//               const SizedBox(
//                 height: 10,
//               )
//               // Divider(color: Colors.grey.shade300),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 TextButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       submitFeedback(
//                           "License previously verified - trusted client");
//                     },
//                     child: Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         'License previously verified - trusted client.',
//                         style: AppFont.mediumText14(context),
//                         textAlign: TextAlign.left,
//                       ),
//                     )),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 TextButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       submitFeedback(
//                           "Test drive under sales associate supervision - license on file");
//                     },
//                     child: Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         'Test drive under sales associate supervision - license on file.',
//                         style: AppFont.mediumText14(context),
//                         textAlign: TextAlign.left,
//                       ),
//                     )),
//                 Divider(height: 1, color: Colors.grey.shade200),
//                 TextButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       submitFeedback(
//                           "Exception approved by management - premium client");
//                     },
//                     child: Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         'Exception approved by management - premium client.',
//                         style: AppFont.mediumText14(context),
//                         textAlign: TextAlign.left,
//                       ),
//                     )),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child:const Text(
//                 'Cancel',
//                 style: TextStyle(color: AppColors.colorsBlue),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// } 
