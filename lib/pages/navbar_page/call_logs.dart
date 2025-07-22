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
          // Icons.warning_rounded,
        );
        return;
      }

      // Show loading dialog
      Get.dialog(
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Excluding calls...'),
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
        'https://api.smartassistapp.in/api/leads/excluded-calls',
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
            // Find the call log with this unique key and update its excluded status
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

        _showSnackbar(
          'Success!',
          message,
          Colors.green,
          // Icons.check_circle_rounded,
        );

        // Then refresh from server to confirm
        await Future.delayed(const Duration(milliseconds: 500));
        _fetchCallLog();
      } else {
        _showSnackbar(
          'Error',
          'Failed to exclude calls: ${response.statusCode}',
          Colors.red,
          // Icons.error_rounded,
        );
      }
    } catch (e) {
      Get.back(); // Close loading dialog if open
      _showSnackbar(
        'Error',
        'Failed to exclude calls: ${e.toString()}',
        Colors.red,
        // Icons.error_rounded,
      );
    }
  }

  void _showSnackbar(String title, String message, Color color) {
    Color backgroundColor;
    Color textColor;

    // Define static colors for different types
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
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      // icon: Icon(icon, color: textColor),
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

  // Responsive size calculations
  Map<String, double> _getResponsiveSizes(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 400) {
      return {
        'avatar_size': 40.0,
        'avatar_font_size': 16.0,
        'name_font_size': 14.0,
        'number_font_size': 12.0,
        'padding_horizontal': 12.0,
        'padding_vertical': 8.0,
        'card_margin_vertical': 4.0,
        'card_margin_horizontal': 12.0,
      };
    } else if (screenWidth < 768) {
      return {
        'avatar_size': 48.0,
        'avatar_font_size': 18.0,
        'name_font_size': 16.0,
        'number_font_size': 14.0,
        'padding_horizontal': 16.0,
        'padding_vertical': 10.0,
        'card_margin_vertical': 6.0,
        'card_margin_horizontal': 16.0,
      };
    } else {
      return {
        'avatar_size': 56.0,
        'avatar_font_size': 20.0,
        'name_font_size': 18.0,
        'number_font_size': 16.0,
        'padding_horizontal': 20.0,
        'padding_vertical': 12.0,
        'card_margin_vertical': 8.0,
        'card_margin_horizontal': 20.0,
      };
    }
  }

  double _titleFontSize(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) return 16;
    if (screenWidth < 768) return 18;
    return 20;
  }

  Future<void> _fetchCallLog() async {
    try {
      setState(() {
        isLoading = true;
      });

      final token = await Storage.getToken();
      final uri = Uri.parse(
        'https://api.smartassistapp.in/api/leads/all-CallLogs',
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
            // Icons.error_rounded,
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
        // Icons.error_rounded,
      );
    }
  }

  void _toggleSelection(String uniqueKey) {
    setState(() {
      selectedCalls[uniqueKey] = !(selectedCalls[uniqueKey] ?? false);

      // Check if any items are selected to show/hide selection mode
      bool hasSelectedItems = selectedCalls.values.contains(true);
      isSelectionMode = hasSelectedItems;
    });
  }

  Widget _buildContactCard(Map<String, dynamic> log, int index) {
    String name = log['name'] ?? "Unknown";
    String mobile = log['mobile'] ?? "No number";
    String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "#";
    String uniqueKey = log['unique_key'] ?? "";
    bool isSelected = selectedCalls[uniqueKey] ?? false;
    bool isExcluded = log['is_excluded'] == true;

    final sizes = _getResponsiveSizes(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: sizes['card_margin_horizontal']!,
        vertical: sizes['card_margin_vertical']!,
      ),
      child: Material(
        elevation: isSelected ? 4 : 2,
        borderRadius: BorderRadius.circular(12),
        shadowColor: isSelected
            ? AppColors.colorsBlue.withOpacity(0.3)
            : Colors.black.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: sizes['padding_horizontal']!,
              vertical: sizes['padding_vertical']!,
            ),
            onTap: () => _toggleSelection(uniqueKey),
            onLongPress: () => _toggleSelection(uniqueKey),
            leading: Stack(
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
                      height: 18,
                      width: 18,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                SizedBox(height: 2),
                Text(
                  mobile,
                  style: GoogleFonts.poppins(
                    fontSize: sizes['number_font_size']!,
                    color: const Color(0xFF718096),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (isExcluded) ...[
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block_rounded, size: 12, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          "Excluded",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
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
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: AppColors.colorsBlue,
                    size: 20,
                  )
                : Icon(
                    Icons.person_outline,
                    color: const Color(0xFFCBD5E0),
                    size: 18,
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

    final sizes = _getResponsiveSizes(context);

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
            size: _titleFontSize(context) - 2,
          ),
        ),
        title: Text(
          isSelectionMode ? '$selectedCount selected' : 'Exclude Contacts',
          style: GoogleFonts.poppins(
            fontSize: _titleFontSize(context),
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
              icon: const Icon(Icons.more_vert, color: Colors.white),
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
                const PopupMenuItem<String>(
                  value: 'select_all',
                  child: Row(
                    children: [
                      Icon(Icons.select_all),
                      SizedBox(width: 8),
                      Text('Select All'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'deselect_all',
                  child: Row(
                    children: [
                      Icon(Icons.deselect),
                      SizedBox(width: 8),
                      Text('Deselect All'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              onPressed: _fetchCallLog,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCallLog,
        color: AppColors.colorsBlue,
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading contacts...'),
                  ],
                ),
              )
            : callLogs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.contacts_rounded,
                        size: 64,
                        color: const Color(0xFFCBD5E0),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No contacts found',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4A5568),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your contacts will appear here',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
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
                        vertical: 8,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: sizes['padding_horizontal']!,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.colorsBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: AppColors.colorsBlue,
                            ),
                          ),
                          SizedBox(width: 8),
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
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.colorsBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Tap to select',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
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
                      padding: EdgeInsets.only(bottom: 100),
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
              // icon: const Icon(Icons.block_rounded, color: Colors.white),
              label: Text(
                'Change status',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                ),
              ),
            )
          : null,
    );
  }
}
