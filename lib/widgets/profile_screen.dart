import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'dart:ui' as ui;

import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  const ProfileScreen({super.key, required this.refreshDashboard});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  bool isLoading = true;
  String? name, email, location, mobile, userRole, profilePic;
  double rating = 0.0;
  double professionalism = 0.0;
  double efficiency = 0.0;
  double responseTime = 0.0;
  double productKnowledge = 0.0;

  // Screenshot controller for evaluation section
  ScreenshotController _evaluationScreenshotController = ScreenshotController();
  ScreenshotController _screenshotController = ScreenshotController();

  // Global key for capturing evaluation widget
  final GlobalKey _evaluationKey = GlobalKey();

  // Fetch profile data from API
  Future<void> fetchProfileData() async {
    final token = await Storage.getToken();
    final response = await http.get(
      Uri.parse('https://dev.smartassistapp.in/api/users/show-profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        name = data['data']['name'];
        email = data['data']['email'];
        location = data['data']['dealer_location'];
        mobile = data['data']['phone'];
        profilePic = data['data']['profile_pic'];
        userRole = data['data']['user_role'];
        rating = data['data']['rating'] != null
            ? data['data']['rating'].toDouble()
            : 0.0;

        final evaluation = data['data']['evaluation'];
        if (evaluation != null) {
          professionalism = evaluation['professionalism'] != null
              ? evaluation['professionalism'] / 10
              : 0.0;
          efficiency = evaluation['efficiency'] != null
              ? evaluation['efficiency'] / 10
              : 0.0;
          responseTime = evaluation['responseTime'] != null
              ? evaluation['responseTime'] / 10
              : 0.0;
          productKnowledge = evaluation['productKnowledge'] != null
              ? evaluation['productKnowledge'] / 10
              : 0.0;
        }
        widget.refreshDashboard();

        isLoading = false;
      });
    } else {
      // Handle the error
      setState(() {
        isLoading = false;
      });
      print('Failed to fetch profile data');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);

    setState(() {
      _profileImage = imageFile;
      _isUploading = true;
    });

    final token = await Storage.getToken();
    final uri = Uri.parse(
      'https://dev.smartassistapp.in/api/users/profile/set',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile(
          'file', // ✅ Corrected key
          imageFile.readAsBytes().asStream(),
          imageFile.lengthSync(),
          filename: path.basename(imageFile.path),
          contentType: MediaType('image', 'jpeg'),
        ),
      );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        print("✅ Profile image uploaded successfully.");
        print("Response: ${res}");

        setState(() {
          profilePic = res['data']; // ✅ Update profilePic from response
          _profileImage = null; // Optional: clear File after successful upload
        });

        fetchProfileData();
      } else {
        print("❌ Upload failed: ${response.statusCode}");
        print("Response: ${response.body}");
      }
    } catch (e) {
      print("❌ Upload error: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      deleteImg(context);
      _profileImage = null;
      // If you want to also clear the network image URL
      profilePic = null; // or profilePic = '';
    });

    // Optional: Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile image removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> deleteImg(BuildContext context) async {
    try {
      final url = Uri.parse(
        'https://dev.smartassistapp.in/api/users/profile/remove-pic',
      );
      final token = await Storage.getToken();

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        // body: json.encode(requestBody),
      );

      // Print the response
      print('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Unknown error';
        // Success handling
        print('Feedback submitted successfully');
        Get.snackbar(
          'Success',
          errorMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        widget.refreshDashboard();
      } else {
        // Error handling
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Unknown error';
      }
    } catch (e) {
      // Exception handling
      print('Exception occurred: ${e.toString()}');
    } finally {
      setState(() {
        // _isUploading = false; // Reset loading state
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchProfileData();
    _screenshotController = ScreenshotController();
    _evaluationScreenshotController = ScreenshotController();
  }

  // Method to capture and share evaluation section
  Future<void> _shareEvaluationSection() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Capture the evaluation section
      final Uint8List? image = await _evaluationScreenshotController.capture();

      // Dismiss loading
      Get.back();

      if (image != null) {
        // Save image to temporary directory
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/evaluation_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(image);

        // Create XFile for sharing
        final XFile xFile = XFile(filePath);

        // Share the image with text
        await Share.shareXFiles(
          [xFile],
          text:
              'Check out my evaluation results!\n\n'
              '📊 My Performance Evaluation:\n'
              '• Professionalism: ${(professionalism * 100).toStringAsFixed(0)}%\n'
              '• Efficiency: ${(efficiency * 100).toStringAsFixed(0)}%\n'
              '• Response Time: ${(responseTime * 100).toStringAsFixed(0)}%\n'
              '• Product Knowledge: ${(productKnowledge * 100).toStringAsFixed(0)}%\n\n'
              '#SmartAssist #Evaluation #Performance',
          subject: '${name ?? "User"}\'s Evaluation Results',
        );

        // Clean up temporary file after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (file.existsSync()) {
            file.deleteSync();
          }
        });
      } else {
        Get.snackbar(
          'Error',
          'Failed to capture evaluation section',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back(); // Dismiss loading if still showing
      print("Error sharing evaluation: $e");
      Get.snackbar(
        'Error',
        'Failed to share evaluation: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Alternative method using RepaintBoundary
  Future<void> _shareEvaluationUsingRepaintBoundary() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      RenderRepaintBoundary? boundary =
          _evaluationKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary != null) {
        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData != null) {
          Uint8List pngBytes = byteData.buffer.asUint8List();

          final directory = await getTemporaryDirectory();
          final filePath =
              '${directory.path}/evaluation_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File(filePath);
          await file.writeAsBytes(pngBytes);

          Get.back(); // Dismiss loading

          final XFile xFile = XFile(filePath);
          await Share.shareXFiles(
            [xFile],
            text:
                'Check out my evaluation results!\n\n'
                '📊 My Performance Evaluation:\n'
                '• Professionalism: ${(professionalism * 100).toStringAsFixed(0)}%\n'
                '• Efficiency: ${(efficiency * 100).toStringAsFixed(0)}%\n'
                '• Response Time: ${(responseTime * 100).toStringAsFixed(0)}%\n'
                '• Product Knowledge: ${(productKnowledge * 100).toStringAsFixed(0)}%\n\n'
                '#SmartAssist #Evaluation #Performance',
            subject: '${name ?? "User"}\'s Evaluation Results',
          );

          Future.delayed(const Duration(seconds: 5), () {
            if (file.existsSync()) {
              file.deleteSync();
            }
          });
        }
      }
    } catch (e) {
      Get.back();
      print("Error sharing evaluation: $e");
      Get.snackbar(
        'Error',
        'Failed to share evaluation',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _captureAndUploadImage() async {
    // Longer delay before capture to ensure UI is fully rendered
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        print("Screenshot capture returned null - trying alternative method");
        // Try alternative capture method - use UI only
        return;
      }

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/map_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath)..writeAsBytesSync(image);

      // await _uploadImage(file);
    } catch (e) {
      print("Error in screenshot capture: $e");
      // Fall back to drive summary upload
      // Don't rethrow - we've handled it with the fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Get.back();
            widget.refreshDashboard();
          },
          icon: const Icon(
            Icons.keyboard_arrow_left_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Profile', style: AppFont.appbarfontWhite(context)),
              // InkWell(
              //   onTap: () {
              //     print('share profile is clicked');
              //   },
              //   child: Text('Share', style: AppFont.mediumText14white(context)),
              // ),
            ],
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    GestureDetector(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Avatar (from file, network, or default)
                          _profileImage != null
                              ? CircleAvatar(
                                  radius: 60,
                                  backgroundImage: FileImage(_profileImage!),
                                )
                              : (profilePic != null && profilePic!.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 60,
                                        backgroundImage: NetworkImage(
                                          profilePic!,
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 60,
                                        backgroundColor: AppColors.containerBg,
                                        child: Text(
                                          (name?.isNotEmpty ?? false)
                                              ? name![0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 70,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      )),

                          // Optional uploading indicator
                          if (_isUploading) const CircularProgressIndicator(),

                          // Show either add or delete icon based on image existence
                          if (_profileImage != null ||
                              (profilePic != null && profilePic!.isNotEmpty))
                            Positioned(
                              bottom: -8,
                              left: 80,
                              child: IconButton(
                                onPressed: _removeImage,
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            )
                          else if (!_isUploading)
                            Positioned(
                              bottom: -8,
                              left: 80,
                              child: IconButton(
                                onPressed: _pickImage,
                                icon: const Icon(
                                  Icons.add_a_photo,
                                  color: AppColors.fontColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(name ?? '', style: AppFont.popupTitleBlack(context)),
                    Text(
                      userRole ?? 'User',
                      style: AppFont.mediumText14(context),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < rating
                              ? AppColors.starColorsYellow
                              : Colors.grey,
                          size: 38,
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text('(0 reviews)', style: AppFont.mediumText14(context)),
                    const SizedBox(height: 10),
                    // Profile details (Email, Location, Mobile)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLightGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 15,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileItem('Email', email ?? ''),
                              const SizedBox(height: 10),
                              _buildProfileItem('Location', location ?? ''),
                              const SizedBox(height: 10),
                              _buildProfileItem('Mobile', mobile ?? ''),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Evaluation Progress Bars with Screenshot capability
                    const SizedBox(height: 20),
                    // Wrap evaluation section with RepaintBoundary for screenshot
                    RepaintBoundary(
                      key: _evaluationKey,
                      child: Screenshot(
                        controller: _evaluationScreenshotController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLightGrey,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 15,
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 10.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Evaluation',
                                        style: AppFont.popupTitleBlack16(
                                          context,
                                        ),
                                      ),
                                      // Share button for evaluation
                                      GestureDetector(
                                        onTap: _shareEvaluationSection,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.colorsBlue,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.share,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Share',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildEvaluationProgress(
                                  'Professionalism',
                                  professionalism,
                                ),
                                const SizedBox(height: 5),
                                _buildEvaluationProgress(
                                  'Efficiency of service call handling',
                                  efficiency,
                                ),
                                const SizedBox(height: 5),
                                _buildEvaluationProgress(
                                  'Response time of service calls',
                                  responseTime,
                                ),
                                const SizedBox(height: 5),
                                _buildEvaluationProgress(
                                  'Product Knowledge & Brand Representation',
                                  productKnowledge,
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
            ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            softWrap: true,
            maxLines: 3,
            label,
            style: AppFont.mediumText14(context),
          ),
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            softWrap: true,
            maxLines: 3,
            value,
            style: AppFont.dropDowmLabel(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationProgress(String label, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(label, style: AppFont.dropDowmLabel(context)),
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '${(percentage * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _getGradientForProgress(percentage).last,
            ),
            softWrap: true,
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 10),
        LinearPercentIndicator(
          lineHeight: 14.0,
          percent: percentage,
          backgroundColor: Colors.grey[200]!,
          barRadius: const Radius.circular(8),
          linearGradient: LinearGradient(
            colors: _getGradientForProgress(percentage),
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  List<Color> _getGradientForProgress(double percentage) {
    if (percentage >= 0.8) {
      return [
        Color.fromRGBO(255, 237, 215, 0.9),
        Color.fromRGBO(83, 157, 243, 1),
        Color.fromRGBO(144, 109, 250, 1),
      ];
    } else if (percentage >= 0.6) {
      return [
        Color.fromRGBO(229, 208, 210, 1),
        Color.fromRGBO(255, 150, 165, 1),
        Color.fromRGBO(255, 122, 113, 1),
      ];
    } else if (percentage >= 0.3) {
      return [
        Color.fromRGBO(254, 221, 176, 1),
        Color.fromRGBO(144, 109, 250, 1),
        Color.fromRGBO(255, 122, 113, 1),
      ];
    } else {
      return [
        Color.fromRGBO(182, 247, 249, 1),
        Color.fromRGBO(168, 230, 251, 1),
        Color.fromRGBO(196, 201, 255, 1),
      ];
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:http_parser/http_parser.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:percent_indicator/percent_indicator.dart'; // For progress bars
// import 'package:get/get.dart';
// import 'package:screenshot/screenshot.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import 'package:path/path.dart' as path;
// import 'package:smartassist/utils/storage.dart';

// class ProfileScreen extends StatefulWidget {
//   final Future<void> Function() refreshDashboard;
//   const ProfileScreen({super.key, required this.refreshDashboard});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   File? _profileImage;
//   final ImagePicker _picker = ImagePicker();
//   bool _isUploading = false;

//   bool isLoading = true;
//   String? name, email, location, mobile, userRole, profilePic;
//   double rating = 0.0;
//   double professionalism = 0.0;
//   double efficiency = 0.0;
//   double responseTime = 0.0;
//   double productKnowledge = 0.0;

//   // Fetch profile data from API
//   Future<void> fetchProfileData() async {
//     final token = await Storage.getToken();
//     final response = await http.get(
//       Uri.parse('https://dev.smartassistapp.in/api/users/show-profile'),
//       headers: {
//         'Authorization': 'Bearer $token',
//         'Content-Type': 'application/json',
//       },
//     );

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       setState(() {
//         name = data['data']['name'];
//         email = data['data']['email'];
//         location = data['data']['dealer_location'];
//         mobile = data['data']['phone'];
//         profilePic = data['data']['profile_pic'];
//         userRole = data['data']['user_role'];
//         rating = data['data']['rating'] != null
//             ? data['data']['rating'].toDouble()
//             : 0.0;

//         final evaluation = data['data']['evaluation'];
//         if (evaluation != null) {
//           professionalism = evaluation['professionalism'] != null
//               ? evaluation['professionalism'] / 10
//               : 0.0;
//           efficiency = evaluation['efficiency'] != null
//               ? evaluation['efficiency'] / 10
//               : 0.0;
//           responseTime = evaluation['responseTime'] != null
//               ? evaluation['responseTime'] / 10
//               : 0.0;
//           productKnowledge = evaluation['productKnowledge'] != null
//               ? evaluation['productKnowledge'] / 10
//               : 0.0;
//         }
//         widget.refreshDashboard();

//         isLoading = false;
//       });
//     } else {
//       // Handle the error
//       setState(() {
//         isLoading = false;
//       });
//       print('Failed to fetch profile data');
//     }
//   }

//   Future<void> _pickImage() async {
//     final pickedFile = await ImagePicker().pickImage(
//       source: ImageSource.gallery,
//     );

//     if (pickedFile == null) return;

//     File imageFile = File(pickedFile.path);

//     setState(() {
//       _profileImage = imageFile;
//       _isUploading = true;
//     });

//     final token = await Storage.getToken();
//     final uri = Uri.parse(
//       'https://dev.smartassistapp.in/api/users/profile/set',
//     );

//     final request = http.MultipartRequest('POST', uri)
//       ..headers['Authorization'] = 'Bearer $token'
//       ..files.add(
//         http.MultipartFile(
//           'file', // ✅ Corrected key
//           imageFile.readAsBytes().asStream(),
//           imageFile.lengthSync(),
//           filename: path.basename(imageFile.path),
//           contentType: MediaType('image', 'jpeg'),
//         ),
//       );

//     try {
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);

//       if (response.statusCode == 200) {
//         final res = json.decode(response.body);
//         print("✅ Profile image uploaded successfully.");
//         print("Response: ${res}");

//         setState(() {
//           profilePic = res['data']; // ✅ Update profilePic from response
//           _profileImage = null; // Optional: clear File after successful upload
//         });

//         fetchProfileData();
//       } else {
//         print("❌ Upload failed: ${response.statusCode}");
//         print("Response: ${response.body}");
//       }
//     } catch (e) {
//       print("❌ Upload error: $e");
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }

//   void _removeImage() {
//     setState(() {
//       deleteImg(context);
//       _profileImage = null;
//       // If you want to also clear the network image URL
//       profilePic = null; // or profilePic = '';
//     });

//     // Optional: Show confirmation snackbar
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Profile image removed'),
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }

//   Future<void> deleteImg(BuildContext context) async {
//     try {
//       final url = Uri.parse(
//         'https://dev.smartassistapp.in/api/users/profile/remove-pic',
//       );
//       final token = await Storage.getToken();

//       final response = await http.put(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         // body: json.encode(requestBody),
//       );

//       // Print the response
//       print('API Response status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final errorMessage =
//             json.decode(response.body)['message'] ?? 'Unknown error';
//         // Success handling
//         print('Feedback submitted successfully');
//         Get.snackbar(
//           'Success',
//           errorMessage,
//           backgroundColor: Colors.green,
//           colorText: Colors.white,
//         );
//         widget.refreshDashboard();
//       } else {
//         // Error handling
//         final errorMessage =
//             json.decode(response.body)['message'] ?? 'Unknown error';
//       }
//     } catch (e) {
//       // Exception handling
//       print('Exception occurred: ${e.toString()}');
//     } finally {
//       setState(() {
//         // _isUploading = false; // Reset loading state
//       });
//     }
//   }

//   ScreenshotController _screenshotController = ScreenshotController();

//   @override
//   void initState() {
//     super.initState();
//     fetchProfileData();

//     _screenshotController = ScreenshotController();
//   }

//   Future<void> _captureAndUploadImage() async {
//     // Longer delay before capture to ensure UI is fully rendered
//     await Future.delayed(const Duration(milliseconds: 500));

//     try {
//       final image = await _screenshotController.capture();
//       if (image == null) {
//         print("Screenshot capture returned null - trying alternative method");
//         // Try alternative capture method - use UI only
//         return;
//       }

//       final directory = await getTemporaryDirectory();
//       final filePath =
//           '${directory.path}/map_image_${DateTime.now().millisecondsSinceEpoch}.png';
//       final file = File(filePath)..writeAsBytesSync(image);

//       // await _uploadImage(file);
//     } catch (e) {
//       print("Error in screenshot capture: $e");
//       // Fall back to drive summary upload
//       // Don't rethrow - we've handled it with the fallback
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           onPressed: () {
//             Get.back();
//             widget.refreshDashboard();
//           },

//           icon: const Icon(
//             Icons.keyboard_arrow_left_rounded,
//             color: Colors.white,
//             size: 40,
//           ),
//         ),
//         title: Align(
//           alignment: Alignment.centerLeft,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text('Your Profile', style: AppFont.appbarfontWhite(context)),
//               InkWell(
//                 onTap: () {
//                   print('share profile is clicked');
//                 },
//                 child: Text('Share', style: AppFont.mediumText14white(context)),
//               ),
//             ],
//           ),
//         ),
//         backgroundColor: AppColors.colorsBlue,

//         automaticallyImplyLeading: false,
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     GestureDetector(
//                       child: Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           // Avatar (from file, network, or default)
//                           _profileImage != null
//                               ? CircleAvatar(
//                                   radius: 60,
//                                   backgroundImage: FileImage(_profileImage!),
//                                 )
//                               : (profilePic != null && profilePic!.isNotEmpty
//                                     ? CircleAvatar(
//                                         radius: 60,
//                                         backgroundImage: NetworkImage(
//                                           profilePic!,
//                                         ),
//                                       )
//                                     : CircleAvatar(
//                                         radius: 60,
//                                         backgroundColor: AppColors.containerBg,
//                                         child: Text(
//                                           (name?.isNotEmpty ?? false)
//                                               ? name![0].toUpperCase()
//                                               : '?',
//                                           style: TextStyle(
//                                             fontSize: 70,
//                                             color: Colors.grey[700],
//                                             fontWeight: FontWeight.normal,
//                                           ),
//                                         ),
//                                       )),

//                           // Optional uploading indicator
//                           if (_isUploading) const CircularProgressIndicator(),

//                           // Show either add or delete icon based on image existence
//                           if (_profileImage != null ||
//                               (profilePic != null && profilePic!.isNotEmpty))
//                             Positioned(
//                               bottom: -8,
//                               left: 80,
//                               child: IconButton(
//                                 onPressed: _removeImage,
//                                 icon: const Icon(
//                                   Icons.delete,
//                                   color: Colors.red,
//                                 ),
//                               ),
//                             )
//                           else if (!_isUploading)
//                             Positioned(
//                               bottom: -8,
//                               left: 80,
//                               child: IconButton(
//                                 onPressed: _pickImage,
//                                 icon: const Icon(
//                                   Icons.add_a_photo,
//                                   color: AppColors.fontColor,
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 10),
//                     Text(name ?? '', style: AppFont.popupTitleBlack(context)),
//                     Text(
//                       userRole ?? 'User',
//                       style: AppFont.mediumText14(context),
//                     ),
//                     const SizedBox(height: 10),
//                     Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: List.generate(5, (index) {
//                         return Icon(
//                           index < rating
//                               ? Icons.star_rounded
//                               : Icons.star_outline_rounded,
//                           color: index < rating
//                               ? AppColors.starColorsYellow
//                               : Colors.grey,
//                           size: 38,
//                         );
//                       }),
//                     ),
//                     const SizedBox(height: 10),
//                     Text('(0 reviews)', style: AppFont.mediumText14(context)),
//                     const SizedBox(height: 10),
//                     // Profile details (Email, Location, Mobile)
//                     Container(
//                       decoration: BoxDecoration(
//                         color: AppColors.backgroundLightGrey,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 20.0,
//                           vertical: 15,
//                         ),
//                         child: Align(
//                           alignment: Alignment.centerLeft,
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.start,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               _buildProfileItem('Email', email ?? ''),
//                               const SizedBox(height: 10),
//                               _buildProfileItem('Location', location ?? ''),
//                               const SizedBox(height: 10),
//                               _buildProfileItem('Mobile', mobile ?? ''),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),

//                     // Evaluation Progress Bars
//                     const SizedBox(height: 20),
//                     // this container i want screen shot and share on the platform
//                     Container(
//                       decoration: BoxDecoration(
//                         color: AppColors.backgroundLightGrey,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10.0,
//                           vertical: 15,
//                         ),
//                         child: Column(
//                           children: [
//                             Padding(
//                               padding: const EdgeInsets.only(left: 10.0),
//                               child: Align(
//                                 alignment: Alignment.centerLeft,
//                                 child: Text(
//                                   'Evaluation',
//                                   style: AppFont.popupTitleBlack16(context),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 10),
//                             _buildEvaluationProgress(
//                               'Professionalism',
//                               professionalism,
//                             ),
//                             const SizedBox(height: 5),
//                             _buildEvaluationProgress(
//                               'Efficiency of service call handling',
//                               efficiency,
//                             ),
//                             const SizedBox(height: 5),
//                             _buildEvaluationProgress(
//                               'Response time of service calls',
//                               responseTime,
//                             ),
//                             const SizedBox(height: 5),
//                             _buildEvaluationProgress(
//                               'Product Knowledge & Brand Representation',
//                               productKnowledge,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildProfileItem(String label, String value) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.start,
//       children: [
//         Align(
//           alignment: Alignment.centerLeft,
//           child: Text(
//             softWrap: true,
//             maxLines: 3,
//             label,
//             style: AppFont.mediumText14(context),
//           ),
//         ),
//         const SizedBox(height: 5),
//         Align(
//           alignment: Alignment.centerLeft,
//           child: Text(
//             softWrap: true,
//             maxLines: 3,
//             value,
//             style: AppFont.dropDowmLabel(context),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildEvaluationProgress(String label, double percentage) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(left: 10),
//           child: Text(label, style: AppFont.dropDowmLabel(context)),
//         ),
//         const SizedBox(height: 5),
//         Padding(
//           padding: const EdgeInsets.only(left: 10),
//           child: Text(
//             '${(percentage * 100).toStringAsFixed(0)}%',
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: _getGradientForProgress(percentage).last,
//             ),
//             softWrap: true,
//             maxLines: 3,
//           ),
//         ),
//         const SizedBox(height: 10),
//         LinearPercentIndicator(
//           lineHeight: 14.0,
//           percent: percentage,
//           backgroundColor: Colors.grey[200]!,
//           barRadius: const Radius.circular(8),
//           linearGradient: LinearGradient(
//             colors: _getGradientForProgress(percentage),
//             begin: Alignment.centerLeft,
//             end: Alignment.centerRight,
//           ),
//         ),
//         const SizedBox(height: 5),
//       ],
//     );
//   }

//   List<Color> _getGradientForProgress(double percentage) {
//     if (percentage >= 0.8) {
//       return [
//         Color.fromRGBO(255, 237, 215, 0.9),
//         Color.fromRGBO(83, 157, 243, 1),
//         Color.fromRGBO(144, 109, 250, 1),
//       ];
//     } else if (percentage >= 0.6) {
//       return [
//         Color.fromRGBO(229, 208, 210, 1),
//         Color.fromRGBO(255, 150, 165, 1),
//         Color.fromRGBO(255, 122, 113, 1),
//       ];
//     } else if (percentage >= 0.3) {
//       return [
//         Color.fromRGBO(254, 221, 176, 1),
//         Color.fromRGBO(144, 109, 250, 1),
//         // Color.fromRGBO(255, 237, 215, 0.9),
//         Color.fromRGBO(255, 122, 113, 1),
//       ];
//     } else {
//       return [
//         Color.fromRGBO(182, 247, 249, 1),
//         Color.fromRGBO(168, 230, 251, 1),
//         Color.fromRGBO(196, 201, 255, 1),
//       ];
//     }
//   }
// }
