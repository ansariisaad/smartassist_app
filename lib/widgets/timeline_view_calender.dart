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

  const CalendarWithTimeline({Key? key, required this.leadName}) : super(key: key);

  @override
  State<CalendarWithTimeline> createState() => _CalendarWithTimelineState();
}

class _CalendarWithTimelineState extends State<CalendarWithTimeline> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _isMonthView = false;
  List<dynamic> appointments = [];
  List<dynamic> tasks = [];
  List<dynamic> events = [];
  DateTime? _selectedDay;
  bool _isLoading = false;
  ScrollController _timelineScrollController = ScrollController();
   Map<String, bool> _expandedSlots = {};

  List<int> _allHours = List.generate(24, (index) => index);
  Set<int> _activeHours = {};
  Map<int, int> _expandedHours = {};
  Map<String, List<dynamic>> _timeSlotItems = {};

  // For "Show More" per time slot (key = time string, value = bool)
  Map<String, bool> _showMoreExpanded = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchActivitiesData();
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
    final currentHour = DateTime.now().hour;
    double scrollPosition = currentHour * 60.0;
    scrollPosition = scrollPosition > 60 ? scrollPosition - 60 : 0;
    _timelineScrollController.animateTo(
      scrollPosition,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _fetchActivitiesData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final token = await Storage.getToken();
      String formattedDate = DateFormat('dd-MM-yyyy').format(_selectedDay ?? _focusedDay);

      final Map<String, String> queryParams = {'date': formattedDate};
      final baseUrl = Uri.parse("https://api.smartassistapp.in/api/calendar/activities/all/asondate");
      final uri = baseUrl.replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          tasks = data['data']['tasks'] ?? [];
          events = data['data']['events'] ?? [];
          _isLoading = false;
        });
        _processTimeSlots();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processTimeSlots() {
    _activeHours.clear();
    _expandedHours.clear();
    _timeSlotItems.clear();

    for (var event in events) {
      final startTime = _parseTimeString(event['start_time'] ?? '00:00');
      final endTime = startTime.add(Duration(hours: 1));
      for (int hour = startTime.hour; hour <= endTime.hour; hour++) {
        _activeHours.add(hour);
      }
      final timeKey = '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
      if (!_timeSlotItems.containsKey(timeKey)) _timeSlotItems[timeKey] = [];
      _timeSlotItems[timeKey]!.add({
        'item': event,
        'type': 'event',
        'startTime': startTime,
        'endTime': endTime,
      });
    }

    for (var task in tasks) {
      DateTime taskTime;
      if (task['time'] != null && task['time'].toString().isNotEmpty) {
        taskTime = _parseTimeString(task['time']);
      } else {
        taskTime = DateTime(2022, 1, 1, 9, 0);
      }
      _activeHours.add(taskTime.hour);

      final timeKey = '${taskTime.hour}:${taskTime.minute.toString().padLeft(2, '0')}';
      if (!_timeSlotItems.containsKey(timeKey)) _timeSlotItems[timeKey] = [];
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
    setState(() {
      // Reset "Show More" state per time slot
      _showMoreExpanded.clear();
      _timeSlotItems.keys.forEach((k) {
        _showMoreExpanded[k] = false;
      });
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _calculateExpandedHours() {
    _expandedHours.clear();
    Map<int, int> itemsPerHour = {};
    _timeSlotItems.forEach((timeKey, items) {
      final hour = int.parse(timeKey.split(':')[0]);
      itemsPerHour[hour] = (itemsPerHour[hour] ?? 0) + items.length;
    });
    itemsPerHour.forEach((hour, count) {
      if (count > 1) {
        _expandedHours[hour] = count;
      }
    });
  }

  double _getHourHeight(int hour) {
    return _expandedHours.containsKey(hour) ? 60.0 * (_expandedHours[hour] ?? 1) : 60.0;
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
    _fetchActivitiesData();
  }

  final FabController fabController = Get.put(FabController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.colorsBlue,
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
                _calendarFormat = _isMonthView ? CalendarFormat.week : CalendarFormat.month;
                _isMonthView = !_isMonthView;
              });
            },
            icon: _isMonthView
                ? Image.asset(
                    'assets/week.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  )
                : Image.asset(
                    'assets/calendar.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              CalenderWidget(
                key: ValueKey(_calendarFormat),
                calendarFormat: _calendarFormat,
                onDateSelected: _handleDateSelected,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                width: double.infinity,
                child: Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay ?? _focusedDay),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTabbedTimelineView(),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildTabbedTimelineView() {
  if (_isLoading) {
    return const Center(child: CircularProgressIndicator(color: Colors.blue));
  }

  final List<int> displayHours = _getDisplayHours();
  if (_timeSlotItems.isEmpty) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/calendar.png",
              width: 48.0 * MediaQuery.of(context).textScaleFactor,
              height: 48.0 * MediaQuery.of(context).textScaleFactor,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No activities scheduled for this day',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  final activeTimeSlots = _timeSlotItems.keys.toList()..sort();

  if (activeTimeSlots.isEmpty) {
    return Expanded(child: _emptyState('No scheduled activities for this date'));
  }

  // Timeline view (vertical tabbed)
  return Expanded(
    child: ListView.separated(
      controller: _timelineScrollController,
      itemCount: activeTimeSlots.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.grey.shade300,
        thickness: 1,
        indent: 8,
        endIndent: 8,
      ),
      itemBuilder: (context, index) {
        final timeKey = activeTimeSlots[index];
        final items = _timeSlotItems[timeKey] ?? [];

        // Group by type, but merge for display (show all event/task types)
        final events = items.where((item) => item['start_time'] != null).toList();
        final tasks = items.where((item) => item['start_time'] == null).toList();

        List<dynamic> allItems = [];
        allItems.addAll(events);
        allItems.addAll(tasks);

        bool isExpanded = _expandedSlots[timeKey] ?? false;
        int showCount = isExpanded ? allItems.length : 2;
        bool showMore = allItems.length > 2;

        List<dynamic> displayItems = allItems.take(showCount).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      timeKey,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...displayItems.map(
                          (item) {
                            if (item['start_time'] != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: _buildEventTab(item),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: _buildTaskTab(item),
                              );
                            }
                          },
                        ).toList(),
                        if (showMore && !isExpanded)
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedSlots[timeKey] = true;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3.0),
                                child: Text(
                                  "Show More (${allItems.length - 2} more) ▼",
                                  style: TextStyle(
                                    color:  const Color.fromRGBO(117, 117, 117, 1),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (showMore && isExpanded)
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedSlots[timeKey] = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3.0),
                                child: Text(
                                  "Show Less ▲",
                                  style: TextStyle(
                                    color: const Color.fromRGBO(117, 117, 117, 1),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}


   DateTime _parseTimeString(String timeStr) {
    if (timeStr.isEmpty) {
      return DateTime(2022, 1, 1, 0, 0);
    }
    bool isPM = timeStr.toLowerCase().contains('pm');
    bool isAM = timeStr.toLowerCase().contains('am');
    String cleanTime = timeStr
        .toLowerCase()
        .replaceAll('am', '')
        .replaceAll('pm', '')
        .replaceAll(' ', '')
        .trim();
    final parts = cleanTime.split(':');
    if (parts.length < 2) return DateTime(2022, 1, 1, 0, 0);
    try {
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }
      return DateTime(2022, 1, 1, hour, minute);
    } catch (e) {
      return DateTime(2022, 1, 1, 0, 0);
    }
  }

  String _formatTimeFor12Hour(String timeStr) {
    if (timeStr.isEmpty || !timeStr.contains(':')) {
      return timeStr;
    }
    DateTime parsedTime = _parseTimeString(timeStr);
    String period = parsedTime.hour >= 12 ? 'PM' : 'AM';
    int hour12 = parsedTime.hour > 12
        ? parsedTime.hour - 12
        : (parsedTime.hour == 0 ? 12 : parsedTime.hour);
    return '${hour12}:${parsedTime.minute.toString().padLeft(2, '0')} $period';
  }


  List<int> _getDisplayHours() {
    Set<int> hours = Set<int>.from(_activeHours);
    if (hours.isNotEmpty) {
      int minHour = hours.reduce((a, b) => a < b ? a : b);
      int maxHour = hours.reduce((a, b) => a > b ? a : b);
      if (minHour > 0) hours.add(minHour - 1);
      if (maxHour < 23) hours.add(maxHour + 1);
    }
    List<int> sortedHours = hours.toList()..sort();
    return sortedHours.isEmpty ? [DateTime.now().hour] : sortedHours;
  }


    Widget _emptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Image.asset(
            'assets/calendar.png',
            width: 50,
            height: 50,
            color: const Color.fromRGBO(117, 117, 117, 1),
          ),
          SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Card/tab UI for event/task ----

  Widget _buildEventTab(dynamic item) {
    String leadId = item['lead_id']?.toString() ?? '';
    String name = item['name'] ?? 'No Name';
    String category = item['category'] ?? 'Appointment';
    String timeRange =
        '${_formatTimeFor12Hour(item['start_time'] ?? '00:00')} - ${_formatTimeFor12Hour(item['end_time'] ?? '00:00')}';

    return InkWell(
      onTap: () {
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
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.colorsBlue.withOpacity(.09),
          border: Border.all(
            color: AppColors.colorsBlue.withOpacity(0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, size: 16, color: AppColors.colorsBlue),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    name,
                    style: AppFont.dropDowmLabel(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              category,
              style: AppFont.dashboardCarName(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTab(dynamic item) {
    String leadId = item['lead_id']?.toString() ?? '';
    String subject = item['subject'] ?? 'No Subject';
    String category = item['category'] ?? 'Task';
    String due = _formatTimeFor12Hour(
      item['due_date'] ?? item['time'] ?? '00:00',
    );

    // Determine task type and icon
    IconData taskIcon = Icons.task_alt;
    Color taskColor = Colors.purple;
    String taskType = 'Task';

    if (category.toLowerCase().contains('call')) {
      taskIcon = Icons.phone;
      taskColor = Colors.green;
      taskType = 'Call';
    } else if (category.toLowerCase().contains('quotation')) {
      taskIcon = Icons.description;
      taskColor = Colors.orange;
      taskType = 'Quotation';
    } else if (category.toLowerCase().contains('test drive')) {
      taskIcon = Icons.directions_car;
      taskColor = Colors.blue;
      taskType = 'Test Drive';
    } else if (category.toLowerCase().contains('meeting')) {
      taskIcon = Icons.people;
      taskColor = Colors.teal;
      taskType = 'Meeting';
    }
    // You can add more types as needed.

    return InkWell(
      onTap: () {
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
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: taskColor.withOpacity(.08),
          border: Border.all(color: taskColor.withOpacity(0.2), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(taskIcon, size: 16, color: taskColor),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$taskType: $subject',
                    style: AppFont.dropDowmLabel(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              category,
              style: AppFont.dashboardCarName(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              'Due: $due',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper functions ---
  
  // DateTime _parseTimeString(String timeStr) {
  //   if (timeStr.isEmpty) {
  //     return DateTime(2022, 1, 1, 0, 0);
  //   }
  //   bool isPM = timeStr.toLowerCase().contains('pm');
  //   bool isAM = timeStr.toLowerCase().contains('am');
  //   String cleanTime = timeStr
  //       .toLowerCase()
  //       .replaceAll('am', '')
  //       .replaceAll('pm', '')
  //       .replaceAll(' ', '')
  //       .trim();
  //   final parts = cleanTime.split(':');
  //   if (parts.length < 2) return DateTime(2022, 1, 1, 0, 0);
  //   try {
  //     int hour = int.parse(parts[0]);
  //     final minute = int.parse(parts[1]);
  //     if (isPM && hour < 12) {
  //       hour += 12;
  //     } else if (isAM && hour == 12) {
  //       hour = 0;
  //     }
  //     return DateTime(2022, 1, 1, hour, minute);
  //   } catch (e) {
  //     return DateTime(2022, 1, 1, 0, 0);
  //   }
  // }

  // String _formatTimeFor12Hour(String timeStr) {
  //   if (timeStr.isEmpty || !timeStr.contains(':')) {
  //     return timeStr;
  //   }
  //   DateTime parsedTime = _parseTimeString(timeStr);
  //   String period = parsedTime.hour >= 12 ? 'PM' : 'AM';
  //   int hour12 = parsedTime.hour > 12
  //       ? parsedTime.hour - 12
  //       : (parsedTime.hour == 0 ? 12 : parsedTime.hour);
  //   return '${hour12}:${parsedTime.minute.toString().padLeft(2, '0')} $period';
  // }
}