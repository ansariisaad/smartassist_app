import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/buttons/add_btn.dart';
import 'package:smartassist/widgets/followups/all_followups.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_testDrive.dart';
import 'package:smartassist/widgets/oppointment/overdue.dart';
import 'package:smartassist/widgets/oppointment/upcoming.dart';
import 'package:smartassist/widgets/testdrive/all_testDrive.dart';
import 'package:smartassist/widgets/testdrive/overdue.dart';
import 'package:smartassist/widgets/testdrive/upcoming.dart';

class AllTestdrive extends StatefulWidget {
  const AllTestdrive({super.key});

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
  int _upcommingButtonIndex = 0;
  TextEditingController searchController = TextEditingController();
  bool _isLoading = true;
  int count = 0;

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BottomNavigation()),
          ),
          icon: const Icon(Icons.arrow_back_ios_outlined, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1380FE),
        title: const Text(
          'Your Test Drives',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
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
                child: _createTestDrive, // Your follow-up widget
              );
            },
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          // Top section with search bar and filter buttons.
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
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
                      fillColor: AppColors.containerBg,
                      contentPadding: const EdgeInsets.fromLTRB(1, 1, 0, 1),
                      border: InputBorder.none,
                      hintText: 'Search by name, email or phone',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: const Icon(Icons.mic, color: Colors.grey),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 20),
                    Container(
                      width: 250,
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
    );
  }

  Widget _buildContentBySelectedTab() {
    switch (_upcommingButtonIndex) {
      case 0: // All Followups
        return _filteredAllTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "No Testdrive available",
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
                    "No upcoming Testdrive available",
                    style: AppFont.smallText12(context),
                  ),
                ),
              )
            : TestUpcoming(
                upcomingTestDrive: _filteredUpcomingTasks,
                isNested: true,
              );
      case 2: // Overdue
        return _filteredOverdueTasks.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "No overdue Testdrive available",
                    style: AppFont.smallText12(context),
                  ),
                ),
              )
            : TestOverdue(
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

  // Widget _buildFilterButton({
  //   required int index,
  //   required String text,
  //   required Color activeColor,
  //   required Color color,
  // }) {
  //   final bool isActive = _upcommingButtonIndex == index;

  //   return Expanded(
  //     child: TextButton(
  //       onPressed: () => setState(() => _upcommingButtonIndex = index),
  //       style: TextButton.styleFrom(
  //         backgroundColor: isActive ? activeColor.withOpacity(0.29) : null,
  //         foregroundColor: isActive ? Colors.blueGrey : Colors.black,
  //         padding: const EdgeInsets.symmetric(vertical: 5),
  //         side: BorderSide(
  //           color: isActive ? activeColor : Colors.transparent,
  //           width: .5,
  //         ),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(30),
  //         ),
  //       ),
  //       child: Text(
  //         text,
  //         style: TextStyle(
  //           fontSize: 14,
  //           fontWeight: FontWeight.w400,
  //           color: isActive ? color : Colors.grey,
  //         ),
  //       ),
  //     ),
  //   );
  // }
}


  // SliverToBoxAdapter(
  //           child: _isLoading
  //               ? const Center(
  //                   child:
  //                       CircularProgressIndicator(color: AppColors.colorsBlue))
  //               : _upcommingButtonIndex == 0
  //                   ? (_filteredUpcomingTasks.isEmpty &&
  //                           _filteredOverdueTasks.isEmpty)
  //                       ? const Center(
  //                           child: Padding(
  //                             padding: EdgeInsets.symmetric(vertical: 20),
  //                             child: Text("No appointments available"),
  //                           ),
  //                         )
  //                       : Column(
  //                           children: [
  //                             if (_filteredUpcomingTasks.isNotEmpty)
  //                               TestUpcoming(
  //                                 upcomingTestDrive: _filteredUpcomingTasks,
  //                                 isNested: true,
  //                               ),
  //                             if (_filteredOverdueTasks.isNotEmpty)
  //                               TestOverdue(
  //                                 overdueTestDrive: _filteredOverdueTasks,
  //                                 isNested: true,
  //                               ),
  //                           ],
  //                         )
  //                   : _upcommingButtonIndex == 1
  //                       ? TestUpcoming(
  //                           upcomingTestDrive: _filteredUpcomingTasks,
  //                           isNested: true,
  //                         )
  //                       : TestOverdue(
  //                           overdueTestDrive: _filteredOverdueTasks,
  //                           isNested: true,
  //                         ),
  //         ),
        
