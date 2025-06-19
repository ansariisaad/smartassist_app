import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/config/getX/fab.controller.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/calender/calender.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';

class CalendarWithTimeline extends StatefulWidget {
  final String leadName;

  const CalendarWithTimeline({Key? key, required this.leadName})
    : super(key: key);

  @override
  State<CalendarWithTimeline> createState() => _CalendarWithTimelineState();
}

class _CalendarWithTimelineState extends State<CalendarWithTimeline> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _isMonthView = false;
  List<dynamic> appointments = [];
  // List<dynamic> tasks = [];
  List<dynamic> tasks = [];
  List<dynamic> events = [];
  DateTime? _selectedDay;
  bool _isLoading = false;
  ScrollController _timelineScrollController = ScrollController();

  // Track all hours (0-23) for a complete timeline
  List<int> _allHours = List.generate(24, (index) => index);

  // Track active hours (hours with data)
  Set<int> _activeHours = {};

  // Map to track expanded hour slots
  Map<int, int> _expandedHours = {};

  // Map to track items by exact time (hour:minute)
  Map<String, List<dynamic>> _timeSlotItems = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchActivitiesData();

    // Scroll to current hour when view loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHour();
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentHour() {
    if (!_timelineScrollController.hasClients) return;

    // Get current hour
    final currentHour = DateTime.now().hour;

    // Calculate scroll position - 60 pixels per hour
    double scrollPosition = currentHour * 60.0;

    // Subtract a small offset for better visibility
    scrollPosition = scrollPosition > 60 ? scrollPosition - 60 : 0;

    _timelineScrollController.animateTo(
      scrollPosition,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Future<void> _fetchInitialData() async {
  //   if (mounted) {
  //     setState(() {
  //       _isLoading = true;
  //     });
  //   }

  //   try {
  //     await _fetchAppointments(_selectedDay ?? _focusedDay);
  //     await _fetchTasks(_selectedDay ?? _focusedDay);
  //     _processTimeSlots();
  //   } catch (e) {
  //     print("Error fetching initial data: $e");
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _fetchActivitiesData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final token = await Storage.getToken();
      // Format the selected date
      String formattedDate = DateFormat(
        'dd-MM-yyyy',
      ).format(_selectedDay ?? _focusedDay);

      // Build query parameters
      final Map<String, String> queryParams = {'date': formattedDate};

      // Add user_id only if team member is selected (not for 'your' option)
      // if (_selectedType == 'team' && _selectedUserId.isNotEmpty) {
      //   queryParams['user_id'] = _selectedUserId;
      // }

      final baseUrl = Uri.parse(
        "https://dev.smartassistapp.in/api/calendar/activities/all/asondate",
      );
      final uri = baseUrl.replace(queryParameters: queryParams);

      print('📤 Fetching activities from: $uri');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Activities Status Code: ${response.statusCode}');
      print('📥 Activities Response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          tasks = data['data']['tasks'] ?? [];
          events = data['data']['events'] ?? [];
          _isLoading = false;
        });

        // Process the time slots after fetching data
        _processTimeSlots();
      } else {
        setState(() => _isLoading = false);
        print('Failed to fetch activities: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching activities data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New method to process all items into time slots
  void _processTimeSlots() {
    _activeHours.clear();
    _expandedHours.clear();
    _timeSlotItems.clear();

    // Process events (appointments)
    for (var event in events) {
      final startTime = _parseTimeString(event['start_time'] ?? '00:00');
      final endTime = startTime.add(Duration(hours: 1));

      for (int hour = startTime.hour; hour <= endTime.hour; hour++) {
        _activeHours.add(hour);
      }

      final timeKey =
          '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
      if (!_timeSlotItems.containsKey(timeKey)) {
        _timeSlotItems[timeKey] = [];
      }
      _timeSlotItems[timeKey]!.add({
        'item': event,
        'type': 'event',
        'startTime': startTime,
        'endTime': endTime,
      });
    }

    // Process tasks
    for (var task in tasks) {
      DateTime taskTime;
      if (task['time'] != null && task['time'].toString().isNotEmpty) {
        taskTime = _parseTimeString(task['time']);
      } else {
        taskTime = DateTime(2022, 1, 1, 9, 0); // Default to 9 AM
      }

      _activeHours.add(taskTime.hour);

      final timeKey =
          '${taskTime.hour}:${taskTime.minute.toString().padLeft(2, '0')}';
      if (!_timeSlotItems.containsKey(timeKey)) {
        _timeSlotItems[timeKey] = [];
      }
      _timeSlotItems[timeKey]!.add({
        'item': task,
        'type': 'task',
        'startTime': taskTime,
        'endTime': taskTime.add(Duration(minutes: 30)),
      });
    }

    if (_activeHours.isEmpty) {
      if (_isSameDay(_selectedDay ?? _focusedDay, DateTime.now())) {
        _activeHours.add(DateTime.now().hour);
      } else {
        _activeHours.add(9);
      }
    }

    _calculateExpandedHours();
    print("Active hours: $_activeHours");
    print("Time slots: ${_timeSlotItems.keys.length}");
  }

  // Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _calculateExpandedHours() {
    _expandedHours.clear();

    // Count items per hour
    Map<int, int> itemsPerHour = {};

    _timeSlotItems.forEach((timeKey, items) {
      final hour = int.parse(timeKey.split(':')[0]);
      itemsPerHour[hour] = (itemsPerHour[hour] ?? 0) + items.length;
    });

    // Calculate expanded height for each hour
    itemsPerHour.forEach((hour, count) {
      if (count > 1) {
        // Each hour gets height based on number of items (with some minimum)
        _expandedHours[hour] = count;
      }
    });
  }

  // Get the appropriate height for an hour based on whether it's expanded
  double _getHourHeight(int hour) {
    // Default height is 60
    return _expandedHours.containsKey(hour)
        ? 60.0 *
              (_expandedHours[hour] ??
                  1) // Expanded height based on number of items
        : 60.0; // Default height
  }

  Future<void> _fetchAppointments(DateTime selectedDate) async {
    final data = await LeadsSrv.fetchAppointments(selectedDate);
    if (!mounted) return;
    setState(() {
      appointments = data;
      _isLoading = false;
    });
    print("Appointments Fetched: $appointments");
    _processTimeSlots();
  }

  Future<void> _fetchTasks(DateTime selectedDate) async {
    final data = await LeadsSrv.fetchtasks(selectedDate);
    if (!mounted) return;
    setState(() {
      tasks = data;
      _isLoading = false;
    });
    print("Tasks Fetched: $tasks");
    _processTimeSlots();
  }

  void _handleDateSelected(DateTime selectedDate) {
    setState(() {
      _selectedDay = selectedDate;
      _focusedDay = selectedDate;
      appointments = [];
      tasks = [];
      _activeHours.clear();
      _expandedHours.clear();
      _timeSlotItems.clear();
      _isLoading = true;
    });

    String formattedDate = DateFormat('dd-MM-yyyy').format(selectedDate);
    print('Selected Date State: ${_selectedDay}');
    print('Fetching data for date: $formattedDate');

    _fetchAppointments(selectedDate);
    _fetchTasks(selectedDate);
  }

  // Initialize the controller
  final FabController fabController = Get.put(FabController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Calendar',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _calendarFormat = _isMonthView
                    ? CalendarFormat.week
                    : CalendarFormat.month;
                _isMonthView = !_isMonthView;
              });
            },
            icon: Icon(
              _isMonthView ? Icons.calendar_view_week : Icons.calendar_month,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Calendar at the top
              CalenderWidget(
                key: ValueKey(_calendarFormat),
                calendarFormat: _calendarFormat,
                onDateSelected: _handleDateSelected,
              ),
              // Date header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                width: double.infinity,
                child: Text(
                  DateFormat(
                    'EEEE, MMMM d',
                  ).format(_selectedDay ?? _focusedDay),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Timeline view
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    )
                  : Expanded(child: _buildImprovedTimelineView()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImprovedTimelineView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    final combinedItems = [...appointments, ...tasks];
    if (combinedItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No activities scheduled for this day',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Only show hours with actual appointments/tasks
    final List<int> displayHours = _getDisplayHours();

    return SingleChildScrollView(
      controller: _timelineScrollController,
      child: Row(
        children: [
          // Left time column
          _buildTimeColumn(displayHours),

          // Divider line
          Container(width: 1, color: Colors.grey.shade300),

          // Main content area
          Expanded(
            child: Stack(
              children: [
                // Time grid lines
                _buildTimeGridLines(displayHours),

                // Build all items from time slots
                ..._buildAllTimeSlotItems(displayHours),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modified to only return hours with actual content
  List<int> _getDisplayHours() {
    // Start with active hours that have content
    Set<int> hours = Set<int>.from(_activeHours);

    // If we have appointments or tasks spanning several hours, add buffer hours
    if (hours.isNotEmpty) {
      int minHour = hours.reduce((a, b) => a < b ? a : b);
      int maxHour = hours.reduce((a, b) => a > b ? a : b);

      // Add one hour before and after for context, but only if they exist
      if (minHour > 0) hours.add(minHour - 1);
      if (maxHour < 23) hours.add(maxHour + 1);
    }

    // Sort hours
    List<int> sortedHours = hours.toList()..sort();
    return sortedHours.isEmpty ? [DateTime.now().hour] : sortedHours;
  }

  Widget _buildTimeColumn(List<int> displayHours) {
    return Container(
      width: 50,
      child: Column(
        children: displayHours.map((hour) {
          // Get appropriate height for this hour slot
          final hourHeight = _getHourHeight(hour);

          return Container(
            height: hourHeight,
            padding: EdgeInsets.only(right: 8),
            alignment: Alignment.topRight,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeGridLines(List<int> displayHours) {
    return Column(
      children: displayHours.map((hour) {
        // Get appropriate height for this hour slot
        final hourHeight = _getHourHeight(hour);

        return Container(
          height: hourHeight,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildAllTimeSlotItems(List<int> displayHours) {
    List<Widget> allWidgets = [];
    final screenWidth = MediaQuery.of(context).size.width;
    final baseItemWidth = screenWidth * 0.75 - 24; // Subtract padding/margins

    // Calculate hour positions first
    Map<int, double> hourPositions = {};
    double currentPosition = 0.0;

    for (int hour in displayHours) {
      hourPositions[hour] = currentPosition;
      currentPosition += _getHourHeight(hour);
    }

    // Sort time slots by time for consistent processing
    List<String> sortedTimeKeys = _timeSlotItems.keys.toList()..sort();

    // Process each time slot
    for (String timeKey in sortedTimeKeys) {
      final items = _timeSlotItems[timeKey]!;
      final parts = timeKey.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Skip if hour isn't in display hours
      if (!hourPositions.containsKey(hour)) continue;

      // Base position for this time slot
      final basePosition =
          hourPositions[hour]! + (minute / 60.0) * _getHourHeight(hour);

      // Process items in this time slot
      for (int i = 0; i < items.length; i++) {
        final itemData = items[i];
        final itemType = itemData['type'];
        final item = itemData['item'];

        // Position vertically to avoid overlaps
        double verticalOffset = 0.0;
        if (items.length > 1) {
          // If multiple items at same time, stack them with vertical offset
          verticalOffset = i * 60.0;
        }

        // Calculate the top position for this item (stack vertically with proper spacing)
        final itemTopPosition =
            basePosition + (i * 70.0); // 55px item + 10px spacing

        // Add widget based on type
        if (itemType == 'event') {
          allWidgets.add(
            _buildEventItem(
              item,
              basePosition: itemTopPosition,
              width: baseItemWidth,
              height: 65.0, // Fixed height
              leftOffset: 0.0,
            ),
          );
        } else if (itemType == 'task') {
          allWidgets.add(
            _buildTaskItem(
              item,
              basePosition: itemTopPosition,
              width: baseItemWidth,
              height: 65.0, // Fixed height
              leftOffset: 0.0,
            ),
          );
        }
      }
    }

    return allWidgets;
  }

  Widget _buildEventItem(
    dynamic item, {
    double basePosition = 0.0,
    double width = 200.0,
    double height = 55.0,
    double widthFactor = 1.0,
    double leftOffset = 0.0,
  }) {
    String leadId = item['lead_id']?.toString() ?? '';
    String formattedStartTime = _formatTimeFor12Hour(
      item['start_time'] ?? '00:00',
    );
    String formattedEndTime = _formatTimeFor12Hour(item['end_time'] ?? '00:00');

    String name = item['name'] ?? 'No Name';
    String category = item['category'] ?? 'Appointment';
    String timeRange = '$formattedStartTime - $formattedEndTime';

    return Positioned(
      top: basePosition,
      left: 12 + (leftOffset * (MediaQuery.of(context).size.width * 0.75 - 24)),
      child: Container(
        width: width * widthFactor,
        height: height,
        margin: const EdgeInsets.only(bottom: 5, right: 8),
        decoration: BoxDecoration(
          color: AppColors.colorsBlue.withOpacity(.09),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.colorsBlue.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: InkWell(
          onTap: () {
            print('Navigating with leadId: $leadId');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowupsDetails(
                  leadId: leadId,
                  isFromFreshlead: false,
                  isFromManager: false,
                  isFromTestdriveOverview: false,
                  refreshDashboard: () async {},
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.colorsBlue, width: 4),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: AppFont.dropDowmLabel(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: AppFont.dashboardCarName(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(
    dynamic item, {
    double basePosition = 0.0,
    double width = 200.0,
    double height = 55.0,
    double widthFactor = 1.0,
    double leftOffset = 0.0,
  }) {
    String leadId = item['lead_id']?.toString() ?? '';
    String formattedDueTime = _formatTimeFor12Hour(item['due_date'] ?? '00:00');
    String title = 'Task: ${item['subject'] ?? 'No Subject'}';
    String status = item['status'] ?? 'Unknown';
    String category = item['category'] ?? 'Normal';
    String timeInfo = formattedDueTime.isNotEmpty ? formattedDueTime : '';

    return Positioned(
      top: basePosition,
      left: 12 + (leftOffset * (MediaQuery.of(context).size.width * 0.75 - 24)),
      child: Container(
        width: width * widthFactor,
        height: height,
        margin: const EdgeInsets.only(bottom: 5, right: 8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(.09),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withOpacity(0.2), width: 0.5),
        ),
        child: InkWell(
          onTap: () {
            print('Navigating with leadId: $leadId');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowupsDetails(
                  leadId: leadId,
                  isFromFreshlead: false,
                  isFromManager: true,
                  isFromTestdriveOverview: false,
                  refreshDashboard: () async {},
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.purple, width: 4)),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppFont.dropDowmLabel(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: AppFont.dashboardCarName(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (timeInfo.isNotEmpty)
                      Text(
                        timeInfo,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildAppointmentItem(
  //   dynamic item, {
  //   double basePosition = 0.0,
  //   double width = 200.0,
  //   double height = 60.0,
  //   double widthFactor = 1.0,
  //   double leftOffset = 0.0,
  // }) {
  //   // Determine color and title for appointment
  //   Color cardColor = _getAppointmentColor(item);

  //   // Get the lead_id from the item
  //   String leadId = item['lead_id']?.toString() ?? '';

  //   // Format the time in 12-hour format with AM/PM
  //   String formattedStartTime = _formatTimeFor12Hour(
  //     item['start_time'] ?? '00:00',
  //   );
  //   String formattedEndTime = _formatTimeFor12Hour(item['end_time'] ?? '00:00');

  //   String title = 'Appointment: ${item['name'] ?? 'No Name'}';
  //   String time = '$formattedStartTime - $formattedEndTime';

  //   return Positioned(
  //     top: basePosition,
  //     left: 8 + (width * leftOffset),
  //     width: (width * widthFactor) - 8, // Account for right margin
  //     height: height,
  //     child: Card(
  //       margin: EdgeInsets.only(bottom: 4, right: 4),
  //       color: cardColor,
  //       elevation: 2,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //       child: InkWell(
  //         onTap: () {
  //           print('Navigating with leadId: $leadId');
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => FollowupsDetails(
  //                 leadId: leadId,
  //                 isFromFreshlead: false,
  //                 isFromManager: false,
  //                 refreshDashboard: () async {},
  //                 isFromTestdriveOverview: false,
  //               ),
  //             ),
  //           );
  //         },
  //         child: Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 children: [
  //                   const Icon(Icons.event, size: 14, color: Colors.white),
  //                   const SizedBox(width: 4),
  //                   Expanded(
  //                     child: Text(
  //                       title,
  //                       style: const TextStyle(
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.white,
  //                         fontSize: 13,
  //                       ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 2),
  //               if (height >= 55)
  //                 Row(
  //                   children: [
  //                     const Icon(
  //                       Icons.access_time,
  //                       size: 12,
  //                       color: Colors.white70,
  //                     ),
  //                     const SizedBox(width: 4),
  //                     Text(
  //                       time,
  //                       style: TextStyle(fontSize: 12, color: Colors.white70),
  //                     ),
  //                   ],
  //                 ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildTaskItem(
  //   dynamic item, {
  //   double basePosition = 0.0,
  //   double width = 200.0,
  //   double height = 55.0,
  //   double widthFactor = 1.0,
  //   double leftOffset = 0.0,
  // }) {
  //   String leadId = item['lead_id']?.toString() ?? '';
  //   String formattedDueTime = _formatTimeFor12Hour(item['due_date'] ?? '00:00');
  //   String title = 'Task: ${item['subject'] ?? 'No Subject'}';
  //   String status = item['status'] ?? 'Unknown';
  //   String category = item['category'] ?? 'Normal';
  //   String timeInfo = formattedDueTime.isNotEmpty ? formattedDueTime : '';

  //   return Positioned(
  //     top: basePosition,
  //     left: 12 + (leftOffset * (MediaQuery.of(context).size.width * 0.75 - 24)),
  //     child: Container(
  //       width: width * widthFactor,
  //       height: height,
  //       margin: const EdgeInsets.only(bottom: 5, right: 8),
  //       decoration: BoxDecoration(
  //         color: Colors.purple.withOpacity(.09),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withOpacity(0.08),
  //             blurRadius: 4,
  //             offset: const Offset(0, 2),
  //           ),
  //         ],
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(color: Colors.purple.withOpacity(0.2), width: 0.5),
  //       ),
  //       child: InkWell(
  //         onTap: () {
  //           print('Navigating with leadId: $leadId');
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => FollowupsDetails(
  //                 leadId: leadId,
  //                 isFromFreshlead: false,
  //                 isFromManager: true,
  //                 isFromTestdriveOverview: false,
  //                 refreshDashboard: () async {},
  //               ),
  //             ),
  //           );
  //         },
  //         borderRadius: BorderRadius.circular(8),
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(
  //             horizontal: 12.0,
  //             vertical: 8.0,
  //           ),
  //           decoration: BoxDecoration(
  //             border: Border(left: BorderSide(color: Colors.purple, width: 4)),
  //             borderRadius: BorderRadius.only(
  //               topLeft: Radius.circular(8),
  //               bottomLeft: Radius.circular(8),
  //             ),
  //           ),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Text(
  //                 title,
  //                 style: AppFont.dropDowmLabel(context),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               const SizedBox(height: 4),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       category,
  //                       style: AppFont.dashboardCarName(context),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                   if (timeInfo.isNotEmpty)
  //                     Text(
  //                       timeInfo,
  //                       style: TextStyle(
  //                         fontSize: 10,
  //                         color: Colors.grey.shade600,
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                     ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildTaskItem(
  //   dynamic item, {
  //   double basePosition = 0.0,
  //   double width = 200.0,
  //   double height = 60.0,
  //   double widthFactor = 1.0,
  //   double leftOffset = 0.0,
  // }) {
  //   // Get the lead_id from the item
  //   String leadId = item['lead_id']?.toString() ?? '';

  //   // Format the time in 12-hour format with AM/PM
  //   String formattedDueTime = _formatTimeFor12Hour(item['due_date'] ?? '00:00');

  //   // Determine color and title for task
  //   Color cardColor = _getTaskColor(item);
  //   String title = 'Task: ${item['subject'] ?? 'No Subject'}';
  //   String status = item['status'] ?? 'Unknown';
  //   String priority = item['priority'] ?? 'Normal';

  //   // Add due time to status display if available
  //   String timeInfo = formattedDueTime.isNotEmpty ? ' • $formattedDueTime' : '';

  //   return Positioned(
  //     top: basePosition,
  //     left: 8 + (width * leftOffset),
  //     width: (width * widthFactor) - 8, // Account for right margin
  //     height: height,
  //     child: Card(
  //       margin: const EdgeInsets.only(bottom: 4, right: 4),
  //       color: cardColor,
  //       elevation: 2,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //       child: InkWell(
  //         onTap: () {
  //           print('Navigating with task leadId: $leadId');
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) => FollowupsDetails(
  //                 leadId: leadId,
  //                 isFromFreshlead: false,
  //                 isFromManager: false,
  //                 refreshDashboard: () async {},
  //                 isFromTestdriveOverview: false,
  //               ),
  //             ),
  //           );
  //         },
  //         child: Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 children: [
  //                   Icon(Icons.task, size: 14, color: Colors.white),
  //                   SizedBox(width: 4),
  //                   Expanded(
  //                     child: Text(
  //                       title,
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.white,
  //                         fontSize: 13,
  //                       ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 2),
  //               Row(
  //                 children: [
  //                   const Icon(Icons.flag, size: 12, color: Colors.white70),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     priority,
  //                     style: const TextStyle(
  //                       fontSize: 12,
  //                       color: Colors.white70,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 8),
  //                   const Icon(
  //                     Icons.info_outline,
  //                     size: 12,
  //                     color: Colors.white70,
  //                   ),
  //                   const SizedBox(width: 4),
  //                   Text(
  //                     '$status$timeInfo',
  //                     style: const TextStyle(
  //                       fontSize: 12,
  //                       color: Colors.white70,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  DateTime _parseTimeString(String timeStr) {
    // If timeStr is null or empty, return a default time
    if (timeStr.isEmpty) {
      return DateTime(2022, 1, 1, 0, 0); // Default time (midnight)
    }

    // Handle both 12-hour and 24-hour time formats
    bool isPM = timeStr.toLowerCase().contains('pm');
    bool isAM = timeStr.toLowerCase().contains('am');

    // Remove AM/PM indicator for parsing
    String cleanTime = timeStr
        .toLowerCase()
        .replaceAll('am', '')
        .replaceAll('pm', '')
        .replaceAll(' ', '')
        .trim();

    final parts = cleanTime.split(':');
    if (parts.length < 2)
      return DateTime(2022, 1, 1, 0, 0); // Invalid time format fallback

    try {
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Convert 12-hour format to 24-hour if needed
      if (isPM && hour < 12) {
        hour += 12; // Add 12 to PM hours except 12 PM
      } else if (isAM && hour == 12) {
        hour = 0; // 12 AM is 0 in 24-hour format
      }

      return DateTime(2022, 1, 1, hour, minute);
    } catch (e) {
      print("Error parsing time: $timeStr - $e");
      return DateTime(2022, 1, 1, 0, 0); // Default to midnight if parsing fails
    }
  }

  // Format time to 12-hour format with AM/PM for display consistency
  String _formatTimeFor12Hour(String timeStr) {
    if (timeStr.isEmpty || !timeStr.contains(':')) {
      return timeStr; // Return unchanged if not in time format
    }

    // Parse the time first to normalize it
    DateTime parsedTime = _parseTimeString(timeStr);

    // Format to 12-hour time
    String period = parsedTime.hour >= 12 ? 'PM' : 'AM';
    int hour12 = parsedTime.hour > 12
        ? parsedTime.hour - 12
        : (parsedTime.hour == 0 ? 12 : parsedTime.hour);

    return '${hour12}:${parsedTime.minute.toString().padLeft(2, '0')} $period';
  }

  Color _getTaskColor(dynamic task) {
    final type = task['taskType']?.toString().toLowerCase() ?? '';
    if (type == 'follow-up' || type == 'followup') {
      return AppColors.colorsBlue; // Blue for follow-up tasks
    } else if (type == 'urgent') {
      return Colors.red; // Red for urgent tasks
    } else if (type == 'reminder') {
      return Colors.green; // Green for reminders
    } else {
      return AppColors.colorsBlue; // Default color for tasks
    }
  }

  Color _getAppointmentColor(dynamic appointment) {
    final type = appointment['type']?.toString().toLowerCase() ?? '';
    if (type == 'meeting') {
      return Colors.blue; // Blue for meetings
    } else if (type == 'call') {
      return Colors.purple; // Purple for calls
    } else if (type == 'urgent') {
      return Colors.red; // Red for urgent appointments
    } else {
      return Colors.teal; // Teal for default appointments
    }
  }
}
