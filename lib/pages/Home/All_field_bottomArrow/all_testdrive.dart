import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/buttons/add_btn.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_testDrive.dart';
import 'package:smartassist/widgets/testdrive/all_testDrive.dart';
import 'package:smartassist/widgets/testdrive/overdue.dart';
import 'package:smartassist/widgets/testdrive/upcoming.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/pages/navbar_page/call_logs.dart';
import 'package:smartassist/utils/storage.dart';

class AllTestdrive extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  const AllTestdrive({super.key, required this.refreshDashboard});

  @override
  State<AllTestdrive> createState() => _AllTestdriveState();
}

class _AllTestdriveState extends State<AllTestdrive> {
  final Widget _createTestDrive = CreateTestdrive(onFormSubmit: () {});
  List<dynamic> _originalAllTasks = [];
  List<dynamic> _originalUpcomingTasks = [];
  List<dynamic> _originalOverdueTasks = [];
  List<dynamic> _filteredAllTasks = [];
  List<dynamic> _filteredUpcomingTasks = [];
  List<dynamic> _filteredOverdueTasks = [];
  bool _isLoadingSearch = false;
  List<dynamic> upcomingTasks = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _filteredTasks = [];
  String _query = '';
  bool _isSearching = false;
  int _upcommingButtonIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  int count = 0;

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  //Helper method to get responsive dimensions
  bool get _isTablet => MediaQuery.of(context).size.width > 768;
  bool get _isSmallScreen => MediaQuery.of(context).size.width < 400;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

  // Responsive padding
  EdgeInsets get _responsivePadding => EdgeInsets.symmetric(
    horizontal: _isTablet ? 20 : (_isSmallScreen ? 8 : 10),
    vertical: _isTablet ? 12 : 8,
  );

  // Responsive font sizes
  double get _titleFontSize => _isTablet ? 20 : (_isSmallScreen ? 16 : 18);
  double get _bodyFontSize => _isTablet ? 16 : (_isSmallScreen ? 12 : 14);
  double get _smallFontSize => _isTablet ? 14 : (_isSmallScreen ? 10 : 12);

  double _getScreenWidth() => MediaQuery.sizeOf(context).width;

  Future<void> fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final token = await Storage.getToken();
      const String apiUrl =
          "https://api.smartassistapp.in/api/events/all-events";

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
          count = data['data']['overdueEvents']?['count'] ?? 0;
          _originalAllTasks = data['data']['allEvents']?['rows'] ?? [];
          _originalUpcomingTasks =
              data['data']['upcomingEvents']?['rows'] ?? [];
          _originalOverdueTasks = data['data']['overdueEvents']?['rows'] ?? [];
          _filteredAllTasks = List.from(_originalAllTasks);
          _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
          _filteredOverdueTasks = List.from(_originalOverdueTasks);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Modified local search method to search across all original task arrays
  void _performLocalSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAllTasks = List.from(_originalAllTasks);
        _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
        _filteredOverdueTasks = List.from(_originalOverdueTasks);
        _isSearching = false;
      } else {
        _isSearching = true;
        final searchQuery = query.toLowerCase();

        // Search in All Tasks
        _filteredAllTasks = _originalAllTasks.where((item) {
          return _matchesSearchCriteria(item, searchQuery);
        }).toList();

        // Search in Upcoming Tasks
        _filteredUpcomingTasks = _originalUpcomingTasks.where((item) {
          return _matchesSearchCriteria(item, searchQuery);
        }).toList();

        // Search in Overdue Tasks
        _filteredOverdueTasks = _originalOverdueTasks.where((item) {
          return _matchesSearchCriteria(item, searchQuery);
        }).toList();
      }
    });
  }

  // Helper method to check if an item matches search criteria
  bool _matchesSearchCriteria(dynamic item, String searchQuery) {
    // Check common fields that might exist in test drive data
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

  // Removed the API search method since we're doing local search only
  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;

    // Perform local search immediately
    _performLocalSearch(_query);
  }

  double _getResponsiveFontSize(BuildContext context, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 12; // Very small screens
    if (screenWidth < 400) return 13; // Small screens
    if (isTablet) return 16;
    return 14; // Default
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

  // Removed the old _filterTasks method since _performLocalSearch now handles all filtering

  // Responsive scaling while maintaining current design proportions
  double _getResponsiveScale() {
    final width = _getScreenWidth();
    if (width <= 320) return 0.85; // Very small phones
    if (width <= 375) return 0.95; // Small phones
    if (width <= 414) return 1.0; // Standard phones (base size)
    if (width <= 600) return 1.05; // Large phones
    if (width <= 768) return 1.1; // Small tablets
    return 1.15; // Large tablets and up
  }

  double _getSubTabFontSize() {
    return 12.0 * _getResponsiveScale(); // Base font size: 12
  }

  double _getSubTabHeight() {
    return 27.0 * _getResponsiveScale(); // Base height: 27
  }

  double _getSubTabWidth() {
    return 240.0 * _getResponsiveScale(); // Base width: 150
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
                child: _createTestDrive, // Your follow-up widget
              );
            },
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: fetchTasks,
        child: CustomScrollView(
          slivers: [
            // Top section with search bar and filter buttons.
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 38, // Minimum height for accessibility
                        maxHeight: 38, // Maximum height to prevent oversizing
                      ),
                      child: TextField(
                        autofocus: false,
                        controller: _searchController,
                        onChanged: (value) => _onSearchChanged(),
                        textAlignVertical: TextAlignVertical.center,
                        style: GoogleFonts.poppins(
                          fontSize: _getResponsiveFontSize(context, isTablet),
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
                          fillColor: AppColors.containerBg,
                          hintText: 'Search by name, email or phone',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: _getResponsiveHintFontSize(
                              context,
                              isTablet,
                            ),
                            fontWeight: FontWeight.w300,
                          ),
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
            // Search hint section
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
    // Check if we're searching and all filtered arrays are empty
    bool isSearchingWithNoResults =
        _isSearching &&
        _filteredAllTasks.isEmpty &&
        _filteredUpcomingTasks.isEmpty &&
        _filteredOverdueTasks.isEmpty;

    // If searching with no results, show a unified message
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

    switch (_upcommingButtonIndex) {
      case 0: // All Followups
        return _filteredAllTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    _isSearching
                        ? "No matching testdrive found"
                        : "No Testdrive available",
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
                        ? "No matching upcoming testdrive found"
                        : "No upcoming Testdrive available",
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
                        ? "No matching overdue testdrive found"
                        : "No overdue Testdrive available",
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
    final bool isActive = _upcommingButtonIndex == index;

    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => _upcommingButtonIndex = index),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? activeColor.withOpacity(0.29) : null,
          foregroundColor: isActive ? Colors.white : Colors.black,
          padding: EdgeInsets.symmetric(
            vertical: 5.0 * _getResponsiveScale(),
            horizontal: 0.0 * _getResponsiveScale(),
          ),
          side: BorderSide(
            color: isActive ? activeColor : Colors.transparent,
            width: .5,
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
