import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/utils/snackbar_helper.dart';
//
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/services/reassign_enq_srv.dart';
import 'package:smartassist/services/api_srv.dart';

class AllEnq extends StatefulWidget {
  const AllEnq({super.key});

  @override
  State<AllEnq> createState() => _AllEnqState();
}

class _AllEnqState extends State<AllEnq> {
  int _selectedButtonIndex = 0;
  bool isLoading = true;
  bool _isLoadingSearch = false;
  bool isSelectionMode = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, double> _swipeOffsets = {};
  final TextEditingController _searchController = TextEditingController();
  Set<String> selectedLeads = {};
  List<dynamic> upcomingTasks = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _filteredTasks = []; // Local filtered results
  String _query = '';

  // Filter variables
  String _selectedBrand = 'All';
  String _selectedAssignee = 'All';
  String _selectedTimeFrame = 'All';
  List<String> _availableBrands = ['All'];
  List<String> _availableAssignees = ['All'];
  final List<String> _timeFrameOptions = [
    'All',
    'Today',
    'This Week',
    'This Month',
  ];

  void _onHorizontalDragUpdate(DragUpdateDetails details, String leadId) {
    setState(() {
      _swipeOffsets[leadId] =
          (_swipeOffsets[leadId] ?? 0) + (details.primaryDelta ?? 0);
    });
  }

  void _handleCall(dynamic item) {
    print("Call action triggered for ${item['name']}");
    // Implement actual call functionality here
  }

  @override
  void initState() {
    super.initState();
    fetchTasksData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> fetchTasksData() async {
    final token = await Storage.getToken();
    try {
      final response = await http.get(
        Uri.parse('https://api.smartassistapp.in/api/leads/my-teams/all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('this is the leadall $data');

        setState(() {
          upcomingTasks = data['data']['rows'] ?? [];
          _filteredTasks = List.from(upcomingTasks); // Initialize filtered list
          isLoading = false;
        });

        // Extract filter options after setting the data
        _extractFilterOptions();

        // Debug: Print the extracted filter options
        print('Available Brands: $_availableBrands');
        print('Available Assignees: $_availableAssignees');
      } else {
        print("Failed to load data: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  // Enhanced method to extract unique brands and assignees from the data
  void _extractFilterOptions() {
    Set<String> brands = {};
    Set<String> assignees = {};

    print('Extracting filter options from ${upcomingTasks.length} tasks');

    for (var task in upcomingTasks) {
      // Debug: Print each task to see the structure
      print('Task data: ${task.toString()}');

      // Extract brand information
      var brandValue = task['brand'];
      if (brandValue != null) {
        String brandString = brandValue.toString().trim();
        if (brandString.isNotEmpty && brandString.toLowerCase() != 'null') {
          brands.add(brandString);
          print('Added brand: $brandString');
        }
      }

      // Extract assignee information (lead_owner)
      var assigneeValue = task['lead_owner'];
      if (assigneeValue != null) {
        String assigneeString = assigneeValue.toString().trim();
        if (assigneeString.isNotEmpty &&
            assigneeString.toLowerCase() != 'null') {
          assignees.add(assigneeString);
          print('Added assignee: $assigneeString');
        }
      }
    }

    setState(() {
      // Create lists with 'All' as the first option, then sorted unique values
      _availableBrands = ['All', ...brands.toList()..sort()];
      _availableAssignees = ['All', ...assignees.toList()..sort()];
    });

    print('Final Available Brands: $_availableBrands');
    print('Final Available Assignees: $_availableAssignees');
  }

  // Check if a date falls within the selected time frame
  bool _isDateInTimeFrame(String dateString, String timeFrame) {
    if (timeFrame == 'All') return true;

    try {
      DateTime date = DateTime.parse(dateString);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      switch (timeFrame) {
        case 'Today':
          DateTime itemDate = DateTime(date.year, date.month, date.day);
          return itemDate.isAtSameMomentAs(today);
        case 'This Week':
          DateTime startOfWeek = today.subtract(
            Duration(days: today.weekday - 1),
          );
          DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
          return date.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              date.isBefore(endOfWeek.add(Duration(days: 1)));
        case 'This Month':
          return date.year == now.year && date.month == now.month;
        default:
          return true;
      }
    } catch (e) {
      print('Error parsing date: $dateString');
      return true; // Include items with invalid dates
    }
  }

  // Apply all filters (search + brand + assignee + time frame)
  void _applyAllFilters() {
    List<dynamic> filtered = List.from(upcomingTasks);

    // Apply search filter
    if (_query.isNotEmpty) {
      filtered = filtered.where((item) {
        String name = (item['lead_name'] ?? '').toString().toLowerCase();
        String email = (item['email'] ?? '').toString().toLowerCase();
        String phone = (item['mobile'] ?? '').toString().toLowerCase();
        String searchQuery = _query.toLowerCase();

        return name.contains(searchQuery) ||
            email.contains(searchQuery) ||
            phone.contains(searchQuery);
      }).toList();
    }

    // Apply brand filter
    if (_selectedBrand != 'All') {
      filtered = filtered.where((item) {
        String itemBrand = (item['brand'] ?? '').toString().trim();
        bool match = itemBrand == _selectedBrand;
        print('Checking brand: $itemBrand == $_selectedBrand ? $match');
        return match;
      }).toList();
    }

    // Apply assignee filter
    if (_selectedAssignee != 'All') {
      filtered = filtered.where((item) {
        String itemAssignee = (item['lead_owner'] ?? '').toString().trim();
        bool match = itemAssignee == _selectedAssignee;
        print(
          'Checking assignee: $itemAssignee == $_selectedAssignee ? $match',
        );
        return match;
      }).toList();
    }

    // Apply time frame filter
    if (_selectedTimeFrame != 'All') {
      filtered = filtered.where((item) {
        String dateString = item['created_at'] ?? '';
        return _isDateInTimeFrame(dateString, _selectedTimeFrame);
      }).toList();
    }

    print('Filtered results count: ${filtered.length}');

    setState(() {
      _filteredTasks = filtered;
    });
  }

  // Local search function for name, email, phone
  void _performLocalSearch(String query) {
    _query = query;
    _applyAllFilters();
  }

  void _updateFilteredResults() {
    _applyAllFilters();
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
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    // Perform local search immediately for better UX
    _performLocalSearch(newQuery);

    // Also perform API search with debounce
    Future.delayed(const Duration(milliseconds: 500), () {
      if (newQuery == _searchController.text.trim()) {
        _fetchSearchResults(newQuery);
      }
    });
  }

  //select leads
  void _toggleSelection(String leadId) {
    HapticFeedback.selectionClick();

    setState(() {
      if (selectedLeads.contains(leadId)) {
        selectedLeads.remove(leadId);
        if (selectedLeads.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedLeads.add(leadId);
        if (!isSelectionMode) {
          isSelectionMode = true;
          HapticFeedback.mediumImpact();
        }
      }
    });
  }

  void _clearSelection() {
    HapticFeedback.lightImpact();

    setState(() {
      selectedLeads.clear();
      isSelectionMode = false;
    });
  }

  // Reset all filters
  void _resetFilters() {
    setState(() {
      _selectedBrand = 'All';
      _selectedAssignee = 'All';
      _selectedTimeFrame = 'All';
      _searchController.clear();
      _query = '';
    });
    _applyAllFilters();
  }

  // Get active filter count
  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedBrand != 'All') count++;
    if (_selectedAssignee != 'All') count++;
    if (_selectedTimeFrame != 'All') count++;
    if (_query.isNotEmpty) count++;
    return count;
  }

  // Responsive helper methods
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

  //build users profile pics
  Widget _buildUserAvatar(Map<String, dynamic> user, String userName) {
    final profilePic = user['profile_pic']?.toString();

    if (profilePic != null && profilePic.isNotEmpty && profilePic != 'null') {
      return Image.network(
        profilePic,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1380FE),
                  const Color(0xFF1380FE).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialAvatar(userName);
        },
      );
    } else {
      return _buildInitialAvatar(userName);
    }
  }

  Widget _buildInitialAvatar(String userName) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1380FE),
            const Color(0xFF1380FE).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      appBar: AppBar(
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: selectedLeads.isNotEmpty
              ? IconButton(
                  key: const ValueKey('clear'),
                  onPressed: _clearSelection,
                  icon: const Icon(FontAwesomeIcons.xmark, color: Colors.white),
                )
              : IconButton(
                  key: const ValueKey('back'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BottomNavigation(),
                      ),
                    );
                  },
                  icon: const Icon(
                    FontAwesomeIcons.angleLeft,
                    color: Colors.white,
                  ),
                ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            selectedLeads.isNotEmpty
                ? "${selectedLeads.length} selected"
                : "Team's Enquiries",
            key: ValueKey(selectedLeads.isNotEmpty),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF1380FE),
        automaticallyImplyLeading: false,
        actions: selectedLeads.isNotEmpty
            ? [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: selectedLeads.isNotEmpty ? 1.0 : 0.0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double screenWidth = MediaQuery.of(context).size.width;
                      double fontSize = screenWidth < 360
                          ? 12
                          : (screenWidth < 600 ? 14 : 16);
                      EdgeInsets padding = screenWidth < 360
                          ? const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            )
                          : screenWidth < 600
                          ? const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            );

                      return TextButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          print("Selected leads: $selectedLeads");

                          if (selectedLeads.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select leads to reassign',
                                ),
                              ),
                            );
                            return;
                          }

                          // Show user selection dialog
                          final selectedUser = await showDialog<Map<String, dynamic>>(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.white,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.85,
                                constraints: const BoxConstraints(
                                  maxHeight: 700,
                                  maxWidth: 400,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header with gradient background
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF1380FE),
                                            const Color(
                                              0xFF1380FE,
                                            ).withOpacity(0.8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.person_search_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Select a PS to reassign',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Content area
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        child: FutureBuilder<List<Map<String, dynamic>>>(
                                          future: LeadsSrv.fetchUsers(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return Container(
                                                height: 200,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 50,
                                                      height: 50,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 3,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              const Color(
                                                                0xFF1380FE,
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Loading users...',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }

                                            if (snapshot.hasError) {
                                              return Container(
                                                height: 200,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[50],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .error_outline_rounded,
                                                        color: Colors.red[400],
                                                        size: 48,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Error loading users',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.grey[800],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '${snapshot.error}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }

                                            final users = snapshot.data ?? [];

                                            if (users.isEmpty) {
                                              return Container(
                                                height: 200,
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[100],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .people_outline_rounded,
                                                        color: Colors.grey[400],
                                                        size: 48,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'No users available',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }

                                            return ListView.separated(
                                              shrinkWrap: true,
                                              itemCount: users.length,
                                              separatorBuilder:
                                                  (context, index) => Divider(
                                                    height: 1,
                                                    color: Colors.grey[200],
                                                  ),
                                              itemBuilder: (context, index) {
                                                final user = users[index];
                                                final userName =
                                                    user['name'] ??
                                                    'Unknown User';

                                                return Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    onTap: () async {
                                                      final userId =
                                                          user['user_id']
                                                              ?.toString();

                                                      if (userId != null &&
                                                          userId.isNotEmpty &&
                                                          userId != 'null') {
                                                        Navigator.of(
                                                          context,
                                                        ).pop({
                                                          'id': userId,
                                                          'name': userName,
                                                        });
                                                      } else {
                                                        // Close dialog first, then show snackbar
                                                        Navigator.of(
                                                          context,
                                                        ).pop();

                                                        // Use a slight delay to ensure navigator is unlocked
                                                        await Future.delayed(
                                                          const Duration(
                                                            milliseconds: 100,
                                                          ),
                                                        );

                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: const Text(
                                                                'Unable to get user ID',
                                                              ),
                                                              backgroundColor:
                                                                  Colors
                                                                      .red[400],
                                                              behavior:
                                                                  SnackBarBehavior
                                                                      .floating,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 16,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          // Avatar
                                                          Container(
                                                            width: 48,
                                                            height: 48,
                                                            decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    24,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFF1380FE,
                                                                    ).withOpacity(
                                                                      0.2,
                                                                    ),
                                                                width: 2,
                                                              ),
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    22,
                                                                  ),
                                                              child:
                                                                  _buildUserAvatar(
                                                                    user,
                                                                    userName,
                                                                  ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),

                                                          // User info
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  userName,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .grey[800],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          // Arrow icon
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_ios_rounded,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[400],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                    // Footer with action buttons
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          // If no user was selected, return early
                          if (selectedUser == null) {
                            return;
                          }

                          final selectedUserId = selectedUser['id']!;
                          final selectedUserName = selectedUser['name']!;

                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          try {
                            final result = await ApiService.reassignLeads(
                              leadIds: selectedLeads,
                              assignee:
                                  selectedUserId, // This is the user_id from fetchUsers response
                            );

                            // Hide loading indicator
                            Navigator.of(context).pop();

                            if (result['success']) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Reassigned to $selectedUserName',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior
                                      .floating, // Optional: Makes it float above UI
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      10,
                                    ), // Optional: rounded corners
                                  ),
                                ),
                              );
                              // Clear selection
                              setState(() {
                                selectedLeads.clear();
                              });

                              // Refresh the leads data
                              await fetchTasksData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['error'] ?? 'Unknown error occurred',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            // Hide loading indicator
                            Navigator.of(context).pop();

                            print("Error reassigning leads: $e"); // Debug log
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unexpected error: $e')),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: padding,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Reassign to",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Responsive Search field container
                Container(
                  margin: EdgeInsets.all(isTablet ? 15 : 10),
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
                        fillColor: AppColors.backgroundLightGrey,
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

                // Filter Section
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 15 : 10,
                    vertical: isTablet ? 8 : 5,
                  ),
                  child: Column(
                    children: [
                      // Filter Buttons Row
                      Row(
                        children: [
                          // Brand Filter
                          Expanded(
                            child: _buildFilterDropdown(
                              'Brand',
                              _selectedBrand,
                              _availableBrands,
                              (value) {
                                setState(() {
                                  _selectedBrand = value!;
                                });
                                _applyAllFilters();
                              },
                              isTablet,
                            ),
                          ),
                          SizedBox(width: isTablet ? 10 : 8),

                          // Assignee Filter
                          Expanded(
                            child: _buildFilterDropdown(
                              'Owner',
                              _selectedAssignee,
                              _availableAssignees,
                              (value) {
                                setState(() {
                                  _selectedAssignee = value!;
                                });
                                _applyAllFilters();
                              },
                              isTablet,
                            ),
                          ),
                          SizedBox(width: isTablet ? 10 : 8),

                          // Time Frame Filter
                          Expanded(
                            child: _buildFilterDropdown(
                              'Time',
                              _selectedTimeFrame,
                              _timeFrameOptions,
                              (value) {
                                setState(() {
                                  _selectedTimeFrame = value!;
                                });
                                _applyAllFilters();
                              },
                              isTablet,
                            ),
                          ),
                        ],
                      ),

                      // Clear Filters Button (only show if filters are active)
                      if (_getActiveFilterCount() > 0)
                        Padding(
                          padding: EdgeInsets.only(top: isTablet ? 8 : 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_getActiveFilterCount()} filter(s) active',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 12 : 10,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              TextButton(
                                onPressed: _resetFilters,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 12 : 8,
                                    vertical: isTablet ? 4 : 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Clear All',
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 14 : 12,
                                    color: AppColors.colorsBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Search query indicator
                if (_query.isNotEmpty || _getActiveFilterCount() > 0)
                  Padding(
                    padding: EdgeInsets.only(
                      left: isTablet ? 15 : 10,
                      bottom: isTablet ? 8 : 5,
                      right: isTablet ? 15 : 10,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _buildFilterSummary(),
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 14 : 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                // Results list - using filtered local results
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: false,
                    trackVisibility: false,
                    thickness: 8.0,
                    radius: const Radius.circular(4.0),
                    interactive: true,
                    child:
                        //  _query.isNotEmpty
                        // ? _buildTasksList(_searchResults)
                        _buildTasksList(_filteredTasks),
                  ),
                ),

                //  _buildTasksList(_filteredTasks)
              ],
            ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String selectedValue,
    List<String> options,
    ValueChanged<String?> onChanged,
    bool isTablet,
  ) {
    // Debug: Print dropdown options
    print('Building dropdown for $label with options: $options');

    return Container(
      height: isTablet ? 40 : 36,
      decoration: BoxDecoration(
        color: selectedValue != 'All'
            ? AppColors.colorsBlue.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: selectedValue != 'All'
              ? AppColors.colorsBlue.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: selectedValue != 'All'
                ? AppColors.colorsBlue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: Container(
            margin: EdgeInsets.only(right: isTablet ? 8 : 6),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: isTablet ? 22 : 20,
              color: selectedValue != 'All'
                  ? AppColors.colorsBlue
                  : Colors.grey[500],
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 13 : 11,
            color: selectedValue != 'All'
                ? AppColors.colorsBlue
                : Colors.grey[700],
            fontWeight: selectedValue != 'All'
                ? FontWeight.w600
                : FontWeight.w400,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(15),
          elevation: 8,
          menuMaxHeight: 250,
          items: options.map<DropdownMenuItem<String>>((String value) {
            bool isSelected = value == selectedValue;
            bool isAllOption = value == 'All';

            return DropdownMenuItem<String>(
              value: value,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 10,
                  vertical: isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.colorsBlue.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (isSelected && !isAllOption)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.check_circle,
                          size: isTablet ? 16 : 14,
                          color: AppColors.colorsBlue,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        isAllOption ? label : value,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 13 : 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.colorsBlue
                              : (isAllOption
                                    ? Colors.grey[600]
                                    : Colors.grey[800]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          selectedItemBuilder: (BuildContext context) {
            return options.map<Widget>((String value) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 10,
                  vertical: 0,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (selectedValue != 'All')
                      Container(
                        margin: EdgeInsets.only(right: 6),
                        width: isTablet ? 6 : 5,
                        height: isTablet ? 6 : 5,
                        decoration: BoxDecoration(
                          color: AppColors.colorsBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        value == 'All' ? label : value,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 13 : 11,
                          fontWeight: selectedValue != 'All'
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selectedValue != 'All'
                              ? AppColors.colorsBlue
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _buildFilterSummary() {
    List<String> activeSummary = [];

    if (_query.isNotEmpty) {
      activeSummary.add('Search: "$_query"');
    }
    if (_selectedBrand != 'All') {
      activeSummary.add('Brand: $_selectedBrand');
    }
    if (_selectedAssignee != 'All') {
      activeSummary.add('Assignee: $_selectedAssignee');
    }
    if (_selectedTimeFrame != 'All') {
      activeSummary.add('Time: $_selectedTimeFrame');
    }

    String summary = activeSummary.join(' | ');
    return 'Filtered by: $summary (${_filteredTasks.length} results)';
  }

  Widget _buildTasksList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      final screenSize = MediaQuery.of(context).size;
      final isTablet = screenSize.width > 600;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getActiveFilterCount() > 0
                  ? FontAwesomeIcons.filter
                  : FontAwesomeIcons.magnifyingGlass,
              size: isTablet ? 60 : 40,
              color: Colors.grey[400],
            ),
            SizedBox(height: isTablet ? 20 : 15),
            Text(
              _getActiveFilterCount() > 0
                  ? 'No results found with current filters'
                  : (_query.isEmpty
                        ? 'No Enquiries available'
                        : 'No results found for "$_query"'),
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 18 : 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_getActiveFilterCount() > 0) ...[
              SizedBox(height: isTablet ? 10 : 8),
              Text(
                'Try adjusting your filters or search terms',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isTablet ? 15 : 10),
              TextButton(
                onPressed: _resetFilters,
                child: Text(
                  'Clear All Filters',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 14 : 12,
                    color: AppColors.colorsBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (_query.isNotEmpty) ...[
              SizedBox(height: isTablet ? 10 : 8),
              Text(
                'Try searching with different keywords',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        var item = tasks[index];

        if (!(item.containsKey('lead_id') && item.containsKey('lead_name'))) {
          return ListTile(title: Text('Invalid data at index $index'));
        }

        String leadId = item['lead_id'] ?? '';
        double swipeOffset = _swipeOffsets[leadId] ?? 0;
        bool isSelected = selectedLeads.contains(leadId);

        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _onHorizontalDragUpdate(details, leadId),
          child: TaskItem(
            name: item['lead_name'] ?? '',
            date: item['created_at'] ?? '',
            subject: item['email'] ?? 'No subject',
            vehicle: item['PMI'] ?? 'Discovery Sport',
            leadId: leadId,
            taskId: leadId,
            brand: item['brand'] ?? '',
            assignee: item['lead_owner'] ?? '',
            number: item['mobile'] ?? '',
            isFavorite: item['favourite'] ?? false,
            swipeOffset: swipeOffset,
            isSelected: isSelected,
            isSelectionMode: isSelectionMode,
            fetchDashboardData: () {},
            onLongPress: () => _toggleSelection(leadId),
            onTap: selectedLeads.isNotEmpty
                ? () => _toggleSelection(leadId)
                : null,
          ),
        );
      },
    );
  }
}

// Rest of the classes remain the same...
class TaskItem extends StatefulWidget {
  final String name, subject, number;
  final String date;
  final String vehicle;
  final String leadId;
  final String taskId;
  final String brand;
  final String assignee;
  final double swipeOffset;
  final bool isFavorite;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback fetchDashboardData;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  // final VoidCallback onFavoriteToggled;
  // final Function(bool) onFavoriteChanged;
  // final VoidCallback onToggleFavorite;

  const TaskItem({
    super.key,
    required this.name,
    required this.date,
    required this.vehicle,
    required this.leadId,
    required this.taskId,
    required this.isFavorite,
    required this.isSelected,
    required this.isSelectionMode,
    required this.brand,
    required this.assignee,
    required this.subject,
    required this.swipeOffset,
    required this.fetchDashboardData,
    required this.number,
    required this.onLongPress,
    this.onTap,
    // required this.onFavoriteToggled,
    // required this.onFavoriteChanged,
    // required this.onToggleFavorite,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem>
    with SingleTickerProviderStateMixin {
  late bool isFav;
  late SlidableController _slidableController;

  void updateFavoriteStatus(bool newStatus) {
    setState(() {
      isFav = newStatus;
    });
  }

  @override
  void initState() {
    super.initState();
    isFav = widget.isFavorite;
    _slidableController = SlidableController(this);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 15 : 10,
        isTablet ? 8 : 5,
        isTablet ? 15 : 10,
        0,
      ),
      child: _buildFollowupCard(context),
    );
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
  }

  Widget _buildFollowupCard(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    bool isCallSwipe = widget.swipeOffset < -50;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.onLongPress();
      },
      onTap:
          widget.onTap ??
          () {
            if (widget.leadId.isNotEmpty) {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FollowupsDetails(
                    leadId: widget.leadId,
                    isFromFreshlead: false,
                    isFromManager: true,

                    isFromTestdriveOverview: false,
            refreshDashboard: ()async{},
                  ),
                ),
              );
            } else {
              print("Invalid leadId");
            }
          },
      child: Slidable(
        key: ValueKey(widget.leadId),
        controller: _slidableController, // Add the controller here
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: isTablet ? 0.15 : 0.2,
          children: [
            ReusableSlidableAction(
              onPressed: () {
                HapticFeedback.heavyImpact();
                widget.onLongPress(); // Handle slide action
              },
              backgroundColor: const Color.fromARGB(255, 231, 225, 225),
              icon: Icons.check_circle_outline_rounded,
              foregroundColor: Colors.white,
              iconSize: isTablet ? 45 : 40,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main Container with AnimatedContainer styling
            AnimatedContainer(
              duration: const Duration(milliseconds: 30),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 15 : 10,
                vertical: isTablet ? 20 : 15,
              ),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.backgroundLightGrey.withOpacity(0.8)
                    : AppColors.backgroundLightGrey,
                borderRadius: BorderRadius.circular(7),
                border: Border(
                  left: BorderSide(
                    width: isTablet ? 10.0 : 8.0,
                    color: widget.isSelected
                        ? AppColors.sideGreen.withOpacity(0.8)
                        : AppColors.colorsBlue.withOpacity(0.6),
                  ),
                  bottom: widget.isSelected
                      ? BorderSide(
                          width: 1,
                          color: AppColors.sideGreen.withOpacity(0.8),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Opacity(
                opacity: (isCallSwipe) ? 0 : 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated check icon (appears when selected)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: widget.isSelected ? 36 : 0,
                      margin: EdgeInsets.only(
                        right: widget.isSelected ? 12 : 0,
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: widget.isSelected ? 1.0 : 0.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 300),
                          scale: widget.isSelected ? 1.0 : 0.8,
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(width: isTablet ? 12 : 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Flexible(child: _buildUserDetails(context)),
                                    _buildVerticalDivider(isTablet ? 18 : 15),
                                    Flexible(
                                      child: _buildSubjectDetails(context),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isTablet ? 6 : 4),
                                Row(
                                  children: [
                                    Flexible(child: _buildCarModel(context)),
                                    _buildVerticalDivider(15),
                                    Text(
                                      "By- ",
                                      style: AppFont.dashboardCarName(context),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Flexible(child: _buildAssignee(context)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Animated navigation button (hides when selected)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: widget.isSelected ? 0 : 36,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: widget.isSelected ? 0.0 : 1.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 300),
                          scale: widget.isSelected ? 0.8 : 1.0,
                          child: _buildNavigationButton(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetails(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Text(
      widget.name,
      textAlign: TextAlign.start,
      style:
          AppFont.dashboardName(
            context,
          )?.copyWith(fontSize: isTablet ? 18 : null) ??
          GoogleFonts.poppins(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w500,
          ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubjectDetails(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    String mobile = widget.number;
    String hiddenMobile = _hideMobileNumber(mobile);

    return Text(
      hiddenMobile,
      style:
          AppFont.smallText(
            context,
          )?.copyWith(fontSize: isTablet ? 14 : null) ??
          GoogleFonts.poppins(
            fontSize: isTablet ? 14 : 12,
            color: Colors.grey[600],
          ),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _hideMobileNumber(String mobile) {
    if (mobile.length >= 10) {
      return mobile.substring(0, 3) + '*****' + mobile.substring(8);
    } else {
      return mobile;
    }
  }

  //navigation button to show action slider
  Widget _buildNavigationButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Simple toggle: close first, then open if it was closed
        _slidableController.close();

        // Use a small delay to ensure close completes, then open
        Future.delayed(Duration(milliseconds: 100), () {
          if (_slidableController.actionPaneType != ActionPaneType.end) {
            _slidableController.openEndActionPane();
          }
        });
      },

      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.arrowContainerColor,
          borderRadius: BorderRadius.circular(30),
        ),

        child: const Icon(
          Icons.arrow_back_ios_rounded,
          size: 25,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(double height) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      margin: EdgeInsets.only(
        bottom: 3,
        left: isTablet ? 15 : 10,
        right: isTablet ? 15 : 10,
      ),
      height: height,
      width: 0.1,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.fontColor)),
      ),
    );
  }

  Widget _buildCarModel(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Text(
      widget.vehicle,
      textAlign: TextAlign.start,
      style:
          AppFont.dashboardCarName(
            context,
          )?.copyWith(fontSize: isTablet ? 16 : null) ??
          GoogleFonts.poppins(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w400,
          ),
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAssignee(BuildContext context) {
    return Text(
      widget.assignee,
      textAlign: TextAlign.start,
      style: AppFont.assigneeName(context),

      overflow: TextOverflow.ellipsis,
    );
  }
}

// Keep the existing FlexibleButton and ReusableSlidableAction classes
class FlexibleButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final BoxDecoration decoration;
  final TextStyle textStyle;

  const FlexibleButton({
    super.key,
    required this.title,
    required this.onPressed,
    required this.decoration,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      height: 30,
      decoration: decoration,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xffF3F9FF),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: textStyle, textAlign: TextAlign.center),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class ReusableSlidableAction extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;
  final Color? foregroundColor;
  final double iconSize;

  const ReusableSlidableAction({
    Key? key,
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    this.foregroundColor,
    this.iconSize = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      borderRadius: BorderRadius.circular(10),
      onPressed: (context) => onPressed(),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.zero,
      child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
    );
  }
}
