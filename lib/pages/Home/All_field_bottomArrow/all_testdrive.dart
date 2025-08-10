import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/buttons/add_btn.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_testDrive.dart';
import 'package:smartassist/widgets/reusable/globle_speechtotext.dart';
import 'package:smartassist/widgets/reusable/skeleton_card.dart';
import 'package:smartassist/widgets/testdrive/all_testDrive.dart';
import 'package:smartassist/widgets/testdrive/overdue.dart';
import 'package:smartassist/widgets/testdrive/upcoming.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AllTestdrive extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  const AllTestdrive({super.key, required this.refreshDashboard});

  @override
  State<AllTestdrive> createState() => _AllTestdriveState();
}

class _AllTestdriveState extends State<AllTestdrive>
    with WidgetsBindingObserver {
  final Widget _createTestDrive = CreateTestdrive(onFormSubmit: () {});
  List<dynamic> _originalAllTasks = [];
  List<dynamic> _originalUpcomingTasks = [];
  List<dynamic> _originalOverdueTasks = [];
  List<dynamic> _filteredAllTasks = [];
  List<dynamic> _filteredUpcomingTasks = [];
  List<dynamic> _filteredOverdueTasks = [];
  List<dynamic> _filteredTasks = [];
  bool _isLoadingSearch = false;
  bool _isLoading = true;
  bool _isListening = false; // Track speech-to-text listening state
  bool _isSearching = false;
  String _query = '';
  int _upcomingButtonIndex = 0; // Fixed typo
  int count = 0;
  int upComingCount = 0;
  int allCount = 0;
  late stt.SpeechToText _speech;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchTasks();
    // _speech = stt.SpeechToText();
    // _initSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Initialize speech recognition
  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorNotification) {
        setState(() {
          _isListening = false;
        });
        print('Speech recognition error: ${errorNotification.errorMsg}');
        // showErrorMessage(
        //   context,
        //   message: 'Speech recognition error: ${errorNotification.errorMsg}',
        // );
      },
    );
    // if (!available) {
    //   showErrorMessage(
    //     context,
    //     message: 'Speech recognition not available on this device',
    //   );
    // }
  }

  // Toggle listening
  void _toggleListening(TextEditingController controller) async {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      setState(() {
        _isListening = true;
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            controller.text = result.recognizedWords;
            _onSearchChanged();
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  // Responsive methods
  bool get _isTablet => MediaQuery.of(context).size.width > 768;
  bool get _isSmallScreen => MediaQuery.of(context).size.width < 400;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

  EdgeInsets get _responsivePadding => EdgeInsets.symmetric(
    horizontal: _isTablet ? 20 : (_isSmallScreen ? 8 : 10),
    vertical: _isTablet ? 12 : 8,
  );

  double get _titleFontSize => _isTablet ? 20 : (_isSmallScreen ? 16 : 18);
  double get _bodyFontSize => _isTablet ? 16 : (_isSmallScreen ? 12 : 14);
  double get _smallFontSize => _isTablet ? 14 : (_isSmallScreen ? 10 : 12);

  double _getScreenWidth() => MediaQuery.sizeOf(context).width;

  double _getResponsiveScale() {
    final width = _getScreenWidth();
    if (width <= 320) return 0.85;
    if (width <= 375) return 0.95;
    if (width <= 414) return 1.0;
    if (width <= 600) return 1.05;
    if (width <= 768) return 1.1;
    return 1.15;
  }

  double _getSubTabFontSize() => 12.0 * _getResponsiveScale();
  double _getSubTabHeight() => 27.0 * _getResponsiveScale();
  double _getSubTabWidth() {
    double baseWidth = 240.0 * _getResponsiveScale();
    if (count > 99) {
      baseWidth += 30.0 * _getResponsiveScale();
    } else if (count > 9) {
      baseWidth += 15.0 * _getResponsiveScale();
    }
    return baseWidth;
  }

  double _getResponsiveFontSize(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12;
    if (screenWidth < 400) return 13;
    if (isTablet) return 16;
    return 14;
  }

  double _getResponsiveHintFontSize(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 10;
    if (screenWidth < 400) return 11;
    if (isTablet) return 14;
    return 12;
  }

  double _getResponsiveIconSize(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 14;
    if (screenWidth < 400) return 15;
    if (isTablet) return 18;
    return 16;
  }

  double _getResponsiveHorizontalPadding(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12;
    if (screenWidth < 400) return 14;
    if (isTablet) return 20;
    return 16;
  }

  double _getResponsiveVerticalPadding(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 10;
    if (screenWidth < 400) return 12;
    if (isTablet) return 16;
    return 14;
  }

  double _getResponsiveIconContainerWidth(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 40;
    if (screenWidth < 400) return 45;
    if (isTablet) return 55;
    return 50;
  }

  Future<void> fetchTasks() async {
    setState(() => _isLoading = true);

    try {
      final result = await LeadsSrv.fetchTestdrive();

      if (result['success'] == true) {
        final data =
            result['data']; // This is already the inner 'data' from API response

        setState(() {
          // ✅ FIXED: Remove extra ['data'] since data is already the inner data
          count = data['overdueEvents']?['count'] ?? 0;
          upComingCount = data['upcomingEvents']?['count'] ?? 0;
          allCount = data['allEvents']?['count'] ?? 0;

          _originalAllTasks = data['allEvents']?['rows'] ?? [];
          _originalUpcomingTasks = data['upcomingEvents']?['rows'] ?? [];
          _originalOverdueTasks = data['overdueEvents']?['rows'] ?? [];

          _filteredAllTasks = List.from(_originalAllTasks);
          _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
          _filteredOverdueTasks = List.from(_originalOverdueTasks);

          _isLoading = false;
        });

        print('✅ Test drives loaded successfully');
        print('📊 All: $allCount, Upcoming: $upComingCount, Overdue: $count');
      } else {
        setState(() => _isLoading = false);
        final errorMessage =
            result['message'] ?? 'Failed to fetch test drives.';
        print('❌ Failed to fetch test drives: $errorMessage');

        if (mounted) {
          showErrorMessage(context, message: errorMessage);
        }
      }
    } catch (e) {
      print('❌ Error in fetchTasks: $e');

      if (mounted) {
        setState(() => _isLoading = false);
        showErrorMessage(context, message: 'Error fetching test drives.');
      }
    }
  }

  // Future<void> fetchTasks() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     final token = await Storage.getToken();
  //     const String apiUrl =
  //         "https://api.smartassistapps.in/api/events/all-events";

  //     final response = await http.get(
  //       Uri.parse(apiUrl),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> data = json.decode(response.body);
  //       setState(() {
  //         count = data['data']['overdueEvents']?['count'] ?? 0;
  //         upComingCount = data['data']['upcomingEvents']?['count'] ?? 0;
  //         allCount = data['data']['allEvents']?['count'] ?? 0;
  //         _originalAllTasks = data['data']['allEvents']?['rows'] ?? [];
  //         _originalUpcomingTasks =
  //             data['data']['upcomingEvents']?['rows'] ?? [];
  //         _originalOverdueTasks = data['data']['overdueEvents']?['rows'] ?? [];
  //         _filteredAllTasks = List.from(_originalAllTasks);
  //         _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
  //         _filteredOverdueTasks = List.from(_originalOverdueTasks);
  //         _isLoading = false;
  //       });
  //     } else {
  //       setState(() => _isLoading = false);
  //       showErrorMessage(context, message: 'Failed to fetch test drives.');
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //       showErrorMessage(context, message: 'Error fetching test drives.');
  //     }
  //   }
  // }

  void _performLocalSearch(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredAllTasks = List.from(_originalAllTasks);
        _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
        _filteredOverdueTasks = List.from(_originalOverdueTasks);
        _filteredTasks = [];
      } else {
        final searchQuery = query.toLowerCase();

        _filteredAllTasks = _originalAllTasks.where((item) {
          return _matchesSearchCriteria(item, searchQuery);
        }).toList();

        _filteredUpcomingTasks = _originalUpcomingTasks.where((item) {
          return _matchesSearchCriteria(item, searchQuery);
        }).toList();

        _filteredOverdueTasks = _originalOverdueTasks.where((item) {
          return _matchesSearchCriteria(item, searchQuery);
        }).toList();

        // Update _filteredTasks for consistency, though not used in UI
        _filteredTasks = _filteredAllTasks;
      }
    });
  }

  bool _matchesSearchCriteria(dynamic item, String searchQuery) {
    String name = (item['lead_name'] ?? item['name'] ?? '')
        .toString()
        .toLowerCase();
    String email = (item['email'] ?? '').toString().toLowerCase();
    String phone = (item['mobile'] ?? item['phone'] ?? '')
        .toString()
        .toLowerCase();
    String subject = (item['subject'] ?? '').toString().toLowerCase();
    String description = (item['description'] ?? '').toString().toLowerCase();
    String vehicleModel = (item['vehicle_model'] ?? '')
        .toString()
        .toLowerCase();
    String customerName = (item['customer_name'] ?? '')
        .toString()
        .toLowerCase();

    return name.contains(searchQuery) ||
        email.contains(searchQuery) ||
        phone.contains(searchQuery) ||
        subject.contains(searchQuery) ||
        description.contains(searchQuery) ||
        vehicleModel.contains(searchQuery) ||
        customerName.contains(searchQuery);
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;

    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Perform local search immediately
    _performLocalSearch(_query);

    // Debounce for potential future API calls or heavy processing
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim() && mounted) {
        _performLocalSearch(_query); // Re-run for consistency
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
            widget.refreshDashboard();
          },
          icon: Icon(
            FontAwesomeIcons.angleLeft,
            color: Colors.white,
            size: _isSmallScreen ? 18 : 20,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Your Test Drives',
            style: GoogleFonts.poppins(
              fontSize: _titleFontSize,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: CustomFloatingButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _createTestDrive,
              );
            },
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: fetchTasks,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SpeechSearchWidget(
                    controller: _searchController,
                    hintText: "Search by name, email or phone",
                    onChanged: (value) => _onSearchChanged(),
                    primaryColor: AppColors.fontColor,
                    backgroundColor: Colors.grey.shade100,
                    borderRadius: 30.0,
                    prefixIcon: Icon(Icons.search, color: AppColors.fontColor),
                  ),

                  // Container(
                  //   margin: const EdgeInsets.symmetric(
                  //     horizontal: 15,
                  //     vertical: 10,
                  //   ),
                  //   child: ConstrainedBox(
                  //     constraints: const BoxConstraints(
                  //       minHeight: 38,
                  //       maxHeight: 38,
                  //     ),
                  //     child: TextField(
                  //       autofocus: false,
                  //       controller: _searchController,
                  //       enabled: !_isListening,
                  //       onChanged: (value) => _onSearchChanged(),
                  //       textAlignVertical: TextAlignVertical.center,
                  //       style: GoogleFonts.poppins(
                  //         fontSize: _getResponsiveFontSize(context, isTablet),
                  //         color: _isListening
                  //             ? AppColors.iconGrey
                  //             : Colors.black,
                  //       ),
                  //       decoration: InputDecoration(
                  //         enabledBorder: OutlineInputBorder(
                  //           borderRadius: BorderRadius.circular(30),
                  //           borderSide: BorderSide.none,
                  //         ),
                  //         focusedBorder: OutlineInputBorder(
                  //           borderRadius: BorderRadius.circular(30),
                  //           borderSide: BorderSide.none,
                  //         ),
                  //         contentPadding: EdgeInsets.symmetric(
                  //           horizontal: _getResponsiveHorizontalPadding(
                  //             context,
                  //             isTablet,
                  //           ),
                  //           vertical: _getResponsiveVerticalPadding(
                  //             context,
                  //             isTablet,
                  //           ),
                  //         ),
                  //         filled: true,
                  //         fillColor: _isListening
                  //             ? AppColors.containerBg.withOpacity(0.8)
                  //             : AppColors.containerBg,
                  //         hintText: _isListening
                  //             ? 'Listening... Speak now'
                  //             : 'Search by name, email or phone',
                  //         hintStyle: GoogleFonts.poppins(
                  //           fontSize: _getResponsiveHintFontSize(
                  //             context,
                  //             isTablet,
                  //           ),
                  //           fontWeight: FontWeight.w300,
                  //           color: _isListening
                  //               ? AppColors.iconGrey
                  //               : Colors.grey,
                  //         ),
                  //         suffixIcon: Container(
                  //           width: _getResponsiveIconContainerWidth(
                  //             context,
                  //             isTablet,
                  //           ),
                  //           child: Center(
                  //             child: IconButton(
                  //               icon: Icon(
                  //                 _isListening
                  //                     ? FontAwesomeIcons.stop
                  //                     : FontAwesomeIcons.microphone,
                  //                 color: _isListening
                  //                     ? AppColors.sideRed
                  //                     : AppColors.fontColor,
                  //                 size: _getResponsiveIconSize(
                  //                   context,
                  //                   isTablet,
                  //                 ),
                  //               ),
                  //               onPressed: () =>
                  //                   _toggleListening(_searchController),
                  //             ),
                  //           ),
                  //         ),

                  //         // suffixIcon: Container(
                  //         //   width: _getResponsiveIconContainerWidth(
                  //         //     context,
                  //         //     isTablet,
                  //         //   ),
                  //         //   child: Center(
                  //         //     child: GlobleSpeechtotext(
                  //         //       onSpeechResult: (result) {
                  //         //         _searchController.text = result;
                  //         //         _onSearchChanged();
                  //         //       },
                  //         //       onListeningStateChanged: (isListening) {
                  //         //         setState(() => _isListening = isListening);
                  //         //       },
                  //         //       iconSize: _getResponsiveIconSize(
                  //         //         context,
                  //         //         isTablet,
                  //         //       ),
                  //         //       // activeColor: AppColors.colorsBlue,
                  //         //       activeColor: AppColors.iconGrey,
                  //         //       inactiveColor: AppColors.fontColor,
                  //         //     ),
                  //         //   ),
                  //         // ),
                  //         prefixIcon: Container(
                  //           width: _getResponsiveIconContainerWidth(
                  //             context,
                  //             isTablet,
                  //           ),
                  //           child: Center(
                  //             child: Icon(
                  //               FontAwesomeIcons.magnifyingGlass,
                  //               color: AppColors.fontColor,
                  //               size: _getResponsiveIconSize(context, isTablet),
                  //             ),
                  //           ),
                  //         ),
                  //         prefixIconConstraints: BoxConstraints(
                  //           minWidth: _getResponsiveIconContainerWidth(
                  //             context,
                  //             isTablet,
                  //           ),
                  //           maxWidth: _getResponsiveIconContainerWidth(
                  //             context,
                  //             isTablet,
                  //           ),
                  //         ),
                  //         border: OutlineInputBorder(
                  //           borderRadius: BorderRadius.circular(30),
                  //           borderSide: BorderSide.none,
                  //         ),
                  //         isDense: true,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  if (_isLoadingSearch)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      child: const LinearProgressIndicator(
                        color: AppColors.colorsBlue,
                        backgroundColor: AppColors.containerBg,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 240,
                            maxWidth: 320,
                          ),
                          // width: _getSubTabWidth(),
                          height: _getSubTabHeight(),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF767676).withOpacity(0.3),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              _buildFilterButton(
                                color: AppColors.colorsBlue,
                                index: 0,
                                text: 'All ($allCount)',
                                activeColor: AppColors.colorsBlue,
                              ),
                              _buildFilterButton(
                                color: AppColors.containerGreen,
                                index: 1,
                                text: 'Upcoming ($upComingCount)',
                                activeColor: AppColors.borderGreen,
                              ),
                              _buildFilterButton(
                                color: AppColors.containerRed,
                                index: 2,
                                text: 'Overdue ($count)',
                                activeColor: AppColors.borderRed,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
            // if (_isSearching && _query.isNotEmpty)
            //   SliverToBoxAdapter(
            //     child: Container(
            //       margin: const EdgeInsets.symmetric(
            //         horizontal: 15,
            //         vertical: 8,
            //       ),
            //       child: Text(
            //         'Showing results for: "$_query"',
            //         style: GoogleFonts.poppins(
            //           fontSize: _smallFontSize,
            //           fontWeight: FontWeight.w400,
            //           color: AppColors.fontColor.withOpacity(0.7),
            //           fontStyle: FontStyle.italic,
            //         ),
            //       ),
            //     ),
            //   ),
            SliverToBoxAdapter(
              child: _isLoading ? SkeletonCard() : _buildContentBySelectedTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBySelectedTab() {
    bool isSearchingWithNoResults =
        _isSearching &&
        _filteredAllTasks.isEmpty &&
        _filteredUpcomingTasks.isEmpty &&
        _filteredOverdueTasks.isEmpty;

    if (isSearchingWithNoResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.magnifyingGlass,
                size: 48,
                color: AppColors.fontColor.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No matching records found',
                style: GoogleFonts.poppins(
                  fontSize: _bodyFontSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.fontColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search terms',
                style: GoogleFonts.poppins(
                  fontSize: _smallFontSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.fontColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_upcomingButtonIndex) {
      case 0: // All Test Drives
        return _filteredAllTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching test drives found"
                        : "No test drives available",
                    style: AppFont.smallText12(context),
                  ),
                ),
              )
            : AllTestDrive(allTestDrive: _filteredAllTasks, isNested: true);
      case 1: // Upcoming
        return _filteredUpcomingTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching upcoming test drives found"
                        : "No upcoming test drives available",
                    style: AppFont.smallText12(context),
                  ),
                ),
              )
            : TestUpcoming(
                refreshDashboard: widget.refreshDashboard,
                upcomingTestDrive: _filteredUpcomingTasks,
                isNested: true,
              );
      case 2: // Overdue
        return _filteredOverdueTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching overdue test drives found"
                        : "No overdue test drives available",
                    style: AppFont.smallText12(context),
                  ),
                ),
              )
            : TestOverdue(
                refreshDashboard: widget.refreshDashboard,
                overdueTestDrive: _filteredOverdueTasks,
                isNested: true,
              );
      default:
        return const SizedBox();
    }
  }

  Widget _buildFilterButton({
    required int index,
    required String text,
    required Color activeColor,
    required Color color,
  }) {
    final bool isActive = _upcomingButtonIndex == index;

    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => _upcomingButtonIndex = index),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? activeColor.withOpacity(0.29) : null,
          foregroundColor: isActive ? Colors.white : Colors.black,
          padding: EdgeInsets.symmetric(
            vertical: 5.0 * _getResponsiveScale(),
            horizontal: 0.0 * _getResponsiveScale(),
          ),
          side: BorderSide(
            color: isActive ? activeColor : Colors.transparent,
            width: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: _getSubTabFontSize(),
            fontWeight: FontWeight.w400,
            color: isActive ? color : Colors.grey,
          ),
        ),
      ),
    );
  }
}
