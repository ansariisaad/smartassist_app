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

  Map<String, bool> _expandedSlots = {};

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
        'https://api.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
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
        "https://api.smartassistapp.in/api/calendar/activities/all/asondate",
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
      _expandedSlots.clear();
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
      _expandedSlots.clear();
    });
    await _fetchActivitiesData();
  }

  void _handleTeamMemberSelection(int index, String userId) async {
    setState(() {
      _selectedProfileIndex = index;
      _selectedUserId = userId;
      _selectedType = 'team';
      _isLoading = true;
      _expandedSlots.clear();
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

        final events = items
            .where((item) => item['start_time'] != null)
            .toList();
        final tasks = items
            .where((item) => item['start_time'] == null)
            .toList();

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
                        ...displayItems.map((item) {
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
                        }).toList(),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3.0,
                                ),
                                child: Text(
                                  "Show More (${allItems.length - 2} more) ▼",
                                  style: TextStyle(
                                    color: const Color.fromRGBO(
                                      117,
                                      117,
                                      117,
                                      1,
                                    ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3.0,
                                ),
                                child: Text(
                                  "Show Less ▲",
                                  style: TextStyle(
                                    color: const Color.fromRGBO(
                                      117,
                                      117,
                                      117,
                                      1,
                                    ),
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
    );
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

  Widget _buildEventTab(dynamic item) {
    String leadId = item['lead_id']?.toString() ?? '';
    String clientName = item['name'] ?? 'No Name';
    String carName = item['PMI'] ?? 'No Car';
    String category = item['subject'] ?? 'Appointment';

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
        margin: EdgeInsets.only(bottom: 4),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF0F3FA), // Slightly blue-grey, similar to image
          border: Border.all(
            color: Colors.black, // Black border
            width: 0.3, // Thin border as per request
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name (BOLD)
            Text(
              clientName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600, // Bold
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            // Car/PMI (Regular)
            Text(
              carName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            // Category (Regular)
            Text(
              category,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTab(dynamic item) {
    String leadId = item['lead_id']?.toString() ?? '';
    String clientName = item['name'] ?? 'No Name';
    String carName = item['PMI'] ?? 'No Car';
    String category = item['subject'] ?? 'Task';

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
        margin: EdgeInsets.only(bottom: 4),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF0F3FA), // Same as above for consistency
          border: Border.all(color: Colors.black, width: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name (BOLD)
            Text(
              clientName,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            // Car/PMI (Regular)
            Text(
              carName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            // Category (Regular)
            Text(
              category,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

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
//   String _selectedType = 'your';
//   String? _selectedLetter;

//   DateTime _focusedDay = DateTime.now();
//   CalendarFormat _calendarFormat = CalendarFormat.week;
//   bool _isMonthView = false;
//   List<dynamic> tasks = [];
//   List<dynamic> events = [];
//   DateTime? _selectedDay;
//   bool _isLoading = false;
//   ScrollController _timelineScrollController = ScrollController();

//   Set<int> _activeHours = {};
//   Map<String, List<dynamic>> _timeSlotItems = {};

//   Map<String, bool> _expandedSlots = {};

//   @override
//   void initState() {
//     super.initState();
//     _selectedDay = _focusedDay;
//     _fetchTeamDetails();
//     _fetchActivitiesData();
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
//     final currentHour = DateTime.now().hour;
//     double scrollPosition = currentHour * 80.0;
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
//         'https://api.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
//       );
//       final response = await http.get(
//         baseUri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );
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
//       }
//     } catch (e) {
//       print('Error fetching team details: $e');
//     }
//   }

//   Future<void> _fetchActivitiesData() async {
//     if (mounted) setState(() => _isLoading = true);
//     try {
//       final token = await Storage.getToken();
//       String formattedDate = DateFormat(
//         'dd-MM-yyyy',
//       ).format(_selectedDay ?? _focusedDay);

//       final Map<String, String> queryParams = {'date': formattedDate};
//       if (_selectedType == 'team' && _selectedUserId.isNotEmpty) {
//         queryParams['user_id'] = _selectedUserId;
//       }
//       final baseUrl = Uri.parse(
//         "https://api.smartassistapp.in/api/calendar/activities/all/asondate",
//       );
//       final uri = baseUrl.replace(queryParameters: queryParams);
//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         setState(() {
//           tasks = data['data']['tasks'] ?? [];
//           events = data['data']['events'] ?? [];
//           _isLoading = false;
//         });
//         _processTimeSlots();
//       } else {
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       print("Error fetching activities data: $e");
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _processTimeSlots() {
//     _activeHours.clear();
//     _timeSlotItems.clear();
//     for (var item in [...events, ...tasks]) {
//       String? timeRaw = item['start_time'] ?? item['time'] ?? item['due_date'];
//       if (timeRaw == null || timeRaw.toString().isEmpty) timeRaw = "09:00";
//       final itemTime = _parseTimeString(timeRaw);
//       final hour = itemTime.hour;
//       _activeHours.add(hour);
//       final timeKey = '${hour.toString().padLeft(2, '0')}:00';
//       if (!_timeSlotItems.containsKey(timeKey)) _timeSlotItems[timeKey] = [];
//       _timeSlotItems[timeKey]!.add(item);
//     }
//     if (_activeHours.isEmpty) {
//       if (_isSameDay(_selectedDay ?? _focusedDay, DateTime.now())) {
//         _activeHours.add(DateTime.now().hour);
//       } else {
//         _activeHours.add(9);
//       }
//     }
//   }

//   bool _isSameDay(DateTime a, DateTime b) =>
//       a.year == b.year && a.month == b.month && a.day == b.day;

//   void _handleDateSelected(DateTime selectedDate) {
//     setState(() {
//       _selectedDay = selectedDate;
//       _focusedDay = selectedDate;
//       tasks = [];
//       events = [];
//       _activeHours.clear();
//       _timeSlotItems.clear();
//       _isLoading = true;
//       _expandedSlots.clear();
//     });
//     _fetchActivitiesData();
//   }

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
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             CalenderWidget(
//               key: ValueKey(_calendarFormat),
//               calendarFormat: _calendarFormat,
//               onDateSelected: _handleDateSelected,
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               width: double.infinity,
//               child: Text(
//                 DateFormat('EEEE, MMMM d').format(_selectedDay ?? _focusedDay),
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             _buildTimelineView(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTimelineView() {
//     if (_isLoading) {
//       return const Center(
//         child: Padding(
//           padding: EdgeInsets.all(48.0),
//           child: CircularProgressIndicator(color: AppColors.colorsBlue),
//         ),
//       );
//     }
//     final activeTimeSlots = _timeSlotItems.keys.toList()..sort();
//     if (activeTimeSlots.isEmpty) {
//       return _emptyState('No scheduled activities for this date');
//     }

//     return ListView.separated(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       itemCount: activeTimeSlots.length,
//       separatorBuilder: (_, __) => Divider(
//         height: 1,
//         color: Colors.grey.shade300,
//         thickness: 1,
//         indent: 8,
//         endIndent: 8,
//       ),
//       itemBuilder: (context, index) {
//         final timeKey = activeTimeSlots[index];
//         final items = _timeSlotItems[timeKey] ?? [];
//         final events = items
//             .where((item) => item['start_time'] != null)
//             .toList();
//         final tasks = items
//             .where((item) => item['start_time'] == null)
//             .toList();
//         List<dynamic> allItems = [];
//         allItems.addAll(events);
//         allItems.addAll(tasks);
//         bool isExpanded = _expandedSlots[timeKey] ?? false;
//         int showCount = isExpanded ? allItems.length : 2;
//         bool showMore = allItems.length > 2;
//         List<dynamic> displayItems = allItems.take(showCount).toList();

//         return Padding(
//           padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(
//                     width: 64,
//                     child: Text(
//                       timeKey,
//                       style: TextStyle(
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 15,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 4),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         ...displayItems
//                             .map(
//                               (item) => Padding(
//                                 padding: const EdgeInsets.only(bottom: 8.0),
//                                 child: _buildTaskCard(item),
//                               ),
//                             )
//                             .toList(),
//                         if (showMore && !isExpanded)
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   _expandedSlots[timeKey] = true;
//                                 });
//                               },
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 3.0,
//                                 ),
//                                 child: Text(
//                                   "Show More (${allItems.length - 2} more) ▼",
//                                   style: TextStyle(
//                                     color: const Color.fromRGBO(
//                                       117,
//                                       117,
//                                       117,
//                                       1,
//                                     ),
//                                     fontSize: 13.5,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         if (showMore && isExpanded)
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   _expandedSlots[timeKey] = false;
//                                 });
//                               },
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 3.0,
//                                 ),
//                                 child: Text(
//                                   "Show Less ▲",
//                                   style: TextStyle(
//                                     color: const Color.fromRGBO(
//                                       117,
//                                       117,
//                                       117,
//                                       1,
//                                     ),
//                                     fontSize: 13.5,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // --- COLOR LOGIC ---

//   Color getTaskCardColor(String category) {
//     final c = category.toLowerCase();
//     if (c.contains('test drive')) {
//       return Color(0xFF4A90E2).withOpacity(0.13); // mid blue
//     }
//     if (c.contains('call') ||
//         c.contains('quotation') ||
//         c.contains('show') ||
//         c.contains('appointment') ||
//         c.contains('enquiry') ||
//         c.contains('follow up') ||
//         c.contains('followup')) {
//       return Color(0xFFF865AB).withOpacity(0.16); // mid pink
//     }
//     return Color(0xFFF0F3FA); // default
//   }

//   Widget _buildTaskCard(dynamic item) {
//     String leadId = item['lead_id']?.toString() ?? '';
//     String clientName = item['name'] ?? 'No Name';
//     String carName = item['PMI'] ?? 'No Car';
//     String category = item['subject'] ?? 'Appointment';

//     return InkWell(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => FollowupsDetails(
//               leadId: leadId,
//               isFromFreshlead: false,
//               isFromManager: item['start_time'] == null,
//               isFromTestdriveOverview: false,
//               refreshDashboard: () async {},
//             ),
//           ),
//         );
//       },
//       child: Container(
//         width: double.infinity,
//         decoration: BoxDecoration(
//           color: getTaskCardColor(category),
//           border: Border.all(color: Colors.black, width: 0.3),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Name (BOLD)
//             Text(
//               clientName,
//               style: GoogleFonts.poppins(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//             SizedBox(height: 2),
//             // Car/PMI (REGULAR)
//             Text(
//               carName,
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.normal,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//             SizedBox(height: 2),
//             // Category (REGULAR)
//             Text(
//               category,
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.normal,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _emptyState(String msg) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 40),
//       child: Column(
//         children: [
//           Image.asset(
//             'assets/calendar.png',
//             width: 50,
//             height: 50,
//             color: const Color.fromRGBO(117, 117, 117, 1),
//           ),
//           SizedBox(height: 12),
//           Text(
//             msg,
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 15,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   DateTime _parseTimeString(String timeStr) {
//     if (timeStr.isEmpty) {
//       return DateTime(2022, 1, 1, 0, 0);
//     }
//     bool isPM = timeStr.toLowerCase().contains('pm');
//     bool isAM = timeStr.toLowerCase().contains('am');
//     String cleanTime = timeStr
//         .toLowerCase()
//         .replaceAll('am', '')
//         .replaceAll('pm', '')
//         .replaceAll(' ', '')
//         .trim();
//     final parts = cleanTime.split(':');
//     if (parts.length < 2) return DateTime(2022, 1, 1, 0, 0);
//     try {
//       int hour = int.parse(parts[0]);
//       final minute = int.parse(parts[1]);
//       if (isPM && hour < 12) {
//         hour += 12;
//       } else if (isAM && hour == 12) {
//         hour = 0;
//       }
//       return DateTime(2022, 1, 1, hour, minute);
//     } catch (e) {
//       return DateTime(2022, 1, 1, 0, 0);
//     }
//   }
// }






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
//   String _selectedType = 'your';
//   String? _selectedLetter;

//   DateTime _focusedDay = DateTime.now();
//   CalendarFormat _calendarFormat = CalendarFormat.week;
//   bool _isMonthView = false;
//   List<dynamic> tasks = [];
//   List<dynamic> events = [];
//   DateTime? _selectedDay;
//   bool _isLoading = false;
//   ScrollController _timelineScrollController = ScrollController();

//   Set<int> _activeHours = {};
//   Map<String, List<dynamic>> _timeSlotItems = {};

//   Map<String, bool> _expandedSlots = {};

//   @override
//   void initState() {
//     super.initState();
//     _selectedDay = _focusedDay;
//     _fetchTeamDetails();
//     _fetchActivitiesData();
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
//     final currentHour = DateTime.now().hour;
//     double scrollPosition = currentHour * 80.0;
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
//         'https://api.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
//       );
//       final response = await http.get(
//         baseUri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );
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
//       }
//     } catch (e) {
//       print('Error fetching team details: $e');
//     }
//   }

//   Future<void> _fetchActivitiesData() async {
//     if (mounted) setState(() => _isLoading = true);
//     try {
//       final token = await Storage.getToken();
//       String formattedDate = DateFormat(
//         'dd-MM-yyyy',
//       ).format(_selectedDay ?? _focusedDay);

//       final Map<String, String> queryParams = {'date': formattedDate};
//       if (_selectedType == 'team' && _selectedUserId.isNotEmpty) {
//         queryParams['user_id'] = _selectedUserId;
//       }
//       final baseUrl = Uri.parse(
//         "https://api.smartassistapp.in/api/calendar/activities/all/asondate",
//       );
//       final uri = baseUrl.replace(queryParameters: queryParams);
//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         setState(() {
//           tasks = data['data']['tasks'] ?? [];
//           events = data['data']['events'] ?? [];
//           _isLoading = false;
//         });
//         _processTimeSlots();
//       } else {
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       print("Error fetching activities data: $e");
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _processTimeSlots() {
//     _activeHours.clear();
//     _timeSlotItems.clear();
//     for (var item in [...events, ...tasks]) {
//       String? timeRaw = item['start_time'] ?? item['time'] ?? item['due_date'];
//       if (timeRaw == null || timeRaw.toString().isEmpty) timeRaw = "09:00";
//       final itemTime = _parseTimeString(timeRaw);
//       final hour = itemTime.hour;
//       _activeHours.add(hour);
//       final timeKey = '${hour.toString().padLeft(2, '0')}:00';
//       if (!_timeSlotItems.containsKey(timeKey)) _timeSlotItems[timeKey] = [];
//       _timeSlotItems[timeKey]!.add(item);
//     }
//     if (_activeHours.isEmpty) {
//       if (_isSameDay(_selectedDay ?? _focusedDay, DateTime.now())) {
//         _activeHours.add(DateTime.now().hour);
//       } else {
//         _activeHours.add(9);
//       }
//     }
//   }

//   bool _isSameDay(DateTime a, DateTime b) =>
//       a.year == b.year && a.month == b.month && a.day == b.day;

//   void _handleDateSelected(DateTime selectedDate) {
//     setState(() {
//       _selectedDay = selectedDate;
//       _focusedDay = selectedDate;
//       tasks = [];
//       events = [];
//       _activeHours.clear();
//       _timeSlotItems.clear();
//       _isLoading = true;
//       _expandedSlots.clear();
//     });
//     _fetchActivitiesData();
//   }

//   void _handleTeamYourSelection(String type) async {
//     setState(() {
//       _selectedType = type;
//       if (type == 'your') {
//         _selectedProfileIndex = 0;
//         _selectedUserId = '';
//       }
//       _isLoading = true;
//       _expandedSlots.clear();
//     });
//     await _fetchActivitiesData();
//   }

//   void _handleTeamMemberSelection(int index, String userId) async {
//     setState(() {
//       _selectedProfileIndex = index;
//       _selectedUserId = userId;
//       _selectedType = 'team';
//       _isLoading = true;
//       _expandedSlots.clear();
//     });
//     await _fetchActivitiesData();
//   }

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
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             _buildTeamYourButtons(),
//             if (_selectedType == 'team') _buildProfileAvatars(),
//             CalenderWidget(
//               key: ValueKey(_calendarFormat),
//               calendarFormat: _calendarFormat,
//               onDateSelected: _handleDateSelected,
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               width: double.infinity,
//               child: Text(
//                 DateFormat('EEEE, MMMM d').format(_selectedDay ?? _focusedDay),
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             _buildTimelineView(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTimelineView() {
//     if (_isLoading) {
//       return const Center(
//         child: Padding(
//           padding: EdgeInsets.all(48.0),
//           child: CircularProgressIndicator(color: AppColors.colorsBlue),
//         ),
//       );
//     }
//     if (_selectedType == 'team' && _selectedUserId.isEmpty) {
//       return _emptyState('Select a PS to view their schedule');
//     }

//     final activeTimeSlots = _timeSlotItems.keys.toList()..sort();

//     if (activeTimeSlots.isEmpty) {
//       return _emptyState('No scheduled activities for this date');
//     }

//     return ListView.separated(
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       itemCount: activeTimeSlots.length,
//       separatorBuilder: (_, __) => Divider(
//         height: 1,
//         color: Colors.grey.shade300,
//         thickness: 1,
//         indent: 8,
//         endIndent: 8,
//       ),
//       itemBuilder: (context, index) {
//         final timeKey = activeTimeSlots[index];
//         final items = _timeSlotItems[timeKey] ?? [];

//         final events = items.where((item) => item['start_time'] != null).toList();
//         final tasks = items.where((item) => item['start_time'] == null).toList();

//         List<dynamic> allItems = [];
//         allItems.addAll(events);
//         allItems.addAll(tasks);

//         bool isExpanded = _expandedSlots[timeKey] ?? false;
//         int showCount = isExpanded ? allItems.length : 2;
//         bool showMore = allItems.length > 2;

//         List<dynamic> displayItems = allItems.take(showCount).toList();

//         return Padding(
//           padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(
//                     width: 64,
//                     child: Text(
//                       timeKey,
//                       style: TextStyle(
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 15,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 4),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         ...displayItems.map(
//                           (item) {
//                             if (item['start_time'] != null) {
//                               return Padding(
//                                 padding: const EdgeInsets.only(bottom: 8.0),
//                                 child: _buildColoredTaskCard(item, isTask: false),
//                               );
//                             } else {
//                               return Padding(
//                                 padding: const EdgeInsets.only(bottom: 8.0),
//                                 child: _buildColoredTaskCard(item, isTask: true),
//                               );
//                             }
//                           },
//                         ).toList(),
//                         if (showMore && !isExpanded)
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   _expandedSlots[timeKey] = true;
//                                 });
//                               },
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(vertical: 3.0),
//                                 child: Text(
//                                   "Show More (${allItems.length - 2} more) ▼",
//                                   style: TextStyle(
//                                     color:  const Color.fromRGBO(117, 117, 117, 1),
//                                     fontSize: 13.5,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         if (showMore && isExpanded)
//                           Align(
//                             alignment: Alignment.centerRight,
//                             child: GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   _expandedSlots[timeKey] = false;
//                                 });
//                               },
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(vertical: 3.0),
//                                 child: Text(
//                                   "Show Less ▲",
//                                   style: TextStyle(
//                                     color: const Color.fromRGBO(117, 117, 117, 1),
//                                     fontSize: 13.5,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // Color logic for card types
//   Widget _buildColoredTaskCard(dynamic item, {required bool isTask}) {
//     String leadId = item['lead_id']?.toString() ?? '';
//     String clientName = item['name'] ?? 'No Name';
//     String carName = item['PMI'] ?? 'No Car';
//     String category = item['subject'] ?? (isTask ? 'Task' : 'Appointment');

//     // Categories that should be pink
//     final pinkCats = ['call', 'appointment', 'enquiry', 'followup', 'quotation'];
//     final blueCats = ['test drive', 'testdrive', 'test_drive'];

//     Color cardColor;
//     if (category.toLowerCase().contains('test') && category.toLowerCase().contains('drive')) {
//       cardColor = Color(0xFFE3ECFF); // Light blue
//     } else if (pinkCats.any((cat) => category.toLowerCase().contains(cat))) {
//       cardColor = Color(0xFFFFE2F3); // Light pink
//     } else {
//       cardColor = Color(0xFFF0F3FA); // Default
//     }

//     return InkWell(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => FollowupsDetails(
//               leadId: leadId,
//               isFromFreshlead: false,
//               isFromManager: isTask,
//               isFromTestdriveOverview: false,
//               refreshDashboard: () async {},
//             ),
//           ),
//         );
//       },
//       child: Container(
//         margin: EdgeInsets.only(bottom: 4),
//         width: double.infinity,
//         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         decoration: BoxDecoration(
//           color: cardColor,
//           border: Border.all(
//             color: Colors.black,
//             width: 0.3,
//           ),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               clientName,
//               style: GoogleFonts.poppins(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//             SizedBox(height: 2),
//             Text(
//               carName,
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.normal,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//             SizedBox(height: 2),
//             Text(
//               category,
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.normal,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ---- Team/Profile logic ---- (unchanged from before)
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
//                       color: AppColors.fontColor,
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
//                       color: AppColors.fontColor,
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

//   Widget _buildProfileAvatars() {
//     List<Map<String, dynamic>> sortedTeamMembers = List.from(_teamMembers);
//     sortedTeamMembers.sort(
//       (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
//         (b['fname'] ?? '').toString().toLowerCase(),
//       ),
//     );
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
//             ...sortedLetters.expand(
//               (letter) => _buildLetterWithMembers(letter),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   List<Widget> _buildLetterWithMembers(String letter) {
//     List<Widget> widgets = [];
//     bool isSelected = _selectedLetter == letter;

//     widgets.add(_buildAlphabetAvatar(letter));
//     if (isSelected) {
//       List<Map<String, dynamic>> letterMembers = _teamMembers.where((member) {
//         String firstName = (member['fname'] ?? '').toString().toUpperCase();
//         return firstName.startsWith(letter);
//       }).toList();

//       letterMembers.sort(
//         (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
//           (b['fname'] ?? '').toString().toLowerCase(),
//         ),
//       );

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

//   Widget _buildAlphabetAvatar(String letter) {
//     bool isSelected = _selectedLetter == letter;
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         InkWell(
//           onTap: () {
//             setState(() {
//               if (_selectedLetter == letter) {
//                 _selectedLetter = null;
//               } else {
//                 _selectedLetter = letter;
//               }
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
//               color: Colors.grey.withOpacity(0.1),
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

//   Widget _emptyState(String msg) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 40),
//       child: Column(
//         children: [
//           Icon(
//             Icons.calendar_today_outlined,
//             color: Colors.grey.shade400,
//             size: 50,
//           ),
//           SizedBox(height: 12),
//           Text(
//             msg,
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 15,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   DateTime _parseTimeString(String timeStr) {
//     if (timeStr.isEmpty) {
//       return DateTime(2022, 1, 1, 0, 0);
//     }
//     bool isPM = timeStr.toLowerCase().contains('pm');
//     bool isAM = timeStr.toLowerCase().contains('am');
//     String cleanTime = timeStr
//         .toLowerCase()
//         .replaceAll('am', '')
//         .replaceAll('pm', '')
//         .replaceAll(' ', '')
//         .trim();
//     final parts = cleanTime.split(':');
//     if (parts.length < 2) return DateTime(2022, 1, 1, 0, 0);
//     try {
//       int hour = int.parse(parts[0]);
//       final minute = int.parse(parts[1]);
//       if (isPM && hour < 12) {
//         hour += 12;
//       } else if (isAM && hour == 12) {
//         hour = 0;
//       }
//       return DateTime(2022, 1, 1, hour, minute);
//     } catch (e) {
//       return DateTime(2022, 1, 1, 0, 0);
//     }
//   }

//   String _formatTimeFor12Hour(String timeStr) {
//     if (timeStr.isEmpty || !timeStr.contains(':')) {
//       return timeStr;
//     }
//     DateTime parsedTime = _parseTimeString(timeStr);
//     String period = parsedTime.hour >= 12 ? 'PM' : 'AM';
//     int hour12 = parsedTime.hour > 12
//         ? parsedTime.hour - 12
//         : (parsedTime.hour == 0 ? 12 : parsedTime.hour);
//     return '${hour12}:${parsedTime.minute.toString().padLeft(2, '0')} $period';
//   }
// }