// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:smartassist/utils/snackbar_helper.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/lead_update.dart';
// import 'package:smartassist/pages/Home/reassign_enq.dart';
// import 'package:smartassist/widgets/reusable/skeleton_globle_search_card.dart';

// class AllLeads extends StatefulWidget {
//   const AllLeads({super.key});

//   @override
//   State<AllLeads> createState() => _AllLeadsState();
// }

// class _AllLeadsState extends State<AllLeads> {
//   // ------------------------  CORE STATE  ------------------------
//   bool isLoading = true;
//   final Map<String, double> _swipeOffsets = {};
//   final ScrollController _scrollController = ScrollController();
//   Set<String> selectedLeads = {};
//   bool isSelectionMode = false;
//   List<dynamic> upcomingTasks = [];
//   List<dynamic> _filteredTasks = [];     // local, after filters/search
//   String _query = '';
//   final TextEditingController _searchController = TextEditingController();

//   // ------------------------  DROPDOWN FILTERS (copied)  ------------------------
//   String _selectedBrand = 'All';
//   String _selectedAssignee = 'All';
//   String _selectedTimeFrame = 'All';
//   List<String> _availableBrands = ['All'];
//   List<String> _availableAssignees = ['All'];
//   final List<String> _timeFrameOptions = [
//     'All',
//     'Today',
//     'This Week',
//     'This Month',
//   ];

//   // ------------------------  RESPONSIVE HELPERS  ------------------------
//   bool _isTablet(BuildContext context) => MediaQuery.of(context).size.width > 768;
//   bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 400;

//   // ------------------------  INIT / DISPOSE  ------------------------
//   @override
//   void initState() {
//     super.initState();
//     fetchTasksData();
//     _searchController.addListener(_onSearchChanged);
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   // ------------------------  DATA FETCH  ------------------------
//   Future<void> fetchTasksData() async {
//     final token = await Storage.getToken();
//     try {
//       final response = await http.get(
//         Uri.parse('https://api.smartassistapp.in/api/leads/fetch/all'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           upcomingTasks  = data['data']['rows'] ?? [];
//           _filteredTasks = List.from(upcomingTasks);
//           isLoading      = false;
//         });

//         // --- build filter dropdown values
//         _extractFilterOptions();
//         _applyAllFilters();
//       } else {
//         print("Failed to load data: ${response.statusCode}");
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print("Error fetching data: $e");
//       setState(() => isLoading = false);
//     }
//   }

//   // ------------------------  SEARCH  ------------------------
//   void _onSearchChanged() {
//     final newQuery = _searchController.text.trim();
//     if (newQuery == _query) return;

//     _query = newQuery;
//     _applyAllFilters();
//   }

//   // ------------------------  FILTER HELPERS (COPIED) ------------------------
//   void _extractFilterOptions() {
//     Set<String> brands    = {};
//     Set<String> assignees = {};

//     for (var task in upcomingTasks) {
//       // brand
//       final brand = task['brand']?.toString().trim();
//       if (brand != null && brand.isNotEmpty && brand.toLowerCase() != 'null') {
//         brands.add(brand);
//       }
//       // owner
//       final owner = task['lead_owner']?.toString().trim();
//       if (owner != null && owner.isNotEmpty && owner.toLowerCase() != 'null') {
//         assignees.add(owner);
//       }
//     }

//     setState(() {
//       _availableBrands     = ['All', ...brands.toList()..sort()];
//       _availableAssignees  = ['All', ...assignees.toList()..sort()];
//     });
//   }

//   bool _isDateInTimeFrame(String dateString, String timeFrame) {
//     if (timeFrame == 'All') return true;
//     try {
//       DateTime date = DateTime.parse(dateString);
//       DateTime now  = DateTime.now();
//       DateTime today = DateTime(now.year, now.month, now.day);

//       switch (timeFrame) {
//         case 'Today':
//           return DateTime(date.year, date.month, date.day).isAtSameMomentAs(today);
//         case 'This Week':
//           DateTime startWeek = today.subtract(Duration(days: today.weekday - 1));
//           DateTime endWeek   = startWeek.add(Duration(days: 6));
//           return date.isAfter(startWeek.subtract(Duration(days: 1))) &&
//                  date.isBefore(endWeek.add(Duration(days: 1)));
//         case 'This Month':
//           return date.year == now.year && date.month == now.month;
//         default:
//           return true;
//       }
//     } catch (e) {
//       return true;
//     }
//   }

//   void _applyAllFilters() {
//     List<dynamic> temp = List.from(upcomingTasks);

//     // --- search ---
//     if (_query.isNotEmpty) {
//       final q = _query.toLowerCase();
//       temp = temp.where((item) {
//         final name  = (item['lead_name'] ?? '').toString().toLowerCase();
//         final mail  = (item['email']     ?? '').toString().toLowerCase();
//         final phone = (item['mobile']    ?? '').toString().toLowerCase();
//         return name.contains(q) || mail.contains(q) || phone.contains(q);
//       }).toList();
//     }

//     // --- brand ---
//     if (_selectedBrand != 'All') {
//       temp = temp.where((e) => (e['brand'] ?? '').toString().trim() == _selectedBrand).toList();
//     }

//     // --- owner ---
//     if (_selectedAssignee != 'All') {
//       temp = temp.where((e) => (e['lead_owner'] ?? '').toString().trim() == _selectedAssignee).toList();
//     }

//     // --- time ---
//     if (_selectedTimeFrame != 'All') {
//       temp = temp.where((e) => _isDateInTimeFrame(e['created_at'] ?? '', _selectedTimeFrame)).toList();
//     }

//     setState(() => _filteredTasks = temp);
//   }

//   int _getActiveFilterCount() {
//     int c = 0;
//     if (_selectedBrand     != 'All') c++;
//     if (_selectedAssignee  != 'All') c++;
//     if (_selectedTimeFrame != 'All') c++;
//     if (_query.isNotEmpty)          c++;
//     return c;
//   }

//   void _resetFilters() {
//     setState(() {
//       _selectedBrand     = 'All';
//       _selectedAssignee  = 'All';
//       _selectedTimeFrame = 'All';
//       _searchController.clear();
//       _query = '';
//     });
//     _applyAllFilters();
//   }

//   // ------------------------  UI HELPERS (copied) ------------------------
//   EdgeInsets _responsivePadding(BuildContext ctx) => EdgeInsets.symmetric(
//     horizontal: _isTablet(ctx) ? 20 : (_isSmallScreen(ctx) ? 8 : 10),
//     vertical: _isTablet(ctx) ? 12 : 8,
//   );

//   double _titleFontSize(BuildContext ctx) =>
//       _isTablet(ctx) ? 20 : (_isSmallScreen(ctx) ? 16 : 18);

//   // build dropdown widget (same as original)
//   Widget _buildFilterDropdown(
//       String label,
//       String selectedValue,
//       List<String> options,
//       ValueChanged<String?> onChanged,
//       bool isTablet,
//     ) {
//     return Container(
//       height: isTablet ? 40 : 36,
//       decoration: BoxDecoration(
//         color: selectedValue != 'All'
//             ? AppColors.colorsBlue.withOpacity(0.08)
//             : Colors.white,
//         borderRadius: BorderRadius.circular(25),
//         border: Border.all(
//           color: selectedValue != 'All'
//               ? AppColors.colorsBlue.withOpacity(0.4)
//               : Colors.grey.withOpacity(0.2),
//           width: 1.5,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: selectedValue != 'All'
//                 ? AppColors.colorsBlue.withOpacity(0.1)
//                 : Colors.grey.withOpacity(0.05),
//             spreadRadius: 1,
//             blurRadius: 3,
//             offset: Offset(0, 1),
//           ),
//         ],
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: selectedValue,
//           isExpanded: true,
//           icon: Container(
//             margin: EdgeInsets.only(right: isTablet ? 8 : 6),
//             child: Icon(
//               Icons.keyboard_arrow_down_rounded,
//               size: isTablet ? 22 : 20,
//               color: selectedValue != 'All'
//                   ? AppColors.colorsBlue
//                   : Colors.grey[500],
//             ),
//           ),
//           style: GoogleFonts.poppins(
//             fontSize: isTablet ? 13 : 11,
//             color: selectedValue != 'All'
//                 ? AppColors.colorsBlue
//                 : Colors.grey[700],
//             fontWeight: selectedValue != 'All'
//                 ? FontWeight.w600
//                 : FontWeight.w400,
//           ),
//           dropdownColor: Colors.white,
//           borderRadius: BorderRadius.circular(15),
//           elevation: 8,
//           menuMaxHeight: 250,
//           items: options.map<DropdownMenuItem<String>>((String value) {
//             bool isSelected   = value == selectedValue;
//             bool isAllOption  = value == 'All';
//             return DropdownMenuItem<String>(
//               value: value,
//               child: Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.symmetric(
//                   horizontal: isTablet ? 12 : 10,
//                   vertical: isTablet ? 8  : 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: isSelected
//                       ? AppColors.colorsBlue.withOpacity(0.1)
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Row(
//                   children: [
//                     if (isSelected && !isAllOption)
//                       Container(
//                         margin: EdgeInsets.only(right: 8),
//                         child: Icon(
//                           Icons.check_circle,
//                           size: isTablet ? 16 : 14,
//                           color: AppColors.colorsBlue,
//                         ),
//                       ),
//                     Expanded(
//                       child: Text(
//                         isAllOption ? label : value,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//           selectedItemBuilder: (context) {
//             return options.map<Widget>((String value) {
//               return Container(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: isTablet ? 12 : 10,
//                 ),
//                 alignment: Alignment.centerLeft,
//                 child: Row(
//                   children: [
//                     if (selectedValue != 'All')
//                       Container(
//                         margin: EdgeInsets.only(right: 6),
//                         width: isTablet ? 6 : 5,
//                         height: isTablet ? 6 : 5,
//                         decoration: BoxDecoration(
//                           color: AppColors.colorsBlue,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                     Expanded(
//                       child: Text(
//                         value == 'All' ? label : value,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }).toList();
//           },
//           onChanged: onChanged,
//         ),
//       ),
//     );
//   }

//   // ------------------------  BUILD  ------------------------
//   @override
//   Widget build(BuildContext context) {
//     final isTablet = _isTablet(context);

//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: Icon(
//             FontAwesomeIcons.angleLeft,
//             color: Colors.white,
//             size: _isSmallScreen(context) ? 18 : 20,
//           ),
//         ),
//         title: Align(
//           alignment: Alignment.centerLeft,
//           child: Text(
//             'My Enquiries',
//             style: GoogleFonts.poppins(
//               fontSize: _titleFontSize(context),
//               fontWeight: FontWeight.w400,
//               color: Colors.white,
//             ),
//           ),
//         ),
//         backgroundColor: AppColors.colorsBlue,
//         automaticallyImplyLeading: false,
//       ),

//       body: isLoading
//           ? SkeletonGlobleSearchCard()
//           : Column(
//               children: [
//                 // --------------------  SEARCH  --------------------
//                 Container(
//                   margin: EdgeInsets.all(isTablet ? 15 : 10),
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(minHeight: 38, maxHeight: 38),
//                     child: TextField(
//                       controller: _searchController,
//                       textAlignVertical: TextAlignVertical.center,
//                       style: GoogleFonts.poppins(fontSize: isTablet ? 14 : 13),
//                       decoration: InputDecoration(
//                         filled: true,
//                         fillColor: AppColors.searchBar,
//                         hintText: 'Search by name, email or phone',
//                         hintStyle: GoogleFonts.poppins(
//                           fontSize: isTablet ? 12 : 11,
//                           fontWeight: FontWeight.w300,
//                         ),
//                         prefixIcon: Container(
//                           width: isTablet ? 50 : 45,
//                           alignment: Alignment.center,
//                           child: Icon(
//                             FontAwesomeIcons.magnifyingGlass,
//                             color: AppColors.fontColor,
//                             size: isTablet ? 18 : 16,
//                           ),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(30),
//                           borderSide: BorderSide.none,
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(30),
//                           borderSide: BorderSide.none,
//                         ),
//                         contentPadding: EdgeInsets.symmetric(
//                           horizontal: isTablet ? 16 : 14,
//                           vertical: isTablet ? 16 : 12,
//                         ),
//                         isDense: true,
//                       ),
//                     ),
//                   ),
//                 ),

//                 // --------------------  FILTER ROW  --------------------
//                 Container(
//                   margin: EdgeInsets.symmetric(
//                     horizontal: isTablet ? 15 : 10,
//                     vertical: isTablet ? 8 : 5,
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: _buildFilterDropdown(
//                           'Brand',
//                           _selectedBrand,
//                           _availableBrands,
//                           (v) { setState(() => _selectedBrand = v!); _applyAllFilters(); },
//                           isTablet,
//                         ),
//                       ),
//                       SizedBox(width: isTablet ? 10 : 8),
//                       Expanded(
//                         child: _buildFilterDropdown(
//                           'Owner',
//                           _selectedAssignee,
//                           _availableAssignees,
//                           (v) { setState(() => _selectedAssignee = v!); _applyAllFilters(); },
//                           isTablet,
//                         ),
//                       ),
//                       SizedBox(width: isTablet ? 10 : 8),
//                       Expanded(
//                         child: _buildFilterDropdown(
//                           'Time',
//                           _selectedTimeFrame,
//                           _timeFrameOptions,
//                           (v) { setState(() => _selectedTimeFrame = v!); _applyAllFilters(); },
//                           isTablet,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // --------------------  CLEAR-FILTERS INDICATOR  --------------------
//                 if (_getActiveFilterCount() > 0)
//                   Padding(
//                     padding: EdgeInsets.only(
//                       left: isTablet ? 15 : 10,
//                       right: isTablet ? 15 : 10,
//                       top: isTablet ? 6  : 4,
//                       bottom: isTablet ? 4 : 2,
//                     ),
//                     child: Row(
//                       children: [
//                         Text(
//                           '${_getActiveFilterCount()} filter(s) active',
//                           style: GoogleFonts.poppins(
//                             fontSize: isTablet ? 12 : 10,
//                             color: Colors.grey[700],
//                             fontStyle: FontStyle.italic,
//                           ),
//                         ),
//                         const Spacer(),
//                         TextButton(
//                           onPressed: _resetFilters,
//                           style: TextButton.styleFrom(
//                             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
//                             minimumSize: Size.zero,
//                             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           ),
//                           child: Text(
//                             'Clear All',
//                             style: GoogleFonts.poppins(
//                               fontSize: isTablet ? 13 : 11,
//                               color: AppColors.sideRed,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                 // --------------------  LIST  --------------------
//                 Expanded(
//                   child: Scrollbar(
//                     controller: _scrollController,
//                     thickness: 6,
//                     radius: const Radius.circular(4),
//                     child: _buildTasksList(_filteredTasks),
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }

//   // ------------------------  TASK LIST  ------------------------
//   Widget _buildTasksList(List<dynamic> tasks) {
//     if (tasks.isEmpty) {
//       final isTablet = _isTablet(context);
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               _getActiveFilterCount() > 0
//                   ? FontAwesomeIcons.filter
//                   : FontAwesomeIcons.magnifyingGlass,
//               size: isTablet ? 60 : 40,
//               color: Colors.grey[400],
//             ),
//             SizedBox(height: isTablet ? 18 : 14),
//             Text(
//               _getActiveFilterCount() > 0
//                   ? 'No results found with current filters'
//                   : (_query.isEmpty
//                         ? 'No Leads available'
//                         : 'No results found for "$_query"'),
//               style: GoogleFonts.poppins(
//                 fontSize: isTablet ? 18 : 16,
//                 color: Colors.grey[600],
//               ),
//               textAlign: TextAlign.center,
//             ),
//             if (_getActiveFilterCount() > 0) ...[
//               SizedBox(height: isTablet ? 10 : 8),
//               Text(
//                 'Try adjusting your filters or search terms',
//                 style: GoogleFonts.poppins(
//                   fontSize: isTablet ? 14 : 12,
//                   color: Colors.grey[500],
//                 ),
//               ),
//               TextButton(
//                 onPressed: _resetFilters,
//                 child: Text(
//                   'Clear All Filters',
//                   style: GoogleFonts.poppins(
//                     fontSize: isTablet ? 14 : 12,
//                     color: AppColors.sideRed,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//       );
//     }

//     // ...  (existing ListView.builder with TaskItem unchanged)
//     // keep your previous TaskItem implementation here
//     return ListView.builder(
//       controller: _scrollController,
//       physics: const AlwaysScrollableScrollPhysics(),
//       itemCount: tasks.length,
//       itemBuilder: (context, index) {
//         final item = tasks[index];
//         if (!(item.containsKey('lead_id') && item.containsKey('lead_name'))) {
//           return ListTile(title: Text('Invalid data at index $index'));
//         }

//         final leadId      = item['lead_id'] ?? '';
//         final swipeOffset = _swipeOffsets[leadId] ?? 0;

//         // TODO: keep the rest of your TaskItem implementation unchanged
//         return TaskItem(
//           name: item['lead_name'] ?? '',
//           date: item['created_at'] ?? '',
//           subject: item['email'] ?? '',
//           vehicle: item['PMI'] ?? '',
//           leadId: leadId,
//           taskId: leadId,
//           brand: item['brand'] ?? '',
//           number: item['mobile'] ?? '',
//           isFavorite: item['favourite'] ?? false,
//           swipeOffset: swipeOffset,
//           fetchDashboardData: () {},
//           onFavoriteToggled: () {},
//           onFavoriteChanged: (_) {},
//           onToggleFavorite: () {},
//           onTap: null,
//         );
//       },
//     );
//   }
// }

// /* -----------------------
//    TaskItem class remains
//    exactly the same as in
//    your previous file.
// ------------------------ */


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
  // ------------------------  CORE STATE  ------------------------
  bool isLoading = true;
  final Map<String, double> _swipeOffsets = {};
  final ScrollController _scrollController = ScrollController();
  Set<String> selectedLeads = {};
  bool isSelectionMode = false;
  List<dynamic> upcomingTasks = [];
  List<dynamic> _filteredTasks = [];     // local, after filters/search
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  // ------------------------  NEW DROPDOWN FILTERS  ------------------------
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

  String _selectedSortBy = 'Date Created';
  String _selectedStatus = 'All';
  String _selectedTimeFilter = 'All Time';

  // ------------------------  RESPONSIVE HELPERS  ------------------------
  bool _isTablet(BuildContext context) => MediaQuery.of(context).size.width > 768;
  bool _isSmallScreen(BuildContext context) => MediaQuery.of(context).size.width < 400;

  // ------------------------  SWIPE HANDLERS  ------------------------
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
      _toggleFavorite(leadId, index);
      bool currentStatus = item['favourite'] ?? false;
      bool newStatus = !currentStatus;

      setState(() {
        upcomingTasks[index]['favourite'] = newStatus;
        _applyAllFilters();
      });
    } else if (swipeOffset < -100) {
      _handleCall(item);
    }

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
          upcomingTasks[index]['favourite'] = newFavoriteStatus;
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

  // ------------------------  INIT / DISPOSE  ------------------------
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

  // ------------------------  DATA FETCH  ------------------------
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
        setState(() {
          upcomingTasks  = data['data']['rows'] ?? [];
          _filteredTasks = List.from(upcomingTasks);
          isLoading      = false;
        });

        _applyAllFilters();
      } else {
        print("Failed to load data: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  // ------------------------  SEARCH  ------------------------
  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;
    _applyAllFilters();
  }

  // ------------------------  FILTER HELPERS  ------------------------
  bool _isDateInTimeFrame(String dateString, String timeFrame) {
    if (timeFrame == 'All Time') return true;
    try {
      DateTime date = DateTime.parse(dateString);
      DateTime now = DateTime.now();

      switch (timeFrame) {
        case 'Today':
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case 'This Week':
          DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return date.isAfter(startOfWeek.subtract(Duration(days: 1)));
        case 'This Month':
          return date.year == now.year && date.month == now.month;
        case 'Last 7 Days':
          DateTime sevenDaysAgo = now.subtract(Duration(days: 7));
          return date.isAfter(sevenDaysAgo);
        case 'Last 30 Days':
          DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));
          return date.isAfter(thirtyDaysAgo);
        case 'Last 90 Days':
          DateTime ninetyDaysAgo = now.subtract(Duration(days: 90));
          return date.isAfter(ninetyDaysAgo);
        default:
          return true;
      }
    } catch (e) {
      return true;
    }
  }

  void _applyAllFilters() {
    List<dynamic> temp = List.from(upcomingTasks);

    // --- search ---
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      temp = temp.where((item) {
        final name  = (item['lead_name'] ?? '').toString().toLowerCase();
        final mail  = (item['email']     ?? '').toString().toLowerCase();
        final phone = (item['mobile']    ?? '').toString().toLowerCase();
        return name.contains(q) || mail.contains(q) || phone.contains(q);
      }).toList();
    }

    // --- status filter ---
    if (_selectedStatus != 'All') {
      temp = temp.where((item) {
        String status = (item['status'] ?? 'New').toString();
        return status.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // --- time filter ---
    if (_selectedTimeFilter != 'All Time') {
      temp = temp.where((item) {
        return _isDateInTimeFrame(item['created_at'] ?? '', _selectedTimeFilter);
      }).toList();
    }

    // --- sorting ---
    switch (_selectedSortBy) {
      case 'Name (A-Z)':
        temp.sort((a, b) {
          String nameA = (a['lead_name'] ?? '').toString().toLowerCase();
          String nameB = (b['lead_name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case 'Name (Z-A)':
        temp.sort((a, b) {
          String nameA = (a['lead_name'] ?? '').toString().toLowerCase();
          String nameB = (b['lead_name'] ?? '').toString().toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;
      case 'Recently Updated':
        temp.sort((a, b) {
          String dateA = a['updated_at'] ?? a['created_at'] ?? '';
          String dateB = b['updated_at'] ?? b['created_at'] ?? '';
          return dateB.compareTo(dateA);
        });
        break;
      case 'Oldest First':
        temp.sort((a, b) {
          String dateA = a['created_at'] ?? '';
          String dateB = b['created_at'] ?? '';
          return dateA.compareTo(dateB);
        });
        break;
      case 'Date Created':
      default:
        temp.sort((a, b) {
          String dateA = a['created_at'] ?? '';
          String dateB = b['created_at'] ?? '';
          return dateB.compareTo(dateA);
        });
        break;
    }

    setState(() => _filteredTasks = temp);
  }

  void _updateFilteredResults() {
    _applyAllFilters();
  }

  int _getActiveFilterCount() {
    int c = 0;
    if (_selectedSortBy != 'Date Created') c++;
    if (_selectedStatus != 'All') c++;
    if (_selectedTimeFilter != 'All Time') c++;
    if (_query.isNotEmpty) c++;
    return c;
  }

  void _resetFilters() {
    setState(() {
      _selectedSortBy = 'Date Created';
      _selectedStatus = 'All';
      _selectedTimeFilter = 'All Time';
      _searchController.clear();
      _query = '';
    });
    _applyAllFilters();
  }

  // ------------------------  UI HELPERS  ------------------------
  EdgeInsets _responsivePadding(BuildContext ctx) => EdgeInsets.symmetric(
    horizontal: _isTablet(ctx) ? 20 : (_isSmallScreen(ctx) ? 8 : 10),
    vertical: _isTablet(ctx) ? 12 : 8,
  );

  double _titleFontSize(BuildContext ctx) =>
      _isTablet(ctx) ? 20 : (_isSmallScreen(ctx) ? 16 : 18);

// build dropdown widget
Widget _buildFilterDropdown(
    String label,
    String selectedValue,
    List<String> options,
    ValueChanged<String?> onChanged,
    bool isTablet,
  ) {
  // Determine default values for each dropdown
  String defaultValue = label == 'Sort By'
      ? 'Date Created'
      : label == 'Status'
      ? 'All'
      : label == 'Time'
      ? 'All Time'
      : options.first;

  // FIXED: Only this specific dropdown should be highlighted if it's not at default
  bool isSelected = selectedValue != defaultValue;

  return Container(
    height: isTablet ? 40 : 36,
    decoration: BoxDecoration(
      color: isSelected
          ? AppColors.colorsBlue.withOpacity(0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(25),
      border: Border.all(
        color: isSelected
            ? AppColors.colorsBlue.withOpacity(0.4)
            : Colors.grey.withOpacity(0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isSelected
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
            color: isSelected
                ? AppColors.colorsBlue
                : Colors.grey[500],
          ),
        ),
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 13 : 11,
          color: isSelected
              ? AppColors.colorsBlue
              : Colors.grey[700],
          fontWeight: FontWeight.w400, // FIXED: Remove bold text
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(15),
        elevation: 8,
        menuMaxHeight: 250,
        items: options.map<DropdownMenuItem<String>>((String value) {
          bool isItemSelected = value == selectedValue;
          return DropdownMenuItem<String>(
            value: value,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 10,
                vertical: isTablet ? 8  : 6,
              ),
              decoration: BoxDecoration(
                color: isItemSelected
                    ? AppColors.colorsBlue.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (isItemSelected)
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
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 13 : 11,
                        fontWeight: FontWeight.w400, // FIXED: Remove bold text
                        color: isItemSelected 
                            ? AppColors.colorsBlue 
                            : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        selectedItemBuilder: (context) {
          return options.map<Widget>((String value) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 10,
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  if (isSelected)
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
                      value == defaultValue && !isSelected ? label : value,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 13 : 11,
                        fontWeight: FontWeight.w400, // FIXED: Remove bold text
                        color: isSelected
                            ? AppColors.colorsBlue
                            : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
        onChanged:  onChanged,
      ),
    ),
  );
}

  // ------------------------  BUILD  ------------------------
  @override
  Widget build(BuildContext context) {
    final isTablet = _isTablet(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
                // --------------------  SEARCH  --------------------
                Container(
                  margin: EdgeInsets.all(isTablet ? 15 : 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 38, maxHeight: 38),
                    child: TextField(
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      style: GoogleFonts.poppins(fontSize: isTablet ? 14 : 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.searchBar,
                        hintText: 'Search by name, email or phone',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: isTablet ? 12 : 11,
                          fontWeight: FontWeight.w300,
                        ),
                        prefixIcon: Container(
                          width: isTablet ? 50 : 45,
                          alignment: Alignment.center,
                          child: Icon(
                            FontAwesomeIcons.magnifyingGlass,
                            color: AppColors.fontColor,
                            size: isTablet ? 18 : 16,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 14,
                          vertical: isTablet ? 16 : 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),

                // --------------------  FILTER ROW  --------------------
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 15 : 10,
                    vertical: isTablet ? 8 : 5,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          'Sort By',
                          _selectedSortBy,
                          _sortOptions,
                          (v) {
                            setState(() => _selectedSortBy = v!);
                            _applyAllFilters();
                          },
                          isTablet,
                        ),
                      ),
                      SizedBox(width: isTablet ? 10 : 8),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Status',
                          _selectedStatus,
                          _statusOptions,
                          (v) {
                            setState(() => _selectedStatus = v!);
                            _applyAllFilters();
                          },
                          isTablet,
                        ),
                      ),
                      SizedBox(width: isTablet ? 10 : 8),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Time',
                          _selectedTimeFilter,
                          _timeFilterOptions,
                          (v) {
                            setState(() => _selectedTimeFilter = v!);
                            _applyAllFilters();
                          },
                          isTablet,
                        ),
                      ),
                    ],
                  ),
                ),

                // --------------------  CLEAR-FILTERS INDICATOR  --------------------
                if (_getActiveFilterCount() > 0)
                  Padding(
                    padding: EdgeInsets.only(
                      left: isTablet ? 15 : 10,
                      right: isTablet ? 15 : 10,
                      top: isTablet ? 6  : 4,
                      bottom: isTablet ? 4 : 2,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_getActiveFilterCount()} filter(s) active',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 12 : 10,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _resetFilters,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13 : 11,
                              color: AppColors.sideRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --------------------  LIST  --------------------
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thickness: 6,
                    radius: const Radius.circular(4),
                    child: _buildTasksList(_filteredTasks),
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------  TASK LIST  ------------------------
  Widget _buildTasksList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      final isTablet = _isTablet(context);
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
            SizedBox(height: isTablet ? 18 : 14),
            Text(
              _getActiveFilterCount() > 0
                  ? 'No results found with current filters'
                  : (_query.isEmpty
                        ? 'No Leads available'
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
              ),
              TextButton(
                onPressed: _resetFilters,
                child: Text(
                  'Clear All Filters',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 14 : 12,
                    color: AppColors.sideRed,
                    fontWeight: FontWeight.w500,
                  ),
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
        final item = tasks[index];
        if (!(item.containsKey('lead_id') && item.containsKey('lead_name'))) {
          return ListTile(title: Text('Invalid data at index $index'));
        }

        final leadId      = item['lead_id'] ?? '';
        final swipeOffset = _swipeOffsets[leadId] ?? 0;

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
    _slidableController.animation.addListener(() {
      final isOpen = _slidableController.ratio != 0;
      if (_isActionPaneOpen != isOpen) {
        setState(() {
          _isActionPaneOpen = isOpen;
        });
      }
    });
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
                              ? AppColors.colorsBlue.withOpacity(0.9)
                              : Colors.yellow.withOpacity(
                                  isFavoriteSwipe ? 0.1 : 0.9,
                                ))
                        : (isFavoriteSwipe
                              ? Colors.yellow.withOpacity(0.1)
                              : (isCallSwipe
                                    ? Colors.green.withOpacity(0.1)
                                    : AppColors.colorsBlue)),
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
