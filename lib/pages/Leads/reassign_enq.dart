import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Leads/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/services/reassign_enq_srv.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/lead_update.dart';

class AllLeads extends StatefulWidget {
  const AllLeads({super.key});

  @override
  State<AllLeads> createState() => _AllLeadsState();
}

class _AllLeadsState extends State<AllLeads> {
  bool isLoading = true;
  List<dynamic> upcomingTasks = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _filteredTasks = [];
  bool _isLoadingSearch = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  Set<String> selectedLeads = {};
  bool isSelectionMode = false;
  final ScrollController _scrollController = ScrollController();

  // Filter variables
  String selectedBrandFilter = 'All';
  String selectedAssigneeFilter = 'All';
  String selectedDateFilter = 'All';
  bool showFilters = false;

  // Filter options (will be populated from data)
  List<String> brandOptions = ['All'];
  List<String> assigneeOptions = ['All'];
  List<String> dateOptions = [
    'All',
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    fetchTasksData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
          _filteredTasks = List.from(upcomingTasks);
          isLoading = false;
          _populateFilterOptions();
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

  void _populateFilterOptions() {
    // Extract unique brands
    Set<String> brands = {'All'};
    Set<String> assignees = {'All'};

    for (var task in upcomingTasks) {
      if (task['brand'] != null && task['brand'].toString().isNotEmpty) {
        brands.add(task['brand'].toString());
      }
      if (task['lead_owner'] != null &&
          task['lead_owner'].toString().isNotEmpty) {
        assignees.add(task['lead_owner'].toString());
      }
    }

    setState(() {
      brandOptions = brands.toList()..sort();
      assigneeOptions = assignees.toList()..sort();
    });
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(upcomingTasks);

    // Apply brand filter
    if (selectedBrandFilter != 'All') {
      filtered = filtered
          .where((task) => task['brand']?.toString() == selectedBrandFilter)
          .toList();
    }

    // Apply assignee filter
    if (selectedAssigneeFilter != 'All') {
      filtered = filtered
          .where(
            (task) => task['lead_owner']?.toString() == selectedAssigneeFilter,
          )
          .toList();
    }

    // Apply date filter
    if (selectedDateFilter != 'All') {
      DateTime now = DateTime.now();
      filtered = filtered.where((task) {
        if (task['created_at'] == null) return false;

        DateTime taskDate = DateTime.parse(task['created_at']);

        switch (selectedDateFilter) {
          case 'Today':
            return DateUtils.isSameDay(taskDate, now);
          case 'Yesterday':
            DateTime yesterday = now.subtract(const Duration(days: 1));
            return DateUtils.isSameDay(taskDate, yesterday);
          case 'This Week':
            DateTime weekAgo = now.subtract(const Duration(days: 7));
            return taskDate.isAfter(weekAgo);
          case 'This Month':
            return taskDate.month == now.month && taskDate.year == now.year;
          default:
            return true;
        }
      }).toList();
    }

    setState(() {
      _filteredTasks = filtered;
    });
  }

  void _resetFilters() {
    setState(() {
      selectedBrandFilter = 'All';
      selectedAssigneeFilter = 'All';
      selectedDateFilter = 'All';
      _filteredTasks = List.from(upcomingTasks);
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (selectedBrandFilter != 'All') count++;
    if (selectedAssigneeFilter != 'All') count++;
    if (selectedDateFilter != 'All') count++;
    return count;
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

    try {
      final token = await Storage.getToken();
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/search/global?query=$query',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = data['data']['suggestions'] ?? [];
        });
      } else {
        showErrorMessage(context, message: data['message']);
      }
    } catch (e) {
      showErrorMessage(context, message: 'Something went wrong..!');
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

  @override
  Widget build(BuildContext context) {
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
                          final selectedUser = await showDialog<Map<String, String>>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Select User'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: LeadsSrv.fetchUsers(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Text(
                                        'Error loading users: ${snapshot.error}',
                                      );
                                    }

                                    final users = snapshot.data ?? [];

                                    if (users.isEmpty) {
                                      return const Text('No users available');
                                    }

                                    return ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: users.length,
                                      itemBuilder: (context, index) {
                                        final user = users[index];

                                        return ListTile(
                                          title: Text(
                                            user['name'] ?? 'Unknown User',
                                          ),
                                          subtitle: Text(user['email'] ?? ''),
                                          onTap: () {
                                            // Extract user ID and name - we know it's stored as 'user_id' from debugging
                                            final userId = user['user_id']
                                                ?.toString();
                                            final userName =
                                                user['name']?.toString() ??
                                                'Unknown User';

                                            if (userId != null &&
                                                userId.isNotEmpty &&
                                                userId != 'null') {
                                              // Return both user ID and name
                                              Navigator.of(context).pop({
                                                'id': userId,
                                                'name': userName,
                                              });
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Unable to get user ID',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                              ],
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
                // Search field container
                Container(
                  margin: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * .04,
                    child: TextField(
                      autofocus: false,
                      controller: _searchController,
                      onChanged: (value) => _onSearchChanged(),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundLightGrey,
                        hintText: 'Search by name, email or phone',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(right: 0),
                          child: Icon(
                            FontAwesomeIcons.magnifyingGlass,
                            color: AppColors.fontColor,
                            size: 15,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // Filter Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      // Filter toggle button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showFilters = !showFilters;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: showFilters
                                    ? const Color(0xFF1380FE)
                                    : AppColors.backgroundLightGrey,
                                borderRadius: BorderRadius.circular(20),
                                // border: Border.all(
                                //   color: const Color(
                                //     0xFF1380FE,
                                //   ).withOpacity(0.3),
                                // ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    FontAwesomeIcons.filter,
                                    size: 14,
                                    color: showFilters
                                        ? Colors.white
                                        : const Color(0xFF1380FE),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Filters',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: showFilters
                                          ? Colors.white
                                          : const Color(0xFF1380FE),
                                    ),
                                  ),
                                  if (_getActiveFilterCount() > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: showFilters
                                            ? Colors.white
                                            : const Color(0xFF1380FE),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${_getActiveFilterCount()}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: showFilters
                                              ? const Color(0xFF1380FE)
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (_getActiveFilterCount() > 0)
                            GestureDetector(
                              onTap: _resetFilters,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      FontAwesomeIcons.xmark,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          final slideAnimation = Tween<Offset>(
                            begin: const Offset(0, -0.1),
                            end: Offset.zero,
                          ).animate(animation);

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slideAnimation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1.0,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: showFilters
                            ? Container(
                                key: const ValueKey('filters_shown'),
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundLightGrey
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFilterRow(
                                      'Brand',
                                      selectedBrandFilter,
                                      brandOptions,
                                      (value) {
                                        setState(() {
                                          selectedBrandFilter = value;
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildFilterRow(
                                      'Assignee',
                                      selectedAssigneeFilter,
                                      assigneeOptions,
                                      (value) {
                                        setState(() {
                                          selectedAssigneeFilter = value;
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _buildFilterRow(
                                      'Date',
                                      selectedDateFilter,
                                      dateOptions,
                                      (value) {
                                        setState(() {
                                          selectedDateFilter = value;
                                        });
                                        _applyFilters();
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('filters_hidden'),
                              ),
                      ),
                    ],
                  ),
                ),

                if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        textAlign: TextAlign.left,
                        'Showing results for: $_query',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                // Results count
                if (_query.isEmpty && _getActiveFilterCount() > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Showing ${_filteredTasks.length} of ${upcomingTasks.length} leads',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                // Expanded widget containing the appropriate list with Scrollbar
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: false,
                    trackVisibility: false,
                    thickness: 8.0,
                    radius: const Radius.circular(4.0),
                    interactive: true,
                    child: _query.isNotEmpty
                        ? _buildTasksList(_searchResults)
                        : _buildTasksList(_filteredTasks),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterRow(
    String label,
    String selectedValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            bool isSelected = option == selectedValue;
            return GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1380FE) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1380FE)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  option,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTasksList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No Data available'));
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
        bool isSelected = selectedLeads.contains(leadId);

        return TaskItem(
          name: item['lead_name'] ?? 'NA',
          date: item['created_at'] ?? 'NA',
          subject: item['email'] ?? 'NA',
          vehicle: item['PMI'] ?? 'NA',
          leadId: leadId,
          brand: item['brand'] ?? 'NA',
          number: item['mobile'] ?? 'NA',
          assignee: item['lead_owner'] ?? 'NA',
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          fetchDashboardData: () {},
          onLongPress: () => _toggleSelection(leadId),
          onTap: selectedLeads.isNotEmpty
              ? () => _toggleSelection(leadId)
              : null,
        );
      },
    );
  }
}

class TaskItem extends StatefulWidget {
  final String name, subject, number;
  final String date;
  final String vehicle;
  final String leadId;
  final String brand;
  final String assignee;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback fetchDashboardData;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  const TaskItem({
    super.key,
    required this.name,
    required this.date,
    required this.vehicle,
    required this.leadId,
    required this.isSelected,
    required this.isSelectionMode,
    required this.brand,
    required this.assignee,
    required this.subject,
    required this.fetchDashboardData,
    required this.onLongPress,
    required this.number,
    this.onTap,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  late bool isFav;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
      child: _buildFollowupCard(context),
    );
  }

  Widget _buildFollowupCard(BuildContext context) {
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
                  ),
                ),
              );
            } else {
              print("Invalid leadId");
            }
          },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          // borderRadius: BorderRadius.circular(10),
          color: widget.isSelected
              ? AppColors.backgroundLightGrey.withOpacity(0.8)
              : AppColors.white,
          border: Border(
            bottom: BorderSide(
              width: 1,
              color: widget.isSelected
                  ? AppColors.sideGreen.withOpacity(0.8)
                  : AppColors.backgroundLightGrey.withOpacity(0.8),
            ),
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: const Color.fromARGB(0, 255, 255, 255),
                    blurRadius: 8,
                    offset: const Offset(1, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: widget.isSelected ? 36 : 0,
              margin: EdgeInsets.only(right: widget.isSelected ? 12 : 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.isSelected ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  scale: widget.isSelected ? 1.0 : 0.8,
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 30,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(child: _buildUserDetails(context)),
                            _buildVerticalDivider(15),
                            Flexible(child: _buildSubjectDetails(context)),
                          ],
                        ),
                        const SizedBox(height: 4),
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
    );
  }

  Widget _buildNavigationButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.leadId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowupsDetails(
                leadId: widget.leadId,
                isFromFreshlead: false,
              ),
            ),
          );
        } else {
          print("Invalid leadId");
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = MediaQuery.of(context).size.width;
          double padding = screenWidth < 360 ? 4 : (screenWidth < 600 ? 6 : 8);
          double borderRadius = screenWidth < 360
              ? 20
              : (screenWidth < 600 ? 30 : 35);
          double iconSize = screenWidth < 360
              ? 16
              : (screenWidth < 600 ? 20 : 24);

          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: const Color(0xFF1380FE),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: iconSize,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserDetails(BuildContext context) {
    return Text(
      widget.name,
      textAlign: TextAlign.start,
      style: AppFont.dashboardName(context),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubjectDetails(BuildContext context) {
    String mobile = widget.number;
    String hiddenMobile = _hideMobileNumber(mobile);
    return Text(
      hiddenMobile,
      style: AppFont.smallText(context),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _hideMobileNumber(String mobile) {
    if (mobile.length >= 10) {
      return '${mobile.substring(0, 3)}*****${mobile.substring(8)}';
    } else {
      return mobile;
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

  Widget _buildCarModel(BuildContext context) {
    return Text(
      widget.vehicle,
      textAlign: TextAlign.start,
      style: AppFont.dashboardCarName(context),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAssignee(BuildContext context) {
    return Text(
      widget.assignee,
      textAlign: TextAlign.start,
      style: AppFont.dashboardCarName(context),
      overflow: TextOverflow.ellipsis,
    );
  }
}
