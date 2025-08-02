import 'dart:convert';
import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/config/controller/tab_controller.dart';
import 'package:smartassist/config/getX/fab.controller.dart';
import 'package:smartassist/pages/Home/gloabal_search_page/global_search.dart';
import 'package:smartassist/pages/notification/notification.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_analytics_two.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/appointment_popup.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_Followups_popups.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_leads.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_testDrive.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_analytics_one.dart';
import 'package:smartassist/widgets/home_btn.dart/threebtn.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/widgets/internet_exception.dart';
import 'package:smartassist/widgets/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String greeting;
  final String leadId;

  const HomeScreen({super.key, required this.greeting, required this.leadId});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<BottomBtnSecondState> _bottomBtnSecondKey =
      GlobalKey<BottomBtnSecondState>();

  Future<void> _refreshDashboard() async {
    _bottomBtnSecondKey.currentState?.refreshData();
  }

  bool hasInternet = true;
  bool isRefreshing = false;
  int _currentTabIndex = 0; // Track which tab is active
  late TabControllerNew _tabController;
  String? leadId;
  bool _isHidden = false;
  String greeting = '';
  String name = '';
  int notificationCount = 0;
  int overdueFollowupsCount = 0;
  int overdueAppointmentsCount = 0;
  int overdueTestDrivesCount = 0;
  List<dynamic> upcomingFollowups = [];
  List<dynamic> overdueFollowups = [];
  List<dynamic> upcomingAppointments = [];
  List<dynamic> overdueAppointments = [];
  List<dynamic> upcomingTestDrives = [];
  List<dynamic> overdueTestDrives = [];
  bool isDashboardLoading = true;
  String? teamRole;

  String? profilePicUrl; // Make nullable
  Map<String, dynamic> dashboardData = {};
  Map<String, dynamic> MtdData = {};
  Map<String, dynamic> QtdData = {};
  Map<String, dynamic> YtdData = {};

  // Search Functionality
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  // final NavigationController controller = Get.put(NavigationController());
  String _query = '';

  // exit popup
  DateTime? _lastBackPressTime;
  final int _exitTimeInMillis = 2000;

  // Initialize the controller
  final FabController fabController = Get.put(FabController());

  @override
  void initState() {
    super.initState();
    _tabController = TabControllerNew();
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);

    // Move async operations to after controller initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchDashboardData();
      _loadDashboardAnalytics();
      _loadTeamRole();
      uploadCallLogsAfterLogin();
    });
  }

  // Call this method when FAB seems disabled
  // void debugFabState() {
  //   fabController.logFabState();
  //   if (fabController.isFabDisabled.value) {
  //     print('FAB is disabled - forcing re-enable');
  //     fabController.isFabDisabled.value = false;
  //   }
  // }

  Future<void> _loadDashboardAnalytics() async {
    setState(() {
      isDashboardLoading = true;
    });
    try {
      final data = await LeadsSrv.fetchDashboardAnalytics();
      setState(() {
        MtdData = data['MTD'] ?? {};
        QtdData = data['QTD'] ?? {};
        YtdData = data['YTD'] ?? {};
      });
    } catch (e) {
      print("Error loading analytics: $e");
    }
  }

  Future<void> _loadTeamRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      teamRole = prefs.getString('USER_ROLE');
    });
    // Print all relevant keys
    print('USER_ROLE value: ${prefs.getString('USER_ROLE')}');
    print('All keys: ${prefs.getKeys()}');
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);

    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // call log after login
  Future<void> uploadCallLogsAfterLogin() async {
    // Request permission
    if (!await Permission.phone.isGranted) {
      var status = await Permission.phone.request();
      if (!status.isGranted) {
        print('Permission denied');
        return;
      }
    }

    // Fetch call logs
    Iterable<CallLogEntry> entries = await CallLog.get();
    List<CallLogEntry> callLogs = entries.toList();

    if (callLogs.isEmpty) {
      print('No call logs to send');
      return;
    }

    // Format logs
    List<Map<String, dynamic>> formattedLogs = callLogs.map((log) {
      return {
        'name': log.name ?? 'Unknown',
        'start_time': log.timestamp?.toString() ?? '',
        'mobile': log.number ?? '',
        'call_type': log.callType?.toString().split('.').last ?? '',
        'call_duration': log.duration?.toString() ?? '',
        'unique_key':
            '${log.timestamp?.toString() ?? ''}${log.number ?? ''}${log.callType?.toString()}${log.duration?.toString()}',
      };
    }).toList();

    print(jsonEncode(formattedLogs));

    // Send to API
    final token = await Storage.getToken();
    const apiUrl = 'https://api.smartassistapp.in/api/leads/create-call-logs';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(formattedLogs),
      );
      print('hello');
      if (response.statusCode == 201) {
        print('Call logs uploaded successfully');

        print('this is the response call log ${response.body}');
      } else {
        print('Failed: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Upload error: $e');
    }
  }

  // Handle form submission from popups
  // Future<void> _handleFormSubmit() async {
  //   print("🔄 Dashboard refresh called from ProfileScreen");
  //   await fetchDashboardData(isRefresh: true);
  //   print("✅ Dashboard refresh completed");
  // }

  Future<void> _handleFormSubmit() async {
    print("🔄 Dashboard refresh called from ProfileScreen");

    setState(() {
      isRefreshing = true;
    });

    await fetchDashboardData(isRefresh: true);

    // Force UI update
    if (mounted) {
      setState(() {
        print("✅ Dashboard UI refreshed");
      });
    }

    print("✅ Dashboard refresh completed");
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        // Just trigger rebuild, no need to change any state
      });
    }
  }

  Future<void> reloadanalysis() async {
    // Refresh the BottomBtnSecond widget data
    if (_bottomBtnSecondKey.currentState != null) {
      await _bottomBtnSecondKey.currentState!.refreshDashboardData();
    }
  }

  Future<void> fetchDashboardData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        isDashboardLoading = true;
      });
    } else {
      setState(() {
        isRefreshing = true;
      });
    }
    try {
      final data = await LeadsSrv.fetchDashboardData();
      if (mounted) {
        setState(() {
          hasInternet = true;
          upcomingFollowups = data['upcomingFollowups'];
          overdueFollowups = data['overdueFollowups'];
          upcomingAppointments = data['upcomingAppointments'];
          overdueAppointments = data['overdueAppointments'];
          upcomingTestDrives = data['upcomingTestDrives'];
          overdueTestDrives = data['overdueTestDrives'];
          overdueFollowupsCount =
              data.containsKey('overdueFollowupsCount') &&
                  data['overdueFollowupsCount'] is int
              ? data['overdueFollowupsCount']
              : 0;

          overdueAppointmentsCount =
              data.containsKey('overdueAppointmentsCount') &&
                  data['overdueAppointmentsCount'] is int
              ? data['overdueAppointmentsCount']
              : 0;

          overdueTestDrivesCount =
              data.containsKey('overdueTestDrivesCount') &&
                  data['overdueTestDrivesCount'] is int
              ? data['overdueTestDrivesCount']
              : 0;

          notificationCount =
              data.containsKey('notifications') && data['notifications'] is int
              ? data['notifications']
              : 0;
          greeting =
              (data.containsKey('greetings') && data['greetings'] is String)
              ? data['greetings']
              : 'Welcome!';

          name =
              (data.containsKey('userData') &&
                  data['userData'] is Map &&
                  data['userData'].containsKey('initials') &&
                  data['userData']['initials'] is String &&
                  data['userData']['initials'].trim().isNotEmpty)
              ? data['userData']['initials'].trim()
              : '';

          profilePicUrl = null;
          if (data['userData'] != null && data['userData'] is Map) {
            final userData = data['userData'] as Map<String, dynamic>;
            if (userData['initials'] != null &&
                userData['initials'] is String) {
              name = userData['initials'].toString().trim();
            }
            if (userData['profile_pic'] != null &&
                userData['profile_pic'] is String) {
              profilePicUrl = userData['profile_pic'];
            }
          }

          // if (upcomingFollowups.isNotEmpty) {
          //   leadId = upcomingFollowups[0]['lead_id'];
          // }
        });
      }
    } catch (e) {
      if (!mounted) return;

      bool isNetworkError =
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network is unreachable');

      setState(() {
        hasInternet = !isNetworkError;
      });

      print('Dashboard fetch error: $e');
      // showErrorMessage(context, message: e.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        isDashboardLoading = false;
        isRefreshing = false;
      });
    }
  }

  Future<void> onrefreshToggle() async {
    await fetchDashboardData(isRefresh: true);
    await uploadCallLogsAfterLogin();
  }

  Future<void> _fetchSearchResults(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isLoadingSearch = true;
    });

    final token = await Storage.getToken();

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/search/global?query=$query',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data['suggestions'] ?? [];
        });
      }
    } catch (e) {
      // showErrorMessage(context, message: 'Something went wrong..!');
      print(e);
    } finally {
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim()) {
        _fetchSearchResults(_query);
      }
    });
  }

  // String? teamRole = await SharedPreferences.getInstance()
  // .then((prefs) => prefs.getString('USER_ROLE'));

  void _showAppointmentPopup(BuildContext context) {
    showDialog(
      barrierDismissible: false,
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
            child: AppointmentPopup(
              // onFormSubmit: fetchDashboardData,
              onFormSubmit: _handleFormSubmit,
              onTabChange: _handleTabChangeFromPopup,
            ), // Appointment modal
          ),
        );
      },
    );
  }

  // Handle tab change from popup
  void _handleTabChangeFromPopup(int tabIndex) {
    // Use controller to change tab
    _tabController.changeTab(tabIndex);
  }

  void _showTestdrivePopup(BuildContext context) {
    showDialog(
      barrierDismissible: false,
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
            child: CreateTestdrive(
              onFormSubmit: _handleFormSubmit,
              onTabChange: _handleTabChangeFromPopup,
            ), // Appointment modal
          ),
        );
      },
    );
  }

  void _showLeadPopup(BuildContext context) {
    showDialog(
      barrierDismissible: false,
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
            child: CreateLeads(
              onFormSubmit: fetchDashboardData,

              dashboardRefresh: reloadanalysis,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasInternet && dashboardData.isEmpty) {
      return InternetException(
        onRetry: () {
          fetchDashboardData();
        },
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final responsiveFontSize = screenWidth * 0.035;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.colorsBlue,
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ' $greeting',
                    textAlign: TextAlign.start,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications),
                        color: Colors.white,
                      ),
                      if (notificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: const BoxDecoration(
                              color: AppColors.sideRed,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 15,
                              minHeight: 15,
                              maxWidth: 20,
                              maxHeight: 20,
                            ),
                            child: Text(
                              notificationCount.toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              body: Stack(
                children: [
                  SafeArea(
                    child: RefreshIndicator(
                      onRefresh: onrefreshToggle,
                      child:
                          // isDashboardLoading
                          //     ? SkeletonHomepage()
                          //     :
                          SingleChildScrollView(
                            controller: fabController.scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              children: [
                                /// ✅ Row with Menu, Search Bar, and Microphone
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 10,
                                        ),
                                        child: SizedBox(
                                          height: 40,
                                          child: TextField(
                                            readOnly: true,
                                            onTap: () {
                                              Get.to(
                                                () => const GlobalSearch(),
                                              );
                                            },
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            decoration: InputDecoration(
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding: EdgeInsets.zero,
                                              filled: true,
                                              fillColor: AppColors.containerBg,
                                              hintText:
                                                  'Search by name, email or phone',
                                              hintStyle: GoogleFonts.poppins(
                                                fontSize: responsiveFontSize,
                                                color: AppColors.fontColor,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              prefixIcon: const Icon(
                                                FontAwesomeIcons
                                                    .magnifyingGlass,
                                                color: AppColors.iconGrey,
                                                size: 15,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                borderSide: BorderSide.none,
                                              ),
                                              suffixIcon: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ProfileScreen(
                                                              refreshDashboard:
                                                                  _handleFormSubmit,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 28,
                                                    height: 28,
                                                    // decoration: BoxDecoration(
                                                    //   color: AppColors
                                                    //       .backgroundLightGrey,
                                                    //   shape: BoxShape.circle,
                                                    // ),
                                                    alignment: Alignment.center,
                                                    child:
                                                        profilePicUrl != null &&
                                                            profilePicUrl!
                                                                .isNotEmpty
                                                        ? ClipOval(
                                                            child: Image.network(
                                                              profilePicUrl!,
                                                              width: 28,
                                                              height: 28,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) {
                                                                    return Container(
                                                                      width: 28,
                                                                      height:
                                                                          28,
                                                                      decoration: BoxDecoration(
                                                                        shape: BoxShape
                                                                            .circle,
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).colorScheme.primary.withOpacity(0.1),
                                                                      ),
                                                                      child: Center(
                                                                        child: Text(
                                                                          (name?.isNotEmpty ??
                                                                                  false)
                                                                              ? name!
                                                                                    .substring(
                                                                                      0,
                                                                                      1,
                                                                                    )
                                                                                    .toUpperCase()
                                                                              : 'N/A',
                                                                          style:
                                                                              AppFont.mediumText14bluebold(
                                                                                context,
                                                                              ).copyWith(
                                                                                fontSize: 10,
                                                                              ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                            ),
                                                          )
                                                        : Container(
                                                            width:
                                                                MediaQuery.of(
                                                                  context,
                                                                ).size.width *
                                                                0.08,
                                                            height:
                                                                MediaQuery.of(
                                                                  context,
                                                                ).size.width *
                                                                0.08,
                                                            alignment: Alignment
                                                                .center,
                                                            decoration: BoxDecoration(
                                                              color: AppColors
                                                                  .backgroundLightGrey,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Text(
                                                              (name?.isNotEmpty ??
                                                                      false)
                                                                  ? name!
                                                                        .substring(
                                                                          0,
                                                                          1,
                                                                        )
                                                                        .toUpperCase()
                                                                  : 'N/A',
                                                              style:
                                                                  AppFont.mediumText14bluebold(
                                                                    context,
                                                                  ).copyWith(
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // const SizedBox(height: 3),
                                Threebtn(
                                  leadId: leadId ?? 'empty',
                                  upcomingFollowups: upcomingFollowups,
                                  overdueFollowups: overdueFollowups,
                                  upcomingAppointments: upcomingAppointments,
                                  overdueAppointments: overdueAppointments,
                                  upcomingTestDrives: upcomingTestDrives,
                                  overdueTestDrives: overdueTestDrives,
                                  refreshDashboard: fetchDashboardData,
                                  overdueFollowupsCount: overdueFollowupsCount,
                                  overdueAppointmentsCount:
                                      overdueAppointmentsCount,
                                  overdueTestDrivesCount:
                                      overdueTestDrivesCount,
                                  tabController: _tabController,
                                  onTabChanged: (index) {
                                    _bottomBtnSecondKey.currentState
                                        ?.handleExternalTabChange(index);
                                  },
                                ),
                                BottomBtnSecond(key: _bottomBtnSecondKey),

                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 10.0,
                                    right: 10.0,
                                  ),
                                  child: Row(
                                    // mainAxisAlignment:
                                    //     MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Performance Analysis',
                                        style: AppFont.appbarfontgrey(context),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _isHidden = !_isHidden;
                                          });
                                        },
                                        icon: Icon(
                                          _isHidden
                                              ? Icons
                                                    .keyboard_arrow_down_rounded
                                              : Icons.keyboard_arrow_up_rounded,
                                          size: 35,
                                          color: AppColors.iconGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isHidden) ...[const BottomBtnThird()],

                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                    ),
                  ),

                  // Replace your current Positioned widget with:
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

                  // Update your popup menu condition:
                  Obx(
                    () =>
                        fabController.isFabExpanded.value &&
                            fabController.isFabVisible.value
                        ? _buildPopupMenu(context)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FAB Builder
  Widget _buildFloatingActionButton(BuildContext context) {
    return Obx(() {
      if (!fabController.isFabVisible.value) {
        return const SizedBox.shrink();
      }

      return AnimatedBuilder(
        animation: Listenable.merge([
          fabController.rotation,
          fabController.scale,
        ]),
        builder: (context, child) {
          // Ensure all animation values are safe
          final rotationValue = (fabController.rotation.value).clamp(0.0, 1.0);
          final scaleValue = (fabController.scale.value).clamp(0.5, 2.0);

          return Transform.scale(
            scale: scaleValue,
            child: Transform.rotate(
              angle: rotationValue * 2 * 3.14159,
              child: GestureDetector(
                onTap: () {
                  print(
                    'FAB tapped - Current state: Visible(${fabController.isFabVisible.value}), Disabled(${fabController.isFabDisabled.value})',
                  );
                  fabController.toggleFab();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: MediaQuery.of(context).size.width * .15,
                  height: MediaQuery.of(context).size.height * .08,
                  decoration: BoxDecoration(
                    color: fabController.isFabDisabled.value
                        ? Colors.grey.withOpacity(0.5)
                        : (fabController.isFabExpanded.value
                              ? Colors.red
                              : AppColors.colorsBlue),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: fabController.isFabExpanded.value
                            ? Colors.red.withOpacity(0.3)
                            : AppColors.colorsBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        fabController.isFabExpanded.value
                            ? Icons.close
                            : Icons.add,
                        key: ValueKey(fabController.isFabExpanded.value),
                        color: fabController.isFabDisabled.value
                            ? Colors.grey
                            : Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
  // Widget _buildFloatingActionButton(BuildContext context) {
  //   return Obx(() {
  //     // Add debugging info
  //     if (!fabController.isFabVisible.value) {
  //       print('FAB not visible - hiding');
  //     }
  //     if (fabController.isFabDisabled.value) {
  //       print('FAB is disabled');
  //     }

  //     return GestureDetector(
  //       onTap: () {
  //         print(
  //           'FAB tapped - Current state: Visible(${fabController.isFabVisible.value}), Disabled(${fabController.isFabDisabled.value})',
  //         );
  //         fabController.toggleFab();
  //       },
  //       child: AnimatedContainer(
  //         duration: const Duration(milliseconds: 300),
  //         width: MediaQuery.of(context).size.width * .15,
  //         height: MediaQuery.of(context).size.height * .08,
  //         decoration: BoxDecoration(
  //           color: fabController.isFabDisabled.value
  //               ? Colors.grey.withOpacity(
  //                   0.5,
  //                 ) // Visual indication when disabled
  //               : (fabController.isFabExpanded.value
  //                     ? Colors.red
  //                     : AppColors.colorsBlue),
  //           shape: BoxShape.circle,
  //         ),
  //         child: Center(
  //           child: AnimatedRotation(
  //             turns: fabController.isFabExpanded.value ? 0.25 : 0.0,
  //             duration: const Duration(milliseconds: 300),
  //             child: Icon(
  //               fabController.isFabExpanded.value ? Icons.close : Icons.add,
  //               color: fabController.isFabDisabled.value
  //                   ? Colors.grey
  //                   : Colors.white,
  //               size: 30,
  //             ),
  //           ),
  //         ),
  //       ),
  //     );
  //   });
  // }

  // Widget _buildPopupMenu(BuildContext context) {
  //   return GestureDetector(
  //     onTap: fabController.closeFab,
  //     child: Stack(
  //       children: [
  //         // Background overlay
  //         Positioned.fill(
  //           child: Container(color: Colors.black.withOpacity(0.7)),
  //         ),

  //         // Popup Items Container aligned bottom right
  //         Positioned(
  //           bottom: 90,
  //           right: 20,
  //           child: SizedBox(
  //             width: 200,
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.end,
  //               children: [
  //                 _buildPopupItem(
  //                   Icons.calendar_month_outlined,
  //                   "Appointment",
  //                   -80,
  //                   onTap: () {
  //                     fabController.closeFab();
  //                     _showAppointmentPopup(context);
  //                   },
  //                 ),
  //                 _buildPopupItem(
  //                   Icons.person_search,
  //                   "Enquiry",
  //                   -60,
  //                   onTap: () {
  //                     fabController.closeFab();
  //                     _showLeadPopup(context);
  //                   },
  //                 ),
  //                 _buildPopupItem(
  //                   Icons.call,
  //                   "Followup",
  //                   -40,
  //                   onTap: () {
  //                     fabController.closeFab();
  //                     _showFollowupPopup(context);
  //                   },
  //                 ),
  //                 _buildPopupItem(
  //                   Icons.directions_car,
  //                   "Test Drive",
  //                   -20,
  //                   onTap: () {
  //                     fabController.closeFab();
  //                     _showTestdrivePopup(context);
  //                   },
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),

  //         // ✅ FAB positioned above the overlay
  //         Positioned(
  //           bottom: 26,
  //           right: 18,
  //           child: _buildFloatingActionButton(context),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildPopupMenu(BuildContext context) {
    return Obx(() {
      if (!fabController.isFabExpanded.value ||
          !fabController.isFabVisible.value) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: fabController.closeFab,
        child: Stack(
          children: [
            // Simple background overlay without animation
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),

            // Popup Items Container with safe animation
            Positioned(
              bottom: 90,
              right: 20,
              child: AnimatedBuilder(
                animation: fabController.menu,
                builder: (context, child) {
                  final menuValue = fabController.menu.value.clamp(0.0, 1.0);

                  return Transform.scale(
                    scale: (0.3 + (menuValue * 0.7)).clamp(0.3, 1.0),
                    alignment: Alignment.bottomRight,
                    child: Opacity(
                      opacity: menuValue,
                      child: SizedBox(
                        width: 200,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildSafePopupItem(
                              Icons.calendar_month_outlined,
                              "Appointment",
                              0,
                              menuValue,
                              onTap: () {
                                fabController.closeFab();
                                _showAppointmentPopup(context);
                              },
                            ),
                            _buildSafePopupItem(
                              Icons.person_search,
                              "Enquiry",
                              1,
                              menuValue,
                              onTap: () {
                                fabController.closeFab();
                                _showLeadPopup(context);
                              },
                            ),
                            _buildSafePopupItem(
                              Icons.call,
                              "Followup",
                              2,
                              menuValue,
                              onTap: () {
                                fabController.closeFab();
                                _showFollowupPopup(context);
                              },
                            ),
                            _buildSafePopupItem(
                              Icons.directions_car,
                              "Test Drive",
                              3,
                              menuValue,
                              onTap: () {
                                fabController.closeFab();
                                _showTestdrivePopup(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // FAB positioned above the overlay
            Positioned(
              bottom: 26,
              right: 18,
              child: _buildFloatingActionButton(context),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSafePopupItem(
    IconData icon,
    String label,
    int index,
    double menuProgress, {
    required Function() onTap,
  }) {
    // Simple delay calculation that won't cause issues
    final delay = (index * 100).toDouble(); // milliseconds delay
    final totalDuration = 400.0; // total animation duration in ms

    // Calculate progress for this item (0.0 to 1.0)
    double itemProgress = 0.0;
    if (menuProgress > 0.1) {
      // Start after 10% of menu animation
      itemProgress = ((menuProgress - 0.1) / 0.9).clamp(0.0, 1.0);
    }

    // Apply easing curve safely
    final easedProgress = Curves.easeOutBack.transform(itemProgress);
    final safeOpacity = easedProgress.clamp(0.0, 1.0);
    final safeScale = (0.3 + (easedProgress * 0.7)).clamp(0.3, 1.0);
    final safeTranslateY = ((1.0 - easedProgress) * 30.0).clamp(0.0, 30.0);

    return AnimatedContainer(
      duration: Duration(milliseconds: (300 + delay).round()),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(0, safeTranslateY, 0),
      child: Transform.scale(
        scale: safeScale,
        child: Opacity(
          opacity: safeOpacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: safeOpacity > 0.3
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.colorsBlue,
                    ),
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
                      boxShadow: safeOpacity > 0.3
                          ? [
                              BoxShadow(
                                color: AppColors.colorsBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } // Popup Item Builder
  // Widget _buildPopupItem(
  //   IconData icon,
  //   String label,
  //   double offsetY, {
  //   required Function() onTap,
  // }) {
  //   return Obx(
  //     () => TweenAnimationBuilder(
  //       tween: Tween<double>(
  //         begin: 0,
  //         end: fabController.isFabExpanded.value ? 1 : 0,
  //       ),
  //       duration: const Duration(milliseconds: 300),
  //       curve: Curves.easeOutBack,
  //       builder: (context, double value, child) {
  //         return Transform.translate(
  //           offset: Offset(0, offsetY * (1 - value)),
  //           child: Opacity(
  //             opacity: value.clamp(0.0, 1.0),
  //             child: Padding(
  //               padding: const EdgeInsets.symmetric(vertical: 6),
  //               child: Row(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   Text(
  //                     label,
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Colors.white,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 8),
  //                   GestureDetector(
  //                     onTap: onTap,
  //                     behavior: HitTestBehavior.opaque,
  //                     child: Container(
  //                       padding: const EdgeInsets.all(12),
  //                       decoration: BoxDecoration(
  //                         color: AppColors.colorsBlue,
  //                         borderRadius: BorderRadius.circular(30),
  //                       ),
  //                       child: Icon(icon, color: Colors.white, size: 24),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }

  void _showFollowupPopup(BuildContext context) async {
    final result = await showDialog<bool>(
      barrierDismissible: false,
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
            child: CreateFollowupsPopups(
              onFormSubmit: _handleFormSubmit,
              onTabChange: _handleTabChangeFromPopup, // Pass the function here
            ),
          ),
        );
      },
    );
  }

  // Add this method to handle back button press
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) >
            Duration(milliseconds: _exitTimeInMillis)) {
      _lastBackPressTime = now;

      // Show a bottom slide dialog
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Exit App',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorsBlue,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to exit?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Cancel button (White)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Dismiss dialog
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.colorsBlue,
                            side: const BorderSide(color: AppColors.colorsBlue),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Exit button (Blue)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            SystemNavigator.pop(); // Exit the app
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.colorsBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Exit',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          );
        },
      );
      return false;
    }
    return true;
  }
}
