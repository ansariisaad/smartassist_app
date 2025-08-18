import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/storage.dart';

class CallLogs extends StatefulWidget {
  const CallLogs({super.key});

  @override
  State<CallLogs> createState() => _CallLogsState();
}

class _CallLogsState extends State<CallLogs> {
  List<Map<String, dynamic>> callLogs = [];
  bool isLoading = true;
  bool isSelectionMode = false;
  final Map<String, bool> selectedCalls = {};

  @override
  void initState() {
    super.initState();
    _fetchCallLog();
  }

  Future<void> _excludeSelectedCalls() async {
    try {
      final List<String> selectedKeys = selectedCalls.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (selectedKeys.isEmpty) {
        _showSnackbar(
          'No calls selected',
          'Please select calls to exclude',
          Colors.amber,
        );
        return;
      }

      // Show loading dialog
      Get.dialog(
        Center(
          child: Card(
            margin: EdgeInsets.all(16.w),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Excluding calls...',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final List<Map<String, String>> requestBody = selectedKeys
          .map((key) => {"unique_key": key})
          .toList();

      final token = await Storage.getToken();
      final url = Uri.parse(
        'https://dev.smartassistapp.in/api/leads/excluded-calls',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      Get.back(); // Close loading dialog

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final message =
            responseData['message'] ?? 'Calls excluded successfully';

        // Update local state immediately
        setState(() {
          for (String key in selectedKeys) {
            for (var log in callLogs) {
              if (log['unique_key'] == key) {
                log['is_excluded'] = true;
                break;
              }
            }
          }
          isSelectionMode = false;
          selectedCalls.clear();
        });

        _showSnackbar('Success!', message, Colors.green);

        await Future.delayed(const Duration(milliseconds: 500));
        _fetchCallLog();
      } else {
        _showSnackbar(
          'Error',
          'Failed to exclude calls: ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (e) {
      Get.back();
      _showSnackbar(
        'Error',
        'Failed to exclude calls: ${e.toString()}',
        Colors.red,
      );
    }
  }

  void _showSnackbar(String title, String message, Color color) {
    Color backgroundColor;
    Color textColor;

    switch (color) {
      case Colors.green:
        backgroundColor = const Color(0xFF4CAF50);
        textColor = Colors.white;
        break;
      case Colors.red:
        backgroundColor = const Color(0xFFF44336);
        textColor = Colors.white;
        break;
      case Colors.amber:
        backgroundColor = const Color(0xFFFFC107);
        textColor = Colors.black87;
        break;
      default:
        backgroundColor = const Color(0xFF2196F3);
        textColor = Colors.white;
    }

    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      colorText: textColor,
      borderRadius: 12.r,
      margin: EdgeInsets.all(16.w),
      titleText: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      messageText: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
    );
  }

  void _selectAll() {
    setState(() {
      selectedCalls.updateAll((key, value) => true);
      isSelectionMode = true;
    });
  }

  void _deselectAll() {
    setState(() {
      selectedCalls.updateAll((key, value) => false);
      isSelectionMode = false;
    });
  }

  // Fixed responsive size calculations
  Map<String, double> _getResponsiveSizes() {
    return {
      'avatar_size': 45.w,
      'avatar_font_size': 16.sp,
      'name_font_size': 15.sp,
      'number_font_size': 13.sp,
      'time_font_size': 12.sp,
      'status_font_size': 10.sp,
      'padding_horizontal': 16.w,
      'padding_vertical': 10.h,
      'card_margin_vertical': 4.h,
      'card_margin_horizontal': 16.w,
      'icon_size': 16.w,
      'checkbox_size': 20.w,
      'status_padding_horizontal': 8.w,
      'status_padding_vertical': 4.h,
    };
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      DateTime dateTime;

      if (timestamp.contains('T') || timestamp.contains('Z')) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp.contains('-')) {
        dateTime = DateTime.parse(timestamp);
      } else {
        int? unixTimestamp = int.tryParse(timestamp);
        if (unixTimestamp != null) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(
            unixTimestamp * (unixTimestamp.toString().length == 10 ? 1000 : 1),
          );
        } else {
          return '';
        }
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEE').format(dateTime);
      } else {
        return DateFormat('dd/MM').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  String _formatDuration(String? duration) {
    if (duration == null || duration.isEmpty) return '';

    try {
      int seconds = int.parse(duration);
      if (seconds < 60) {
        return '${seconds}s';
      } else {
        int minutes = seconds ~/ 60;
        int remainingSeconds = seconds % 60;
        return remainingSeconds > 0
            ? '${minutes}m ${remainingSeconds}s'
            : '${minutes}m';
      }
    } catch (e) {
      return duration;
    }
  }

  Future<void> _fetchCallLog() async {
    try {
      setState(() {
        isLoading = true;
      });

      final token = await Storage.getToken();
      final uri = Uri.parse(
        'https://dev.smartassistapp.in/api/leads/all-CallLogs',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (mounted) {
          setState(() {
            callLogs.clear();
            selectedCalls.clear();

            List<dynamic> logsData;
            if (jsonData is List) {
              logsData = jsonData;
            } else if (jsonData is Map && jsonData['logs'] != null) {
              logsData = jsonData['logs'];
            } else {
              logsData = [jsonData];
            }

            for (var logItem in logsData) {
              if (logItem is Map<String, dynamic>) {
                callLogs.add(Map<String, dynamic>.from(logItem));
                String uniqueKey = logItem['unique_key']?.toString() ?? '';
                if (uniqueKey.isNotEmpty) {
                  selectedCalls[uniqueKey] = false;
                }
              }
            }

            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          _showSnackbar(
            'Error',
            'Failed to load call logs: ${response.statusCode}',
            Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      _showSnackbar(
        'Error',
        'Failed to load call logs: ${e.toString()}',
        Colors.red,
      );
    }
  }

  void _toggleSelection(String uniqueKey) {
    setState(() {
      selectedCalls[uniqueKey] = !(selectedCalls[uniqueKey] ?? false);
      bool hasSelectedItems = selectedCalls.values.contains(true);
      isSelectionMode = hasSelectedItems;
    });
  }

  IconData _getCallTypeIcon(String callType) {
    switch (callType.toLowerCase()) {
      case 'incoming':
      case 'in':
        return Icons.call_received_rounded;
      case 'outgoing':
      case 'out':
        return Icons.call_made_rounded;
      case 'missed':
        return Icons.call_received_rounded;
      default:
        return Icons.phone_rounded;
    }
  }

  Color _getCallTypeColor(String callType) {
    switch (callType.toLowerCase()) {
      case 'incoming':
      case 'in':
        return const Color(0xFF10B981);
      case 'outgoing':
      case 'out':
        return const Color(0xFF3B82F6);
      case 'missed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildContactCard(Map<String, dynamic> log, int index) {
    String name = log['name'] ?? "Unknown";
    String mobile = log['mobile'] ?? "No number";
    String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "#";
    String uniqueKey = log['unique_key'] ?? "";
    bool isSelected = selectedCalls[uniqueKey] ?? false;
    bool isExcluded = log['is_excluded'] == true;

    String callTime = _formatTime(
      log['timestamp'] ?? log['call_time'] ?? log['date'],
    );
    String duration = _formatDuration(log['duration']);
    String callType = log['call_type'] ?? log['type'] ?? '';

    final sizes = _getResponsiveSizes();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: sizes['card_margin_horizontal']!,
        vertical: sizes['card_margin_vertical']!,
      ),
      child: Material(
        elevation: isSelected ? 4 : 2,
        borderRadius: BorderRadius.circular(12.r),
        shadowColor: isSelected
            ? AppColors.colorsBlue.withOpacity(0.3)
            : Colors.black.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            color: isSelected
                ? AppColors.colorsBlue.withOpacity(0.05)
                : Colors.white,
            border: isSelected
                ? Border.all(
                    color: AppColors.colorsBlue.withOpacity(0.4),
                    width: 1.5,
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizes['padding_horizontal']!,
              vertical: sizes['padding_vertical']!,
            ),
            child: InkWell(
              onTap: () => _toggleSelection(uniqueKey),
              onLongPress: () => _toggleSelection(uniqueKey),
              borderRadius: BorderRadius.circular(12.r),
              child: Row(
                children: [
                  // Avatar Section
                  Stack(
                    children: [
                      Container(
                        height: sizes['avatar_size']!,
                        width: sizes['avatar_size']!,
                        decoration: BoxDecoration(
                          color: AppColors.colorsBlue,
                          borderRadius: BorderRadius.circular(
                            sizes['avatar_size']! / 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            firstLetter,
                            style: GoogleFonts.poppins(
                              fontSize: sizes['avatar_font_size']!,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            height: 18.w,
                            width: 18.w,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(9.r),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 10.w,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: 12.w),

                  // Content Section - VERTICAL LAYOUT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name Row
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: sizes['name_font_size']!,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D3748),
                          ),
                        ),

                        SizedBox(height: 4.h),

                        // Phone Number Row with Call Type Icon
                        Row(
                          children: [
                            if (callType.isNotEmpty) ...[
                              Icon(
                                _getCallTypeIcon(callType),
                                size: sizes['icon_size']!,
                                color: _getCallTypeColor(callType),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Expanded(
                              child: Text(
                                mobile,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: sizes['number_font_size']!,
                                  color: const Color(0xFF718096),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 4.h),

                        // Time and Duration Row (stacked vertically)
                        if (callTime.isNotEmpty || duration.isNotEmpty) ...[
                          Row(
                            children: [
                              if (callTime.isNotEmpty) ...[
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12.w,
                                  color: const Color(0xFF718096),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  callTime,
                                  style: GoogleFonts.poppins(
                                    fontSize: sizes['time_font_size']!,
                                    color: const Color(0xFF718096),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                              if (callTime.isNotEmpty && duration.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                                  width: 1,
                                  height: 12.h,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              if (duration.isNotEmpty) ...[
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12.w,
                                  color: const Color(0xFF718096),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  duration,
                                  style: GoogleFonts.poppins(
                                    fontSize: sizes['time_font_size']!,
                                    color: const Color(0xFF718096),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        // Excluded Status
                        if (isExcluded) ...[
                          SizedBox(height: 6.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: sizes['status_padding_horizontal']!,
                              vertical: sizes['status_padding_vertical']!,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.block_rounded,
                                  size: 12.w,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "Excluded",
                                  style: GoogleFonts.poppins(
                                    fontSize: sizes['status_font_size']!,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(width: 8.w),

                  // Trailing Icon
                  Icon(
                    isSelected ? Icons.check_circle : Icons.person_outline,
                    color: isSelected
                        ? AppColors.colorsBlue
                        : const Color(0xFFCBD5E0),
                    size: sizes['checkbox_size']!,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int selectedCount = selectedCalls.values
        .where((selected) => selected)
        .length;

    final sizes = _getResponsiveSizes();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            FontAwesomeIcons.angleLeft,
            color: Colors.white,
            size: 18.sp,
          ),
        ),
        title: Text(
          isSelectionMode ? '$selectedCount selected' : 'Exclude Contacts',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          if (isSelectionMode) ...[
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white, size: 20.w),
              onSelected: (value) {
                switch (value) {
                  case 'select_all':
                    _selectAll();
                    break;
                  case 'deselect_all':
                    _deselectAll();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'select_all',
                  child: Row(
                    children: [
                      Icon(Icons.select_all, size: 18.w),
                      SizedBox(width: 8.w),
                      Text(
                        'Select All',
                        style: GoogleFonts.poppins(fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'deselect_all',
                  child: Row(
                    children: [
                      Icon(Icons.deselect, size: 18.w),
                      SizedBox(width: 8.w),
                      Text(
                        'Deselect All',
                        style: GoogleFonts.poppins(fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              onPressed: _fetchCallLog,
              icon: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20.w,
              ),
            ),
          ],
          SizedBox(width: 8.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCallLog,
        color: AppColors.colorsBlue,
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32.w,
                      height: 32.w,
                      child: const CircularProgressIndicator(),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Loading contacts...',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              )
            : callLogs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Icon(
                        Icons.contacts_rounded,
                        size: 64.w,
                        color: const Color(0xFFCBD5E0),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'No contacts found',
                      style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4A5568),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Your contacts will appear here',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (callLogs.isNotEmpty)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: sizes['card_margin_horizontal']!,
                        vertical: 8.h,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: sizes['padding_horizontal']!,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: AppColors.colorsBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 14.w,
                              color: AppColors.colorsBlue,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '${callLogs.length} contact${callLogs.length != 1 ? 's' : ''} found',
                              style: GoogleFonts.poppins(
                                fontSize: sizes['number_font_size']!,
                                color: const Color(0xFF4A5568),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelectionMode)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.colorsBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                'Tap to select',
                                style: GoogleFonts.poppins(
                                  fontSize: sizes['status_font_size']!,
                                  color: AppColors.colorsBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: 100.h),
                      itemCount: callLogs.length,
                      itemBuilder: (context, index) =>
                          _buildContactCard(callLogs[index], index),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _excludeSelectedCalls,
              backgroundColor: const Color(0xFFF44336),
              heroTag: "exclude",
              elevation: 6,
              label: Text(
                'Change status',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            )
          : null,
    );
  }
}
