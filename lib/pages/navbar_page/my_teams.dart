import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/config/controller/tab_controller.dart';
import 'package:smartassist/config/getX/fab.controller.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/pages/Home/single_details_pages/teams_enquiryIds.dart';
import 'package:smartassist/pages/navbar_page/call_analytics.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/team_calllog_userid.dart';

class MyTeams extends StatefulWidget {
  const MyTeams({Key? key}) : super(key: key);

  @override
  State<MyTeams> createState() => _MyTeamsState();
}

class _MyTeamsState extends State<MyTeams> {
  // ADD THESE VARIABLES TO YOUR CLASS
  int _currentDisplayCount = 10; // Initially show 10 records
  static const int _incrementCount = 10; // Show 10 more each time
  static const int _decrementCount = 10;
  List<dynamic> _teamComparisonData = [];
  // Your existing variables
  // List<dynamic> _membersData = []; // Your existing data list

  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;
  String _selectedLetter = '';
  List<Map<String, dynamic>> _filteredByLetter = [];

  int _tabIndex = 0; // 0 for Individual Performance, 1 for Team Comparison
  int _periodIndex = 0; // ALL, MTD, QTD, YTD
  int _metricIndex = 0; // Selected metric for comparison
  int _selectedProfileIndex = 0; // Default to 'All' profile
  String _selectedUserId = '';
  bool _isComparing = false;
  int overdueCount = 0;
  String selectedTimeRange = '1D';
  // String userId = '';
  bool isLoading = false;
  // String _selectedCheckboxIds = '';
  String _selectedType = 'All';
  Map<String, dynamic> _individualPerformanceData = {};
  Set<String> _selectedCheckboxIds = {};
  List<Map<String, dynamic>> selectedItems = [];
  Set<String> selectedUserIds = {};
  late TabControllerNew _tabController;
  Set<String> _selectedLetters = {};
  bool _isMultiSelectMode = false;
  int _upcommingButtonIndex = 0;
  String? _sortColumn;
  List<dynamic> _originalMembersData = [];
  int _sortState = 0;

  bool isHideAllcall = false;
  bool isHideActivities = false;
  bool isHide = false;
  bool isHideCalls = false;
  bool isSingleCall = false;
  bool isHideCheckbox = false;
  // Data state
  // bool isLoading = false;
  Map<String, dynamic> _teamData = {};
  Map<String, dynamic>? _selectedUserData = {};
  List<Map<String, dynamic>> _teamMembers = [];

  // call log all
  Map<String, dynamic> _analyticsData = {};
  List<Map<String, dynamic>> _membersData = [];

  // Activity lists
  List<Map<String, dynamic>> _upcomingFollowups = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _upcomingTestDrives = [];

  //singleuserid call log
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _enquiryData;
  Map<String, dynamic>? _coldCallData;

  bool get _isOnlyLetterSelected =>
      _selectedLetters.isNotEmpty &&
      _selectedProfileIndex == -1 &&
      _selectedUserId.isEmpty;

  // Controller for FAB
  final FabController fabController = Get.put(FabController());
  final GlobalKey incomingKey = GlobalKey();
  final GlobalKey outgoingKey = GlobalKey();
  final GlobalKey connectedKey = GlobalKey();
  final GlobalKey durationKey = GlobalKey();
  final GlobalKey rejectedKey = GlobalKey();
  final GlobalKey enquiries = GlobalKey();
  final GlobalKey tDrives = GlobalKey();
  final GlobalKey orders = GlobalKey();
  final GlobalKey cancel = GlobalKey();
  final GlobalKey net_orders = GlobalKey();
  final GlobalKey retails = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isFabVisible) {
          setState(() => _isFabVisible = false);
        }
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!_isFabVisible) {
          setState(() => _isFabVisible = true);
        }
      }
    });
    _tabController = TabControllerNew();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch team data using the new consolidated API
      await _fetchTeamDetails();
      await _fetchAllCalllog();
      // _prepareTeamMembersForAzList();
      // await _fetchSingleCalllog();
    } catch (error) {
      print("Error during initialization: $error");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Method to load more records
  void _loadMoreRecords() {
    setState(() {
      // Get the current data that's being displayed
      List<dynamic> dataToDisplay;

      if (_isComparing &&
          selectedUserIds.isNotEmpty &&
          _teamComparisonData.isNotEmpty) {
        dataToDisplay = _teamComparisonData;
      } else if (_isComparing && selectedUserIds.isNotEmpty) {
        dataToDisplay = _membersData.where((member) {
          return selectedUserIds.contains(member['user_id'].toString());
        }).toList();
      } else {
        dataToDisplay = _membersData;
      }

      // Update display count based on the actual data being shown
      _currentDisplayCount = math.min(
        _currentDisplayCount + _incrementCount,
        dataToDisplay.length,
      );
    });
  }

  void _loadLessRecords() {
    setState(() {
      _currentDisplayCount = math.max(
        _incrementCount,
        _currentDisplayCount - _incrementCount,
      );
    });
  }

  void showBubbleTooltip(BuildContext context, GlobalKey key, String message) {
    final overlay = Overlay.of(context);
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size;
    final offset = renderBox?.localToGlobal(Offset.zero);

    if (overlay == null || renderBox == null || offset == null || size == null)
      return;

    // Estimate the tooltip width (you could also use TextPainter for precise width if needed)
    const double tooltipPadding = 20.0;
    final double estimatedTooltipWidth = message.length * 7.0 + tooltipPadding;

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy - 35, // above the icon
        left:
            offset.dx +
            size.width / 2 -
            estimatedTooltipWidth / 2, // centered horizontally
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(milliseconds: 1000), () {
      overlayEntry.remove();
    });
  }

  // Method to check if there are more records to show
  bool _hasMoreRecords() {
    return _currentDisplayCount < _membersData.length;
  }

  bool _hasMoreRecordsTeams(List<dynamic> currentList) {
    return _currentDisplayCount < currentList.length;
  }

  Future<void> _fetchSingleCalllog() async {
    try {
      setState(() {
        isLoading = true;
      });

      final token = await Storage.getToken();

      String periodParam = '';
      switch (selectedTimeRange) {
        case '1D':
          periodParam = 'DAY'; // REMOVE the '?type=' part
          break;
        case '1W':
          periodParam = 'WEEK';
          break;
        case '1M':
          periodParam = 'MTD';
          break;
        case '1Q':
          periodParam = 'QTD';
          break;
        case '1Y':
          periodParam = 'YTD';
          break;
        default:
          periodParam = 'DAY';
      }

      final Map<String, String> queryParams = {
        'type': periodParam, // CHANGE THIS LINE
      };

      // Add userId to query parameters if it's available
      if (_selectedUserId.isNotEmpty) {
        queryParams['user_id'] = _selectedUserId;
      }

      final baseUri = Uri.parse(
        'https://api.smartassistapp.in/api/users/ps/dashboard/call-analytics',
      );

      final uri = baseUri.replace(queryParameters: queryParams);

      print('📤 Fetching call analytics from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Call Analytics Status Code: ${response.statusCode}');
      print('📥 Call Analytics Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (mounted) {
          setState(() {
            _dashboardData = jsonData['data'];
            _enquiryData = jsonData['data']['summaryEnquiry'];
            _coldCallData = jsonData['data']['summaryColdCalls'];
            isLoading = false;
          });
        }
      } else {
        throw Exception(
          'Failed to load dashboard data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      debugPrint('Error fetching data: $e');
    }
  }

  Future<void> _fetchAllCalllog() async {
    setState(() {
      isLoading = true;
    });

    try {
      final token = await Storage.getToken();
      // Build period parameter
      String? periodParam;
      switch (_periodIndex) {
        case 1:
          periodParam = 'MTD';
          break;
        case 0:
          periodParam = 'QTD';
          break;
        case 2:
          periodParam = 'YTD';
          break;
        default:
          periodParam = 'QTD';
      }

      final Map<String, String> queryParams = {};
      if (periodParam != null) {
        queryParams['type'] = periodParam;
      }

      final baseUri = Uri.parse(
        'https://api.smartassistapp.in/api/users/sm/dashboard/call-analytics',
      );

      final uri = baseUri.replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        setState(() {
          _analyticsData = responseData['data'];
          _membersData = List<Map<String, dynamic>>.from(
            responseData['data']['members'],
          );
          isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to fetch call analytics: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching call analytics: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Create a helper method to properly clear all selections
  void _clearAllSelections() {
    setState(() {
      // Clear tracking lists
      selectedUserIds.clear();
      _selectedCheckboxIds.clear();
      _selectedProfileIndex = -1;
      _selectedUserId = '';

      // 🔥 IMPORTANT: Clear isSelected from all member objects
      for (var member in _membersData) {
        member['isSelected'] = false;
      }
      for (var member in _teamComparisonData) {
        member['isSelected'] = false;
      }
    });
  }

  Future<void> _fetchTeamDetails() async {
    try {
      setState(() {
        isLoading = true; // Set loading state
      });

      final token = await Storage.getToken();
      // ... (rest of your existing API call logic)

      // Build period parameter
      String? periodParam;
      switch (_periodIndex) {
        case 1:
          periodParam = 'MTD';
          break;
        case 0:
          periodParam = 'QTD';
          break;
        case 2:
          periodParam = 'YTD';
          break;
        default:
          periodParam = 'QTD';
      }

      final Map<String, String> queryParams = {};

      if (periodParam != null) {
        queryParams['type'] = periodParam;
      }

      final targetMetric = [
        'target_enquiries',
        'target_testDrives',
        'target_orders',
        'target_cancellation',
        'target_netOrders',
        'target_retail',
      ];

      // Define summary metrics (moved outside to be available for both cases)
      final summaryMetrics = [
        'enquiries',
        'testDrives',
        'orders',
        'cancellation',
        'netOrders',
        'retail',
      ];
      final summaryParam = summaryMetrics[_metricIndex];
      final targetParam = targetMetric[_metricIndex];

      // ✅ Add summary parameter for both All and specific user selection
      queryParams['summary'] = summaryParam;
      queryParams['target'] = targetParam;

      // 🔥 MODIFIED LOGIC: Handle user selection based on comparison mode
      if (_isComparing && selectedUserIds.isNotEmpty) {
        // ✅ If comparison mode is ON, ONLY pass userIds (NO user_id)
        queryParams['userIds'] = selectedUserIds.join(',');
      } else if (!_isComparing &&
          _selectedProfileIndex != 0 &&
          _selectedUserId.isNotEmpty) {
        // ✅ If comparison mode is OFF and specific user is selected, pass user_id
        queryParams['user_id'] = _selectedUserId;
      }

      if (_isComparing && selectedUserIds.isEmpty) {
        setState(() {
          _isComparing = false;
          _teamComparisonData = [];
        });
      }
      // ✅ If "All" is selected (_selectedProfileIndex == 0), no user parameters are added

      final baseUri = Uri.parse(
        'https://api.smartassistapp.in/api/users/sm/analytics/team-dashboard',
      );

      final uri = baseUri.replace(queryParameters: queryParams);

      print('📤 Fetching from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _teamData = data['data'] ?? {};

          // Team comparison data
          if (_teamData.containsKey('teamComparsion')) {
            _teamComparisonData = List<dynamic>.from(
              _teamData['teamComparsion'] ?? [],
            );
            print('📊 Team Comparison Data Updated: $_teamComparisonData');
          } else {
            _teamComparisonData = [];
          }

          // Save total performance
          if (_teamData.containsKey('totalPerformance')) {
            _selectedUserData?['totalPerformance'] =
                _teamData['totalPerformance'];
          }

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

          if (_selectedProfileIndex == 0) {
            // Summary data
            _selectedUserData = _teamData['summary'] ?? {};
            _selectedUserData?['totalPerformance'] =
                _teamData['totalPerformance'] ?? {};
          } else if (_selectedProfileIndex - 1 < _teamMembers.length) {
            // Specific user selected
            final selectedMember = _teamMembers[_selectedProfileIndex - 1];
            _selectedUserData = selectedMember;

            final selectedUserPerformance =
                _teamData['selectedUserPerformance'] ?? {};
            final upcoming = selectedUserPerformance['Upcoming'] ?? {};
            final overdue = selectedUserPerformance['Overdue'] ?? {};

            if (_upcommingButtonIndex == 0) {
              _upcomingFollowups = List<Map<String, dynamic>>.from(
                upcoming['upComingFollowups'] ?? [],
              );
              _upcomingAppointments = List<Map<String, dynamic>>.from(
                upcoming['upComingAppointment'] ?? [],
              );
              _upcomingTestDrives = List<Map<String, dynamic>>.from(
                upcoming['upComingTestDrive'] ?? [],
              );
            } else {
              _upcomingFollowups = List<Map<String, dynamic>>.from(
                overdue['overdueFollowups'] ?? [],
              );
              _upcomingAppointments = List<Map<String, dynamic>>.from(
                overdue['overdueAppointments'] ?? [],
              );
              _upcomingTestDrives = List<Map<String, dynamic>>.from(
                overdue['overdueTestDrives'] ?? [],
              );

              overdueCount =
                  _upcomingFollowups.length +
                  _upcomingAppointments.length +
                  _upcomingTestDrives.length;
            }
          }
          // ... (rest of your existing state updates)

          isLoading = false; // Clear loading state
        });
      } else {
        throw Exception('Failed to fetch team details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching team details: $e');
      setState(() {
        isLoading = false; // Clear loading state on error
      });
    }
  }

  // Process team data for team comparison display
  List<Map<String, dynamic>> _processTeamComparisonData() {
    if (!(_teamData.containsKey('teamComparsion') &&
        _teamData['teamComparsion'] is List)) {
      return [];
    }
    return List<Map<String, dynamic>>.from(_teamData['teamComparsion']);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.colorsBlue,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            selectedUserIds.length >= 2
                ? InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        bool allSelected =
                            selectedUserIds.length == _teamMembers.length;

                        if (allSelected) {
                          // If already selected all, unselect all
                          selectedUserIds.clear();
                          _selectedLetters.clear();
                          _selectedType = '';
                        } else {
                          // Select all
                          _isMultiSelectMode = true;
                          selectedUserIds.clear();
                          selectedUserIds.addAll(
                            _teamMembers.map(
                              (member) => member['user_id'].toString(),
                            ),
                          );
                          _selectedLetters.clear();
                          for (var member in _teamMembers) {
                            String firstLetter = (member['fname'] ?? '')
                                .toString()
                                .toUpperCase();
                            if (firstLetter.isNotEmpty) {
                              _selectedLetters.add(firstLetter[0]);
                            }
                          }
                          _selectedType = 'Letter';
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: selectedUserIds.length == _teamMembers.length
                            ? Colors.green.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            side: BorderSide(color: Colors.white),
                            activeColor: Colors.white,

                            checkColor: Colors.blue,
                            value:
                                selectedUserIds.length == _teamMembers.length,
                            onChanged: (_) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                bool allSelected =
                                    selectedUserIds.length ==
                                    _teamMembers.length;

                                if (allSelected) {
                                  selectedUserIds.clear();
                                  _selectedLetters.clear();
                                  _selectedType = '';
                                } else {
                                  _isMultiSelectMode = true;
                                  selectedUserIds.clear();
                                  selectedUserIds.addAll(
                                    _teamMembers.map(
                                      (member) => member['user_id'].toString(),
                                    ),
                                  );
                                  _selectedLetters.clear();
                                  for (var member in _teamMembers) {
                                    String firstLetter = (member['fname'] ?? '')
                                        .toString()
                                        .toUpperCase();
                                    if (firstLetter.isNotEmpty) {
                                      _selectedLetters.add(firstLetter[0]);
                                    }
                                  }
                                  _selectedType = 'Letter';
                                }
                              });
                            },
                          ),
                          Text(
                            'Select All',
                            style: AppFont.appbarfontWhite(context),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text('My Team', style: AppFont.appbarfontWhite(context)),

            if (selectedUserIds.length >= 2)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isComparing = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fetchTeamDetails();
                    });
                  },
                  child: Text(
                    'Compare',
                    style: AppFont.mediumText14white(context),
                  ),
                ),
              ),
          ],
        ),
      ),

      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is UserScrollNotification) {
            final direction = notification.direction;
            if (direction == ScrollDirection.reverse && _isFabVisible) {
              setState(() => _isFabVisible = false);
            } else if (direction == ScrollDirection.forward && !_isFabVisible) {
              setState(() => _isFabVisible = true);
            }
          }
          return false;
        },
        child: Stack(
          children: [
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _fetchTeamDetails,
                child: SingleChildScrollView(
                  controller: fabController.scrollController,
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Required to allow pull-to-refresh
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [_buildProfileAvatars()]),
                        ),
                        const SizedBox(height: 10),
                        if (isLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          if (!_isComparing)
                            _buildIndividualPerformanceTab(
                              context,
                              screenWidth,
                            ),
                          const SizedBox(height: 10),
                          _buildTeamComparisonTab(context, screenWidth),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatars() {
    List<Map<String, dynamic>> sortedTeamMembers = List.from(_teamMembers);
    sortedTeamMembers.sort(
      (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
        (b['fname'] ?? '').toString().toLowerCase(),
      ),
    );

    // Get unique letters
    Set<String> uniqueLetters = {};
    for (var member in sortedTeamMembers) {
      String firstLetter = (member['fname'] ?? '').toString().toUpperCase();
      if (firstLetter.isNotEmpty) {
        uniqueLetters.add(firstLetter[0]);
      }
    }

    List<String> sortedLetters = uniqueLetters.toList()..sort();

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        height: 90,
        padding: const EdgeInsets.only(top: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Always show All button first
            _buildProfileAvatarStaticsAll('All', 0),

            // Build letters with their members inline
            ...sortedLetters.expand(
              (letter) => _buildLetterWithMembers(letter),
            ),
          ],
        ),
      ),
    );
  }

  // New method to build letter with its members inline
  List<Widget> _buildLetterWithMembers(String letter) {
    List<Widget> widgets = [];
    bool isSelected = _selectedLetters.contains(letter);

    // Add the letter avatar
    widgets.add(_buildAlphabetAvatar(letter));

    // If letter is selected, add its members right after
    if (isSelected) {
      List<Map<String, dynamic>> letterMembers = _teamMembers.where((member) {
        String firstName = (member['fname'] ?? '').toString().toUpperCase();
        return firstName.startsWith(letter);
      }).toList();

      // Sort members alphabetically
      letterMembers.sort(
        (a, b) => (a['fname'] ?? '').toString().toLowerCase().compareTo(
          (b['fname'] ?? '').toString().toLowerCase(),
        ),
      );

      // Add member avatars
      for (int i = 0; i < letterMembers.length; i++) {
        widgets.add(
          _buildProfileAvatar(
            letterMembers[i]['fname'] ?? '',
            i + 1,
            letterMembers[i]['user_id'] ?? '',
            letterMembers[i]['profile'],
            letterMembers[i]['initials'] ?? '',
          ),
        );
      }
    }

    return widgets;
  }

  // Enhanced alphabet avatar method with haptic feedback
  Widget _buildAlphabetAvatar(String letter) {
    bool isSelected = _selectedLetters.contains(letter);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            // Light haptic feedback on tap
            HapticFeedback.lightImpact();

            setState(() {
              if (_isMultiSelectMode) {
                // In multi-select mode, toggle selection
                if (isSelected) {
                  _selectedLetters.remove(letter);
                  // If no letters selected, exit multi-select mode
                  if (_selectedLetters.isEmpty) {
                    _isMultiSelectMode = false;
                    _selectedType = 'All';
                    _selectedProfileIndex = 0;
                  }
                } else {
                  _selectedLetters.add(letter);
                  _selectedType = 'Letter';
                  // _selectedProfileIndex = -1; // Letter selection
                }
              } else {
                // Single select mode - but keep existing selections and add new one
                if (isSelected) {
                  // If clicking same letter, deselect it
                  _selectedLetters.remove(letter);
                  if (_selectedLetters.isEmpty) {
                    _selectedType = 'All';
                    _selectedProfileIndex = 0; // Back to "All"
                  }
                } else {
                  // Add this letter to selection (don't clear existing)
                  _selectedLetters.add(letter);
                  _selectedType = 'Letter';
                  // _selectedProfileIndex = -1; // Letter selection
                }
              }

              _selectedProfileIndex = -1;
            });
            // _fetchTeamDetails();  new
          },

          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.colorsBlue
                      : AppColors.backgroundLightGrey,
                  border: isSelected
                      ? Border.all(color: AppColors.colorsBlue, width: 2.5)
                      : Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isSelected ? 22 : 20,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    child: Text(letter),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // AnimatedDefaultTextStyle(
        //   duration: const Duration(milliseconds: 200),
        //   style: AppFont.mediumText14(context).copyWith(
        //     color: isSelected ? AppColors.colorsBlue : null,
        //     fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        //   ),
        //   child: Text(letter),
        // ),
      ],
    );
  }

  // Enhanced "All" button with haptic feedback
  Widget _buildProfileAvatarStaticsAll(String firstName, int index) {
    bool isSelected = _selectedType == 'All' && _selectedLetters.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            // Medium haptic feedback for "All" button
            HapticFeedback.mediumImpact();
            setState(() {
              _selectedProfileIndex = index;
              _selectedType = 'All';
              _selectedLetters.clear();
              _isMultiSelectMode = false;
              _isComparing = false;
              selectedUserIds.clear(); // Clear selected users
              _teamComparisonData = []; // Clear comparison data
            });

            await _fetchTeamDetails();
          },
          onLongPress: () {
            // Heavy haptic feedback for long press on "All"
            HapticFeedback.heavyImpact();

            // Show info about total members
            int totalMembers = _teamMembers.length;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Total $totalMembers team members'),
                  ],
                ),
                duration: const Duration(seconds: 1),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 150,
                  left: 20,
                  right: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isMultiSelectMode
                      ? AppColors.sideRed
                      : (isSelected
                            ? AppColors.colorsBlue
                            : AppColors.backgroundLightGrey),
                  border: isSelected
                      ? Border.all(color: AppColors.colorsBlue, width: 2.5)
                      : Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isMultiSelectMode
                          ? Icons.close_rounded
                          : (isSelected
                                ? Icons.people_rounded
                                : Icons.people_rounded),
                      key: ValueKey(
                        _isMultiSelectMode
                            ? 'clear'
                            : (isSelected ? 'groups' : 'people'),
                      ),
                      color: _isMultiSelectMode
                          ? Colors.white
                          : (isSelected ? Colors.white : Colors.grey),
                      size: isSelected ? 34 : 32,
                    ),
                  ),
                ),
              ),
              // Multi-select mode indicator
              if (_isMultiSelectMode)
                Positioned(
                  top: -2,
                  right: 3,
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 200),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        InkWell(
          onTap: () async {
            setState(() {
              _selectedProfileIndex = index;
              _selectedType = 'All';
              _selectedLetters.clear(); // Clear all letter selections
              _isMultiSelectMode = false; // Exit multi-select mode
              _isComparing = false; // Exit comparison mode when selecting "All"

              _metricIndex = 0;
              isSelected = true; // new
              if (!_isComparing) {
                _clearAllSelections();
              }
            });
            // await _fetchAllCalllog();
            await _fetchTeamDetails();
            // await _fetchSingleCalllog();
          },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppFont.mediumText14(context).copyWith(
              color: isSelected
                  ? AppColors.colorsBlue
                  : (_isMultiSelectMode ? AppColors.fontColor : null),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            child: Text(
              _isMultiSelectMode ? 'Clear' : 'All',
              style: AppFont.mediumText14(context),
            ),
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
    bool isSelectedForComparison = selectedUserIds.contains(userId);
    bool isCurrentlySelected =
        _selectedProfileIndex == index && _selectedUserId == userId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPress: () {
            // Strong haptic feedback on long press
            HapticFeedback.heavyImpact();

            setState(() {
              // Activate multi-select mode
              _isMultiSelectMode = true;

              // Toggle the current item's selection
              if (isSelectedForComparison) {
                selectedUserIds.remove(userId);
              } else {
                selectedUserIds.add(userId);
              }
            });
          },

          // Your onTap implementation (combining your existing logic with multi-select)
          onTap: () async {
            // Light haptic feedback on tap
            HapticFeedback.lightImpact();

            if (_isMultiSelectMode) {
              // Multi-select mode: toggle selection for comparison
              setState(() {
                if (isSelectedForComparison) {
                  selectedUserIds.remove(userId);
                  // If no items selected, exit multi-select mode
                  if (selectedUserIds.isEmpty) {
                    _isMultiSelectMode = false;
                  }
                } else {
                  selectedUserIds.add(userId);
                }
              });
            } else if (!_isComparing) {
              // Single select mode: your existing logic
              setState(() {
                if (_selectedUserId == userId) {
                  _clearAllSelections();
                } else {
                  _selectedProfileIndex = index;
                  _selectedUserId = userId;
                  _selectedType = 'dynamic';
                }
              });
              // ✅ This ensures _fetchTeamDetails runs AFTER setState completes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchTeamDetails();
                _fetchSingleCalllog();
              });
            }
          },

          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
            child: Stack(
              children: [
                // Main avatar container
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    border: _getBorderStyle(isSelectedForComparison, index),
                  ),
                  child: ClipOval(
                    child: _buildProfileContent(
                      isSelectedForComparison,
                      profileUrl,
                      initials,
                      firstName,
                      context,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 70),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppFont.mediumText14(context).copyWith(
              color: _getNameTextColor(
                isSelectedForComparison,
                isCurrentlySelected,
              ),
              fontWeight: (isSelectedForComparison || isCurrentlySelected)
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
            child: Text(
              firstName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // Helper method to get the appropriate text color for names
  Color _getNameTextColor(
    bool isSelectedForComparison,
    bool isCurrentlySelected,
  ) {
    if (_isMultiSelectMode) {
      // In multi-select mode
      if (isSelectedForComparison) {
        return AppColors.fontColor; // Highlight selected items
      } else {
        return Colors.grey.shade500; // Dim unselected items
      }
    } else {
      // In single-select mode
      if (isCurrentlySelected) {
        return AppColors.fontColor; // Highlight currently selected item
      } else if (_selectedUserId != null) {
        return Colors
            .grey
            .shade500; // Dim unselected items when something is selected
      } else {
        return AppColors.fontColor; // Default color when nothing is selected
      }
    }
  }

  // Helper method to determine border style based on selection state
  Border? _getBorderStyle(bool isSelectedForComparison, int index) {
    if (_selectedProfileIndex == index) {
      return Border.all(color: AppColors.backgroundLightGrey, width: 3);
    }
    return Border.all(color: AppColors.colorsBlue.withOpacity(0.1), width: 1);
  }

  // Border _getBorderStyle(bool isSelectedForComparison, int index) {
  //   bool isCurrentlySelected =
  //       _selectedProfileIndex == index && _selectedUserId == selectedUserIds;
  //   return isSelectedForComparison || isCurrentlySelected
  //       ? Border.all(color: AppColors.colorsBlue, width: 2.5)
  //       : Border.all(color: Colors.grey.withOpacity(0.3), width: 1);
  // }

  // Helper method to build profile content with modern styling

  Widget _buildProfileContent(
    bool isSelectedForComparison,
    String? profileUrl,
    String initials,
    String firstName,
    BuildContext context,
  ) {
    if (isSelectedForComparison) {
      // Multi-select mode: show simple circle with check icon
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.sideGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 30),
      );
    } else {
      // Normal mode: show profile image or initials
      if (profileUrl != null && profileUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Image.network(
            profileUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildInitialAvatar(initials, firstName, showLoader: true);
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildInitialAvatar(initials, firstName);
            },
          ),
        );
      } else {
        return _buildInitialAvatar(initials, firstName);
      }
    }
  }

  Widget _buildInitialAvatar(
    String initials,
    String firstName, {
    bool showLoader = false,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _getConsistentColor(firstName + initials),
        shape: BoxShape.circle,
      ),
      child: showLoader
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          : Center(
              child: Text(
                initials.isNotEmpty
                    ? initials.toUpperCase()
                    : (firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  Color _getConsistentColor(String seed) {
    // Create a hash from the seed string
    int hash = seed.hashCode;

    // Use the hash to generate consistent RGB values
    final math.Random random = math.Random(hash);

    // Generate colors that are vibrant but not too light/dark
    int red = 80 + random.nextInt(150); // 80-230 range
    int green = 80 + random.nextInt(150); // 80-230 range
    int blue = 80 + random.nextInt(150); // 80-230 range

    return Color.fromARGB(255, red, green, blue);
  }

  // Individual Performance Tab Content
  Widget _buildIndividualPerformanceTab(
    BuildContext context,
    double screenWidth,
  ) {
    if (_isOnlyLetterSelected) {
      return Container(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            "Select a user to view details.",
            style: AppFont.dropDowmLabelLightcolors(context),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundLightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildPeriodFilter(screenWidth),
                // if(_isComparing)
                _buildIndividualPerformanceMetrics(context),
              ],
            ),
          ),
          if (_selectedType != 'All') ...[
            // _buildUpcomingActivities(context),
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.backgroundLightGrey,
                  width: 1,
                ),
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 0,
                    spreadRadius: 0.2,
                    offset: Offset(1, 1), // Equal shadow on all sides
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 10, bottom: 0),
                        child: Text(
                          'Activities',
                          style: AppFont.dropDowmLabel(context).copyWith(
                            color: AppColors.iconGrey,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            isHideActivities = !isHideActivities;
                          });
                        },
                        icon: Icon(
                          isHideActivities
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 35,
                          color: AppColors.iconGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!isHideActivities) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundLightGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(top: 10),
                child: _buildUpcomingActivities(context),
              ),
            ],
          ],
          if (_selectedType != 'All') ...[
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.backgroundLightGrey,
                  width: 1,
                ),
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 0,
                    spreadRadius: 0.2,
                    offset: Offset(1, 1), // Equal shadow on all sides
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 10, bottom: 0),
                        child: Text(
                          'Call logs',
                          style: AppFont.dropDowmLabel(context).copyWith(
                            color: AppColors.iconGrey,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            isSingleCall = !isSingleCall;
                          });
                        },
                        icon: Icon(
                          isSingleCall
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 35,
                          color: AppColors.iconGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isSingleCall) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundLightGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSingleuserCalllog(context),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Team Comparison Tab Content
  Widget _buildTeamComparisonTab(BuildContext context, double screenWidth) {
    return Column(
      children: [
        if (isLoading)
          Center(child: CircularProgressIndicator())
        else if (_isComparing)
          _buildTeamComparisonChart(context, screenWidth)
        else
          _callAnalyticAll(context),
      ],
    );
  }

  // Period filter (ALL, MTD, QTD, YTD)
  Widget _buildPeriodFilter(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: Colors.grey.shade300, width: 1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                _buildPeriodButton('MTD', 1),
                _buildPeriodButton('QTD', 0),
                _buildPeriodButton('YTD', 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Individual period button
  Widget _buildPeriodButton(String label, int index) {
    return InkWell(
      onTap: () {
        setState(() {
          _periodIndex = index;
          _fetchTeamDetails();
          // _fetchSingleCalllog();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
        decoration: BoxDecoration(
          color: _periodIndex == index
              ? AppColors.colorsBlue.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: _periodIndex == index
                ? AppColors.colorsBlue
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _periodIndex == index
                ? AppColors.colorsBlue
                : AppColors.iconGrey,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleuserCalllog(BuildContext context) {
    return TeamCalllogUserid(
      key: ValueKey(selectedTimeRange),
      dashboardData: _dashboardData,
      enquiryData: _enquiryData,
      coldCallData: _coldCallData,
      onTimeRangeChanged: _handleTimeRangeChange,
      initialTimeRange: selectedTimeRange, // <- pass it here!
    );
  }

  // ADD THIS METHOD
  void _handleTimeRangeChange(String newTimeRange) {
    setState(() {
      selectedTimeRange = newTimeRange;
      isLoading = true;
    });
    _fetchSingleCalllog();
  }

  // Fixed Performance Metrics Widget all
  Widget _buildIndividualPerformanceMetrics(BuildContext context) {
    // Determine selection state
    final bool isSpecificUserSelected = _selectedProfileIndex > 0;
    final bool isAllSelected =
        _selectedProfileIndex == 0 && _selectedLetters.isEmpty;
    final bool isLetterSelected = _selectedLetters.isNotEmpty;

    // Debug prints
    print(
      'Selection state - ProfileIndex: $_selectedProfileIndex, Letters: $_selectedLetters, Type: $_selectedType',
    );
    print(
      'Flags - isSpecificUser: $isSpecificUserSelected, isAll: $isAllSelected, isLetter: $isLetterSelected',
    );

    // Function to get total for a specific key based on selection
    int getTotalForKey(String key) {
      if (isSpecificUserSelected) {
        // Individual user - use selectedUserPerformance from _teamData or _selectedUserData
        final userStats =
            _teamData['selectedUserPerformance'] ?? _selectedUserData ?? {};
        return int.tryParse(userStats[key]?.toString() ?? '0') ?? 0;
      } else {
        // All users or letter selection - use team comparison data
        final stats = (_isMultiSelectMode || _isComparing)
            ? (_teamData["teamComparsion"] as List? ?? [])
                  .where((member) => member["isSelected"] == true)
                  .toList()
            : (_teamData["teamComparsion"] as List? ?? []);

        if (stats.isNotEmpty) {
          // Aggregate from team members
          return stats.fold(
            0,
            (sum, member) =>
                sum + (int.tryParse(member[key]?.toString() ?? '0') ?? 0),
          );
        } else if (isAllSelected) {
          // Fallback to totalPerformance for "All" selection
          final totalStats = _selectedUserData?['totalPerformance'] ?? {};
          return int.tryParse(totalStats[key]?.toString() ?? '0') ?? 0;
        }
      }
      return 0;
    }

    // Calculate net orders
    // int calculateNetOrders() {
    //   final orders = getTotalForKey('orders');
    //   final cancellations = getTotalForKey('cancellation');
    //   return math.max(0, orders - cancellations);
    // }

    final List<Map<String, dynamic>> metrics = [
      {'label': 'Enquiries', 'key': 'enquiries'},
      {'label': 'Test Drive', 'key': 'testDrives'},
      {'label': 'Orders', 'key': 'orders'},
      {'label': 'Cancellations', 'key': 'cancellation'},
      {'label': 'Net Orders', 'key': 'net_orders'},
      // {
      //   'label': 'Net Orders',
      //   'key': 'netOrders',
      //   'value': calculateNetOrders(),
      // },
      {'label': 'Retails', 'key': 'retail'},
    ];

    List<Widget> rows = [];
    for (int i = 0; i < metrics.length; i += 2) {
      rows.add(
        Row(
          children: [
            for (int j = i; j < i + 2 && j < metrics.length; j++) ...[
              Expanded(
                child: _buildMetricCard(
                  metrics[j].containsKey('value')
                      ? metrics[j]['value'].toString()
                      : getTotalForKey(metrics[j]['key'] as String).toString(),
                  metrics[j]['label'] as String,
                  AppColors.colorsBlue,
                  isSelected: _metricIndex == j,
                  isUserSelected: _selectedType != 'All',
                ),
              ),
              if (j % 2 == 0 && j + 1 < metrics.length)
                const SizedBox(width: 12),
            ],
          ],
        ),
      );
      if (i + 2 < metrics.length) rows.add(const SizedBox(height: 12));
    }

    // Check if we have any data to display
    bool hasData =
        isSpecificUserSelected ||
        (_teamData["teamComparsion"] as List? ?? []).isNotEmpty ||
        (_selectedUserData?['totalPerformance'] != null);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            )
          : const Center(child: Text('No data available')),
    );
  }

  // Team Comparison Chart
  Widget _buildTeamComparisonChart(BuildContext context, double screenWidth) {
    // Process data
    final teamData = _processTeamComparisonData();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedType != 'dynamic') ...[
            // Toggle area
            InkWell(
              onTap: () => setState(() {
                setState(() {
                  isHide = !isHide;
                });
              }),

              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.backgroundLightGrey,
                    width: 1,
                  ),
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 0,
                      spreadRadius: 0.2,
                      offset: Offset(1, 1), // Equal shadow on all sides
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      style: ButtonStyle(
                        padding: MaterialStateProperty.all<EdgeInsets>(
                          EdgeInsets.zero,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          isHide = !isHide;
                        });
                      },
                      icon: Icon(
                        isHide
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 35,
                        color: AppColors.iconGrey,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      child: Text(
                        'Team Comparison',
                        style: AppFont.dropDowmLabel(context).copyWith(
                          color: AppColors.iconGrey,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    _buildFilterTeams(screenWidth),
                  ],
                ),
              ),
            ),

            // 👇 Conditionally render chart section
            if (!isHide) ...[
              if (teamData.isEmpty)
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 10),
                    child: Text(
                      'No team data available',
                      style: AppFont.dropDowmLabelLightcolors(context),
                    ),
                  ),
                )
              else
                _buildTableTeamParison(),
              _buildShowMoreButtonTeamComparison(),
            ],
          ],
        ],
      ),
    );
  }

  // Period filter (ALL, MTD, QTD, YTD)
  Widget _buildFilterTeams(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IntrinsicWidth(
            child: Container(
              constraints: const BoxConstraints(minWidth: 60, maxWidth: 150),
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _buildPeriodButton('MTD', 1),
                  _buildPeriodButton('QTD', 0),
                  _buildPeriodButton('YTD', 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Individual period button
  // Widget _buildPeriodButton(String label, int index) {
  //   return InkWell(
  //     onTap: () {
  //       setState(() {
  //         _periodIndex = index;
  //         _fetchTeamDetails();
  //         // _fetchSingleCalllog();
  //       });
  //     },
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
  //       decoration: BoxDecoration(
  //         color: _periodIndex == index
  //             ? AppColors.colorsBlue.withOpacity(0.1)
  //             : Colors.transparent,
  //         border: Border.all(
  //           color: _periodIndex == index
  //               ? AppColors.colorsBlue
  //               : Colors.transparent,
  //         ),
  //         borderRadius: BorderRadius.circular(30),
  //       ),
  //       child: Text(
  //         label,
  //         style: TextStyle(
  //           color: _periodIndex == index
  //               ? AppColors.colorsBlue
  //               : AppColors.iconGrey,
  //           fontWeight: FontWeight.w500,
  //           fontSize: 14,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTableTeamParison() {
    double screenWidth = MediaQuery.of(context).size.width;

    // Check if there's data to display
    bool hasData = _membersData.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            spreadRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: hasData
          ? Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                  width: 0.6,
                ),
                verticalInside: BorderSide.none,
              ),
              columnWidths: {
                0: FixedColumnWidth(screenWidth * 0.30), // Name column
                1: FixedColumnWidth(screenWidth * 0.11), // Incoming
                2: FixedColumnWidth(screenWidth * 0.11), // Outgoing
                3: FixedColumnWidth(screenWidth * 0.11), // Connected
                4: FixedColumnWidth(screenWidth * 0.11), // Duration
                5: FixedColumnWidth(screenWidth * 0.11), // Declined
                6: FixedColumnWidth(screenWidth * 0.11),
              },
              children: [
                TableRow(
                  children: [
                    const SizedBox(), // Empty cell for name column
                    _buildSortableHeader(
                      'EQ',
                      'enquiries',
                      enquiries,
                      'Enquiries',
                    ),
                    _buildSortableHeader(
                      'TD',
                      'testDrives',
                      tDrives,
                      'Test Drives',
                    ),
                    _buildSortableHeader('OD', 'orders', orders, 'Orders'),
                    _buildSortableHeader(
                      'CL',
                      'cancellation',
                      cancel,
                      'Cancellations',
                    ),
                    _buildSortableHeader(
                      'ND',
                      'net_orders',
                      net_orders,
                      'Net Orders',
                    ),
                    _buildSortableHeader('RS', 'retail', retails, 'Retails'),
                  ],
                ),
                ..._buildMemberRowsTeams(),
              ],
            )
          : _buildEmptyState(),
    );
  }

  Widget _buildSortableHeader(
    String displayText,
    String sortKey,
    GlobalKey key,
    String tooltipText,
  ) {
    bool isCurrentSortColumn = _sortColumn == sortKey;

    return GestureDetector(
      key: key,
      onTap: () {
        // Show tooltip
        showBubbleTooltip(context, key, tooltipText);

        // Sort logic with 3 states
        setState(() {
          if (_sortColumn == sortKey) {
            // If clicking the same column, cycle through states
            _sortState = (_sortState + 1) % 3;
          } else {
            // If clicking a different column, start with descending (highest first)
            _sortColumn = sortKey;
            _sortState = 1; // Start with descending
          }
        });

        // Trigger data sorting
        _sortData();
      },
      child: Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayText,
              style: AppFont.smallTextBold(context).copyWith(
                color: isCurrentSortColumn && _sortState != 0
                    ? Colors.blue
                    : null,
              ),
            ),
            // Sort indicator
            if (isCurrentSortColumn && _sortState != 0)
              Icon(
                _sortState == 1 ? Icons.arrow_downward : Icons.arrow_upward,
                size: 12,
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  void _sortData() {
    // Store original data if not already stored
    if (_originalMembersData.isEmpty) {
      _originalMembersData = List.from(_membersData);
    }

    List<dynamic> dataToSort;

    // Determine which data to sort
    if (_isComparing && _teamComparisonData.isNotEmpty) {
      dataToSort = _teamComparisonData;
    } else if (_isComparing && selectedUserIds.isNotEmpty) {
      dataToSort = _membersData.where((member) {
        return selectedUserIds.contains(member['user_id'].toString());
      }).toList();
    } else {
      dataToSort = _membersData;
    }

    // Sort based on current state
    if (_sortState == 0) {
      // Original order - restore from original data and sort by name descending
      if (_isComparing && _teamComparisonData.isNotEmpty) {
        // For team comparison, just sort by name
        dataToSort.sort((a, b) {
          String aName = (a['name'] ?? '').toString().toLowerCase();
          String bName = (b['name'] ?? '').toString().toLowerCase();
          return bName.compareTo(aName); // Z to A
        });
      } else {
        // For regular data, restore original order first, then sort by name
        dataToSort = List.from(_originalMembersData);
        if (_isComparing && selectedUserIds.isNotEmpty) {
          dataToSort = dataToSort.where((member) {
            return selectedUserIds.contains(member['user_id'].toString());
          }).toList();
        }
        dataToSort.sort((a, b) {
          String aName = (a['name'] ?? '').toString().toLowerCase();
          String bName = (b['name'] ?? '').toString().toLowerCase();
          return bName.compareTo(aName); // Z to A
        });
      }
    } else if (_sortColumn != null) {
      // Sort by the selected column
      dataToSort.sort((a, b) {
        var aValue = a[_sortColumn];
        var bValue = b[_sortColumn];

        // Handle null values
        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return _sortState == 1 ? 1 : -1;
        if (bValue == null) return _sortState == 1 ? -1 : 1;

        // Convert to numbers for proper sorting
        double aNum = double.tryParse(aValue.toString()) ?? 0;
        double bNum = double.tryParse(bValue.toString()) ?? 0;

        if (_sortState == 1) {
          // Descending order (highest first)
          return bNum.compareTo(aNum);
        } else {
          // Ascending order (lowest first)
          return aNum.compareTo(bNum);
        }
      });
    }

    // // Sort based on current state
    // if (_sortState == 0) {
    //   // Original order - sort by name descending
    //   dataToSort.sort((a, b) {
    //     String aName = (a['name'] ?? '').toString().toLowerCase();
    //     String bName = (b['name'] ?? '').toString().toLowerCase();
    //     return bName.compareTo(aName); // Z to A
    //   });
    // } else if (_sortColumn != null) {
    //   // Sort by the selected column
    //   dataToSort.sort((a, b) {
    //     var aValue = a[_sortColumn];
    //     var bValue = b[_sortColumn];

    //     // Handle null values
    //     if (aValue == null && bValue == null) return 0;
    //     if (aValue == null) return _sortState == 1 ? 1 : -1;
    //     if (bValue == null) return _sortState == 1 ? -1 : 1;

    //     // Convert to numbers for proper sorting
    //     double aNum = double.tryParse(aValue.toString()) ?? 0;
    //     double bNum = double.tryParse(bValue.toString()) ?? 0;

    //     if (_sortState == 1) {
    //       // Descending order (highest first)
    //       return bNum.compareTo(aNum);
    //     } else {
    //       // Ascending order (lowest first)
    //       return aNum.compareTo(bNum);
    //     }
    //   });
    // }

    // Update the appropriate data source
    if (_isComparing && _teamComparisonData.isNotEmpty) {
      _teamComparisonData = dataToSort;
    } else {
      // For filtered data, we need to update the main data source
      if (_isComparing && selectedUserIds.isNotEmpty) {
        // Create a map for quick lookup of sorted positions
        Map<String, int> sortedPositions = {};
        for (int i = 0; i < dataToSort.length; i++) {
          sortedPositions[dataToSort[i]['user_id'].toString()] = i;
        }

        // Sort the main data based on the sorted positions
        _membersData.sort((a, b) {
          String aId = a['user_id'].toString();
          String bId = b['user_id'].toString();

          // If both are in selected users, sort by their sorted positions
          if (selectedUserIds.contains(aId) && selectedUserIds.contains(bId)) {
            return (sortedPositions[aId] ?? 0).compareTo(
              sortedPositions[bId] ?? 0,
            );
          }

          // If only one is selected, prioritize selected items
          if (selectedUserIds.contains(aId)) return -1;
          if (selectedUserIds.contains(bId)) return 1;

          // For non-selected items, maintain original order
          return 0;
        });
      } else {
        _membersData = List<Map<String, dynamic>>.from(dataToSort);
      }
    }
  }

  Widget _callAnalyticAll(BuildContext context) {
    if (_isOnlyLetterSelected) {
      return Container(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            "Select a user to view call analysis.",
            style: AppFont.dropDowmLabelLightcolors(context),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () {
        setState(() {
          // isHideAllcall = !isHideAllcall;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Column(
          children: [
            if (_selectedType != 'dynamic') ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.backgroundLightGrey,
                    width: 1,
                  ),
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 0,
                      spreadRadius: 0.2,
                      offset: Offset(1, 1), // Equal shadow on all sides
                    ),
                  ],
                ),

                child: InkWell(
                  onTap: () => setState(() {
                    setState(() {
                      isHideAllcall = !isHideAllcall;
                    });
                  }),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                isHideAllcall = !isHideAllcall;
                              });
                            },
                            icon: Icon(
                              isHideAllcall
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 35,
                              color: AppColors.iconGrey,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 10, bottom: 0),
                            child: Text(
                              'Call Analysis',
                              style: AppFont.dropDowmLabel(context).copyWith(
                                color: AppColors.iconGrey,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isHideAllcall) ...[
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      _buildUserStatsCard(),
                      _buildAnalyticsTable(),
                      _buildShowMoreButton(),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Enhanced Show More button with better text
  Widget _buildShowMoreButton() {
    if (_membersData.isEmpty || !_hasMoreRecords()) {
      return const SizedBox.shrink();
    }

    int remainingRecords = _membersData.length - _currentDisplayCount;
    int recordsToShow = math.min(_incrementCount, remainingRecords);

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _loadMoreRecords,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show More ($recordsToShow more)'),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatsCard() {
    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        // border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            spreadRadius: 1,
            offset: Offset(0, 0), // Equal shadow on all sides
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  // border: Border.all(
                  //   color: Colors.grey.withOpacity(0.5),
                  //   width: 0,
                  // ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 1,
                      spreadRadius: 1,
                      offset: Offset(0, 0), // Equal shadow on all sides
                    ),
                  ],
                ),

                child: Text(
                  'Team size : ${_analyticsData['teamSize'] ?? '0'}',
                  style: AppFont.mediumText14(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBox(
                _analyticsData['TotalConnected']?.toString() ?? '0',
                'Connected',
              ),
              _buildVerticalDivider(50),
              _buildStatBox(
                _analyticsData['TotalDuration']?.toString() ?? '0',
                'Duration',
              ),
              _buildVerticalDivider(50),
              _buildStatBox(
                _analyticsData['Declined']?.toString() ?? '0',
                'Declined',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTable() {
    return _buildTableContent();
  }

  Widget _buildTableContent() {
    final GlobalKey incomingKey = GlobalKey();
    final GlobalKey outgoingKey = GlobalKey();
    final GlobalKey connectedKey = GlobalKey();
    final GlobalKey durationKey = GlobalKey();
    final GlobalKey rejectedKey = GlobalKey();
    double screenWidth = MediaQuery.of(context).size.width;

    // Check if there's data to display
    bool hasData = _membersData.isNotEmpty;

    void showBubbleTooltip(
      BuildContext context,
      GlobalKey key,
      String message,
    ) {
      final overlay = Overlay.of(context);
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      final size = renderBox?.size;
      final offset = renderBox?.localToGlobal(Offset.zero);

      if (overlay == null ||
          renderBox == null ||
          offset == null ||
          size == null)
        return;

      // Estimate the tooltip width (you could also use TextPainter for precise width if needed)
      const double tooltipPadding = 20.0;
      final double estimatedTooltipWidth =
          message.length * 7.0 + tooltipPadding;

      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: offset.dy - 35, // above the icon
          left:
              offset.dx +
              size.width / 2 -
              estimatedTooltipWidth / 2, // centered horizontally
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 0, 0),
                borderRadius: BorderRadius.circular(8),
                // boxShadow: const [
                //   BoxShadow(
                //     color: Colors.black26,
                //     blurRadius: 6,
                //     offset: Offset(2, 2),
                //   ),
                // ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);

      Future.delayed(const Duration(milliseconds: 1000), () {
        overlayEntry.remove();
      });
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        // border: Border.all(
        //   color: Colors.grey.withOpacity(0.5), // border color
        //   width: 1.0, // border width
        // ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            spreadRadius: 1,
            offset: Offset(0, 0), // Equal shadow on all sides
          ),
        ],
      ),
      child: hasData
          ? Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                  width: 0.6,
                ),
                verticalInside: BorderSide.none,
              ),
              columnWidths: {
                0: FixedColumnWidth(screenWidth * 0.35), // Name column
                1: FixedColumnWidth(screenWidth * 0.12), // Incoming
                2: FixedColumnWidth(screenWidth * 0.12), // Outgoing
                3: FixedColumnWidth(screenWidth * 0.12), // Connected
                4: FixedColumnWidth(screenWidth * 0.12), // Duration
                5: FixedColumnWidth(screenWidth * 0.12), // Declined
              },
              children: [
                TableRow(
                  children: [
                    const SizedBox(), // Empty cell for name column
                    // Incoming
                    GestureDetector(
                      key: incomingKey,
                      onTap: () =>
                          showBubbleTooltip(context, incomingKey, 'Incoming'),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 2,
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.04,
                          height: MediaQuery.of(context).size.width * 0.04,
                          child: Image.asset(
                            'assets/incoming.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Outgoing
                    GestureDetector(
                      key: outgoingKey,
                      onTap: () =>
                          showBubbleTooltip(context, outgoingKey, 'Outgoing'),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 2,
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.04,
                          height: MediaQuery.of(context).size.width * 0.04,
                          child: Image.asset(
                            'assets/outgoing.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Connected calls
                    GestureDetector(
                      key: connectedKey,
                      onTap: () => showBubbleTooltip(
                        context,
                        connectedKey,
                        'Connected Calls',
                      ),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 2,
                        ),
                        child: Icon(
                          Icons.call,
                          color: AppColors.sideGreen,
                          size: MediaQuery.of(context).size.width * 0.05,
                        ),
                      ),
                    ),

                    // Duration
                    GestureDetector(
                      key: durationKey,
                      onTap: () => showBubbleTooltip(
                        context,
                        durationKey,
                        'Total Duration',
                      ),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 2,
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: AppColors.colorsBlue,
                          size: MediaQuery.of(context).size.width * 0.05,
                        ),
                      ),
                    ),

                    // Missed
                    GestureDetector(
                      key: rejectedKey,
                      onTap: () =>
                          showBubbleTooltip(context, rejectedKey, 'Rejected'),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 2,
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.04,
                          height: MediaQuery.of(context).size.width * 0.04,
                          child: Image.asset(
                            'assets/missed.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                ..._buildMemberRows(),
              ],
            )
          : _buildEmptyState(),
    );
  }

  // Optional: Add an empty state widget
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'No data available',
          style: AppFont.smallText10(context).copyWith(color: Colors.grey),
        ),
      ),
    );
  }

  // Enhanced version with better edge case handling:
  List<TableRow> _buildMemberRows() {
    // Safety check for empty data
    if (_membersData.isEmpty) {
      return [];
    }

    // Get only the records to display based on current count
    List<dynamic> displayMembers = _membersData
        .take(_currentDisplayCount)
        .toList();

    return displayMembers.map((member) {
      final List<Color> _bgColors = [
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.indigo,
        Colors.purpleAccent,
      ];
      Color getRandomColor(String name) {
        final int hash = name.codeUnits.fold(0, (prev, el) => prev + el);
        return _bgColors[hash % _bgColors.length].withOpacity(0.8);
      }

      CircleAvatar buildAvatar(Map<String, dynamic> member) {
        final String? imageUrl = member['profileImage'];
        final String name = member['name'] ?? '';
        final String initials = name.isNotEmpty
            ? name.trim().substring(0, 1).toUpperCase()
            : '?';

        return CircleAvatar(
          radius: 12,
          backgroundColor: (imageUrl == null || imageUrl.isEmpty)
              ? getRandomColor(name)
              : Colors.transparent,
          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
              ? NetworkImage(imageUrl)
              : null,
          child: (imageUrl == null || imageUrl.isEmpty)
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        );
      }

      return _buildTableRow([
        // Your existing table row code...
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CallAnalytics(
                  userName: member['name'].toString(),
                  userId: member['user_id'].toString(),
                  isFromSM: true,
                ),
              ),
            );
          },
          child: Row(
            children: [
              // 👇 CircleAvatar with image or initials
              Builder(
                builder: (context) {
                  final String name = member['name'] ?? '';
                  final String? imageUrl = member['profileImage'];
                  final String initials = name.isNotEmpty
                      ? name
                            .trim()
                            .split(' ')
                            .map((e) => e[0])
                            .take(1)
                            .join()
                            .toUpperCase()
                      : '?';

                  return CircleAvatar(
                    radius: 12,
                    backgroundColor: (imageUrl == null || imageUrl.isEmpty)
                        ? getRandomColor(name)
                        : Colors.transparent,
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                        ? NetworkImage(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                },
              ),

              const SizedBox(width: 6),

              // 👇 Member name
              Expanded(
                child: Text(
                  member['name'].toString(),
                  overflow: TextOverflow.ellipsis,
                  style: AppFont.smallText10(context),
                ),
              ),
            ],
          ),
        ),
        Text(
          member['incoming'].toString(),
          style: AppFont.smallText10(context),
        ),
        Text(
          member['outgoing'].toString(),
          style: AppFont.smallText10(context),
        ),
        Text(
          member['connected'].toString(),
          style: AppFont.smallText10(context),
        ),
        Text(
          member['duration'].toString(),
          style: AppFont.smallText10(context),
        ),
        Text(
          member['declined'].toString(),
          style: AppFont.smallText10(context),
        ),
      ]);
    }).toList();
  }

  // teams comparison table
  List<TableRow> _buildMemberRowsTeams() {
    List<dynamic> dataToDisplay;
    final List<Color> _bgColors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.purpleAccent,
    ];

    Color getRandomColor(String name) {
      final int hash = name.codeUnits.fold(0, (prev, el) => prev + el);
      return _bgColors[hash % _bgColors.length].withOpacity(0.8);
    }

    CircleAvatar buildAvatar(Map<String, dynamic> member) {
      final String? imageUrl = member['profileImage'];
      final String initials =
          (member['name'] ?? member['name'] ?? '').toString().trim().isNotEmpty
          ? (member['name'] ?? member['name'] ?? '')
                .toString()
                .trim()
                .substring(0, 1)
                .toUpperCase()
          : '?';

      final String colorSeed = (member['name'] ?? member['name'] ?? '')
          .toString();

      return CircleAvatar(
        radius: 12,
        backgroundColor: (imageUrl == null || imageUrl.isEmpty)
            ? getRandomColor(colorSeed)
            : Colors.transparent,
        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
            ? NetworkImage(imageUrl)
            : null,
        child: (imageUrl == null || imageUrl.isEmpty)
            ? Text(
                initials,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }

    if (_isComparing && _teamComparisonData.isNotEmpty) {
      dataToDisplay = _teamComparisonData;
      print('📊 Using team comparison data: ${dataToDisplay.length} members');
    } else if (_isComparing && selectedUserIds.isNotEmpty) {
      dataToDisplay = _membersData.where((member) {
        return selectedUserIds.contains(member['user_id'].toString());
      }).toList();
      print('📊 Using filtered members data: ${dataToDisplay.length} members');
    } else {
      dataToDisplay = _membersData;
      print('📊 Using regular members data: ${dataToDisplay.length} members');
    }

    if (dataToDisplay.isEmpty) {
      return [];
    }

    int safeDisplayCount = math.max(
      0,
      math.min(_currentDisplayCount, dataToDisplay.length),
    );
    List<dynamic> displayMembers = dataToDisplay
        .take(safeDisplayCount)
        .toList();

    return displayMembers.asMap().entries.map((entry) {
      int index = entry.key;
      var member = entry.value;

      if (member == null) return TableRow(children: List.filled(7, Text('')));

      bool isSelected = selectedUserIds.contains(
        member['user_id']?.toString() ?? '',
      );

      return _buildTableRow([
        InkWell(
          onTap: () {
            // Your existing navigation logic
          },
          child: Row(
            children: [
              Stack(children: [buildAvatar(member)]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  member['name'].toString(),
                  overflow: TextOverflow.ellipsis,
                  style: AppFont.smallText10(context),
                ),
              ),
            ],
          ),
        ),
        Text(
          member['enquiries'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          member['testDrives'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          member['orders'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          member['cancellation'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          member['net_orders'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          member['retail'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ]);
    }).toList();
  }

  Widget _buildShowMoreButtonTeamComparison() {
    List<dynamic> dataToDisplay;

    if (_isComparing &&
        selectedUserIds.isNotEmpty &&
        _teamComparisonData.isNotEmpty) {
      dataToDisplay = _teamComparisonData;
    } else if (_isComparing && selectedUserIds.isNotEmpty) {
      dataToDisplay = _membersData.where((member) {
        return selectedUserIds.contains(member['user_id'].toString());
      }).toList();
    } else {
      dataToDisplay = _membersData;
    }

    // Add this check - if no data, don't show anything
    // Check if there's actually data to display
    if (dataToDisplay.isEmpty) {
      return const SizedBox.shrink();
    }

    // Also check if current display count is valid
    if (_currentDisplayCount <= 0) {
      return const SizedBox.shrink();
    }

    // Check if we can show more records
    bool hasMoreRecords = _currentDisplayCount < dataToDisplay.length;

    // Check if we can show less records - only if we're showing more than initial count
    bool canShowLess =
        _currentDisplayCount > _incrementCount &&
        _currentDisplayCount >= dataToDisplay.length;

    // If no action is possible, don't show button
    if (!hasMoreRecords && !canShowLess) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Show Less button - only when all data is displayed and we can reduce
          if (canShowLess)
            TextButton(
              onPressed: _loadLessRecords,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Show Less'),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_up, size: 16),
                ],
              ),
            ),

          // Show More button - only when there are more records to show
          if (hasMoreRecords)
            TextButton(
              onPressed: _loadMoreRecords,
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Show More (${dataToDisplay.length - _currentDisplayCount} more)',
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to get the number of records to show
  int _getRecordsToShow(List<dynamic> dataToDisplay) {
    int remainingRecords = dataToDisplay.length - _currentDisplayCount;
    return math.min(_incrementCount, remainingRecords);
  }

  TableRow _buildTableRow(List<Widget> widgets) {
    return TableRow(
      children: widgets.map((widget) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0),
          child: widget, // Use the widget directly here
        );
      }).toList(),
    );
  }

  // Individual metric card
  Widget _buildMetricCard(
    String value,
    String label,
    Color valueColor, {
    bool isSelected = false,
    Color backgroundColor = Colors.white,
    Color textColor = Colors.black,
    bool isUserSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.5, horizontal: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isSelected && !isUserSelected && _selectedType == 'All')
              ? Colors.transparent
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, // Left align content
        children: [
          Text(
            value,
            textAlign: TextAlign.left, // Align text left
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,

              color: backgroundColor == Colors.white ? valueColor : textColor,
            ),
          ),
          const SizedBox(height: 2), // 2px vertical spacing
          Text(
            label,
            textAlign: TextAlign.left, // Align text left
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textColor.withOpacity(0.7),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // Upcoming Activities Section
  // Widget _buildUpcomingActivities(BuildContext context) {
  //   return Container(
  //     margin: const EdgeInsets.all(10),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.only(bottom: 0),
  //           child: Row(
  //             children: [
  //               // const SizedBox(height: 10),
  //               Container(
  //                 margin: const EdgeInsets.only(bottom: 10, top: 5),
  //                 width: 180,
  //                 height: 30,
  //                 decoration: BoxDecoration(
  //                   border: Border.all(
  //                     color: AppColors.arrowContainerColor,
  //                     width: .5,
  //                   ),
  //                   borderRadius: BorderRadius.circular(30),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     _buildFilterButton(
  //                       index: 0,
  //                       text: 'Upcoming',
  //                       activeColor: AppColors.borderGreen,
  //                     ),
  //                     _buildFilterButton(
  //                       index: 1,
  //                       text: 'Overdue ($overdueCount)',
  //                       activeColor: AppColors.borderRed,
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         if (_upcomingFollowups.isNotEmpty)
  //           _buildActivitySection(context, _upcomingFollowups, 'due_date'),
  //         if (_upcomingAppointments.isNotEmpty)
  //           _buildActivitySection(context, _upcomingAppointments, 'start_date'),
  //         if (_upcomingTestDrives.isNotEmpty)
  //           _buildActivitySection(context, _upcomingTestDrives, 'start_date'),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildUpcomingActivities(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Row(
              children: [
                IntrinsicWidth(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10, top: 5),
                    constraints: const BoxConstraints(
                      minWidth: 180, // Minimum width
                      maxWidth: 300, // Maximum width to prevent overflow
                    ),
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.arrowContainerColor,
                        width: .5,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterButton(
                          index: 0,
                          text: 'Upcoming',
                          activeColor: AppColors.borderGreen,
                        ),
                        _buildFilterButton(
                          index: 1,
                          text: 'Overdue ($overdueCount)',
                          activeColor: AppColors.borderRed,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_upcomingFollowups.isNotEmpty)
            _buildActivitySection(context, _upcomingFollowups, 'due_date'),
          if (_upcomingAppointments.isNotEmpty)
            _buildActivitySection(context, _upcomingAppointments, 'start_date'),
          if (_upcomingTestDrives.isNotEmpty)
            _buildActivitySection(context, _upcomingTestDrives, 'start_date'),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required int index,
    required String text,
    required Color activeColor,
  }) {
    return Expanded(
      child: TextButton(
        onPressed: () {
          setState(() {
            _upcommingButtonIndex = index;

            // ✅ Prevent clearing if no user is selected
            if (_selectedProfileIndex == 0) return;

            final selectedUserPerformance =
                _teamData['selectedUserPerformance'] ?? {};

            final upcoming = selectedUserPerformance['Upcoming'] ?? {};
            final overdue = selectedUserPerformance['Overdue'] ?? {};

            if (_upcommingButtonIndex == 0) {
              _upcomingFollowups = List<Map<String, dynamic>>.from(
                upcoming['upComingFollowups'] ?? [],
              );
              _upcomingAppointments = List<Map<String, dynamic>>.from(
                upcoming['upComingAppointment'] ?? [],
              );
              _upcomingTestDrives = List<Map<String, dynamic>>.from(
                upcoming['upComingTestDrive'] ?? [],
              );
            } else {
              _upcomingFollowups = List<Map<String, dynamic>>.from(
                overdue['overdueFollowups'] ?? [],
              );
              _upcomingAppointments = List<Map<String, dynamic>>.from(
                overdue['overdueAppointments'] ?? [],
              );
              _upcomingTestDrives = List<Map<String, dynamic>>.from(
                overdue['overdueTestDrives'] ?? [],
              );

              // overdueCount = overdue['count']?.length ?? 0;
              overdueCount =
                  _upcomingFollowups.length +
                  _upcomingAppointments.length +
                  _upcomingTestDrives.length;
            }
          });
        },
        style: TextButton.styleFrom(
          backgroundColor: _upcommingButtonIndex == index
              ? activeColor.withOpacity(0.29)
              : Colors.transparent,
          foregroundColor: _upcommingButtonIndex == index
              ? activeColor
              : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
          side: BorderSide(
            color: _upcommingButtonIndex == index
                ? activeColor
                : Colors.transparent,
            width: .5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            color: _upcommingButtonIndex == index
                ? activeColor.withOpacity(0.89)
                : AppColors.iconGrey,
          ),
        ),
      ),
    );
  }

  // Activity section builder
  Widget _buildActivitySection(
    BuildContext context,
    List<Map<String, dynamic>> activities,
    // String label,
    String dateKey,

    // bool hasAvtivities = activities.isNotEmpty,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: _buildFollowupCard(
                  context,
                  name: activity['name'] ?? '',
                  subject: activity['subject'] ?? '',
                  date: activity[dateKey] ?? '',
                  leadId: activity['lead_id'] ?? '',
                  vehicle: activity['PMI'] ?? '',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFollowupCard(
    BuildContext context, {
    required String name,
    required String subject,
    required String date,
    required String leadId,
    required String vehicle,
    // required String userId,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: const Border(
          left: BorderSide(width: 8.0, color: AppColors.colorsBlue),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    // crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * .30,
                        ),
                        child: Text(
                          name,
                          maxLines: 1, // Allow up to 2 lines
                          overflow: TextOverflow
                              .ellipsis, // Show ellipsis if it overflows beyond 2 lines
                          softWrap: true,
                          style: AppFont.dashboardName(context),
                        ),
                      ),
                      // SizedBox(width: 5),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        height: 15,
                        width: 0.1,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppColors.fontColor),
                          ),
                        ),
                      ),
                      if (vehicle.isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * .30,
                          ),
                          child: Text(
                            vehicle,
                            style: AppFont.dashboardCarName(context),
                            maxLines: 1, // Allow up to 2 lines
                            overflow: TextOverflow
                                .ellipsis, // Show ellipsis if it overflows beyond 2 lines
                            softWrap: true, // Allow wrapping
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(subject, style: AppFont.smallText10(context)),
                      _formatDate(context, date),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (leadId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamsEnquiryids(
                      leadId: leadId,
                      userId: _selectedUserId,
                    ),
                  ),
                );
              } else {
                print("Invalid leadId");
              }
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.arrowContainerColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 25,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatDate(BuildContext context, String dateStr) {
    String formattedDate = '';

    try {
      DateTime parseDate = DateTime.parse(dateStr);

      // Check if the date is today
      if (parseDate.year == DateTime.now().year &&
          parseDate.month == DateTime.now().month &&
          parseDate.day == DateTime.now().day) {
        formattedDate = 'Today';
      } else {
        // If not today, format it as "26th March"
        int day = parseDate.day;
        String suffix = _getDaySuffix(day);
        String month = DateFormat('MMM').format(parseDate); // Full month name
        formattedDate = '${day}$suffix $month';
      }
    } catch (e) {
      formattedDate = dateStr; // Fallback if date parsing fails
    }

    return Row(
      children: [
        const SizedBox(width: 5),
        Text(formattedDate, style: AppFont.smallText10(context)),
      ],
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildVerticalDivider(double height) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3, left: 10, right: 10),
      height: height,
      width: 0.1,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.fontColor)),
      ),
    );
  }

  // Individual activity card
  Widget _buildActivityCard(
    BuildContext context, {
    required String name,
    required String subject,
    required String date,
    required String leadId,
    required String vehicle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: const Border(
          left: BorderSide(width: 8.0, color: AppColors.colorsBlue),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(name, style: AppFont.dashboardName(context)),
                      // if (vehicle.isNotEmpty) _buildVerticalDivider(15),
                      if (vehicle.isNotEmpty)
                        Text(
                          vehicle,
                          style: AppFont.dashboardCarName(context),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(subject, style: AppFont.smallText(context)),
                      // _formatDate(context, date),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (leadId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FollowupsDetails(
                      leadId: leadId,
                      isFromFreshlead: false,
                      isFromManager: true,
                      refreshDashboard: () async {},
                      isFromTestdriveOverview: false,
                    ),
                  ),
                );
              } else {
                print("Invalid leadId");
              }
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.arrowContainerColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 25,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppFont.appbarfontblack(context)),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppFont.mediumText14(context).copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
