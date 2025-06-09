import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/config/controller/tab_controller.dart';
import 'package:smartassist/config/getX/fab.controller.dart';
import 'package:smartassist/pages/Leads/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/pages/Leads/single_details_pages/teams_enquiryIds.dart';
import 'package:smartassist/pages/navbar_page/call_analytics.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/home_btn.dart/teams_popups.dart/appointment_teams.dart';
import 'package:smartassist/widgets/home_btn.dart/teams_popups.dart/createTeam.dart';
import 'package:smartassist/widgets/home_btn.dart/teams_popups.dart/followups_teams.dart';
import 'package:smartassist/widgets/home_btn.dart/teams_popups.dart/lead_teams.dart';
import 'package:smartassist/widgets/home_btn.dart/teams_popups.dart/testdrive_teams.dart';
import 'package:smartassist/widgets/team_calllog_userid.dart';
import 'package:azlistview/azlistview.dart';

class MyTeams extends StatefulWidget {
  const MyTeams({Key? key}) : super(key: key);

  @override
  State<MyTeams> createState() => _MyTeamsState();
}

class _MyTeamsState extends State<MyTeams> {
  // ADD THESE VARIABLES TO YOUR CLASS
  int _currentDisplayCount = 10; // Initially show 10 records
  static const int _incrementCount = 10; // Show 10 more each time
  List<dynamic> _teamComparisonData = [];
  // Your existing variables
  // List<dynamic> _membersData = []; // Your existing data list

  final ScrollController _scrollController = ScrollController();
  String _selectedLetter = '';
  List<Map<String, dynamic>> _filteredByLetter = [];

  // Tab and filter state
  int _tabIndex = 0; // 0 for Individual Performance, 1 for Team Comparison
  int _periodIndex = 0; // ALL, MTD, QTD, YTD
  int _metricIndex = 0; // Selected metric for comparison
  int _selectedProfileIndex = 0; // Default to 'All' profile
  String _selectedUserId = '';
  bool _isComparing = false;
  int count = 0;
  // String userId = '';
  // bool isLoading = false;
  // String _selectedCheckboxIds = '';
  String _selectedType = 'All';
  Map<String, dynamic> _individualPerformanceData = {};

  Set<String> _selectedCheckboxIds = {}; //remove this
  List<Map<String, dynamic>> selectedItems = [];
  Set<String> selectedUserIds = {};
  // String? selectedUserIds;

  late TabControllerNew _tabController;
  Set<String> _selectedLetters = {}; // Replace String _selectedLetter
  bool _isMultiSelectMode = false;
  int _upcommingButtonIndex = 0;

  bool isHideAllcall = false;
  bool isHideActivities = false;
  bool isHide = false;
  bool isHideCalls = false;
  bool isSingleCall = false;
  bool isHideCheckbox = false;
  // Data state
  bool isLoading = false;
  Map<String, dynamic> _teamData = {};
  Map<String, dynamic> _selectedUserData = {};
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

  // Controller for FAB
  final FabController fabController = Get.put(FabController());

  @override
  void initState() {
    super.initState();
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
      Get.snackbar(
        'Error',
        'Failed to load team data',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
      _currentDisplayCount = math.min(
        _currentDisplayCount + _incrementCount,
        _membersData.length,
      );
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
      // setState(() {
      //   _isLoading = true;
      // });

      final token = await Storage.getToken();

      // Determine period parameter based on selection
      String? periodParam;
      switch (_periodIndex) {
        // case 0:
        //   periodParam = 'DAY';
        //   break;
        // case 1:
        //   periodParam = 'WEEK' ;
        //   break;
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

      // ✅ Add userId to query parameters if it's available
      if (_selectedUserId.isNotEmpty) {
        queryParams['userId'] = _selectedUserId;
      }

      // ✅ Fixed: Use the correct base URL without concatenating userId
      final baseUri = Uri.parse(
        'https://api.smartassistapp.in/api/users/sm/dashboard/individual/call-analytics',
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
      print('this is single response ${uri}');
      print('📤 Fetching from single: $uri');

      print('📥 Call Analytics Status Code: ${response.statusCode}');
      print('📥 Call Analytics Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Check if the widget is still in the widget tree before calling setState
        if (mounted) {
          setState(() {
            _dashboardData = jsonData['data'];
            _enquiryData = jsonData['data']['summaryEnquiry'];
            _coldCallData = jsonData['data']['summaryColdCalls'];
            // _isLoading = false;
          });
        }
      } else {
        // Handle unsuccessful status codes
        throw Exception(
          'Failed to load dashboard data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Check if the widget is still in the widget tree before calling setState
      // if (mounted) {
      //   setState(() {
      //     _isLoading = false;
      //   });
      // }

      // Handle different types of errors
      if (e is http.ClientException) {
        debugPrint('Network error: $e');
      } else if (e is FormatException) {
        debugPrint('Error parsing data: $e');
      } else {
        debugPrint('Unexpected error: $e');
      }
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
        // case 1:
        //   periodParam = 'DAY';
        //   break;
        // case 2:
        //   periodParam = 'WEEK';
        //   break;
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
  // Future<void> _fetchAllCalllog() async {
  //   setState(() {
  //     isLoading = true;
  //   });

  //   try {
  //     final data = await LeadsSrv.fetchAllCalllog(periodIndex: _periodIndex);
  //     setState(() {
  //       _analyticsData = data['analyticsData'];
  //       _membersData = data['membersData'];
  //       isLoading = false;
  //     });
  //   } catch (e) {
  //     print('Error: $e');
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  // Fetch team details using the new API endpoint
  Future<void> _fetchTeamDetails() async {
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

      // 🔥 REMOVE THE DUPLICATE LOGIC - Only keep this single user selection logic
      // ❌ REMOVED: Duplicate user_id logic that was causing the issue
      // if (_selectedProfileIndex != 0 && _selectedUserId.isNotEmpty) {
      //   queryParams['user_id'] = _selectedUserId;
      // }

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
      // ✅ If "All" is selected (_selectedProfileIndex == 0), no user parameters are added

      final baseUri = Uri.parse(
        'https://api.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
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

          // teams comparison
          if (_teamData.containsKey('teamComparsion')) {
            _teamComparisonData = List<dynamic>.from(
              _teamData['teamComparsion'] ?? [],
            );
            print('📊 Team Comparison Data: $_teamComparisonData');
          } else {
            _teamComparisonData = [];
          }

          // Save total performance
          if (_teamData.containsKey('totalPerformance')) {
            _selectedUserData['totalPerformance'] =
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
            _selectedUserData['totalPerformance'] =
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
            }
          }
        });
      } else {
        throw Exception('Failed to fetch team details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching team details: $e');
    }
  }

  // Future<void> _fetchTeamDetails() async {
  //   try {
  //     final token = await Storage.getToken();

  //     // Build period parameter
  //     String? periodParam;
  //     switch (_periodIndex) {
  //       // case 0:
  //       //   periodParam = 'DAY';
  //       //   break;
  //       // case 1:
  //       //   periodParam = 'WEEK';
  //       //   break;
  //       case 1:
  //         periodParam = 'MTD';
  //         break;
  //       case 0:
  //         periodParam = 'QTD';
  //         break;
  //       case 2:
  //         periodParam = 'YTD';
  //         break;
  //       default:
  //         periodParam = 'QTD';
  //     }

  //     final Map<String, String> queryParams = {};

  //     if (periodParam != null) {
  //       queryParams['type'] = periodParam;
  //     }

  //     final targetMetric = [
  //       'target_enquiries',
  //       'target_testDrives',
  //       'target_orders',
  //       'target_cancellation',
  //       'target_netOrders',
  //       'target_retail',
  //     ];

  //     // Define summary metrics (moved outside to be available for both cases)
  //     final summaryMetrics = [
  //       'enquiries',
  //       'testDrives',
  //       'orders',
  //       'cancellation',
  //       'netOrders',
  //       'retail',
  //     ];
  //     final summaryParam = summaryMetrics[_metricIndex];
  //     final targetParam = targetMetric[_metricIndex];

  //     // ✅ Add summary parameter for both All and specific user selection
  //     queryParams['summary'] = summaryParam;
  //     queryParams['target'] = targetParam;
  //     // ✅ Only add user_id if a specific user is selected (not for "All")
  //     if (_selectedProfileIndex != 0 && _selectedUserId.isNotEmpty) {
  //       queryParams['user_id'] = _selectedUserId;
  //     }

  //     // Add userIds if checkboxes are selected
  //     // ✅ If comparison mode is OFF (only single user is selected), pass user_id
  //     // if (!_isComparing &&
  //     //     _selectedProfileIndex != 0 &&
  //     //     _selectedUserId.isNotEmpty) {
  //     //   queryParams['user_id'] = _selectedUserId;
  //     // }
  //     // 🔥 MODIFIED LOGIC: Handle user selection based on comparison mode
  //     if (_isComparing && selectedUserIds.isNotEmpty) {
  //       // ✅ If comparison mode is ON, ONLY pass userIds (remove user_id)
  //       queryParams['userIds'] = selectedUserIds.join(',');
  //     } else if (!_isComparing &&
  //         _selectedProfileIndex != 0 &&
  //         _selectedUserId.isNotEmpty) {
  //       // ✅ If comparison mode is OFF and specific user is selected, pass user_id
  //       queryParams['user_id'] = _selectedUserId;
  //     }

  //     // ✅ If comparison mode is ON, pass all selected user IDs
  //     // if (_isComparing && selectedUserIds.isNotEmpty) {
  //     //   queryParams['userIds'] = selectedUserIds.join(',');
  //     // }
  //     // if (selectedUserIds.isNotEmpty) {
  //     //   queryParams['userIds'] = selectedUserIds.join(',');
  //     // }

  //     final baseUri = Uri.parse(
  //       'https://api.smartassistapp.in/api/users/sm/dashboard/team-dashboard',
  //     );

  //     final uri = baseUri.replace(queryParameters: queryParams);

  //     print('📤 Fetching from: $uri');

  //     final response = await http.get(
  //       uri,
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     print('📥 Status Code: ${response.statusCode}');
  //     print('📥 Response: ${response.body}');

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);

  //       setState(() {
  //         _teamData = data['data'] ?? {};

  //         // Save total performance
  //         if (_teamData.containsKey('totalPerformance')) {
  //           _selectedUserData['totalPerformance'] =
  //               _teamData['totalPerformance'];
  //         }

  //         if (_teamData.containsKey('allMember') &&
  //             _teamData['allMember'].isNotEmpty) {
  //           _teamMembers = [];

  //           for (var member in _teamData['allMember']) {
  //             _teamMembers.add({
  //               'fname': member['fname'] ?? '',
  //               'lname': member['lname'] ?? '',
  //               'user_id': member['user_id'] ?? '',
  //               'profile': member['profile'],
  //               'initials': member['initials'] ?? '',
  //             });
  //           }
  //         }

  //         if (_selectedProfileIndex == 0) {
  //           // Summary data
  //           _selectedUserData = _teamData['summary'] ?? {};
  //           _selectedUserData['totalPerformance'] =
  //               _teamData['totalPerformance'] ?? {};
  //         } else if (_selectedProfileIndex - 1 < _teamMembers.length) {
  //           // Specific user selected
  //           final selectedMember = _teamMembers[_selectedProfileIndex - 1];
  //           _selectedUserData = selectedMember;

  //           final selectedUserPerformance =
  //               _teamData['selectedUserPerformance'] ?? {};
  //           final upcoming = selectedUserPerformance['Upcoming'] ?? {};
  //           final overdue = selectedUserPerformance['Overdue'] ?? {};

  //           if (_upcommingButtonIndex == 0) {
  //             _upcomingFollowups = List<Map<String, dynamic>>.from(
  //               upcoming['upComingFollowups'] ?? [],
  //             );
  //             _upcomingAppointments = List<Map<String, dynamic>>.from(
  //               upcoming['upComingAppointment'] ?? [],
  //             );
  //             _upcomingTestDrives = List<Map<String, dynamic>>.from(
  //               upcoming['upComingTestDrive'] ?? [],
  //             );
  //           } else {
  //             _upcomingFollowups = List<Map<String, dynamic>>.from(
  //               overdue['overdueFollowups'] ?? [],
  //             );
  //             _upcomingAppointments = List<Map<String, dynamic>>.from(
  //               overdue['overdueAppointments'] ?? [],
  //             );
  //             _upcomingTestDrives = List<Map<String, dynamic>>.from(
  //               overdue['overdueTestDrives'] ?? [],
  //             );
  //           }
  //         }
  //       });
  //     } else {
  //       throw Exception('Failed to fetch team details: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error fetching team details: $e');
  //   }
  // }

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
        backgroundColor: Colors.blue,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('My Team', style: AppFont.appbarfontWhite(context)),
            if (selectedUserIds.length >= 2)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextButton(
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all<EdgeInsets>(
                        EdgeInsets.zero,
                      ),
                    ),

                    onPressed: () {
                      setState(() {
                        _isComparing = true;
                      });
                      _fetchTeamDetails();
                    },
                    child: Text(
                      'Compare',
                      style: AppFont.mediumText14white(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchTeamDetails,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      controller: fabController.scrollController,
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
                            if (!_isComparing)
                              _buildIndividualPerformanceTab(
                                context,
                                screenWidth,
                              ),
                            const SizedBox(height: 10),
                            _buildTeamComparisonTab(context, screenWidth),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // FAB Button animation
          Obx(
            () => AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: fabController.isFabVisible.value ? 26 : -80,
              right: 18,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: fabController.isFabVisible.value ? 1.0 : 0.0,
                child: _buildFloatingActionButton(context),
              ),
            ),
          ),

          // FAB Popup menu
          Obx(
            () =>
                fabController.isFabExpanded.value &&
                    fabController.isFabVisible.value
                ? _buildPopupMenu(context)
                : const SizedBox.shrink(),
          ),
        ],
      ),

      // body: Stack(
      //   children: [
      //     isLoading
      //         ? const Center(child: CircularProgressIndicator())
      //         : SingleChildScrollView(
      //             controller: fabController.scrollController,
      //             child: Container(
      //               color: Colors.white,
      //               padding: const EdgeInsets.all(10.0),
      //               child: Column(
      //                 crossAxisAlignment: CrossAxisAlignment.start,
      //                 children: [
      //                   SingleChildScrollView(
      //                     scrollDirection: Axis.horizontal,
      //                     child: Row(
      //                       children: [
      //                         // _buildProfileAvatarStaticsAll('All', 0),
      //                         _buildProfileAvatars(),
      //                       ],
      //                     ),
      //                   ),

      //                   // Vertical scrollbar only - no item display needed
      //                   const SizedBox(height: 10),

      //                   // Individual Performance content
      //                   if (!_isComparing)
      //                     _buildIndividualPerformanceTab(context, screenWidth),

      //                   // _buildIndividualPerformanceTab(context, screenWidth),
      //                   const SizedBox(height: 10),

      //                   // Team Comparison content
      //                   _buildTeamComparisonTab(context, screenWidth),

      //                   const SizedBox(height: 10),
      //                 ],
      //               ),
      //             ),
      //           ),

      //     // Replace your current Positioned widget with:
      //     Obx(
      //       () => AnimatedPositioned(
      //         duration: const Duration(milliseconds: 300),
      //         curve: Curves.easeInOut,
      //         bottom: fabController.isFabVisible.value ? 26 : -80,
      //         right: 18,
      //         child: AnimatedOpacity(
      //           duration: const Duration(milliseconds: 300),
      //           opacity: fabController.isFabVisible.value ? 1.0 : 0.0,
      //           child: _buildFloatingActionButton(context),
      //         ),
      //       ),
      //     ),

      //     // Update your popup menu condition:
      //     Obx(
      //       () =>
      //           fabController.isFabExpanded.value &&
      //               fabController.isFabVisible.value
      //           ? _buildPopupMenu(context)
      //           : const SizedBox.shrink(),
      //     ),
      //   ],
      // ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return Obx(
      () => GestureDetector(
        onTap: fabController.toggleFab,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: MediaQuery.of(context).size.width * .15,
          height: MediaQuery.of(context).size.height * .08,
          decoration: BoxDecoration(
            color: fabController.isFabExpanded.value
                ? Colors.red
                : AppColors.colorsBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedRotation(
              turns: fabController.isFabExpanded.value ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                fabController.isFabExpanded.value ? Icons.close : Icons.add,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Popup Item Builder
  Widget _buildPopupItem(
    IconData icon,
    String label,
    double offsetY, {
    required Function() onTap,
  }) {
    return Obx(
      () => TweenAnimationBuilder(
        tween: Tween<double>(
          begin: 0,
          end: fabController.isFabExpanded.value ? 1 : 0,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, double value, child) {
          return Transform.translate(
            offset: Offset(0, offsetY * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.colorsBlue,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAppointmentPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero, // Remove default padding
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
            ), // Add margin for better UX
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppointmentTeams(onFormSubmit: () {}), // Appointment modal
          ),
        );
      },
    );
  }

  void _showCreateteamPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero, // Remove default padding
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
            ), // Add margin for better UX
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Createteam(
              // onFormSubmit: () {},
            ), // Appointment modal
          ),
        );
      },
    );
  }

  void _showTestdrivePopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero, // Remove default padding
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
            ), // Add margin for better UX
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TestdriveTeams(onFormSubmit: () {}), // Appointment modal
          ),
        );
      },
    );
  }

  void _showLeadPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
            ), // Add some margin for better UX
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: LeadTeams(onFormSubmit: () {}),
          ),
        );
      },
    );
  }

  void _showFollowupPopup(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FollowupsTeams(
              onFormSubmit: () {}, // Pass the function here
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return GestureDetector(
      onTap: fabController.closeFab,
      child: Stack(
        children: [
          // Background overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),

          // Popup Items Container aligned bottom right
          Positioned(
            bottom: 80,
            right: 18,
            child: SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPopupItem(
                    Icons.calendar_month_outlined,
                    "Appointment",
                    -80,
                    onTap: () {
                      fabController.closeFab();
                      _showAppointmentPopup(context);
                    },
                  ),
                  // _buildPopupItem(Icons.people, "My teams", -60, onTap: () {
                  //   fabController.closeFab();
                  //   _showCreateteamPopup(context);
                  // }),
                  _buildPopupItem(
                    Icons.receipt_long_rounded,
                    "Enquiry",
                    -60,
                    onTap: () {
                      fabController.closeFab();
                      _showLeadPopup(context);
                    },
                  ),
                  _buildPopupItem(
                    Icons.call,
                    "Followup",
                    -40,
                    onTap: () {
                      fabController.closeFab();
                      _showFollowupPopup(context);
                    },
                  ),
                  _buildPopupItem(
                    Icons.directions_car,
                    "Test Drive",
                    -20,
                    onTap: () {
                      fabController.closeFab();
                      _showTestdrivePopup(context);
                    },
                  ),
                ],
              ),
            ),
          ),

          // ✅ FAB positioned above the overlay
          Positioned(
            bottom: 20,
            right: 15,
            child: _buildFloatingActionButton(context),
          ),
        ],
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

      // Add visual separator before members
      if (letterMembers.isNotEmpty) {
        widgets.add(
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }

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

      // Add visual separator after members if there are more letters coming
      if (letterMembers.isNotEmpty) {
        widgets.add(
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1),
            ),
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
                  }
                } else {
                  _selectedLetters.add(letter);
                  _selectedType = 'Letter';
                }
              } else {
                // Single select mode - but keep existing selections and add new one
                if (isSelected) {
                  // If clicking same letter, deselect it
                  _selectedLetters.remove(letter);
                  if (_selectedLetters.isEmpty) {
                    _selectedType = 'All';
                  }
                } else {
                  // Add this letter to selection (don't clear existing)
                  _selectedLetters.add(letter);
                  _selectedType = 'Letter';
                }
              }

              _selectedProfileIndex = -1;
            });
            _fetchTeamDetails();
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
                      ? Colors.blue.withOpacity(0.15)
                      : AppColors.backgroundLightGrey,
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2.5)
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
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.grey.shade600,
                    ),
                    child: Text(letter),
                  ),
                ),
              ),
              // Multi-select indicator with animation
              if (_isMultiSelectMode && isSelected)
                Positioned(
                  top: -2,
                  right: 3,
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppFont.mediumText14(context).copyWith(
            color: isSelected ? Colors.blue : null,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          child: Text(letter),
        ),
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
              _selectedLetters.clear(); // Clear all letter selections
              _isMultiSelectMode = false; // Exit multi-select mode

              if (!_isComparing) {
                _clearAllSelections();
              }
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
                  color: isSelected
                      ? Colors.blue.withOpacity(0.15)
                      : AppColors.backgroundLightGrey,
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2.5)
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
                          ? Icons.clear_all
                          : (isSelected ? Icons.groups : Icons.people),
                      key: ValueKey(
                        _isMultiSelectMode
                            ? 'clear'
                            : (isSelected ? 'groups' : 'people'),
                      ),
                      color: isSelected ? Colors.blue : Colors.grey.shade400,
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
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // InkWell(
        //   onTap: () async {
        //     setState(() {
        //       _selectedProfileIndex = index;
        //       _selectedType = 'All';
        //       _selectedLetters.clear(); // Clear all letter selections
        //       _isMultiSelectMode = false; // Exit multi-select mode
        //       _metricIndex = 0;
        //       if (!_isComparing) {
        //         _clearAllSelections();
        //       }
        //     });
        //     // await _fetchAllCalllog();
        //     await _fetchTeamDetails();
        //   },
        //   child: AnimatedDefaultTextStyle(
        //     duration: const Duration(milliseconds: 200),
        //     style: AppFont.mediumText14(context).copyWith(
        //       color: isSelected
        //           ? Colors.blue
        //           : (_isMultiSelectMode ? Colors.orange : null),
        //       fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        //     ),
        //     child: Text(_isMultiSelectMode ? 'Reset' : 'Alls '),
        //   ),
        // ),
        InkWell(
          onTap: () async {
            try {
              // First: update selection state only
              _selectedProfileIndex = index;
              _selectedType = 'All';
              _selectedLetters.clear();
              _isMultiSelectMode = false;
              _metricIndex = 0;
              if (!_isComparing) {
                _clearAllSelections();
              }

              // Wait for data fetch
              await _fetchTeamDetails();

              // Then: rebuild the UI with new data
              setState(() {});
            } catch (e) {
              print('Error fetching team details: $e');
            }
          },

          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppFont.mediumText14(context).copyWith(
              color: isSelected
                  ? Colors.blue
                  : (_isMultiSelectMode ? Colors.orange : null),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            child: Text(
              _isMultiSelectMode ? 'Reset' : 'All',
            ), // Fixed typo 'Alls '
          ),
        ),
        // InkWell(
        //   onTap: () {
        //     if (!_isComparing) {
        //       _clearAllSelections();
        //     }
        //   },
        //   child: AnimatedDefaultTextStyle(
        //     duration: const Duration(milliseconds: 200),
        //     style: AppFont.mediumText14(context).copyWith(
        //       color: isSelected
        //           ? Colors.blue
        //           : (_isMultiSelectMode ? Colors.orange : null),
        //       fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        //     ),
        //     child: Text(_isMultiSelectMode ? 'Reset' : 'All'),
        //   ),
        // ),
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
              await _fetchTeamDetails();
            }
          },

          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 5, 0),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.backgroundLightGrey,
              border: isSelectedForComparison
                  ? Border.all(color: Colors.green, width: 3)
                  : _selectedProfileIndex == index
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: ClipOval(
              child: isSelectedForComparison
                  ? const Icon(Icons.check, color: Colors.white)
                  : (profileUrl != null && profileUrl.isNotEmpty)
                  ? Image.network(
                      profileUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            initials.toUpperCase(),
                            style: AppFont.appbarfontblack(context),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        initials.toUpperCase(),
                        style: AppFont.appbarfontblack(context),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(firstName, style: AppFont.mediumText14(context)),
        const SizedBox(height: 8),
      ],
    );
  }

  // Widget _buildProfileAvatars() {
  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     child: Container(
  //       margin: const EdgeInsets.only(top: 10),
  //       height: 90,
  //       padding: const EdgeInsets.symmetric(horizontal: 0),
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           for (int i = 0; i < _teamMembers.length; i++)
  //             _buildProfileAvatar(
  //               _teamMembers[i]['fname'] ?? '',
  //               i + 1, // Starts from 1 because 0 is 'All'
  //               _teamMembers[i]['user_id'] ?? '',
  //               _teamMembers[i]['profile'], // Pass the profile URL
  //               _teamMembers[i]['initials'] ?? '', // Pass the initials
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Individual profile avatar saad

  // Individual Performance Tab Content
  Widget _buildIndividualPerformanceTab(
    BuildContext context,
    double screenWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundLightGrey,
              borderRadius: BorderRadius.circular(5),
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
                color: AppColors.backgroundLightGrey,
                borderRadius: BorderRadius.circular(10),
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
                          style: AppFont.dropDowmLabel(context),
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
                color: AppColors.backgroundLightGrey,
                borderRadius: BorderRadius.circular(10),
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
                          style: AppFont.dropDowmLabel(context),
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
        // _buildPeriodFilter(screenWidth),
        // _buildMetricButtons(),
        // _buildTeamComparisonChart(context),
        if (_isComparing) _buildTeamComparisonChart(context),
        if (!_isComparing) _callAnalyticAll(context),
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
          _fetchSingleCalllog();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        decoration: BoxDecoration(
          border: Border.all(
            color: _periodIndex == index ? Colors.blue : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _periodIndex == index ? Colors.blue : Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleuserCalllog(BuildContext context) {
    return TeamCalllogUserid(
      dashboardData: _dashboardData,
      enquiryData: _enquiryData,
      coldCallData: _coldCallData,
    );
  }

  // Individual Performance Metrics Display
  // Widget _buildIndividualPerformanceMetrics(BuildContext context) {
  //   // Use selectedUserPerformance if a user is selected, else use totalPerformance
  //   final bool isUserSelected = _selectedProfileIndex != 0;

  //   // Choose appropriate stats object
  //   // final stats = isUserSelected
  //   //     ? _teamData['selectedUserPerformance'] ?? {}
  //   //     : _selectedUserData['totalPerformance'] ?? {};
  //   final stats = (_metricIndex >= 0)
  //       ? (isUserSelected
  //             ? _teamData['selectedUserPerformance'] ?? {}
  //             : _selectedUserData['totalPerformance'] ?? {})
  //       : {};

  //   final metrics = [
  //     {'label': 'Enquiries', 'key': 'enquiries'},
  //     {'label': 'Test Drive', 'key': 'testDrives'},
  //     {'label': 'Orders', 'key': 'orders'},
  //     {'label': 'Cancellations', 'key': 'cancellation'},
  //     {
  //       'label': 'Net Orders',
  //       'key': 'Net orders',
  //       // 'value': (stats['Orders'] ?? 0) - (stats['Cancellation'] ?? 0)
  //     },
  //     {'label': 'Retails', 'key': 'retail'},
  //   ];

  //   List<Widget> rows = [];
  //   for (int i = 0; i < metrics.length; i += 2) {
  //     rows.add(
  //       Row(
  //         children: [
  //           for (int j = i; j < i + 2 && j < metrics.length; j++) ...[
  //             Expanded(
  //               child: InkWell(
  //                 onTap: () {
  //                   setState(() {
  //                     _metricIndex = j;
  //                     _fetchTeamDetails(); // Refresh with selected metric
  //                   });
  //                 },
  //                 child: _buildMetricCard(
  //                   "${metrics[j].containsKey('value') ? metrics[j]['value'] : stats[metrics[j]['key']] ?? 0}",
  //                   metrics[j]['label']!,
  //                   Colors.blue,
  //                   isSelected: _metricIndex == j,
  //                 ),
  //               ),
  //             ),
  //             if (j % 2 == 0) const SizedBox(width: 12),
  //           ],
  //         ],
  //       ),
  //     );
  //     rows.add(const SizedBox(height: 12));
  //   }

  //   return Padding(
  //     padding: const EdgeInsets.all(10),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: rows,
  //     ),
  //   );
  // }

  Widget _buildIndividualPerformanceMetrics(BuildContext context) {
    final bool isUserSelected = _selectedProfileIndex != 0;

    // Choose appropriate stats object with fallback
    final stats = isUserSelected
        ? (_teamData['selectedUserPerformance'] ?? {})
        : (_selectedUserData['totalPerformance'] ?? {});
    //  final stats = (_isMultiSelectMode || _isComparing)
    //       ? (_teamData["teamComparsion"] as List<dynamic>? ?? [])
    //             .where((member) => member["isSelected"] == true)
    //             .toList()
    //       : (_teamData["teamComparsion"] as List<dynamic>? ?? []);

    // Debug print to check stats
    print('Stats for metrics: $stats, isUserSelected: $isUserSelected');

    if (stats.isEmpty) {
      print(
        'Warning: Stats is empty. _selectedUserData: $_selectedUserData, _teamData: $_teamData',
      );
    }

    final metrics = [
      {'label': 'Enquiries', 'key': 'enquiries'},
      {'label': 'Test Drive', 'key': 'testDrives'},
      {'label': 'Orders', 'key': 'orders'},
      {'label': 'Cancellations', 'key': 'cancellation'},
      {
        'label': 'Net Orders',
        'key': 'netOrders',
        'value': ((stats['orders'] ?? 0) - (stats['cancellation'] ?? 0))
            .clamp(0, double.infinity)
            .toInt(),
      },
      {'label': 'Retails', 'key': 'retail'},
    ];

    List<Widget> rows = [];
    for (int i = 0; i < metrics.length; i += 2) {
      rows.add(
        Row(
          children: [
            for (int j = i; j < i + 2 && j < metrics.length; j++) ...[
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _metricIndex = j;
                      _fetchTeamDetails(); // Refresh with selected metric
                    });
                  },
                  child: _buildMetricCard(
                    metrics[j].containsKey('value')
                        ? metrics[j]['value'].toString()
                        : (stats[metrics[j]['key']]?.toString() ?? '0'),
                    metrics[j]['label']!,
                    Colors.blue,
                    isSelected: _metricIndex == j,
                  ),
                ),
              ),
              if (j % 2 == 0) const SizedBox(width: 12),
            ],
          ],
        ),
      );
      rows.add(const SizedBox(height: 12));
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: stats.isEmpty
          ? const Center(child: Text('No data available'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
    );
  }

  // Team Comparison Chart
  Widget _buildTeamComparisonChart(BuildContext context) {
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
              onTap: () {
                setState(() {
                  isHide = !isHide;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundLightGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
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
                        style: AppFont.dropDowmLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 👇 Conditionally render chart section
            if (isHide) ...[
              if (teamData.isEmpty)
                const Center(
                  child: Text(
                    'No team data available',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                _buildTableTeamParison(), // optional extracted widget
              _buildShowMoreButtonTeamComparison(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTableTeamParison() {
    double screenWidth = MediaQuery.of(context).size.width;

    // Check if there's data to display
    bool hasData = _membersData.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: AppColors.backgroundLightGrey,
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
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                        top: 10,
                        right: 2,
                      ),
                      child: Text('Enq', style: AppFont.smallTextBold(context)),
                      // Text('Incoming',
                      //     textAlign: TextAlign.start,
                      //     style: AppFont.smallText10(context))
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                        top: 10,
                        right: 2,
                      ),
                      child: Text('TD', style: AppFont.smallTextBold(context)),
                      // Text('Incoming',
                      //     textAlign: TextAlign.start,
                      //     style: AppFont.smallText10(context))
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                        top: 10,
                        right: 2,
                      ),
                      child: Text('Ord', style: AppFont.smallTextBold(context)),
                      //  Text('Outgoing',
                      //     textAlign: TextAlign.start,
                      //     style: AppFont.smallText10(context)),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                        top: 10,
                        right: 2,
                      ),
                      child: Text('CI', style: AppFont.smallTextBold(context)),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(bottom: 10, top: 10),
                      child: Text(
                        'N-Ord',
                        style: AppFont.smallTextBold(context),
                      ),
                      // Text('Duration',
                      //     textAlign: TextAlign.start,
                      //     style: AppFont.smallText10(context)),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                        top: 10,
                        right: 0,
                      ),
                      child: Text('Rtl', style: AppFont.smallTextBold(context)),
                      //  Text('Declined',
                      //     textAlign: TextAlign.start,
                      //     style: AppFont.smallText10(context))
                    ),
                  ],
                ),
                ..._buildMemberRowsTeams(),
              ],
            )
          : _buildEmptyState(),
    );
  }

  // call ananlytics

  Widget _callAnalyticAll(BuildContext context) {
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
                  color: AppColors.backgroundLightGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            style: AppFont.dropDowmLabel(context),
                          ),
                        ),
                      ],
                    ),
                  ],
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

  Widget _buildUserStatsCard() {
    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.5), // border color
          width: 1.0, // border width
        ),
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
                  color: AppColors.homeContainerLeads,
                  borderRadius: BorderRadius.circular(30),
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
        border: Border.all(
          color: Colors.grey.withOpacity(0.5), // border color
          width: 1.0, // border width
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            spreadRadius: 2,
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
      Color _getRandomColor(String name) {
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
              ? _getRandomColor(name)
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
                        ? _getRandomColor(name)
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

    if (_isComparing &&
        selectedUserIds.isNotEmpty &&
        _teamComparisonData.isNotEmpty) {
      dataToDisplay = _teamComparisonData;
      print('📊 Using team comparison data: ${dataToDisplay.length} members');
    } else {
      if (_isComparing && selectedUserIds.isNotEmpty) {
        dataToDisplay = _membersData.where((member) {
          return selectedUserIds.contains(member['user_id'].toString());
        }).toList();
        print(
          '📊 Using filtered members data: ${dataToDisplay.length} members',
        );
      } else {
        dataToDisplay = _membersData;
        print('📊 Using regular members data: ${dataToDisplay.length} members');
      }
    }

    if (dataToDisplay.isEmpty) {
      return [];
    }

    // 🔥 FIX: Use safe count calculation
    int safeDisplayCount = math.min(_currentDisplayCount, dataToDisplay.length);
    List<dynamic> displayMembers = dataToDisplay
        .take(safeDisplayCount)
        .toList();

    return displayMembers.asMap().entries.map((entry) {
      int index = entry.key;
      var member = entry.value;

      // Safe access with null checks
      if (member == null) return TableRow(children: []);

      bool isSelected = selectedUserIds.contains(
        member['user_id']?.toString() ?? '',
      );

      return _buildTableRow([
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CallAnalytics(
                  userId: member['user_id'].toString(),
                  isFromSM: true,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    child: Text(
                      member['fname'].toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  member['fname'].toString(),
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
          member['retail'].toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        // 🔥 Show target data if available (from team comparison)
        Text(
          (member['target_enquiries'] ?? member['retail'] ?? 0).toString(),
          style: AppFont.smallText10(context).copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ]);
    }).toList();
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

    if (dataToDisplay.isEmpty || !_hasMoreRecordsTeams(dataToDisplay)) {
      return const SizedBox.shrink();
    }

    int remainingRecords = dataToDisplay.length - _currentDisplayCount;
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
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
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
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 50),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Adjust font size based on number of digits
                  final int length = value.length;
                  double fontSize;

                  if (length <= 2) {
                    fontSize = 30;
                  } else if (length == 3) {
                    fontSize = 26;
                  } else if (length == 4) {
                    fontSize = 22;
                  } else if (length == 5) {
                    fontSize = 18;
                  } else {
                    fontSize = 16;
                  }

                  return Text(
                    value,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: backgroundColor == Colors.white
                          ? valueColor
                          : textColor,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 120),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Adjust font size based on number of digits
                  final int length = value.length;
                  double fontSize;

                  if (length <= 2) {
                    fontSize = 14;
                  } else if (length == 3) {
                    fontSize = 12;
                  } else if (length == 4) {
                    fontSize = 10;
                  } else if (length == 5) {
                    fontSize = 8;
                  } else {
                    fontSize = 10;
                  }

                  return Text(
                    label,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Upcoming Activities Section
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
                // const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.only(bottom: 10, top: 5),
                  width: 150,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF767676),
                      width: .5,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildFilterButton(
                        index: 0,
                        text: 'Upcoming',
                        activeColor: const Color.fromARGB(255, 81, 223, 121),
                      ),
                      _buildFilterButton(
                        index: 1,
                        text: 'Overdue ($count)',
                        activeColor: const Color.fromRGBO(238, 59, 59, 1),
                      ),
                    ],
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

              count = overdue['count']?.length ?? 0;
            }
          });
        },
        style: TextButton.styleFrom(
          backgroundColor: _upcommingButtonIndex == index
              ? activeColor.withOpacity(0.29)
              : null,
          foregroundColor: _upcommingButtonIndex == index
              ? Colors.blueGrey
              : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 5),
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
        child: Text(text, style: AppFont.smallText(context)),
      ),
    );
  }

  // Activity section builder
  Widget _buildActivitySection(
    BuildContext context,
    List<Map<String, dynamic>> activities,
    // String label,
    String dateKey,
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
                      Text(name, style: AppFont.smallTextBold14(context)),
                    ],
                  ),
                  Row(
                    children: [
                      if (vehicle.isNotEmpty)
                        Text(
                          vehicle,
                          style: AppFont.smallText12(context),
                          softWrap: true,
                          overflow: TextOverflow.visible,
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
