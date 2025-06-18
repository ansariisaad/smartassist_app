// import 'package:flutter/material.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
// import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/followups.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:smartassist/widgets/buttons/add_btn.dart';

// class AllAppointmentItem extends StatefulWidget {
//   final String name, mobile, taskId;
//   final String subject;
//   final String date;
//   final String vehicle;
//   final String leadId;
//   final double swipeOffset;
//   final bool isFavorite;
//   final VoidCallback onToggleFavorite;

//   const AllAppointmentItem({
//     super.key,
//     required this.name,
//     required this.subject,
//     required this.date,
//     required this.vehicle,
//     required this.leadId,
//     this.swipeOffset = 0.0,
//     this.isFavorite = false,
//     required this.onToggleFavorite,
//     required this.mobile,
//     required this.taskId,
//   });

//   @override
//   State<AllAppointmentItem> createState() => _AllAppointmentItemsItemState();
// }

// class _AllAppointmentItemsItemState extends State<AllAppointmentItem>
//     with WidgetsBindingObserver, SingleTickerProviderStateMixin {
//   bool _wasCallingPhone = false;
//   late SlidableController _slidableController;

//   @override
//   void initState() {
//     super.initState();
//     // Register this class as an observer to track app lifecycle changes
//     WidgetsBinding.instance.addObserver(this);
//     _slidableController = SlidableController(this);
//   }

//   @override
//   void dispose() {
//     // Remove observer when widget is disposed
//     WidgetsBinding.instance.removeObserver(this);
//     _slidableController.dispose();
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     // This gets called when app lifecycle state changes
//     if (state == AppLifecycleState.resumed && _wasCallingPhone) {
//       // App is resumed and we marked that user was making a call
//       _wasCallingPhone = false;
//       // Show the mail action dialog after a short delay to ensure app is fully resumed
//       Future.delayed(const Duration(milliseconds: 300), () {
//         if (mounted) {
//           _mailAction();
//         }
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
//       child: InkWell(
//         onTap: () {
//           if (widget.leadId.isNotEmpty) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => FollowupsDetails(
//                   leadId: widget.leadId,
//                   isFromFreshlead: false,
//                   isFromManager: false,
//                   isFromTestdriveOverview: false,
//                   // refreshDashboard: widget.refreshDashboard,
//                   refreshDashboard: () async {},
//                   // isFromTestdriveOverview: false,
//                 ),
//               ),
//             );
//           } else {
//             print("Invalid leadId");
//           }
//         },
//         child: _buildOverdueCard(context),
//       ),
//     );
//   }

//   Widget _buildOverdueCard(BuildContext context) {
//     bool isFavoriteSwipe = widget.swipeOffset > 50;
//     bool isCallSwipe = widget.swipeOffset < -50;

//     return Slidable(
//       key: ValueKey(widget.leadId), // Always good to set keys
//       controller: _slidableController,
//       startActionPane: ActionPane(
//         extentRatio: 0.2,
//         motion: const ScrollMotion(),
//         children: [
//           ReusableSlidableAction(
//             onPressed: widget.onToggleFavorite, // handle fav toggle
//             backgroundColor: Colors.amber,
//             icon: widget.isFavorite
//                 ? Icons.star_rounded
//                 : Icons.star_border_rounded,
//             foregroundColor: Colors.white,
//           ),
//         ],
//       ),

//       endActionPane: ActionPane(
//         extentRatio: 0.4,
//         motion: const StretchMotion(),
//         children: [
//           if (widget.subject == 'Call')
//             ReusableSlidableAction(
//               onPressed: _phoneAction,
//               backgroundColor: Colors.blue,
//               icon: Icons.phone,
//               foregroundColor: Colors.white,
//             ),
//           if (widget.subject == 'Send SMS')
//             ReusableSlidableAction(
//               onPressed: _messageAction,
//               backgroundColor: Colors.blueGrey,
//               icon: Icons.message_rounded,
//               foregroundColor: Colors.white,
//             ),
//           // Edit is always shown
//           ReusableSlidableAction(
//             onPressed: _mailAction,
//             backgroundColor: const Color.fromARGB(255, 231, 225, 225),
//             icon: Icons.edit,
//             foregroundColor: Colors.white,
//           ),
//         ],
//       ),
//       child: Stack(
//         children: [
//           // Favorite Swipe Overlay
//           if (isFavoriteSwipe) Positioned.fill(child: _buildFavoriteOverlay()),

//           // Call Swipe Overlay
//           if (isCallSwipe) Positioned.fill(child: _buildCallOverlay()),

//           // Main Card
//           Opacity(
//             opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//               decoration: BoxDecoration(
//                 color: AppColors.containerBg,
//                 borderRadius: BorderRadius.circular(5),
//                 border: Border(
//                   left: BorderSide(
//                     width: 8.0,
//                     color: widget.isFavorite
//                         ? Colors.yellow
//                         : Colors.blueAccent,
//                   ),
//                 ),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       const SizedBox(width: 8),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               _buildUserDetails(context),
//                               _buildVerticalDivider(15),
//                               _buildCarModel(context),
//                             ],
//                           ),
//                           const SizedBox(height: 4),
//                           Row(
//                             children: [
//                               _buildSubjectDetails(context),
//                               _date(context),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   _buildNavigationButton(context),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFavoriteOverlay() {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Colors.yellow.withOpacity(0.2),
//             Colors.yellow.withOpacity(0.8),
//           ],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       child: Row(
//         children: [
//           const SizedBox(width: 15),
//           Icon(
//             widget.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
//             color: const Color.fromRGBO(226, 195, 34, 1),
//             size: 40,
//           ),
//           const SizedBox(width: 10),
//           Text(
//             widget.isFavorite ? 'Unfavorite' : 'Favorite',
//             style: GoogleFonts.poppins(
//               color: const Color.fromRGBO(187, 158, 0, 1),
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCallOverlay() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.green, Colors.green],
//           begin: Alignment.centerRight,
//           end: Alignment.centerLeft,
//         ),
//         borderRadius: BorderRadius.all(Radius.circular(10)),
//       ),
//       child: Row(
//         children: [
//           const SizedBox(width: 10),
//           const Icon(Icons.phone_in_talk, color: Colors.white, size: 30),
//           const SizedBox(width: 10),
//           Text(
//             'Call',
//             style: GoogleFonts.poppins(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUserDetails(BuildContext context) {
//     return ConstrainedBox(
//       constraints: BoxConstraints(
//         maxWidth: MediaQuery.of(context).size.width * .35,
//       ),
//       child: Text(
//         maxLines: 1, // Allow up to 2 lines
//         overflow: TextOverflow
//             .ellipsis, // Show ellipsis if it overflows beyond 2 lines
//         softWrap: true,
//         widget.name,
//         style: AppFont.dashboardName(context),
//       ),
//     );
//   }

//   Widget _buildCarModel(BuildContext context) {
//     return ConstrainedBox(
//       constraints: const BoxConstraints(maxWidth: 100),
//       child: Text(
//         widget.vehicle,
//         style: AppFont.dashboardCarName(context),
//         maxLines: 1, // Allow up to 2 lines
//         overflow: TextOverflow
//             .ellipsis, // Show ellipsis if it overflows beyond 2 lines
//         softWrap: true, // Allow wrapping
//       ),
//     );
//   }

//   Widget _buildSubjectDetails(BuildContext context) {
//     IconData icon;
//     if (widget.subject == 'Call') {
//       icon = Icons.phone_in_talk;
//     } else if (widget.subject == 'Send SMS') {
//       icon = Icons.mail_rounded;
//     } else if (widget.subject == 'Provide quotation') {
//       icon = Icons.mail_rounded;
//     } else if (widget.subject == 'Send Email') {
//       icon = Icons.mail_rounded;
//     } else {
//       icon = Icons.phone; // fallback icon
//     }

//     return Row(
//       children: [
//         Icon(icon, color: Colors.blue, size: 18),
//         const SizedBox(width: 5),
//         Text('${widget.subject},', style: AppFont.smallText(context)),
//       ],
//     );
//   }

//   // Widget _buildSubjectDetails(BuildContext context) {
//   //   return Row(
//   //     children: [
//   //       const Icon(Icons.phone_in_talk, color: Colors.blue, size: 18),
//   //       const SizedBox(width: 5),
//   //       Text('${widget.subject},', style: AppFont.smallText(context)),
//   //     ],
//   //   );
//   // }

//   Widget _date(BuildContext context) {
//     String formattedDate = '';
//     try {
//       DateTime parseDate = DateTime.parse(widget.date);
//       if (parseDate.year == DateTime.now().year &&
//           parseDate.month == DateTime.now().month &&
//           parseDate.day == DateTime.now().day) {
//         formattedDate = 'Today';
//       } else {
//         int day = parseDate.day;
//         String suffix = _getDaySuffix(day);
//         String month = DateFormat('MMM').format(parseDate);
//         formattedDate = '$day$suffix $month';
//       }
//     } catch (e) {
//       formattedDate = widget.date;
//     }
//     return Row(
//       children: [
//         const SizedBox(width: 5),
//         Text(formattedDate, style: AppFont.smallText(context)),
//       ],
//     );
//   }

//   String _getDaySuffix(int day) {
//     if (day >= 11 && day <= 13) return 'th';
//     switch (day % 10) {
//       case 1:
//         return 'st';
//       case 2:
//         return 'nd';
//       case 3:
//         return 'rd';
//       default:
//         return 'th';
//     }
//   }

//   Widget _buildVerticalDivider(double height) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10),
//       height: height,
//       width: 0.1,
//       decoration: const BoxDecoration(
//         border: Border(right: BorderSide(color: AppColors.fontColor)),
//       ),
//     );
//   }

//   bool _isActionPaneOpen = false;

//   Widget _buildNavigationButton(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         if (_isActionPaneOpen) {
//           _slidableController.close();
//           setState(() {
//             _isActionPaneOpen = false;
//           });
//         } else {
//           _slidableController.close();
//           Future.delayed(Duration(milliseconds: 100), () {
//             _slidableController.openEndActionPane();
//             setState(() {
//               _isActionPaneOpen = true;
//             });
//           });
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.all(3),
//         decoration: BoxDecoration(
//           color: AppColors.arrowContainerColor,
//           borderRadius: BorderRadius.circular(30),
//         ),
//         child: Icon(
//           _isActionPaneOpen
//               ? Icons.arrow_forward_ios_rounded
//               : Icons.arrow_back_ios_rounded,
//           size: 25,
//           color: Colors.white,
//         ),
//       ),
//     );
//   }

//   void _phoneAction() {
//     print("Call action triggered for ${widget.mobile}");

//     // String mobile = item['mobile'] ?? '';

//     if (widget.mobile.isNotEmpty) {
//       try {
//         // Set flag that we're making a phone call
//         _wasCallingPhone = true;

//         // Simple approach without canLaunchUrl check
//         final phoneNumber = 'tel:${widget.mobile}';
//         launchUrl(
//           Uri.parse(phoneNumber),
//           mode: LaunchMode.externalNonBrowserApplication,
//         );
//       } catch (e) {
//         print('Error launching phone app: $e');

//         // Reset flag if there was an error
//         _wasCallingPhone = false;
//         // Show error message to user
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Could not launch phone dialer')),
//           );
//         }
//       }
//     } else {
//       if (context.mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('No phone number available')));
//       }
//     }
//   }

//   void _messageAction() {
//     print("Message action triggered");
//   }

//   void _mailAction() {
//     print("Mail action triggered");

//     showDialog(
//       barrierDismissible: false,
//       context: context,
//       builder: (context) {
//         return Dialog(
//           insetPadding: const EdgeInsets.symmetric(horizontal: 10),
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: FollowupsEdit(onFormSubmit: () {}, taskId: widget.taskId),
//         );
//       },
//     );
//   }
// }

// class ReusableSlidableAction extends StatelessWidget {
//   final VoidCallback onPressed;
//   final Color backgroundColor;
//   final IconData icon;
//   final Color? foregroundColor;
//   final double iconSize;

//   const ReusableSlidableAction({
//     Key? key,
//     required this.onPressed,
//     required this.backgroundColor,
//     required this.icon,
//     this.foregroundColor,
//     this.iconSize = 40.0,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return CustomSlidableAction(
//       padding: EdgeInsets.zero,
//       onPressed: (context) => onPressed(),
//       backgroundColor: backgroundColor,
//       child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
//     );
//   }
// }

// class allAppointment extends StatefulWidget {
//   final List<dynamic> allAppointments;
//   final bool isNested;

//   const allAppointment({
//     super.key,
//     required this.allAppointments,
//     this.isNested = false,
//   });

//   @override
//   State<allAppointment> createState() => _allAppointmentState();
// }

// class _allAppointmentState extends State<allAppointment> {
//   List<bool> _favorites = [];

//   @override
//   void initState() {
//     super.initState();
//     _initializeFavorites();
//   }

//   @override
//   void didUpdateWidget(allAppointment oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.allAppointments != oldWidget.allAppointments) {
//       _initializeFavorites();
//     }
//   }

//   void _initializeFavorites() {
//     _favorites = List.generate(
//       widget.allAppointments.length,
//       (index) => widget.allAppointments[index]['favourite'] == true,
//     );
//   }

//   void _toggleFavorite(int index) {
//     setState(() {
//       _favorites[index] = !_favorites[index];
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (widget.allAppointments.isEmpty) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 20),
//           child: Text(
//             "No followups available",
//             style: AppFont.smallText12(context),
//           ),
//         ),
//       );
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (!widget.isNested)
//           const Padding(
//             padding: EdgeInsets.fromLTRB(15, 15, 0, 0),
//             child: Text(
//               "All Follow ups",
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//             ),
//           ),
//         ListView.builder(
//           physics: const NeverScrollableScrollPhysics(),
//           shrinkWrap: true,
//           itemCount: widget.allAppointments.length,
//           itemBuilder: (context, index) {
//             final item = widget.allAppointments[index];
//             return AllAppointmentItem(
//               name: item['name'] ?? '',
//               subject: item['subject'] ?? '',
//               date: item['due_date'] ?? '',
//               vehicle: item['PMI'] ?? '',
//               leadId: item['lead_id'] ?? '',
//               mobile: item['mobile'] ?? '',
//               taskId: item['task_id'] ?? '',
//               isFavorite: _favorites[index],
//               onToggleFavorite: () => _toggleFavorite(index),
//             );
//           },
//         ),
//       ],
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/followups/all_followups.dart';
// import 'package:smartassist/widgets/followups/all_followup.dart'; // Import the new widget
import 'package:smartassist/widgets/followups/overdue_followup.dart';
import 'package:smartassist/widgets/followups/upcoming_row.dart';
import 'package:smartassist/widgets/home_btn.dart/dashboard_popups/create_Followups_popups.dart';
import 'package:smartassist/widgets/buttons/add_btn.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/widgets/oppointment/all_oppintment.dart';
import 'package:smartassist/widgets/oppointment/overdue.dart';
import 'package:smartassist/widgets/oppointment/upcoming.dart';

class AllAppointment extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  const AllAppointment({super.key, required this.refreshDashboard});

  @override
  State<AllAppointment> createState() => _AllAppointmentState();
}

class _AllAppointmentState extends State<AllAppointment> {
  final Widget _createFollowups = CreateFollowupsPopups(onFormSubmit: () {});
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
  int _upcommingButtonIndex = 0;

  int count = 0;

  TextEditingController searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  final TextEditingController _searchController = TextEditingController();

  // Helper method to get responsive dimensions
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

  // double _getSubTabWidth() {
  //   return 240.0 * _getResponsiveScale(); // Base width: 150
  // }

  double _getSubTabWidth() {
    // Calculate approximate width needed based on content
    double baseWidth = 240.0 * _getResponsiveScale();

    // Add extra width if count is large (adjust as needed)
    if (count > 99) {
      baseWidth += 30.0 * _getResponsiveScale();
    } else if (count > 9) {
      baseWidth += 15.0 * _getResponsiveScale();
    }

    return baseWidth;
  }

  Future<void> fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final token = await Storage.getToken();
      const String apiUrl =
          "https://api.smartassistapp.in/api/tasks/all-appointments";

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

  void _performLocalSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTasks = List.from(upcomingTasks);
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
    });
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
          'https://dev.smartassistapp.in/api/search/global?query=$query',
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

    // Perform local search immediately for better UX
    _performLocalSearch(_query);

    // Also perform API search with debounce
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim()) {
        _fetchSearchResults(_query);
      }
    });
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
            'Your Follow ups',
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
                  child: Text("No appointmet available"),
                ),
              )
            : AllOppintment(allFollowups: _filteredAllTasks, isNested: true);
      case 1: // Upcoming
        return _filteredUpcomingTasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No upcoming appointmet available"),
                ),
              )
            : OppUpcoming(
                refreshDashboard: widget.refreshDashboard,
                upcomingOpp: _filteredUpcomingTasks,
                isNested: true,
              );
      case 2: // Overdue
        return _filteredOverdueTasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No overdue appointmet available"),
                ),
              )
            : OppOverdue(
                refreshDashboard: widget.refreshDashboard,
                overdueeOpp: _filteredOverdueTasks,
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
            horizontal: 4.0 * _getResponsiveScale(),
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
