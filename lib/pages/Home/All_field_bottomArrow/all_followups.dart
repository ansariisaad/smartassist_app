import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/followups/all_followups.dart';
// import 'package:smartassist/widgets/followups/all_followup.dart'; // Import the new widget
import 'package:smartassist/widgets/followups/overdue_followup.dart';
import 'package:smartassist/widgets/followups/upcoming_row.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_Followups_popups.dart';
import 'package:smartassist/widgets/buttons/add_btn.dart';

class AddFollowups extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  const AddFollowups({super.key, required this.refreshDashboard});

  @override
  State<AddFollowups> createState() => _AddFollowupsState();
}

class _AddFollowupsState extends State<AddFollowups> {
  final Widget _createFollowups = CreateFollowupsPopups(onFormSubmit: () {});
  List<dynamic> _originalAllTasks = [];
  List<dynamic> _originalUpcomingTasks = [];
  List<dynamic> _originalOverdueTasks = [];
  List<dynamic> _filteredAllTasks = [];
  List<dynamic> _filteredUpcomingTasks = [];
  List<dynamic> _filteredOverdueTasks = [];
  int _upcommingButtonIndex = 0;
  int count = 0;

  TextEditingController searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  double _getScreenWidth() => MediaQuery.sizeOf(context).width;

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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterTasks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAllTasks = List.from(_originalAllTasks);
        _filteredUpcomingTasks = List.from(_originalUpcomingTasks);
        _filteredOverdueTasks = List.from(_originalOverdueTasks);
      } else {
        final lowercaseQuery = query.toLowerCase();
        void filterList(List<dynamic> original, List<dynamic> filtered) {
          filtered.clear();
          filtered.addAll(
            original.where(
              (task) =>
                  task['name'].toString().toLowerCase().contains(
                    lowercaseQuery,
                  ) ||
                  task['subject'].toString().toLowerCase().contains(
                    lowercaseQuery,
                  ),
            ),
          );
        }

        filterList(_originalAllTasks, _filteredAllTasks);
        filterList(_originalUpcomingTasks, _filteredUpcomingTasks);
        filterList(_originalOverdueTasks, _filteredOverdueTasks);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
            widget.refreshDashboard();
          },
          // onPressed: () => Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(builder: (context) => BottomNavigation()),
          // ),
          icon: const Icon(Icons.arrow_back_ios_outlined, color: Colors.white),
        ),

        backgroundColor: const Color(0xFF1380FE),
        title: Align(
          alignment: Alignment.centerLeft,
          child: const Text(
            'Your Follow ups',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
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
                child: _createFollowups, // Your follow-up widget
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
                    margin: const EdgeInsets.all(10),
                    child: TextField(
                      controller: searchController,
                      onChanged: _filterTasks,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          // 👈 Add this
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFE1EFFF),
                        contentPadding: const EdgeInsets.fromLTRB(1, 4, 0, 4),
                        border: InputBorder.none,
                        hintText: 'Search',
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        // suffixIcon: const Icon(Icons.mic, color: Colors.grey),
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
    switch (_upcommingButtonIndex) {
      case 0: // All Followups
        return _filteredAllTasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No followups available"),
                ),
              )
            : AllFollowup(allFollowups: _filteredAllTasks, isNested: true);
      case 1: // Upcoming
        return _filteredUpcomingTasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No upcoming followups available"),
                ),
              )
            : FollowupsUpcoming(
                refreshDashboard: widget.refreshDashboard,
                upcomingFollowups: _filteredUpcomingTasks,
                isNested: true,
              );
      case 2: // Overdue
        return _filteredOverdueTasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No overdue followups available"),
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
    final bool isActive = _upcommingButtonIndex == index;

    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => _upcommingButtonIndex = index),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? activeColor.withOpacity(0.29) : null,
          foregroundColor: isActive ? Colors.white : Colors.black,
          // padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
          padding: EdgeInsets.symmetric(
            vertical: 5.0 * _getResponsiveScale(),
            horizontal: 8.0 * _getResponsiveScale(),
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
