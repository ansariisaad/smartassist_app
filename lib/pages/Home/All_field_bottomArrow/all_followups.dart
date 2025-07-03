import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/followups/all_followups.dart';
import 'package:smartassist/widgets/followups/overdue_followup.dart';
import 'package:smartassist/widgets/followups/upcoming_row.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_Followups_popups.dart';
import 'package:smartassist/widgets/buttons/add_btn.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/widgets/reusable/globle_speechtotext.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AddFollowups extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  const AddFollowups({super.key, required this.refreshDashboard});

  @override
  State<AddFollowups> createState() => _AddFollowupsState();
}

class _AddFollowupsState extends State<AddFollowups>
    with WidgetsBindingObserver {
  final Widget _createFollowups = CreateFollowupsPopups(onFormSubmit: () {});
  List<dynamic> _originalAllTasks = [];
  List<dynamic> _originalUpcomingTasks = [];
  List<dynamic> _originalOverdueTasks = [];
  List<dynamic> _filteredAllTasks = [];
  List<dynamic> _filteredUpcomingTasks = [];
  List<dynamic> _filteredOverdueTasks = [];
  bool _isLoadingSearch = false;
  bool _isLoading = true;
  bool _isListening = false; // Track speech-to-text listening state
  bool _isSearching = false;
  String _query = '';
  int _upcomingButtonIndex = 0;
  int count = 0;
  late stt.SpeechToText _speech;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchTasks();

    _speech = stt.SpeechToText();
    _initSpeech();
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
        showErrorMessage(
          context,
          message: 'Speech recognition error: ${errorNotification.errorMsg}',
        );
      },
    );
    if (!available) {
      showErrorMessage(
        context,
        message: 'Speech recognition not available on this device',
      );
    }
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
            _onSearchChanged(); // Trigger search filtering
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
      final token = await Storage.getToken();
      const String apiUrl = "https://dev.smartassistapp.in/api/tasks/all-tasks";

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          count = data['data']['overdueWeekTasks']?['count'] ?? 0;
          _originalAllTasks = data['data']['allTasks']?['rows'] ?? [];
          _originalUpcomingTasks =
              data['data']['upcomingWeekTasks']?['rows'] ?? [];
          _originalOverdueTasks =
              data['data']['overdueWeekTasks']?['rows'] ?? [];
          _filteredAllTasks = List.from(_originalAllTasks);
          _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
          _filteredOverdueTasks = List.from(_originalOverdueTasks);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        showErrorMessage(context, message: 'Failed to fetch follow-ups.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorMessage(context, message: 'Error fetching follow-ups.');
      }
    }
  }

  void _performLocalSearch(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredAllTasks = List.from(_originalAllTasks);
        _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
        _filteredOverdueTasks = List.from(_originalOverdueTasks);
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
      }
    });
  }

  // bool _matchesSearchCriteria(dynamic item, String searchQuery) {
  //   String name = (item['lead_name'] ?? item['name'] ?? '')
  //       .toString()
  //       .toLowerCase();
  //   String email = (item['email'] ?? '').toString().toLowerCase();
  //   String phone = (item['mobile'] ?? '').toString().toLowerCase();
  //   String subject = (item['subject'] ?? '').toString().toLowerCase();

  //   return name.contains(searchQuery) ||
  //       email.contains(searchQuery) ||
  //       phone.contains(searchQuery) ||
  //       subject.contains(searchQuery);
  // }

  bool _matchesSearchCriteria(dynamic item, String searchQuery) {
    String name = (item['lead_name'] ?? item['name'] ?? '')
        .toString()
        .toLowerCase();
    String email = (item['email'] ?? '').toString().toLowerCase();
    String phone = (item['mobile'] ?? '').toString().toLowerCase();
    String subject = (item['subject'] ?? '').toString().toLowerCase();
    return name.contains(searchQuery) ||
        email.contains(searchQuery) ||
        phone.contains(searchQuery) ||
        subject.contains(searchQuery);
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;
    _query = newQuery;
    _searchDebounceTimer?.cancel();
    _performLocalSearch(_query);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim() && mounted) {
        _performLocalSearch(_query);
      }
    });
  }

  // void _onSearchChanged() {
  //   final newQuery = _searchController.text.trim();
  //   if (newQuery == _query) return;

  //   _query = newQuery;

  //   // Cancel previous timer
  //   _searchDebounceTimer?.cancel();

  //   // Perform local search immediately
  //   _performLocalSearch(_query);

  //   // Debounce for consistency
  //   _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
  //     if (_query == _searchController.text.trim() && mounted) {
  //       _performLocalSearch(_query);
  //     }
  //   });
  // }

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
            'Your Follow-ups',
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
                child: _createFollowups,
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
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 38,
                        maxHeight: 38,
                      ),
                      child: TextField(
                        autofocus: false,
                        controller: _searchController,
                        enabled: !_isListening,
                        onChanged: (value) => _onSearchChanged(),
                        textAlignVertical: TextAlignVertical.center,
                        style: GoogleFonts.poppins(
                          fontSize: _getResponsiveFontSize(context, isTablet),
                          color: _isListening
                              ? AppColors.iconGrey
                              : Colors.black,
                        ),
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: _getResponsiveHorizontalPadding(
                              context,
                              isTablet,
                            ),
                            vertical: _getResponsiveVerticalPadding(
                              context,
                              isTablet,
                            ),
                          ),
                          filled: true,
                          fillColor: _isListening
                              ? AppColors.containerBg.withOpacity(0.8)
                              : AppColors.containerBg,
                          hintText: _isListening
                              ? 'Listening... Speak now'
                              : 'Search by name, email or phone',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: _getResponsiveHintFontSize(
                              context,
                              isTablet,
                            ),
                            fontWeight: FontWeight.w300,
                            color: _isListening
                                ? AppColors.iconGrey
                                : Colors.grey,
                          ),

                          suffixIcon: Container(
                            width: _getResponsiveIconContainerWidth(
                              context,
                              isTablet,
                            ),
                            child: Center(
                              child: IconButton(
                                icon: Icon(
                                  _isListening
                                      ? FontAwesomeIcons.microphone
                                      : FontAwesomeIcons.microphoneSlash,
                                  color: _isListening
                                      ? AppColors.fontColor
                                      : AppColors.fontColor,
                                  size: _getResponsiveIconSize(
                                    context,
                                    isTablet,
                                  ),
                                ),
                                onPressed: () =>
                                    _toggleListening(_searchController),
                              ),
                            ),
                          ),
                          // suffixIcon: Container(
                          //   width: _getResponsiveIconContainerWidth(
                          //     context,
                          //     isTablet,
                          //   ),
                          //   child: Center(
                          //     child:
                          //     // i dont want to use it i want to use the _togglelistening and initspeect and it fileter the search
                          //      GlobleSpeechtotext(
                          //       onSpeechResult: (result) {
                          //         _searchController.text = result;
                          //         _onSearchChanged();
                          //       },
                          //       onListeningStateChanged: (isListening) {
                          //         setState(() => _isListening = isListening);
                          //       },
                          //       iconSize: _getResponsiveIconSize(
                          //         context,
                          //         isTablet,
                          //       ),
                          //       // activeColor: AppColors.colorsBlue,
                          //       activeColor: AppColors.iconGrey,
                          //       inactiveColor: AppColors.fontColor,
                          //     ),
                          //   ),
                          // ),
                          prefixIcon: Container(
                            width: _getResponsiveIconContainerWidth(
                              context,
                              isTablet,
                            ),
                            child: Center(
                              child: Icon(
                                FontAwesomeIcons.magnifyingGlass,
                                color: AppColors.fontColor,
                                size: _getResponsiveIconSize(context, isTablet),
                              ),
                            ),
                          ),
                          prefixIconConstraints: BoxConstraints(
                            minWidth: _getResponsiveIconContainerWidth(
                              context,
                              isTablet,
                            ),
                            maxWidth: _getResponsiveIconContainerWidth(
                              context,
                              isTablet,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
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
                          width: _getSubTabWidth(),
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
                                text: 'All',
                                activeColor: AppColors.borderblue,
                              ),
                              _buildFilterButton(
                                color: AppColors.containerGreen,
                                index: 1,
                                text: 'Upcoming',
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
            if (_isSearching && _query.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  child: Text(
                    'Showing results for: "$_query"',
                    style: GoogleFonts.poppins(
                      fontSize: _smallFontSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.fontColor.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.colorsBlue,
                      ),
                    )
                  : _buildContentBySelectedTab(),
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
      case 0: // All Follow-ups
        return _filteredAllTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching follow-ups found"
                        : "No follow-ups available",
                    style: GoogleFonts.poppins(
                      fontSize: _bodyFontSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.fontColor.withOpacity(0.7),
                    ),
                  ),
                ),
              )
            : AllFollowup(allFollowups: _filteredAllTasks, isNested: true);
      case 1: // Upcoming
        return _filteredUpcomingTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching upcoming follow-ups found"
                        : "No upcoming follow-ups available",
                    style: GoogleFonts.poppins(
                      fontSize: _bodyFontSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.fontColor.withOpacity(0.7),
                    ),
                  ),
                ),
              )
            : FollowupsUpcoming(
                refreshDashboard: widget.refreshDashboard,
                upcomingFollowups: _filteredUpcomingTasks,
                isNested: true,
              );
      case 2: // Overdue
        return _filteredOverdueTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching overdue follow-ups found"
                        : "No overdue follow-ups available",
                    style: GoogleFonts.poppins(
                      fontSize: _bodyFontSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.fontColor.withOpacity(0.7),
                    ),
                  ),
                ),
              )
            : OverdueFollowup(
                refreshDashboard: widget.refreshDashboard,
                overdueeFollowups: _filteredOverdueTasks,
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
            horizontal: 4.0 * _getResponsiveScale(),
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




// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/utils/bottom_navigation.dart';
// import 'package:smartassist/utils/snackbar_helper.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/followups/all_followups.dart';
// // import 'package:smartassist/widgets/followups/all_followup.dart'; // Import the new widget
// import 'package:smartassist/widgets/followups/overdue_followup.dart';
// import 'package:smartassist/widgets/followups/upcoming_row.dart';
// import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_Followups_popups.dart';
// import 'package:smartassist/widgets/buttons/add_btn.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';

// class AddFollowups extends StatefulWidget {
//   final Future<void> Function() refreshDashboard;
//   const AddFollowups({super.key, required this.refreshDashboard});

//   @override
//   State<AddFollowups> createState() => _AddFollowupsState();
// }

// class _AddFollowupsState extends State<AddFollowups> {
//   final Widget _createFollowups = CreateFollowupsPopups(onFormSubmit: () {});
//   List<dynamic> _originalAllTasks = [];
//   List<dynamic> _originalUpcomingTasks = [];
//   List<dynamic> _originalOverdueTasks = [];
//   List<dynamic> _filteredAllTasks = [];
//   List<dynamic> _filteredUpcomingTasks = [];
//   List<dynamic> _filteredOverdueTasks = [];
//   bool _isLoadingSearch = false;
//   List<dynamic> upcomingTasks = [];
//   List<dynamic> _searchResults = [];
//   List<dynamic> _filteredTasks = [];
//   String _query = '';
//   int _upcommingButtonIndex = 0;

//   int count = 0;

//   TextEditingController searchController = TextEditingController();
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchTasks();
//   }

//   final TextEditingController _searchController = TextEditingController();

//   // Helper method to get responsive dimensions
//   bool get _isTablet => MediaQuery.of(context).size.width > 768;
//   bool get _isSmallScreen => MediaQuery.of(context).size.width < 400;
//   double get _screenWidth => MediaQuery.of(context).size.width;
//   double get _screenHeight => MediaQuery.of(context).size.height;

//   // Responsive padding
//   EdgeInsets get _responsivePadding => EdgeInsets.symmetric(
//     horizontal: _isTablet ? 20 : (_isSmallScreen ? 8 : 10),
//     vertical: _isTablet ? 12 : 8,
//   );

//   // Responsive font sizes
//   double get _titleFontSize => _isTablet ? 20 : (_isSmallScreen ? 16 : 18);
//   double get _bodyFontSize => _isTablet ? 16 : (_isSmallScreen ? 12 : 14);
//   double get _smallFontSize => _isTablet ? 14 : (_isSmallScreen ? 10 : 12);

//   double _getScreenWidth() => MediaQuery.sizeOf(context).width;

//   // Responsive scaling while maintaining current design proportions
//   double _getResponsiveScale() {
//     final width = _getScreenWidth();
//     if (width <= 320) return 0.85; // Very small phones
//     if (width <= 375) return 0.95; // Small phones
//     if (width <= 414) return 1.0; // Standard phones (base size)
//     if (width <= 600) return 1.05; // Large phones
//     if (width <= 768) return 1.1; // Small tablets
//     return 1.15; // Large tablets and up
//   }

//   double _getSubTabFontSize() {
//     return 12.0 * _getResponsiveScale(); // Base font size: 12
//   }

//   double _getSubTabHeight() {
//     return 27.0 * _getResponsiveScale(); // Base height: 27
//   }

//   // double _getSubTabWidth() {
//   //   return 240.0 * _getResponsiveScale(); // Base width: 150
//   // }

//   double _getSubTabWidth() {
//     // Calculate approximate width needed based on content
//     double baseWidth = 240.0 * _getResponsiveScale();

//     // Add extra width if count is large (adjust as needed)
//     if (count > 99) {
//       baseWidth += 30.0 * _getResponsiveScale();
//     } else if (count > 9) {
//       baseWidth += 15.0 * _getResponsiveScale();
//     }

//     return baseWidth;
//   }

//   Future<void> fetchTasks() async {
//     setState(() => _isLoading = true);
//     try {
//       final token = await Storage.getToken();
//       const String apiUrl = "https://dev.smartassistapp.in/api/tasks/all-tasks";

//       final response = await http.get(
//         Uri.parse(apiUrl),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         setState(() {
//           count = data['data']['overdueWeekTasks']?['count'] ?? 0;
//           _originalAllTasks = data['data']['allTasks']?['rows'] ?? [];
//           _originalUpcomingTasks =
//               data['data']['upcomingWeekTasks']?['rows'] ?? [];
//           _originalOverdueTasks =
//               data['data']['overdueWeekTasks']?['rows'] ?? [];

//           _filteredAllTasks = List.from(_originalAllTasks);
//           _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
//           _filteredOverdueTasks = List.from(_originalOverdueTasks);
//           _isLoading = false;
//         });
//       } else {
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   void _performLocalSearch(String query) {
//     if (query.isEmpty) {
//       setState(() {
//         _filteredTasks = List.from(upcomingTasks);
//       });
//       return;
//     }

//     setState(() {
//       _filteredTasks = upcomingTasks.where((item) {
//         String name = (item['lead_name'] ?? '').toString().toLowerCase();
//         String email = (item['email'] ?? '').toString().toLowerCase();
//         String phone = (item['mobile'] ?? '').toString().toLowerCase();
//         String searchQuery = query.toLowerCase();

//         return name.contains(searchQuery) ||
//             email.contains(searchQuery) ||
//             phone.contains(searchQuery);
//       }).toList();
//     });
//   }

//   Future<void> _fetchSearchResults(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _searchResults.clear();
//       });
//       return;
//     }

//     setState(() {
//       _isLoadingSearch = true;
//     });

//     try {
//       final token = await Storage.getToken();
//       final response = await http.get(
//         Uri.parse(
//           'https://dev.smartassistapp.in/api/search/global?query=$query',
//         ),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       final Map<String, dynamic> data = json.decode(response.body);
//       if (response.statusCode == 200) {
//         setState(() {
//           _searchResults = data['data']['suggestions'] ?? [];
//         });
//       } else {
//         showErrorMessage(context, message: data['message']);
//       }
//     } catch (e) {
//       showErrorMessage(context, message: 'Something went wrong..!');
//     } finally {
//       setState(() {
//         _isLoadingSearch = false;
//       });
//     }
//   }

//   void _onSearchChanged() {
//     final newQuery = _searchController.text.trim();
//     if (newQuery == _query) return;

//     _query = newQuery;

//     // Perform local search immediately for better UX
//     _performLocalSearch(_query);

//     // Also perform API search with debounce
//     Future.delayed(const Duration(milliseconds: 500), () {
//       if (_query == _searchController.text.trim()) {
//         _fetchSearchResults(_query);
//       }
//     });
//   }

//   // Responsive helper methods
//   double _getResponsiveFontSize(BuildContext context, bool isTablet) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth < 360) return 12; // Very small screens
//     if (screenWidth < 400) return 13; // Small screens
//     if (isTablet) return 16;
//     return 14; // Default
//   }

//   double _getResponsiveHintFontSize(BuildContext context, bool isTablet) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth < 360) return 10;
//     if (screenWidth < 400) return 11;
//     if (isTablet) return 14;
//     return 12;
//   }

//   double _getResponsiveIconSize(BuildContext context, bool isTablet) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth < 360) return 14;
//     if (screenWidth < 400) return 15;
//     if (isTablet) return 18;
//     return 16;
//   }

//   double _getResponsiveHorizontalPadding(BuildContext context, bool isTablet) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth < 360) return 12;
//     if (screenWidth < 400) return 14;
//     if (isTablet) return 20;
//     return 16;
//   }

//   double _getResponsiveVerticalPadding(BuildContext context, bool isTablet) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth < 360) return 10;
//     if (screenWidth < 400) return 12;
//     if (isTablet) return 16;
//     return 14;
//   }

//   double _getResponsiveIconContainerWidth(BuildContext context, bool isTablet) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     if (screenWidth < 360) return 40;
//     if (screenWidth < 400) return 45;
//     if (isTablet) return 55;
//     return 50;
//   }

//   void _filterTasks(String query) {
//     setState(() {
//       if (query.isEmpty) {
//         _filteredAllTasks = List.from(_originalAllTasks);
//         _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
//         _filteredOverdueTasks = List.from(_originalOverdueTasks);
//       } else {
//         final lowercaseQuery = query.toLowerCase();
//         void filterList(List<dynamic> original, List<dynamic> filtered) {
//           filtered.clear();
//           filtered.addAll(
//             original.where(
//               (task) =>
//                   task['name'].toString().toLowerCase().contains(
//                     lowercaseQuery,
//                   ) ||
//                   task['subject'].toString().toLowerCase().contains(
//                     lowercaseQuery,
//                   ),
//             ),
//           );
//         }

//         filterList(_originalAllTasks, _filteredAllTasks);
//         filterList(_originalUpcomingTasks, _filteredUpcomingTasks);
//         filterList(_originalOverdueTasks, _filteredOverdueTasks);
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenSize = MediaQuery.of(context).size;
//     final isTablet = screenSize.width > 600;
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           onPressed: () {
//             Navigator.pop(context);
//             widget.refreshDashboard();
//           },
//           icon: Icon(
//             FontAwesomeIcons.angleLeft,
//             color: Colors.white,
//             size: _isSmallScreen ? 18 : 20,
//           ),
//         ),
//         title: Align(
//           alignment: Alignment.centerLeft,
//           child: Text(
//             'Your Follow ups',
//             style: GoogleFonts.poppins(
//               fontSize: _titleFontSize,
//               fontWeight: FontWeight.w400,
//               color: Colors.white,
//             ),
//           ),
//         ),
//         backgroundColor: AppColors.colorsBlue,
//         automaticallyImplyLeading: false,
//       ),
//       floatingActionButton: CustomFloatingButton(
//         onPressed: () {
//           showDialog(
//             context: context,
//             builder: (context) {
//               return Dialog(
//                 insetPadding: const EdgeInsets.symmetric(horizontal: 10),
//                 backgroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: _createFollowups, // Your follow-up widget
//               );
//             },
//           );
//         },
//       ),
//       body: RefreshIndicator(
//         onRefresh: fetchTasks,
//         child: CustomScrollView(
//           slivers: [
//             // Top section with search bar and filter buttons.
//             SliverToBoxAdapter(
//               child: Column(
//                 children: [
//                   Container(
//                     margin: const EdgeInsets.symmetric(
//                       horizontal: 15,
//                       vertical: 10,
//                     ),
//                     child: ConstrainedBox(
//                       constraints: BoxConstraints(
//                         minHeight: 38, // Minimum height for accessibility
//                         maxHeight: 38, // Maximum height to prevent oversizing
//                       ),
//                       child: TextField(
//                         autofocus: false,
//                         controller: _searchController,
//                         onChanged: (value) => _onSearchChanged(),
//                         textAlignVertical: TextAlignVertical.center,
//                         style: GoogleFonts.poppins(
//                           fontSize: _getResponsiveFontSize(context, isTablet),
//                         ),
//                         decoration: InputDecoration(
//                           enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: BorderSide.none,
//                           ),
//                           contentPadding: EdgeInsets.symmetric(
//                             horizontal: _getResponsiveHorizontalPadding(
//                               context,
//                               isTablet,
//                             ),
//                             vertical: _getResponsiveVerticalPadding(
//                               context,
//                               isTablet,
//                             ),
//                           ),
//                           filled: true,
//                           fillColor: AppColors.containerBg,
//                           hintText: 'Search by name, email or phone',
//                           hintStyle: GoogleFonts.poppins(
//                             fontSize: _getResponsiveHintFontSize(
//                               context,
//                               isTablet,
//                             ),
//                             fontWeight: FontWeight.w300,
//                           ),
//                           prefixIcon: Container(
//                             width: _getResponsiveIconContainerWidth(
//                               context,
//                               isTablet,
//                             ),
//                             child: Center(
//                               child: Icon(
//                                 FontAwesomeIcons.magnifyingGlass,
//                                 color: AppColors.fontColor,
//                                 size: _getResponsiveIconSize(context, isTablet),
//                               ),
//                             ),
//                           ),
//                           prefixIconConstraints: BoxConstraints(
//                             minWidth: _getResponsiveIconContainerWidth(
//                               context,
//                               isTablet,
//                             ),
//                             maxWidth: _getResponsiveIconContainerWidth(
//                               context,
//                               isTablet,
//                             ),
//                           ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(30),
//                             borderSide: BorderSide.none,
//                           ),
//                           isDense: true,
//                         ),
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 0),
//                     child: Row(
//                       children: [
//                         const SizedBox(width: 10),
//                         Container(
//                           width: _getSubTabWidth(),
//                           height: _getSubTabHeight(),
//                           decoration: BoxDecoration(
//                             border: Border.all(
//                               color: const Color(0xFF767676).withOpacity(0.3),
//                               width: 0.5,
//                             ),
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                           child: Row(
//                             children: [
//                               _buildFilterButton(
//                                 color: AppColors.colorsBlue,
//                                 index: 0,
//                                 text: 'All',
//                                 activeColor: AppColors.borderblue,
//                               ),
//                               _buildFilterButton(
//                                 color: AppColors.containerGreen,
//                                 index: 1,
//                                 text: 'Upcoming',
//                                 activeColor: AppColors.borderGreen,
//                               ),
//                               _buildFilterButton(
//                                 color: AppColors.containerRed,
//                                 index: 2,
//                                 text: 'Overdue ($count)',
//                                 activeColor: AppColors.borderRed,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 5),
//                 ],
//               ),
//             ),

//             SliverToBoxAdapter(
//               child: _isLoading
//                   ? const Center(
//                       child: CircularProgressIndicator(
//                         color: AppColors.colorsBlue,
//                       ),
//                     )
//                   : _buildContentBySelectedTab(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildContentBySelectedTab() {
//     switch (_upcommingButtonIndex) {
//       case 0: // All Followups
//         return _filteredAllTasks.isEmpty
//             ? const Center(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(vertical: 20),
//                   child: Text("No followups available"),
//                 ),
//               )
//             : AllFollowup(allFollowups: _filteredAllTasks, isNested: true);
//       case 1: // Upcoming
//         return _filteredUpcomingTasks.isEmpty
//             ? const Center(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(vertical: 20),
//                   child: Text("No upcoming followups available"),
//                 ),
//               )
//             : FollowupsUpcoming(
//                 refreshDashboard: widget.refreshDashboard,
//                 upcomingFollowups: _filteredUpcomingTasks,
//                 isNested: true,
//               );
//       case 2: // Overdue
//         return _filteredOverdueTasks.isEmpty
//             ? const Center(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(vertical: 20),
//                   child: Text("No overdue followups available"),
//                 ),
//               )
//             : OverdueFollowup(
//                 refreshDashboard: widget.refreshDashboard,
//                 overdueeFollowups: _filteredOverdueTasks,
//                 isNested: true,
//               );
//       default:
//         return const SizedBox();
//     }
//   }

//   Widget _buildFilterButton({
//     required int index,
//     required String text,
//     required Color activeColor,
//     required Color color,
//   }) {
//     final bool isActive = _upcommingButtonIndex == index;

//     return Expanded(
//       child: TextButton(
//         onPressed: () => setState(() => _upcommingButtonIndex = index),
//         style: TextButton.styleFrom(
//           backgroundColor: isActive ? activeColor.withOpacity(0.29) : null,
//           foregroundColor: isActive ? Colors.white : Colors.black,
//           // padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
//           padding: EdgeInsets.symmetric(
//             vertical: 5.0 * _getResponsiveScale(),
//             horizontal: 4.0 * _getResponsiveScale(),
//           ),
//           side: BorderSide(
//             color: isActive ? activeColor : Colors.transparent,
//             width: .5,
//           ),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//         ),
//         child: Text(
//           text,
//           style: TextStyle(
//             fontSize: _getSubTabFontSize(),
//             fontWeight: FontWeight.w400,
//             color: isActive ? color : Colors.grey,
//           ),
//         ),
//       ),
//     );
//   }
// }

