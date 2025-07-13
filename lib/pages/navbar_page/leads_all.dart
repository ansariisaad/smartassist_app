import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/lead_update.dart';
import 'package:smartassist/pages/Home/reassign_enq.dart';
import 'package:smartassist/widgets/reusable/skeleton_globle_search_card.dart';

class AllLeads extends StatefulWidget {
  const AllLeads({super.key});

  @override
  State<AllLeads> createState() => _AllLeadsState();
}

class _AllLeadsState extends State<AllLeads> {
  bool isLoading = true;
  final Map<String, double> _swipeOffsets = {};
  Set<String> selectedLeads = {};
  bool isSelectionMode = false;
  List<dynamic> upcomingTasks = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _filteredTasks = []; // Local filtered results
  bool _isLoadingSearch = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter variables
  String _selectedSortBy = 'Date Created';
  String _selectedStatus = 'All';
  String _selectedTimeFilter = 'All Time';

  // Filter options
  final List<String> _sortOptions = [
    'Date Created',
    'Name (A-Z)',
    'Name (Z-A)',
    'Recently Updated',
    'Oldest First',
  ];

  final List<String> _statusOptions = [
    'All',
    'New',
    'Follow Up',
    'Qualified',
    'Lost',
  ];

  final List<String> _timeFilterOptions = [
    'All Time',
    'Today',
    'This Week',
    'This Month',
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
  ];

  void _onHorizontalDragUpdate(DragUpdateDetails details, String leadId) {
    setState(() {
      _swipeOffsets[leadId] =
          (_swipeOffsets[leadId] ?? 0) + (details.primaryDelta ?? 0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, dynamic item, int index) {
    String leadId = item['lead_id'];
    double swipeOffset = _swipeOffsets[leadId] ?? 0;

    if (swipeOffset > 100) {
      // Right Swipe (Favorite)
      _toggleFavorite(leadId, index);
      bool currentStatus = item['favourite'] ?? false;
      bool newStatus = !currentStatus;

      // Update the UI immediately without waiting for API
      setState(() {
        upcomingTasks[index]['favourite'] = newStatus;
        _updateFilteredResults(); // Update filtered results too
      });
    } else if (swipeOffset < -100) {
      // Left Swipe (Call)
      _handleCall(item);
    }

    // Reset animation
    setState(() {
      _swipeOffsets[leadId] = 0.0;
    });
  }

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

  // Helper methods to get responsive dimensions - moved to methods to avoid context issues
  bool _isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width > 768;
  bool _isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 400;
  double _screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  // Responsive padding
  EdgeInsets _responsivePadding(BuildContext context) => EdgeInsets.symmetric(
    horizontal: _isTablet(context) ? 20 : (_isSmallScreen(context) ? 8 : 10),
    vertical: _isTablet(context) ? 12 : 8,
  );

  // Responsive font sizes
  double _titleFontSize(BuildContext context) =>
      _isTablet(context) ? 20 : (_isSmallScreen(context) ? 16 : 18);
  double _bodyFontSize(BuildContext context) =>
      _isTablet(context) ? 16 : (_isSmallScreen(context) ? 12 : 14);
  double _smallFontSize(BuildContext context) =>
      _isTablet(context) ? 14 : (_isSmallScreen(context) ? 10 : 12);

  Future<void> _toggleFavorite(String leadId, int index) async {
    final token = await Storage.getToken();
    try {
      bool currentStatus = upcomingTasks[index]['favourite'] ?? false;
      bool newFavoriteStatus = !currentStatus;

      final response = await http.put(
        Uri.parse(
          'https://api.smartassistapp.in/api/favourites/mark-fav/lead/$leadId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          // Update upcomingTasks
          upcomingTasks[index]['favourite'] = newFavoriteStatus;
          // Update _filteredTasks to reflect the change
          int filteredIndex = _filteredTasks.indexWhere(
            (task) => task['lead_id'] == leadId,
          );
          if (filteredIndex != -1) {
            _filteredTasks[filteredIndex]['favourite'] = newFavoriteStatus;
          }
        });
      } else {
        print('Failed to toggle favorite: ${response.statusCode}');
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
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
    super.dispose();
  }

  Future<void> fetchTasksData() async {
    final token = await Storage.getToken();
    try {
      final response = await http.get(
        Uri.parse('https://api.smartassistapp.in/api/leads/fetch/all'),
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
          _applyFilters(); // Apply initial filters
          isLoading = false;
        });
      } else {
        print("Failed to load data: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  void _performLocalSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTasks = List.from(upcomingTasks); // Copy without sorting
        _applyFilters(); // Apply filters after search
      });
      return;
    }

    setState(() {
      _filteredTasks = upcomingTasks.where((item) {
        String name = (item['lead_name'] ?? '').toString().toLowerCase();
        String email = (item['email'] ?? '').toString().toLowerCase();
        String phone = (item['mobile'] ?? '').toString().toLowerCase();
        String searchQuery = query.toLowerCase();

        return name.contains(searchQuery) ||
            email.contains(searchQuery) ||
            phone.contains(searchQuery);
      }).toList();
      _applyFilters(); // Apply filters after search
    });
  }

  void _updateFilteredResults() {
    if (_query.isEmpty) {
      setState(() {
        _filteredTasks = List.from(upcomingTasks); // Copy without sorting
        _applyFilters(); // Apply filters
      });
    } else {
      _performLocalSearch(_query);
    }
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;

    // Perform local search immediately for better UX
    _performLocalSearch(_query);
  }

  // Filter methods
  void _applyFilters() {
    List<dynamic> filteredList = List.from(_filteredTasks);

    // Apply status filter
    if (_selectedStatus != 'All') {
      filteredList = filteredList.where((item) {
        String status = (item['status'] ?? 'New').toString();
        return status.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // Apply time filter
    if (_selectedTimeFilter != 'All Time') {
      DateTime now = DateTime.now();
      filteredList = filteredList.where((item) {
        String dateStr = item['created_at'] ?? '';
        if (dateStr.isEmpty) return false;

        try {
          DateTime itemDate = DateTime.parse(dateStr);

          switch (_selectedTimeFilter) {
            case 'Today':
              return itemDate.year == now.year &&
                  itemDate.month == now.month &&
                  itemDate.day == now.day;
            case 'This Week':
              DateTime startOfWeek = now.subtract(
                Duration(days: now.weekday - 1),
              );
              return itemDate.isAfter(startOfWeek.subtract(Duration(days: 1)));
            case 'This Month':
              return itemDate.year == now.year && itemDate.month == now.month;
            case 'Last 7 Days':
              DateTime sevenDaysAgo = now.subtract(Duration(days: 7));
              return itemDate.isAfter(sevenDaysAgo);
            case 'Last 30 Days':
              DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));
              return itemDate.isAfter(thirtyDaysAgo);
            case 'Last 90 Days':
              DateTime ninetyDaysAgo = now.subtract(Duration(days: 90));
              return itemDate.isAfter(ninetyDaysAgo);
            default:
              return true;
          }
        } catch (e) {
          print('Error parsing date: $e');
          return false;
        }
      }).toList();
    }

    // Apply sorting
    switch (_selectedSortBy) {
      case 'Name (A-Z)':
        filteredList.sort((a, b) {
          String nameA = (a['lead_name'] ?? '').toString().toLowerCase();
          String nameB = (b['lead_name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'Name (Z-A)':
        filteredList.sort((a, b) {
          String nameA = (a['lead_name'] ?? '').toString().toLowerCase();
          String nameB = (b['lead_name'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;
      case 'Recently Updated':
        filteredList.sort((a, b) {
          String dateA = a['updated_at'] ?? a['created_at'] ?? '';
          String dateB = b['updated_at'] ?? b['created_at'] ?? '';
          return dateB.compareTo(dateA);
        });
        break;
      case 'Oldest First':
        filteredList.sort((a, b) {
          String dateA = a['created_at'] ?? '';
          String dateB = b['created_at'] ?? '';
          return dateA.compareTo(dateB);
        });
        break;
      case 'Date Created':
      default:
        filteredList.sort((a, b) {
          String dateA = a['created_at'] ?? '';
          String dateB = b['created_at'] ?? '';
          return dateB.compareTo(dateA);
        });
        break;
    }

    setState(() {
      _filteredTasks = filteredList;
    });
  }

  void _onFilterChanged() {
    _updateFilteredResults();
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

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    required bool isTablet,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 12 : 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Container(
            height: isTablet ? 40 : 36,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 8,
              vertical: 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: Container(
                  margin: EdgeInsets.only(right: isTablet ? 8 : 6),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: isTablet ? 22 : 20,
                    color: Colors.grey[500],
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 13 : 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(15),
                elevation: 8,
                menuMaxHeight: 250,
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
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
          },
          icon: Icon(
            FontAwesomeIcons.angleLeft,
            color: Colors.white,
            size: _isSmallScreen(context) ? 18 : 20,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'My Enquiries',
            style: GoogleFonts.poppins(
              fontSize: _titleFontSize(context),
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? SkeletonGlobleSearchCard()
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
                        fillColor: AppColors.searchBar,
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

                // Filter dropdowns
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 15 : 10,
                    vertical: isTablet ? 10 : 5,
                  ),
                  child: Row(
                    children: [
                      _buildDropdownFilter(
                        label: 'Sort By',
                        value: _selectedSortBy,
                        options: _sortOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedSortBy = value!;
                          });
                          _onFilterChanged();
                        },
                        isTablet: isTablet,
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      _buildDropdownFilter(
                        label: 'Status',
                        value: _selectedStatus,
                        options: _statusOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                          _onFilterChanged();
                        },
                        isTablet: isTablet,
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      _buildDropdownFilter(
                        label: 'Time',
                        value: _selectedTimeFilter,
                        options: _timeFilterOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedTimeFilter = value!;
                          });
                          _onFilterChanged();
                        },
                        isTablet: isTablet,
                      ),
                    ],
                  ),
                ),

                // Active filters indicator
                if (_selectedSortBy != 'Date Created' ||
                    _selectedStatus != 'All' ||
                    _selectedTimeFilter != 'All Time')
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isTablet ? 15 : 10,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: isTablet ? 16 : 14,
                          color: AppColors.colorsBlue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Filters active',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 12 : 10,
                            color: AppColors.colorsBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSortBy = 'Date Created';
                              _selectedStatus = 'All';
                              _selectedTimeFilter = 'All Time';
                            });
                            _onFilterChanged();
                          },
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12 : 10,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Search query indicator
                if (_query.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      left: isTablet ? 15 : 10,
                      bottom: isTablet ? 8 : 5,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Showing results for: $_query (${_filteredTasks.length} found)',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 14 : 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                // Results count
                if (_query.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      left: isTablet ? 15 : 10,
                      bottom: isTablet ? 8 : 5,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total Records: ${_filteredTasks.length}',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                // Results list - using filtered local results
                Expanded(child: _buildTasksList(_filteredTasks)),
              ],
            ),
    );
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
              FontAwesomeIcons.magnifyingGlass,
              size: isTablet ? 60 : 40,
              color: Colors.grey[400],
            ),
            SizedBox(height: isTablet ? 20 : 15),
            Text(
              _query.isEmpty
                  ? 'No Leads available'
                  : 'No results found for "$_query"',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 18 : 16,
                color: Colors.grey[600],
              ),
            ),
            if (_query.isNotEmpty) ...[
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
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        var item = tasks[index];

        if (!(item.containsKey('lead_id') && item.containsKey('lead_name'))) {
          return ListTile(title: Text('Invalid data at index $index'));
        }

        String leadId = item['lead_id'] ?? '';
        double swipeOffset = _swipeOffsets[leadId] ?? 0;

        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _onHorizontalDragUpdate(details, leadId),
          onHorizontalDragEnd: (details) =>
              _onHorizontalDragEnd(details, item, index),
          child: TaskItem(
            name: item['lead_name'] ?? '',
            date: item['created_at'] ?? '',
            subject: item['email'] ?? 'No subject',
            vehicle: item['PMI'] ?? 'Discovery Sport',
            leadId: leadId,
            taskId: leadId,
            brand: item['brand'] ?? '',
            number: item['mobile'] ?? '',
            isFavorite: item['favourite'] ?? false,
            swipeOffset: swipeOffset,
            fetchDashboardData: () {},
            onFavoriteToggled: () async {
              _updateFilteredResults();
            },
            onTap: selectedLeads.isNotEmpty
                ? () => _toggleSelection(leadId)
                : null,
            onFavoriteChanged: (newStatus) {
              setState(() {
                // Find the item in the original list and update it
                int originalIndex = upcomingTasks.indexWhere(
                  (task) => task['lead_id'] == leadId,
                );
                if (originalIndex != -1) {
                  upcomingTasks[originalIndex]['favourite'] = newStatus;
                }
                _updateFilteredResults();
              });
            },
            onToggleFavorite: () {
              // Find the correct index in the original list
              int originalIndex = upcomingTasks.indexWhere(
                (task) => task['lead_id'] == leadId,
              );
              if (originalIndex != -1) {
                _toggleFavorite(leadId, originalIndex);
              }
            },
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
  final double swipeOffset;
  final bool isFavorite;
  final VoidCallback fetchDashboardData;
  final VoidCallback onFavoriteToggled;
  final Function(bool) onFavoriteChanged;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onTap;

  const TaskItem({
    super.key,
    required this.name,
    required this.date,
    required this.vehicle,
    required this.leadId,
    required this.taskId,
    required this.isFavorite,
    required this.onFavoriteToggled,
    required this.brand,
    required this.subject,
    required this.swipeOffset,
    required this.fetchDashboardData,
    required this.onFavoriteChanged,
    required this.onToggleFavorite,
    required this.number,
    required this.onTap,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem>
    with SingleTickerProviderStateMixin {
  late SlidableController _slidableController;
  late bool isFav;

  void updateFavoriteStatus(bool newStatus) {
    setState(() {
      isFav = newStatus;
    });
  }

  @override
  void initState() {
    super.initState();
    _slidableController = SlidableController(this);

    isFav = widget.isFavorite;
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
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

  Widget _buildFollowupCard(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    bool isFavoriteSwipe = widget.swipeOffset > 50;
    bool isCallSwipe = widget.swipeOffset < -50;

    return GestureDetector(
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
                    isFromManager: false,

                    isFromTestdriveOverview: false,
                    refreshDashboard: () async {},
                  ),
                ),
              );
            } else {
              print("Invalid leadId");
            }
          },
      child: Slidable(
        key: ValueKey(widget.leadId),
        controller: _slidableController, // Add this line
        closeOnScroll: true,
        startActionPane: ActionPane(
          extentRatio: isTablet ? 0.15 : 0.2,
          motion: const ScrollMotion(),
          children: [
            ReusableSlidableAction(
              onPressed: () {
                widget.onToggleFavorite();
                _slidableController.close();
                setState(() {
                  _isActionPaneOpen = false;
                });
              },
              onDismissed: () {},
              backgroundColor: Colors.amber,
              icon: widget.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              foregroundColor: Colors.white,
              iconSize: isTablet ? 45 : 40,
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: isTablet ? 0.15 : 0.2,
          children: [
            ReusableSlidableAction(
              onPressed: () {
                _mailAction();
                _slidableController.close();
                setState(() {
                  _isActionPaneOpen = false;
                });
              },

              backgroundColor: const Color.fromARGB(255, 231, 225, 225),
              icon: Icons.edit,
              foregroundColor: Colors.white,
              iconSize: isTablet ? 45 : 40,
              onDismissed: () {
                setState(() {
                  _isActionPaneOpen = false;
                });
              },
            ),
          ],
        ),
        child: Stack(
          children: [
            // Favorite Swipe Overlay
            if (isFavoriteSwipe)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.yellow.withOpacity(0.2),
                        Colors.yellow.withOpacity(0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(width: isTablet ? 20 : 15),
                        Icon(
                          isFav
                              ? Icons.star_outline_rounded
                              : Icons.star_rounded,
                          color: const Color.fromRGBO(226, 195, 34, 1),
                          size: isTablet ? 50 : 40,
                        ),
                        SizedBox(width: isTablet ? 15 : 10),
                        Text(
                          isFav ? 'Unfavorite' : 'Favorite',
                          style: GoogleFonts.poppins(
                            color: const Color.fromRGBO(187, 158, 0, 1),
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Call Swipe Overlay
            if (isCallSwipe)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.2),
                        Colors.green.withOpacity(0.8),
                      ],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(width: isTablet ? 15 : 10),
                        Icon(
                          Icons.phone_in_talk,
                          color: Colors.white,
                          size: isTablet ? 35 : 30,
                        ),
                        SizedBox(width: isTablet ? 15 : 10),
                        Text(
                          'Call',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Main Container
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 15 : 10,
                vertical: isTablet ? 20 : 15,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundLightGrey,
                borderRadius: BorderRadius.circular(7),
                border: Border(
                  left: BorderSide(
                    width: isTablet ? 10.0 : 8.0,
                    color: isFav
                        ? (isCallSwipe
                              ? Colors.green.withOpacity(0.9)
                              : Colors.yellow.withOpacity(
                                  isFavoriteSwipe ? 0.1 : 0.9,
                                ))
                        : (isFavoriteSwipe
                              ? Colors.yellow.withOpacity(0.1)
                              : (isCallSwipe
                                    ? Colors.green.withOpacity(0.1)
                                    : AppColors.sideGreen)),
                  ),
                ),
              ),
              child: Opacity(
                opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildNavigationButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      setState(() {
        isFav = widget.isFavorite;
      });
    }
  }

  void _mailAction() {
    print("Mail action triggered");

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: LeadUpdate(
            onFormSubmit: () {},
            leadId: widget.leadId,
            onEdit: widget.onFavoriteToggled,
          ),
        );
      },
    );
  }

  bool _isActionPaneOpen = false;
  Widget _buildNavigationButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return GestureDetector(
      onTap: () {
        if (_isActionPaneOpen) {
          // Close the action pane if it's open
          _slidableController.close();
          setState(() {
            _isActionPaneOpen = false;
          });
        } else {
          // Open the end action pane if it's closed
          _slidableController.openEndActionPane();
          setState(() {
            _isActionPaneOpen = true;
          });
        }
      },
      child: Container(
        padding: EdgeInsets.all(isTablet ? 4 : 3),
        decoration: BoxDecoration(
          color: AppColors.arrowContainerColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          _isActionPaneOpen
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_rounded,
          size: isTablet ? 28 : 25,
          color: Colors.white,
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
}
