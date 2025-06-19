import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  // Map to track which calls are selected
  final Map<String, bool> selectedCalls = {};

  @override
  void initState() {
    super.initState();
    _fetchCallLog();
  }

  // Future<void> _fetchCallLog() async {
  //   try {
  //     setState(() {
  //       isLoading = true;
  //     });

  //     final token = await Storage.getToken();
  //     final uri =
  //         Uri.parse('https://dev.smartassistapp.in/api/leads/all-CallLogs');

  //     final response = await http.get(
  //       uri,
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );
  //     print(uri);

  //     if (response.statusCode == 200) {
  //       final jsonData = json.decode(response.body);
  //       print('this is call log ${response.body}');
  //       if (mounted) {
  //         setState(() {
  //           // Parse the logs array from the response
  //           if (jsonData['logs'] != null && jsonData['logs'] is List) {
  //             callLogs = List<Map<String, dynamic>>.from(jsonData['logs']);

  //             // Initialize all calls as unselected
  //             for (var log in callLogs) {
  //               selectedCalls[log['unique_key']] = false;
  //             }
  //           }
  //           isLoading = false;
  //         });
  //       }
  //     } else {
  //       if (mounted) {
  //         setState(() {
  //           isLoading = false;
  //         });
  //         Get.snackbar(
  //           'Error',
  //           'Failed to load call logs: ${response.statusCode}',
  //           backgroundColor: Colors.red,
  //           colorText: Colors.white,
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });
  //     }
  //     print(e.toString());
  //     Get.snackbar(
  //       'Error',
  //       'Failed to load call logs: ${e.toString()}',
  //       backgroundColor: Colors.red,
  //       colorText: Colors.white,
  //     );
  //   }
  // }

  Future<void> _excludeSelectedCalls() async {
    try {
      // Get the list of selected unique keys
      final List<String> selectedKeys = selectedCalls.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (selectedKeys.isEmpty) {
        Get.snackbar(
          'Warning',
          'No calls selected to exclude',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Create the request body
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

      if (response.statusCode == 200) {
        final message =
            json.decode(response.body)['message'] ??
            'Calls excluded successfully';
        Get.snackbar(
          'Success',
          message,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        print('this is new ${response.body}');

        // Refresh call logs
        _fetchCallLog();
      } else {
        Get.snackbar(
          'Error',
          'Failed to exclude calls: ${response.statusCode}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print(e.toString());
      Get.snackbar(
        'Error',
        'Failed to exclude calls: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Helper function to get call type icon and color
  IconData getCallTypeIcon(String? callType) {
    switch (callType) {
      case "incoming":
        return Icons.call_received;
      case "outgoing":
        return Icons.call_made;
      case "missed":
        return Icons.call_missed;
      case "rejected":
        return Icons.call_missed_outgoing;
      case "blocked":
        return Icons.block;
      case "voicemail":
        return Icons.voicemail;
      default:
        return Icons.call;
    }
  }

  Color getCallTypeColor(String? callType) {
    switch (callType) {
      case "incoming":
        return Colors.green;
      case "outgoing":
        return Colors.blue;
      case "missed":
        return Colors.red;
      case "rejected":
        return Colors.orange;
      case "blocked":
        return Colors.purple;
      case "voicemail":
        return Colors.teal;
      default:
        return Colors.grey;
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
      print(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('this is call log ${response.body}');
        if (mounted) {
          setState(() {
            // Clear previous data
            callLogs.clear();
            selectedCalls.clear();

            // Check if the response is directly an array or nested under 'logs'
            List<dynamic> logsData;
            if (jsonData is List) {
              // Direct array response
              logsData = jsonData;
            } else if (jsonData is Map && jsonData['logs'] != null) {
              // Nested under 'logs' key
              logsData = jsonData['logs'];
            } else {
              // Fallback - treat entire response as logs
              logsData = [jsonData];
            }

            // Parse the logs array from the response
            for (var logItem in logsData) {
              if (logItem is Map<String, dynamic>) {
                callLogs.add(Map<String, dynamic>.from(logItem));
                // Initialize as unselected - ensure unique_key exists and is a string
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
          Get.snackbar(
            'Error',
            'Failed to load call logs: ${response.statusCode}',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error in _fetchCallLog: ${e.toString()}');
      print('Stack trace: ${StackTrace.current}');
      Get.snackbar(
        'Error',
        'Failed to load call logs: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Updated formatDuration method to handle dynamic types
  String formatDuration(dynamic duration) {
    if (duration == null) return "0s";

    int seconds;
    if (duration is String) {
      seconds = int.tryParse(duration) ?? 0;
    } else if (duration is int) {
      seconds = duration;
    } else if (duration is double) {
      seconds = duration.toInt();
    } else {
      return "0s";
    }

    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    String result = "";
    if (hours > 0) result += "${hours}h ";
    if (minutes > 0) result += "${minutes}m ";
    if (remainingSeconds > 0 || result.isEmpty)
      result += "${remainingSeconds}s";

    return result.trim();
  }

  // String formatDuration(int? seconds) {
  //   if (seconds == null) return "0s";

  //   int hours = seconds ~/ 3600;
  //   int minutes = (seconds % 3600) ~/ 60;
  //   int remainingSeconds = seconds % 60;

  //   String result = "";
  //   if (hours > 0) result += "${hours}h ";
  //   if (minutes > 0) result += "${minutes}m ";
  //   if (remainingSeconds > 0 || result.isEmpty)
  //     result += "${remainingSeconds}s";

  //   return result.trim();
  // }

  String formatDateTime(String? date, String? time) {
    if (date == null || time == null) return "";

    try {
      final dateTime = DateTime.parse("$date $time");
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final callDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      String formattedTime = DateFormat('h:mm a').format(dateTime);

      if (callDate == today) {
        return "Today, $formattedTime";
      } else if (callDate == yesterday) {
        return "Yesterday, $formattedTime";
      } else {
        return DateFormat('MMM d, h:mm a').format(dateTime);
      }
    } catch (e) {
      return "$date $time";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Call logs', style: AppFont.appbarfontgrey(context)),
            TextButton(
              onPressed: _excludeSelectedCalls,
              child: Text(
                'Exclude Selected',
                style: AppFont.smallText12(context),
              ),
            ),
          ],
        ),
        foregroundColor: AppColors.fontColor,
        leading: IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BottomNavigation()),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 25),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : callLogs.isEmpty
          ? const Center(child: Text("No call logs found"))
          : ListView.builder(
              itemCount: callLogs.length,
              itemBuilder: (context, index) {
                final log = callLogs[index];
                String name = log['name'] ?? "Unknown";
                String firstLetter = name.isNotEmpty ? name[0] : "#";
                String uniqueKey = log['unique_key'] ?? "";

                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selectedCalls[uniqueKey] ?? false,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        selectedCalls[uniqueKey] = value;
                      });
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Row(
                    children: [
                      Container(
                        height: 40.h,
                        width: 40.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            textAlign: TextAlign.center,
                            firstLetter,
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              color: AppColors.colorsBlue,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFont.dropDowmLabel(context),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Icon(
                                    getCallTypeIcon(log['call_type']),
                                    size: 16.sp,
                                    color: getCallTypeColor(log['call_type']),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log['mobile'] ?? "No number",
                                  style: AppFont.smallText(context),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      formatDateTime(
                                        log['call_date'],
                                        log['start_time'],
                                      ),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: const Color(0xffA0A0A0),
                                        fontFamily: "Poppins",
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      child: Text(
                                        formatDuration(log['call_duration']),
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: const Color(0xffA0A0A0),
                                          fontFamily: "Poppins",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: log['is_excluded'] == true
                      ? Text(
                          "Excluded",
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : null,
                );
              },
            ),
      floatingActionButton: selectedCalls.values.contains(true)
          ? SizedBox(
              width: 60,
              child: FloatingActionButton(
                // focusColor: Colors.white,
                backgroundColor: Colors.blue,
                onPressed: _excludeSelectedCalls,
                child: const Icon(Icons.check, color: Colors.white),
                tooltip: 'Exclude Selected Calls',
              ),
            )
          : null,
    );
  }
}
