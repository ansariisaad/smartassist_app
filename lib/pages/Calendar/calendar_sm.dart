import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/config/getX/fab.controller.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/calender/calender.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class CalendarSm extends StatefulWidget {
  final String leadName;
  const CalendarSm({super.key, required this.leadName});
  @override
  State<CalendarSm> createState() => _CalendarSmState();
}

class _CalendarSmState extends State<CalendarSm> {
  Map<String, dynamic> _teamData = {};
  List<Map<String, dynamic>> _teamMembers = [];
  int _selectedProfileIndex = 0;
  String _selectedUserId = '';
  String _selectedType = 'your';
  String? _selectedLetter;

  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _isMonthView = false;
  List<dynamic> tasks = [];
  List<dynamic> events = [];
  DateTime? _selectedDay;
  bool _isLoading = false;
  ScrollController _timelineScrollController = ScrollController();

  Set<int> _activeHours = {};
  Map<String, List<dynamic>> _timeSlotItems = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchTeamDetails();
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
    double scrollPosition = currentHour * 80.0;
    scrollPosition = scrollPosition > 60 ? scrollPosition - 60 : 0;
    _timelineScrollController.animateTo(
      scrollPosition,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _fetchTeamDetails() async {
    try {
      final token = await Storage.getToken();
      final baseUri = Uri.parse(
        'https://dev.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
      );
      final response = await http.get(
        baseUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _teamData = data['data'] ?? {};
          if (_teamData.containsKey('allMember') &&
              _teamData['allMember'].isNotEmpty) {
            _teamMembers = [];
            for (var member in _teamData['allMember']) {
              _teamMembers.add({
                'fname': member['fname'] ?? '',
                'lname': member['lname'] ?? '',
                'user_id': member['user_id'] ?? '',
                'profile': member['profile'],
                'initials': member['initials'] ?? '',
              });
            }
          }
        });
      }
    } catch (e) {
      print('Error fetching team details: $e');
    }
  }

  Future<void> _fetchActivitiesData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final token = await Storage.getToken();
      String formattedDate = DateFormat(
        'dd-MM-yyyy',
      ).format(_selectedDay ?? _focusedDay);

      final Map<String, String> queryParams = {'date': formattedDate};
      if (_selectedType == 'team' && _selectedUserId.isNotEmpty) {
        queryParams['user_id'] = _selectedUserId;
      }
      final baseUrl = Uri.parse(
        "https://dev.smartassistapp.in/api/calendar/activities/all/asondate",
      );
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
      print("Error fetching activities data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processTimeSlots() {
    _activeHours.clear();
    _timeSlotItems.clear();
    for (var item in [...events, ...tasks]) {
      String? timeRaw = item['start_time'] ?? item['time'] ?? item['due_date'];
      if (timeRaw == null || timeRaw.toString().isEmpty) timeRaw = "09:00";
      final itemTime = _parseTimeString(timeRaw);
      final hour = itemTime.hour;
      _activeHours.add(hour);
      final timeKey = '${hour.toString().padLeft(2, '0')}:00';
      if (!_timeSlotItems.containsKey(timeKey)) _timeSlotItems[timeKey] = [];
      _timeSlotItems[timeKey]!.add(item);
    }
    if (_activeHours.isEmpty) {
      if (_isSameDay(_selectedDay ?? _focusedDay, DateTime.now())) {
        _activeHours.add(DateTime.now().hour);
      } else {
        _activeHours.add(9);
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _handleDateSelected(DateTime selectedDate) {
    setState(() {
      _selectedDay = selectedDate;
      _focusedDay = selectedDate;
      tasks = [];
      events = [];
      _activeHours.clear();
      _timeSlotItems.clear();
      _isLoading = true;
    });
    _fetchActivitiesData();
  }

  void _handleTeamYourSelection(String type) async {
    setState(() {
      _selectedType = type;
      if (type == 'your') {
        _selectedProfileIndex = 0;
        _selectedUserId = '';
      }
      _isLoading = true;
    });
    await _fetchActivitiesData();
  }

  void _handleTeamMemberSelection(int index, String userId) async {
    setState(() {
      _selectedProfileIndex = index;
      _selectedUserId = userId;
      _selectedType = 'team';
      _isLoading = true;
    });
    await _fetchActivitiesData();
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
                _calendarFormat = _isMonthView
                    ? CalendarFormat.week
                    : CalendarFormat.month;
                _isMonthView = !_isMonthView;
              });
            },
            icon: _isMonthView
                ? Icon(Icons.view_week, color: Colors.white)
                : Icon(Icons.calendar_today, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTeamYourButtons(),
            if (_selectedType == 'team') _buildProfileAvatars(),
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
            _buildTimelineView(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: AppColors.colorsBlue),
        ),
      );
    }
    if (_selectedType == 'team' && _selectedUserId.isEmpty) {
      return _emptyState('Select a PS to view their schedule');
    }

    // Only show active time slots (that have items)
    final activeTimeSlots = _timeSlotItems.keys.toList()..sort();

    if (activeTimeSlots.isEmpty) {
      return _emptyState('No scheduled activities for this date');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
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

        // Separate tasks and events
        final events = items
            .where((item) => item['start_time'] != null)
            .toList();
        final tasks = items
            .where((item) => item['start_time'] == null)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
          child: Row(
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
                    // Display Events first
                    ...events
                        .map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildEventTab(event),
                          ),
                        )
                        .toList(),

                    // Display Tasks after events
                    ...tasks
                        .map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildTaskTab(task),
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 50, color: Colors.grey.shade300),
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
        width: double.infinity, // Full width instead of fixed 180
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
    }

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
        width: double.infinity, // Full width instead of fixed 180
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

  // --- SUPPORT FOR TEAM/PROFILE ---
  Widget _buildTeamYourButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 35,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(239, 239, 239, 1),
            border: Border.all(
              color: const Color.fromRGBO(239, 239, 239, 1),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 50,
                decoration: BoxDecoration(
                  color: _selectedType == 'team'
                      ? Colors.white
                      : const Color.fromRGBO(239, 239, 239, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                  ),
                  onPressed: () => _handleTeamYourSelection('team'),
                  child: Text(
                    "Team's",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.fontColor,
                    ),
                  ),
                ),
              ),
              Container(
                width: 100,
                height: 50,
                decoration: BoxDecoration(
                  color: _selectedType == 'your'
                      ? Colors.white
                      : const Color.fromRGBO(239, 239, 239, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                  ),
                  onPressed: () => _handleTeamYourSelection('your'),
                  child: Text(
                    'Your',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.fontColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatars() {
    List<Map<String, dynamic>> sortedTeamMembers = List.from(_teamMembers);
    sortedTeamMembers.sort(
      (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
        (b['fname'] ?? '').toString().toLowerCase(),
      ),
    );
    Set<String> uniqueLetters = {};
    for (var member in sortedTeamMembers) {
      String firstLetter = (member['fname'] ?? '').toString().toUpperCase();
      if (firstLetter.isNotEmpty) {
        uniqueLetters.add(firstLetter[0]);
      }
    }
    List<String> sortedLetters = uniqueLetters.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ...sortedLetters.expand(
              (letter) => _buildLetterWithMembers(letter),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLetterWithMembers(String letter) {
    List<Widget> widgets = [];
    bool isSelected = _selectedLetter == letter;

    widgets.add(_buildAlphabetAvatar(letter));
    if (isSelected) {
      List<Map<String, dynamic>> letterMembers = _teamMembers.where((member) {
        String firstName = (member['fname'] ?? '').toString().toUpperCase();
        return firstName.startsWith(letter);
      }).toList();

      letterMembers.sort(
        (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
          (b['fname'] ?? '').toString().toLowerCase(),
        ),
      );

      if (letterMembers.isNotEmpty) {
        widgets.add(
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.colorsBlue.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }
      for (int i = 0; i < letterMembers.length; i++) {
        int memberIndex =
            _teamMembers.indexWhere(
              (member) => member['user_id'] == letterMembers[i]['user_id'],
            ) +
            1;
        widgets.add(
          _buildProfileAvatar(
            letterMembers[i]['fname'] ?? '',
            memberIndex,
            letterMembers[i]['user_id'] ?? '',
            letterMembers[i]['profile'],
            letterMembers[i]['initials'] ?? '',
          ),
        );
      }
      if (letterMembers.isNotEmpty) {
        widgets.add(
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.colorsBlue.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildAlphabetAvatar(String letter) {
    bool isSelected = _selectedLetter == letter;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_selectedLetter == letter) {
                _selectedLetter = null;
              } else {
                _selectedLetter = letter;
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.colorsBlue.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              border: isSelected
                  ? Border.all(color: AppColors.colorsBlue, width: 2.5)
                  : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: isSelected ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.colorsBlue
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          letter,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.colorsBlue : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar(
    String firstName,
    int index,
    String userId,
    String? profileUrl,
    String initials,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _handleTeamMemberSelection(index, userId),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withOpacity(0.1),
              border: _selectedProfileIndex == index
                  ? Border.all(color: AppColors.colorsBlue, width: 2)
                  : null,
            ),
            child: ClipOval(
              child: profileUrl != null && profileUrl.isNotEmpty
                  ? Image.network(
                      profileUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            initials.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        initials.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          firstName,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
      ],
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
}



// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/config/getX/fab.controller.dart';
// import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/calender/calender.dart';
// import 'package:table_calendar/table_calendar.dart';
// import 'package:google_fonts/google_fonts.dart';

// import 'package:http/http.dart' as http;

// class CalendarSm extends StatefulWidget {
//   final String leadName;

//   const CalendarSm({super.key, required this.leadName});

//   @override
//   State<CalendarSm> createState() => _CalendarSmState();
// }

// class _CalendarSmState extends State<CalendarSm> {
//   Map<String, dynamic> _teamData = {};
//   List<Map<String, dynamic>> _teamMembers = [];
//   int _selectedProfileIndex = 0;
//   String _selectedUserId = '';
//   String _selectedType = 'your'; // 'your' or 'team'

//   DateTime _focusedDay = DateTime.now();
//   CalendarFormat _calendarFormat = CalendarFormat.week;
//   bool _isMonthView = false;
//   List<dynamic> tasks = [];
//   List<dynamic> events = [];
//   List<dynamic> appointments = [];
//   DateTime? _selectedDay;
//   bool _isLoading = false;
//   ScrollController _timelineScrollController = ScrollController();

//   // Track all hours (0-23) for a complete timeline
//   List<int> _allHours = List.generate(24, (index) => index);

//   // Track active hours (hours with data)
//   Set<int> _activeHours = {};

//   // Map to track expanded hour slots
//   Map<int, int> _expandedHours = {};

//   // Map to track items by exact time (hour:minute)
//   Map<String, List<dynamic>> _timeSlotItems = {};

//   @override
//   void initState() {
//     super.initState();
//     _selectedDay = _focusedDay;
//     _fetchTeamDetails();
//     // Initial load with 'your' data (no user_id)
//     _fetchActivitiesData();

//     // Scroll to current hour when view loads
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _scrollToCurrentHour();
//     });
//   }

//   @override
//   void dispose() {
//     _timelineScrollController.dispose();
//     super.dispose();
//   }

//   void _scrollToCurrentHour() {
//     if (!_timelineScrollController.hasClients) return;

//     // Get current hour
//     final currentHour = DateTime.now().hour;

//     // Calculate scroll position - 60 pixels per hour
//     double scrollPosition = currentHour * 60.0;

//     // Subtract a small offset for better visibility
//     scrollPosition = scrollPosition > 60 ? scrollPosition - 60 : 0;

//     _timelineScrollController.animateTo(
//       scrollPosition,
//       duration: Duration(milliseconds: 300),
//       curve: Curves.easeOut,
//     );
//   }

//   Future<void> _fetchTeamDetails() async {
//     try {
//       final token = await Storage.getToken();

//       final baseUri = Uri.parse(
//         'https://dev.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
//       );

//       final response = await http.get(
//         baseUri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       print('📥 Team Details Status Code: ${response.statusCode}');
//       print('📥 Team Details Response: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         setState(() {
//           _teamData = data['data'] ?? {};

//           if (_teamData.containsKey('allMember') &&
//               _teamData['allMember'].isNotEmpty) {
//             _teamMembers = [];

//             for (var member in _teamData['allMember']) {
//               _teamMembers.add({
//                 'fname': member['fname'] ?? '',
//                 'lname': member['lname'] ?? '',
//                 'user_id': member['user_id'] ?? '',
//                 'profile': member['profile'],
//                 'initials': member['initials'] ?? '',
//               });
//             }
//           }
//         });
//       } else {
//         throw Exception('Failed to fetch team details: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching team details: $e');
//     }
//   }

//   Future<void> _fetchActivitiesData() async {
//     if (mounted) {
//       setState(() {
//         _isLoading = true;
//       });
//     }

//     try {
//       final token = await Storage.getToken();
//       // Format the selected date
//       String formattedDate = DateFormat(
//         'dd-MM-yyyy',
//       ).format(_selectedDay ?? _focusedDay);

//       // Build query parameters
//       final Map<String, String> queryParams = {'date': formattedDate};

//       // Add user_id only if team member is selected (not for 'your' option)
//       if (_selectedType == 'team' && _selectedUserId.isNotEmpty) {
//         queryParams['user_id'] = _selectedUserId;
//       }

//       final baseUrl = Uri.parse(
//         "https://dev.smartassistapp.in/api/calendar/activities/all/asondate",
//       );
//       final uri = baseUrl.replace(queryParameters: queryParams);

//       print('📤 Fetching activities from: $uri');
//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       print('📥 Activities Status Code: ${response.statusCode}');
//       print('📥 Activities Response: ${response.body}');

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         setState(() {
//           tasks = data['data']['tasks'] ?? [];
//           events = data['data']['events'] ?? [];
//           _isLoading = false;
//         });

//         // Process the time slots after fetching data
//         _processTimeSlots();
//       } else {
//         setState(() => _isLoading = false);
//         print('Failed to fetch activities: ${response.statusCode}');
//       }
//     } catch (e) {
//       print("Error fetching activities data: $e");
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   // New method to process all items into time slots
//   void _processTimeSlots() {
//     _activeHours.clear();
//     _expandedHours.clear();
//     _timeSlotItems.clear();

//     // Process events (appointments)
//     for (var event in events) {
//       final startTime = _parseTimeString(event['start_time'] ?? '00:00');
//       final endTime = startTime.add(Duration(hours: 1));

//       for (int hour = startTime.hour; hour <= endTime.hour; hour++) {
//         _activeHours.add(hour);
//       }

//       final timeKey =
//           '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
//       if (!_timeSlotItems.containsKey(timeKey)) {
//         _timeSlotItems[timeKey] = [];
//       }
//       _timeSlotItems[timeKey]!.add({
//         'item': event,
//         'type': 'event',
//         'startTime': startTime,
//         'endTime': endTime,
//       });
//     }

//     // Process tasks
//     for (var task in tasks) {
//       DateTime taskTime;
//       if (task['time'] != null && task['time'].toString().isNotEmpty) {
//         taskTime = _parseTimeString(task['time']);
//       } else {
//         taskTime = DateTime(2022, 1, 1, 9, 0); // Default to 9 AM
//       }

//       _activeHours.add(taskTime.hour);

//       final timeKey =
//           '${taskTime.hour}:${taskTime.minute.toString().padLeft(2, '0')}';
//       if (!_timeSlotItems.containsKey(timeKey)) {
//         _timeSlotItems[timeKey] = [];
//       }
//       _timeSlotItems[timeKey]!.add({
//         'item': task,
//         'type': 'task',
//         'startTime': taskTime,
//         'endTime': taskTime.add(Duration(minutes: 30)),
//       });
//     }

//     if (_activeHours.isEmpty) {
//       if (_isSameDay(_selectedDay ?? _focusedDay, DateTime.now())) {
//         _activeHours.add(DateTime.now().hour);
//       } else {
//         _activeHours.add(9);
//       }
//     }

//     _calculateExpandedHours();
//     print("Active hours: $_activeHours");
//     print("Time slots: ${_timeSlotItems.keys.length}");
//   }

//   // Check if two dates are the same day
//   bool _isSameDay(DateTime a, DateTime b) {
//     return a.year == b.year && a.month == b.month && a.day == b.day;
//   }

//   void _calculateExpandedHours() {
//     _expandedHours.clear();

//     // Count total items per hour across all time slots
//     Map<int, int> itemsPerHour = {};

//     _timeSlotItems.forEach((timeKey, items) {
//       final hour = int.parse(timeKey.split(':')[0]);
//       itemsPerHour[hour] = (itemsPerHour[hour] ?? 0) + items.length;
//     });

//     // Set the number of items for each hour
//     itemsPerHour.forEach((hour, count) {
//       if (count > 0) {
//         _expandedHours[hour] = count;
//       }
//     });
//   }

//   // Get the appropriate height for an hour based on whether it's expanded
//   double _getHourHeight(int hour) {
//     // Height per item is 65 pixels (55px item + 10px spacing)
//     // If there are items in this hour, scale the height by the number of items
//     return _expandedHours.containsKey(hour)
//         ? 65.0 * _expandedHours[hour]!
//         : 65.0;
//   }

//   void _handleDateSelected(DateTime selectedDate) {
//     setState(() {
//       _selectedDay = selectedDate;
//       _focusedDay = selectedDate;
//       tasks = [];
//       events = [];
//       appointments = [];
//       _activeHours.clear();
//       _expandedHours.clear();
//       _timeSlotItems.clear();
//       _isLoading = true;
//     });

//     String formattedDate = DateFormat('dd-MM-yyyy').format(selectedDate);
//     print('Selected Date State: ${_selectedDay}');
//     print('Fetching data for date: $formattedDate');

//     _fetchActivitiesData();
//   }

//   // Handle team/your selection
//   void _handleTeamYourSelection(String type) async {
//     setState(() {
//       _selectedType = type;
//       if (type == 'your') {
//         _selectedProfileIndex = 0;
//         _selectedUserId = '';
//       }
//       _isLoading = true;
//     });

//     await _fetchActivitiesData();
//   }

//   // Handle team member selection
//   void _handleTeamMemberSelection(int index, String userId) async {
//     setState(() {
//       _selectedProfileIndex = index;
//       _selectedUserId = userId;
//       _selectedType = 'team';
//       _isLoading = true;
//     });

//     await _fetchActivitiesData();
//   }

//   // Initialize the controller
//   final FabController fabController = Get.put(FabController());

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.colorsBlue,
//         automaticallyImplyLeading: false,
//         title: Align(
//           alignment: Alignment.centerLeft,
//           child: Text(
//             'Calendar',
//             style: GoogleFonts.poppins(
//               fontSize: 18,
//               fontWeight: FontWeight.w500,
//               color: Colors.white,
//             ),
//           ),
//         ),
//         actions: [
//           IconButton(
//             onPressed: () {
//               setState(() {
//                 _calendarFormat = _isMonthView
//                     ? CalendarFormat.week
//                     : CalendarFormat.month;
//                 _isMonthView = !_isMonthView;
//               });
//             },
//             icon: _isMonthView
//                 ? Image.asset(
//                     'assets/week.png',
//                     width: 24,
//                     height: 24,
//                     color: Colors.white,
//                   )
//                 : Image.asset(
//                     'assets/calendar.png',
//                     width: 24,
//                     height: 24,
//                     color: Colors.white,
//                   ),
//           ),
//         ],
//       ),
//       body:
//           // _isLoading
//           //     ? const Center(child: CircularProgressIndicator(color: AppColors.colorsBlue))
//           //     :
//           SingleChildScrollView(
//             child: Column(
//               children: [
//                 // Team/Your selection buttons
//                 _buildTeamYourButtons(),

//                 // Team members avatars (show only when team is selected)
//                 if (_selectedType == 'team') _buildProfileAvatars(),

//                 // Calendar at the top
//                 CalenderWidget(
//                   key: ValueKey(_calendarFormat),
//                   calendarFormat: _calendarFormat,
//                   onDateSelected: _handleDateSelected,
//                 ),

//                 // Date header
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 8,
//                   ),
//                   width: double.infinity,
//                   child: Text(
//                     DateFormat(
//                       'EEEE, MMMM d',
//                     ).format(_selectedDay ?? _focusedDay),
//                     style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),

//                 // Timeline view - no longer in Expanded
//                 _buildImprovedTimelineView(),
//               ],
//             ),
//           ),
//     );
//   }

//   Widget _buildTeamYourButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Container(
//           height: 35,
//           margin: const EdgeInsets.symmetric(vertical: 10),
//           decoration: BoxDecoration(
//             color: const Color.fromRGBO(239, 239, 239, 1),
//             border: Border.all(
//               color: const Color.fromRGBO(239, 239, 239, 1),
//               width: 2,
//             ),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 100,
//                 height: 50,
//                 decoration: BoxDecoration(
//                   color: _selectedType == 'team'
//                       ? Colors.white
//                       : const Color.fromRGBO(239, 239, 239, 1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: TextButton(
//                   style: TextButton.styleFrom(
//                     padding: EdgeInsets.zero,
//                     splashFactory: NoSplash.splashFactory,
//                     overlayColor: Colors.transparent,
//                   ),
//                   onPressed: () => _handleTeamYourSelection('team'),
//                   child: Text(
//                     "Team's",
//                     style: GoogleFonts.poppins(
//                       fontSize: 14,
//                       color: _selectedType == 'team'
//                           ? AppColors.fontColor
//                           : AppColors.fontColor,
//                     ),
//                   ),
//                 ),
//               ),
//               Container(
//                 width: 100,
//                 height: 50,
//                 decoration: BoxDecoration(
//                   color: _selectedType == 'your'
//                       ? Colors.white
//                       : const Color.fromRGBO(239, 239, 239, 1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: TextButton(
//                   style: TextButton.styleFrom(
//                     padding: EdgeInsets.zero,
//                     splashFactory: NoSplash.splashFactory,
//                     overlayColor: Colors.transparent,
//                   ),
//                   onPressed: () => _handleTeamYourSelection('your'),
//                   child: Text(
//                     'Your',
//                     style: GoogleFonts.poppins(
//                       fontSize: 14,
//                       color: _selectedType == 'your'
//                           ? AppColors.fontColor
//                           : AppColors.fontColor,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // Add this variable to your class
//   String? _selectedLetter;

//   Widget _buildProfileAvatars() {
//     List<Map<String, dynamic>> sortedTeamMembers = List.from(_teamMembers);
//     sortedTeamMembers.sort(
//       (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
//         (b['fname'] ?? '').toString().toLowerCase(),
//       ),
//     );

//     // Get unique letters from team members
//     Set<String> uniqueLetters = {};
//     for (var member in sortedTeamMembers) {
//       String firstLetter = (member['fname'] ?? '').toString().toUpperCase();
//       if (firstLetter.isNotEmpty) {
//         uniqueLetters.add(firstLetter[0]);
//       }
//     }

//     List<String> sortedLetters = uniqueLetters.toList()..sort();

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Container(
//         margin: const EdgeInsets.only(top: 10),
//         height: 90,
//         padding: const EdgeInsets.symmetric(horizontal: 0),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Build letters with their members inline
//             ...sortedLetters.expand(
//               (letter) => _buildLetterWithMembers(letter),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Method to build letter with its members inline
//   List<Widget> _buildLetterWithMembers(String letter) {
//     List<Widget> widgets = [];
//     bool isSelected = _selectedLetter == letter;

//     // Add the letter avatar
//     widgets.add(_buildAlphabetAvatar(letter));

//     // If letter is selected, add its members right after
//     if (isSelected) {
//       List<Map<String, dynamic>> letterMembers = _teamMembers.where((member) {
//         String firstName = (member['fname'] ?? '').toString().toUpperCase();
//         return firstName.startsWith(letter);
//       }).toList();

//       // Sort members alphabetically
//       letterMembers.sort(
//         (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
//           (b['fname'] ?? '').toString().toLowerCase(),
//         ),
//       );

//       // Add visual separator before members
//       if (letterMembers.isNotEmpty) {
//         widgets.add(
//           Container(
//             width: 2,
//             height: 40,
//             margin: const EdgeInsets.symmetric(horizontal: 4),
//             decoration: BoxDecoration(
//               color: AppColors.colorsBlue.withOpacity(0.4),
//               borderRadius: BorderRadius.circular(1),
//             ),
//           ),
//         );
//       }

//       // Add member avatars
//       for (int i = 0; i < letterMembers.length; i++) {
//         int memberIndex =
//             _teamMembers.indexWhere(
//               (member) => member['user_id'] == letterMembers[i]['user_id'],
//             ) +
//             1;

//         widgets.add(
//           _buildProfileAvatar(
//             letterMembers[i]['fname'] ?? '',
//             memberIndex,
//             letterMembers[i]['user_id'] ?? '',
//             letterMembers[i]['profile'],
//             letterMembers[i]['initials'] ?? '',
//           ),
//         );
//       }

//       // Add visual separator after members
//       if (letterMembers.isNotEmpty) {
//         widgets.add(
//           Container(
//             width: 2,
//             height: 40,
//             margin: const EdgeInsets.symmetric(horizontal: 4),
//             decoration: BoxDecoration(
//               color: AppColors.colorsBlue.withOpacity(0.4),
//               borderRadius: BorderRadius.circular(1),
//             ),
//           ),
//         );
//       }
//     }

//     return widgets;
//   }

//   // Alphabet avatar method
//   Widget _buildAlphabetAvatar(String letter) {
//     bool isSelected = _selectedLetter == letter;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         InkWell(
//           onTap: () {
//             setState(() {
//               // Single selection: if same letter is tapped, deselect it
//               if (_selectedLetter == letter) {
//                 _selectedLetter = null;
//               } else {
//                 _selectedLetter = letter;
//               }

//               // Update your calendar filtering logic here
//               _filterCalendarByLetter();
//             });
//           },
//           child: Container(
//             margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: isSelected
//                   ? AppColors.colorsBlue.withOpacity(0.15)
//                   : Colors.grey.withOpacity(0.1),
//               border: isSelected
//                   ? Border.all(color: AppColors.colorsBlue, width: 2.5)
//                   : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
//             ),
//             child: Center(
//               child: Text(
//                 letter,
//                 style: TextStyle(
//                   fontSize: isSelected ? 22 : 20,
//                   fontWeight: FontWeight.bold,
//                   color: isSelected
//                       ? AppColors.colorsBlue
//                       : Colors.grey.shade600,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           letter,
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
//             color: isSelected ? AppColors.colorsBlue : Colors.black,
//           ),
//         ),
//       ],
//     );
//   }

//   // Your existing profile avatar method (unchanged)
//   Widget _buildProfileAvatar(
//     String firstName,
//     int index,
//     String userId,
//     String? profileUrl,
//     String initials,
//   ) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         InkWell(
//           onTap: () => _handleTeamMemberSelection(index, userId),
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 15),
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.grey.withOpacity(
//                 0.1,
//               ), // Updated to match AppColors.backgroundLightGrey
//               border: _selectedProfileIndex == index
//                   ? Border.all(color: AppColors.colorsBlue, width: 2)
//                   : null,
//             ),
//             child: ClipOval(
//               child: profileUrl != null && profileUrl.isNotEmpty
//                   ? Image.network(
//                       profileUrl,
//                       width: 50,
//                       height: 50,
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Center(
//                           child: Text(
//                             initials.toUpperCase(),
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.black,
//                             ),
//                           ),
//                         );
//                       },
//                     )
//                   : Center(
//                       child: Text(
//                         initials.toUpperCase(),
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                         ),
//                       ),
//                     ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           firstName,
//           style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 8),
//       ],
//     );
//   }

//   // Add this method to handle calendar filtering
//   void _filterCalendarByLetter() {
//     if (_selectedLetter == null) {
//       // Show all team members in calendar
//       // Your logic to show all calendar events
//     } else {
//       // Filter calendar events by selected letter
//       List<String> filteredUserIds = [];

//       List<Map<String, dynamic>> letterMembers = _teamMembers.where((member) {
//         String firstName = (member['fname'] ?? '').toString().toUpperCase();
//         return firstName.startsWith(_selectedLetter!);
//       }).toList();

//       for (var member in letterMembers) {
//         filteredUserIds.add(member['user_id'] ?? '');
//       }

//       // Your logic to filter calendar events by filteredUserIds
//       // Example: _filteredEvents = _allEvents.where((event) => filteredUserIds.contains(event['user_id'])).toList();
//     }

//     // Refresh your calendar view
//     // setState(() {});
//   }

//   // Widget _buildProfileAvatars() {
//   //   return SingleChildScrollView(
//   //     scrollDirection: Axis.horizontal,
//   //     child: Container(
//   //       margin: const EdgeInsets.only(top: 10),
//   //       height: 90,
//   //       padding: const EdgeInsets.symmetric(horizontal: 0),
//   //       child: Row(
//   //         crossAxisAlignment: CrossAxisAlignment.center,
//   //         children: [
//   //           for (int i = 0; i < _teamMembers.length; i++)
//   //             _buildProfileAvatar(
//   //               _teamMembers[i]['fname'] ?? '',
//   //               i + 1, // Starts from 1 because 0 is 'All'
//   //               _teamMembers[i]['user_id'] ?? '',
//   //               _teamMembers[i]['profile'], // Pass the profile URL
//   //               _teamMembers[i]['initials'] ?? '', // Pass the initials
//   //             ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }

//   // // Individual profile avatar
//   // Widget _buildProfileAvatar(
//   //   String firstName,
//   //   int index,
//   //   String userId,
//   //   String? profileUrl,
//   //   String initials,
//   // ) {
//   //   return Column(
//   //     mainAxisSize: MainAxisSize.min,
//   //     children: [
//   //       InkWell(
//   //         onTap: () => _handleTeamMemberSelection(index, userId),
//   //         child: Container(
//   //           margin: const EdgeInsets.symmetric(horizontal: 15),
//   //           width: 50,
//   //           height: 50,
//   //           decoration: BoxDecoration(
//   //             shape: BoxShape.circle,
//   //             color: AppColors.backgroundLightGrey,
//   //             border: _selectedProfileIndex == index
//   //                 ? Border.all(color: AppColors.colorsBlue, width: 2)
//   //                 : null,
//   //           ),
//   //           child: ClipOval(
//   //             child: profileUrl != null && profileUrl.isNotEmpty
//   //                 ? Image.network(
//   //                     profileUrl,
//   //                     width: 50,
//   //                     height: 50,
//   //                     fit: BoxFit.cover,
//   //                     errorBuilder: (context, error, stackTrace) {
//   //                       // Fallback to initials if image fails to load
//   //                       return Center(
//   //                         child: Text(
//   //                           initials.toUpperCase(),
//   //                           style: TextStyle(
//   //                             fontSize: 16,
//   //                             fontWeight: FontWeight.bold,
//   //                             color: Colors.black,
//   //                           ),
//   //                         ),
//   //                       );
//   //                     },
//   //                   )
//   //                 : Center(
//   //                     child: Text(
//   //                       initials.toUpperCase(),
//   //                       style: TextStyle(
//   //                         fontSize: 16,
//   //                         fontWeight: FontWeight.bold,
//   //                         color: Colors.black,
//   //                       ),
//   //                     ),
//   //                   ),
//   //           ),
//   //         ),
//   //       ),
//   //       const SizedBox(height: 8),
//   //       Text(
//   //         firstName,
//   //         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//   //       ),
//   //       const SizedBox(height: 8),
//   //     ],
//   //   );
//   // }

//   Widget _buildImprovedTimelineView() {
//     if (_isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(color: AppColors.colorsBlue),
//       );
//     }

//     // Show message if team is selected but no user is chosen
//     if (_selectedType == 'team' && _selectedUserId.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 double imageSize =
//                     MediaQuery.of(context).size.width *
//                     0.12; // 12% of screen width
//                 return Image.asset(
//                   'assets/calendar.png', // Replace with your image path
//                   width: imageSize,
//                   height: imageSize,
//                   color: Colors
//                       .grey, // Optional: applies color filter to the image
//                 );
//               },
//             ),
//             SizedBox(
//               height: MediaQuery.of(context).size.height * 0.02,
//             ), // 2% of screen height
//             Text(
//               'Select a PS to view their schedule',
//               style: TextStyle(
//                 fontSize:
//                     MediaQuery.of(context).size.width *
//                     0.04, // 4% of screen width
//                 color: Colors.grey,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       );
//     }

//     final combinedItems = [...tasks, ...events];
//     if (combinedItems.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Image.asset(
//               "assets/calendar.png",
//               width: 48.0 * MediaQuery.of(context).textScaleFactor,
//               height: 48.0 * MediaQuery.of(context).textScaleFactor,
//               color: Colors.grey,
//             ),
//             SizedBox(height: 16.0 * MediaQuery.of(context).textScaleFactor),
//             Text(
//               'No activities scheduled for this day',
//               style: TextStyle(
//                 fontSize: 16.0 * MediaQuery.of(context).textScaleFactor,
//                 color: Colors.grey,
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     // Get display hours
//     final List<int> displayHours = _getDisplayHours();

//     return SingleChildScrollView(
//       controller: _timelineScrollController,
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Time column
//           _buildTimeColumn(displayHours),
//           Container(width: 1, color: Colors.grey.shade300),
//           // Main content area
//           Expanded(
//             child: Stack(
//               children: [
//                 _buildTimeGridLines(displayHours),
//                 ..._buildAllTimeSlotItems(displayHours),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Modified to only return hours with actual content
//   List<int> _getDisplayHours() {
//     // Start with active hours that have content
//     Set<int> hours = Set<int>.from(_activeHours);

//     // If we have appointments or tasks spanning several hours, add buffer hours
//     if (hours.isNotEmpty) {
//       int minHour = hours.reduce((a, b) => a < b ? a : b);
//       int maxHour = hours.reduce((a, b) => a > b ? a : b);

//       // Add one hour before and after for context, but only if they exist
//       if (minHour > 0) hours.add(minHour - 1);
//       if (maxHour < 23) hours.add(maxHour + 1);
//     }

//     // Sort hours
//     List<int> sortedHours = hours.toList()..sort();
//     return sortedHours.isEmpty ? [DateTime.now().hour] : sortedHours;
//   }

//   Widget _buildTimeColumn(List<int> displayHours) {
//     return Container(
//       width: 50,
//       child: Column(
//         children: displayHours.map((hour) {
//           // Get appropriate height for this hour slot
//           final hourHeight = _getHourHeight(hour);

//           return Container(
//             height: hourHeight,
//             padding: EdgeInsets.only(right: 8),
//             alignment: Alignment.topRight,
//             child: Text(
//               '${hour.toString().padLeft(2, '0')}:00',
//               style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildTimeGridLines(List<int> displayHours) {
//     return Column(
//       children: displayHours.map((hour) {
//         // Get appropriate height for this hour slot
//         final hourHeight = _getHourHeight(hour);

//         return Container(
//           height: hourHeight,
//           decoration: BoxDecoration(
//             border: Border(
//               top: BorderSide(color: Colors.grey.shade200, width: 1),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   List<Widget> _buildAllTimeSlotItems(List<int> displayHours) {
//     List<Widget> allWidgets = [];
//     final screenWidth = MediaQuery.of(context).size.width;
//     final baseItemWidth = screenWidth * 0.75 - 24; // Subtract padding/margins

//     // Calculate hour positions
//     Map<int, double> hourPositions = {};
//     double currentPosition = 0.0;

//     for (int hour in displayHours) {
//       hourPositions[hour] = currentPosition;
//       currentPosition += _getHourHeight(hour);
//     }

//     // Sort time slots by time
//     List<String> sortedTimeKeys = _timeSlotItems.keys.toList()
//       ..sort((a, b) {
//         final aParts = a.split(':');
//         final bParts = b.split(':');
//         final aHour = int.parse(aParts[0]);
//         final aMinute = int.parse(aParts[1]);
//         final bHour = int.parse(bParts[0]);
//         final bMinute = int.parse(bParts[1]);

//         if (aHour != bHour) return aHour.compareTo(bHour);
//         return aMinute.compareTo(bMinute);
//       });

//     // Process each time slot
//     for (String timeKey in sortedTimeKeys) {
//       final items = _timeSlotItems[timeKey]!;
//       final parts = timeKey.split(':');
//       final hour = int.parse(parts[0]);
//       final minute = int.parse(parts[1]);

//       if (!hourPositions.containsKey(hour)) continue;

//       // Calculate base position for this time slot
//       // Use 65.0 as the base height for minute scaling to match item height
//       final basePosition =
//           hourPositions[hour]! +
//           (minute / 60.0) * 65.0; // Adjusted minute scaling

//       for (int i = 0; i < items.length; i++) {
//         final itemData = items[i];
//         final itemType = itemData['type'];
//         final item = itemData['item'];

//         // Calculate the top position for this item (stack vertically with proper spacing)
//         final itemTopPosition =
//             basePosition + (i * 70.0); // 55px item + 10px spacing

//         // Add widget based on type
//         if (itemType == 'event') {
//           allWidgets.add(
//             _buildEventItem(
//               item,
//               basePosition: itemTopPosition,
//               width: baseItemWidth,
//               height: 65.0, // Fixed height
//               leftOffset: 0.0,
//             ),
//           );
//         } else if (itemType == 'task') {
//           allWidgets.add(
//             _buildTaskItem(
//               item,
//               basePosition: itemTopPosition,
//               width: baseItemWidth,
//               height: 65.0, // Fixed height
//               leftOffset: 0.0,
//             ),
//           );
//         }
//       }
//     }

//     return allWidgets;
//   }

//   Widget _buildEventItem(
//     dynamic item, {
//     double basePosition = 0.0,
//     double width = 200.0,
//     double height = 55.0,
//     double widthFactor = 1.0,
//     double leftOffset = 0.0,
//   }) {
//     String leadId = item['lead_id']?.toString() ?? '';
//     String formattedStartTime = _formatTimeFor12Hour(
//       item['start_time'] ?? '00:00',
//     );
//     String formattedEndTime = _formatTimeFor12Hour(item['end_time'] ?? '00:00');

//     String name = item['name'] ?? 'No Name';
//     String category = item['category'] ?? 'Appointment';
//     String timeRange = '$formattedStartTime - $formattedEndTime';

//     return Positioned(
//       top: basePosition,
//       left: 12 + (leftOffset * (MediaQuery.of(context).size.width * 0.75 - 24)),
//       child: Container(
//         width: width * widthFactor,
//         height: height,
//         margin: const EdgeInsets.only(bottom: 5, right: 8),
//         decoration: BoxDecoration(
//           color: AppColors.colorsBlue.withOpacity(.09),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.08),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(
//             color: AppColors.colorsBlue.withOpacity(0.2),
//             width: 0.5,
//           ),
//         ),
//         child: InkWell(
//           onTap: () {
//             print('Navigating with leadId: $leadId');
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => FollowupsDetails(
//                   leadId: leadId,
//                   isFromFreshlead: false,
//                   isFromManager: false,
//                   isFromTestdriveOverview: false,
//                   refreshDashboard: () async {},
//                 ),
//               ),
//             );
//           },
//           borderRadius: BorderRadius.circular(8),
//           child: Container(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 12.0,
//               vertical: 8.0,
//             ),
//             decoration: BoxDecoration(
//               border: Border(
//                 left: BorderSide(color: AppColors.colorsBlue, width: 4),
//               ),
//               borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(8),
//                 bottomLeft: Radius.circular(8),
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   name,
//                   style: AppFont.dropDowmLabel(context),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         category,
//                         style: AppFont.dashboardCarName(context),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     Text(
//                       timeRange,
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.grey.shade600,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTaskItem(
//     dynamic item, {
//     double basePosition = 0.0,
//     double width = 200.0,
//     double height = 55.0,
//     double widthFactor = 1.0,
//     double leftOffset = 0.0,
//   }) {
//     String leadId = item['lead_id']?.toString() ?? '';
//     String formattedDueTime = _formatTimeFor12Hour(item['due_date'] ?? '00:00');
//     String title = 'Task: ${item['subject'] ?? 'No Subject'}';
//     String status = item['status'] ?? 'Unknown';
//     String category = item['category'] ?? 'Normal';
//     String timeInfo = formattedDueTime.isNotEmpty ? formattedDueTime : '';

//     return Positioned(
//       top: basePosition,
//       left: 12 + (leftOffset * (MediaQuery.of(context).size.width * 0.75 - 24)),
//       child: Container(
//         width: width * widthFactor,
//         height: height,
//         margin: const EdgeInsets.only(bottom: 5, right: 8),
//         decoration: BoxDecoration(
//           color: Colors.purple.withOpacity(.09),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.08),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.purple.withOpacity(0.2), width: 0.5),
//         ),
//         child: InkWell(
//           onTap: () {
//             print('Navigating with leadId: $leadId');
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => FollowupsDetails(
//                   leadId: leadId,
//                   isFromFreshlead: false,
//                   isFromManager: true,
//                   isFromTestdriveOverview: false,
//                   refreshDashboard: () async {},
//                 ),
//               ),
//             );
//           },
//           borderRadius: BorderRadius.circular(8),
//           child: Container(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 12.0,
//               vertical: 8.0,
//             ),
//             decoration: BoxDecoration(
//               border: Border(left: BorderSide(color: Colors.purple, width: 4)),
//               borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(8),
//                 bottomLeft: Radius.circular(8),
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   title,
//                   style: AppFont.dropDowmLabel(context),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         category,
//                         style: AppFont.dashboardCarName(context),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     if (timeInfo.isNotEmpty)
//                       Text(
//                         timeInfo,
//                         style: TextStyle(
//                           fontSize: 10,
//                           color: Colors.grey.shade600,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   DateTime _parseTimeString(String timeStr) {
//     // If timeStr is null or empty, return a default time
//     if (timeStr.isEmpty) {
//       return DateTime(2022, 1, 1, 0, 0); // Default time (midnight)
//     }

//     // Handle both 12-hour and 24-hour time formats
//     bool isPM = timeStr.toLowerCase().contains('pm');
//     bool isAM = timeStr.toLowerCase().contains('am');

//     // Remove AM/PM indicator for parsing
//     String cleanTime = timeStr
//         .toLowerCase()
//         .replaceAll('am', '')
//         .replaceAll('pm', '')
//         .replaceAll(' ', '')
//         .trim();

//     final parts = cleanTime.split(':');
//     if (parts.length < 2)
//       return DateTime(2022, 1, 1, 0, 0); // Invalid time format fallback

//     try {
//       int hour = int.parse(parts[0]);
//       final minute = int.parse(parts[1]);

//       // Convert 12-hour format to 24-hour if needed
//       if (isPM && hour < 12) {
//         hour += 12; // Add 12 to PM hours except 12 PM
//       } else if (isAM && hour == 12) {
//         hour = 0; // 12 AM is 0 in 24-hour format
//       }

//       return DateTime(2022, 1, 1, hour, minute);
//     } catch (e) {
//       print("Error parsing time: $timeStr - $e");
//       return DateTime(2022, 1, 1, 0, 0); // Default to midnight if parsing fails
//     }
//   }

//   // Format time to 12-hour format with AM/PM for display consistency
//   String _formatTimeFor12Hour(String timeStr) {
//     if (timeStr.isEmpty || !timeStr.contains(':')) {
//       return timeStr; // Return unchanged if not in time format
//     }

//     // Parse the time first to normalize it
//     DateTime parsedTime = _parseTimeString(timeStr);

//     // Format to 12-hour time
//     String period = parsedTime.hour >= 12 ? 'PM' : 'AM';
//     int hour12 = parsedTime.hour > 12
//         ? parsedTime.hour - 12
//         : (parsedTime.hour == 0 ? 12 : parsedTime.hour);

//     return '${hour12}:${parsedTime.minute.toString().padLeft(2, '0')} $period';
//   }
// }
 