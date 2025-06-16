// import 'package:flutter/material.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/pages/Leads/single_details_pages/singleLead_followup.dart';
// import 'package:smartassist/pages/home/single_details_pages/singleLead_followup.dart';
// import 'package:smartassist/utils/bottom_navigation.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:smartassist/utils/snackbar_helper.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/lead_update.dart';

// class AllLeads extends StatefulWidget {
//   const AllLeads({super.key});

//   @override
//   State<AllLeads> createState() => _AllLeadsState();
// }

// class _AllLeadsState extends State<AllLeads> {
//   bool isLoading = true;
//   int _selectedButtonIndex = 0;
//   final Map<String, double> _swipeOffsets = {};
//   List<dynamic> upcomingTasks = [];
//   List<dynamic> _searchResults = [];
//   bool _isLoadingSearch = false;
//   String _query = '';
//   final TextEditingController _searchController = TextEditingController();

//   void _onHorizontalDragUpdate(DragUpdateDetails details, String leadId) {
//     setState(() {
//       _swipeOffsets[leadId] =
//           (_swipeOffsets[leadId] ?? 0) + (details.primaryDelta ?? 0);
//     });
//   }

//   void _onHorizontalDragEnd(DragEndDetails details, dynamic item, int index) {
//     String leadId = item['lead_id'];

//     final TextEditingController _searchController = TextEditingController();
//     double swipeOffset = _swipeOffsets[leadId] ?? 0;

//     if (swipeOffset > 100) {
//       // Right Swipe (Favorite)
//       _toggleFavorite(leadId, index);

//       // Find and get reference to the TaskItem's state
//       final GlobalKey<_TaskItemState> itemKey = GlobalKey<_TaskItemState>();

//       // Instead, use a callback to update the UI
//       bool currentStatus = item['favourite'] ?? false;
//       bool newStatus = !currentStatus;

//       // Update the UI immediately without waiting for API
//       setState(() {
//         upcomingTasks[index]['favourite'] = newStatus;
//       });
//     } else if (swipeOffset < -100) {
//       // Left Swipe (Call)
//       _handleCall(item);
//     }

//     // Reset animation
//     setState(() {
//       _swipeOffsets[leadId] = 0.0;
//     });
//   }

//   Future<void> _toggleFavorite(String leadId, int index) async {
//     final token = await Storage.getToken();
//     try {
//       // Get the current favorite status before toggling
//       bool currentStatus = upcomingTasks[index]['favourite'] ?? false;
//       bool newFavoriteStatus = !currentStatus;

//       final response = await http.put(
//         Uri.parse(
//           'https://api.smartassistapp.in/api/favourites/mark-fav/lead/$leadId',
//         ),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         // Parse the response to get the updated favorite status
//         final responseData = json.decode(response.body);

//         // Update only the specific item in the list
//         setState(() {
//           upcomingTasks[index]['favourite'] = newFavoriteStatus;
//         });

//         // No need to call fetchTasksData() which would reload everything
//       } else {
//         print('Failed to toggle favorite: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error toggling favorite: $e');
//     }
//   }

//   void _handleCall(dynamic item) {
//     print("Call action triggered for ${item['name']}");
//     // Implement actual call functionality here
//   }

//   @override
//   void initState() {
//     super.initState();
//     fetchTasksData();
//     _searchController.addListener(_onSearchChanged);
//   }

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
//         print('this is the leadall $data');
//         setState(() {
//           upcomingTasks = data['data']['rows'] ?? [];
//           isLoading = false;
//         });
//       } else {
//         print("Failed to load data: ${response.statusCode}");
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print("Error fetching data: $e");
//       setState(() => isLoading = false);
//     }
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
//           'https://api.smartassistapp.in/api/search/global?query=$query',
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
//     Future.delayed(const Duration(milliseconds: 500), () {
//       if (_query == _searchController.text.trim()) {
//         _fetchSearchResults(_query);
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => BottomNavigation()),
//             );
//           },
//           icon: const Icon(FontAwesomeIcons.angleLeft, color: Colors.white),
//         ),
//         title: Text(
//           'My Enquiries',
//           style: GoogleFonts.poppins(
//             fontSize: 18,
//             fontWeight: FontWeight.w400,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: Colors.blue,
//         automaticallyImplyLeading: false,
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 // Search field container (unchanged)
//                 Container(
//                   margin: const EdgeInsets.all(10),
//                   child: SizedBox(
//                     width: double.infinity,
//                     height: MediaQuery.of(context).size.height * .05,
//                     child: TextField(
//                       autofocus: false,
//                       controller: _searchController,
//                       onChanged: (value) => _onSearchChanged(),
//                       textAlignVertical: TextAlignVertical.center,
//                       decoration: InputDecoration(
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(30),
//                           borderSide: BorderSide.none,
//                         ),
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 15,
//                         ), // Reduce padding
//                         filled: true,
//                         fillColor: AppColors.searchBar,
//                         hintText: 'Search by name, email or phone',
//                         hintStyle: GoogleFonts.poppins(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w300,
//                         ),
//                         prefixIcon: const Padding(
//                           padding: EdgeInsets.only(
//                             right: 8,
//                           ), // Reduce icon padding
//                           child: Icon(
//                             FontAwesomeIcons.magnifyingGlass,
//                             color: AppColors.fontColor,
//                             size: 15,
//                           ),
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(30),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                     ),
//                   ),
//                   // Search query indicator - keep this outside the Expanded
//                 ),
//                 if (_query.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 10),
//                     child: Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         textAlign: TextAlign.left,
//                         'Showing results for: $_query',
//                         style: GoogleFonts.poppins(
//                           fontSize: 12,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                     ),
//                   ),

//                 // Expanded widget containing the appropriate list
//                 Expanded(
//                   child: _query.isNotEmpty
//                       ? _buildTasksList(_searchResults)
//                       : _buildTasksList(upcomingTasks),
//                 ),
//               ],
//             ),
//     );
//   }

//   Widget _buildTasksList(List<dynamic> tasks) {
//     if (tasks.isEmpty) {
//       return const Center(child: Text('No Leads available'));
//     }

//     return ListView.builder(
//       // shrinkWrap: true,
//       physics: const AlwaysScrollableScrollPhysics(),
//       itemCount: tasks.length,
//       itemBuilder: (context, index) {
//         var item = tasks[index];

//         // Make sure all required fields exist or provide defaults
//         if (!(item.containsKey('lead_id') && item.containsKey('lead_name'))) {
//           return ListTile(title: Text('Invalid data at index $index'));
//         }

//         String leadId = item['lead_id'] ?? '';
//         double swipeOffset = _swipeOffsets[leadId] ?? 0;

//         return GestureDetector(
//           onHorizontalDragUpdate: (details) =>
//               _onHorizontalDragUpdate(details, leadId),
//           onHorizontalDragEnd: (details) =>
//               _onHorizontalDragEnd(details, item, index),
//           child: TaskItem(
//             name: item['lead_name'] ?? '',
//             date: item['created_at'] ?? '', // Using created_at as fallback
//             subject: item['email'] ?? 'No subject',
//             vehicle:
//                 item['PMI'] ??
//                 'Discovery Sport', // PMI contains the vehicle info
//             leadId: leadId,
//             taskId: leadId, // Using leadId as taskId since there's no taskId
//             brand: item['brand'] ?? '',
//             number: item['mobile'] ?? '',
//             isFavorite: item['favourite'] ?? false,
//             swipeOffset: swipeOffset,
//             fetchDashboardData: () {},
//             onFavoriteToggled: fetchTasksData,
//             // onEdit: fetchTasksData,
//             onFavoriteChanged: (newStatus) {
//               setState(() {
//                 upcomingTasks[index]['favourite'] = newStatus;
//               });
//             },
//             onToggleFavorite: () {
//               _toggleFavorite(leadId, index);
//             },
//           ),
//         );
//       },
//     );
//   }
// }

// class TaskItem extends StatefulWidget {
//   final String name, subject, number;
//   final String date;
//   final String vehicle;
//   final String leadId;
//   final String taskId;
//   final String brand;
//   final double swipeOffset;
//   final bool isFavorite;
//   final VoidCallback fetchDashboardData;
//   final VoidCallback onFavoriteToggled;
//   final Function(bool) onFavoriteChanged;
//   final VoidCallback onToggleFavorite;
//   // final VoidCallback fetchTasksData;
//   const TaskItem({
//     super.key,
//     required this.name,
//     required this.date,
//     required this.vehicle,
//     required this.leadId,
//     required this.taskId,
//     required this.isFavorite,
//     required this.onFavoriteToggled,
//     required this.brand,
//     required this.subject,
//     required this.swipeOffset,
//     required this.fetchDashboardData,
//     required this.onFavoriteChanged,
//     required this.onToggleFavorite,
//     required this.number,
//   });

//   @override
//   State<TaskItem> createState() => _TaskItemState();
// }

// class _TaskItemState extends State<TaskItem> {
//   late bool isFav;

//   void updateFavoriteStatus(bool newStatus) {
//     setState(() {
//       isFav = newStatus;
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     isFav = widget.isFavorite;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
//       child: _buildFollowupCard(context),
//     );
//   }

//   Widget _buildFollowupCard(BuildContext context) {
//     bool isFavoriteSwipe = widget.swipeOffset > 50;
//     bool isCallSwipe = widget.swipeOffset < -50;

//     // Gradient background for swipe
//     // LinearGradient _buildSwipeGradient() {
//     //   if (isFavoriteSwipe) {
//     //     return const LinearGradient(
//     //       colors: [
//     //         Color.fromRGBO(239, 206, 29, 0.67),
//     //         Color.fromRGBO(239, 206, 29, 0.67)
//     //       ],
//     //       begin: Alignment.centerLeft,
//     //       end: Alignment.centerRight,
//     //     );
//     //   } else if (isCallSwipe) {
//     //     return LinearGradient(
//     //       colors: [
//     //         Colors.green.withOpacity(0.2),
//     //         Colors.green.withOpacity(0.8)
//     //       ],
//     //       begin: Alignment.centerRight,
//     //       end: Alignment.centerLeft,
//     //     );
//     //   }
//     //   return const LinearGradient(
//     //     colors: [AppColors.containerBg, AppColors.containerBg],
//     //     begin: Alignment.centerLeft,
//     //     end: Alignment.centerRight,
//     //   );
//     // }

//     return Slidable(
//       key: ValueKey(widget.leadId),
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
//         motion: const StretchMotion(),
//         extentRatio: 0.2,
//         children: [
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
//           if (isFavoriteSwipe)
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Colors.yellow.withOpacity(0.2),
//                       Colors.yellow.withOpacity(0.8),
//                     ],
//                     begin: Alignment.centerLeft,
//                     end: Alignment.centerRight,
//                   ),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Center(
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     children: [
//                       const SizedBox(width: 15),
//                       Icon(
//                         isFav ? Icons.star_outline_rounded : Icons.star_rounded,
//                         color: const Color.fromRGBO(226, 195, 34, 1),
//                         size: 40,
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         isFav ? 'Unfavorite' : 'Favorite',
//                         style: GoogleFonts.poppins(
//                           color: const Color.fromRGBO(187, 158, 0, 1),
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//           // Call Swipe Overlay
//           if (isCallSwipe)
//             Positioned.fill(
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       Colors.green.withOpacity(0.2),
//                       Colors.green.withOpacity(0.8),
//                     ],
//                     begin: Alignment.centerRight,
//                     end: Alignment.centerLeft,
//                   ),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Center(
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     children: [
//                       const SizedBox(width: 10),
//                       const Icon(
//                         Icons.phone_in_talk,
//                         color: Colors.white,
//                         size: 30,
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         'Call',
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(width: 5),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//           // Main Container
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
//             decoration: BoxDecoration(
//               color: AppColors.backgroundLightGrey,
//               // gradient: _buildSwipeGradient(),
//               borderRadius: BorderRadius.circular(7),
//               border: Border(
//                 left: BorderSide(
//                   width: 8.0,
//                   color: isFav
//                       ? (isCallSwipe
//                             ? Colors.green.withOpacity(
//                                 0.9,
//                               ) // Green when swiping for a call
//                             : Colors.yellow.withOpacity(
//                                 isFavoriteSwipe ? 0.1 : 0.9,
//                               )) // Keep yellow when favorite
//                       : (isFavoriteSwipe
//                             ? Colors.yellow.withOpacity(0.1)
//                             : (isCallSwipe
//                                   ? Colors.green.withOpacity(0.1)
//                                   : AppColors.sideGreen)),
//                 ),
//               ),
//             ),
//             child: Opacity(
//               opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   Row(
//                     children: [
//                       const SizedBox(width: 8),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                               _buildUserDetails(context),
//                               _buildVerticalDivider(15),
//                               _buildSubjectDetails(context),
//                               // _buildCarModel(context),
//                             ],
//                           ),
//                           const SizedBox(height: 4),
//                           Row(
//                             children: [
//                               _buildCarModel(context),
//                               // _buildSubjectDetails(context),
//                               // _date(context),
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

//   void _mailAction() {
//     print("Mail action triggered");

//     showDialog(
//       context: context,
//       builder: (context) {
//         return Dialog(
//           insetPadding: const EdgeInsets.symmetric(horizontal: 10),
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: LeadUpdate(
//             onFormSubmit: () {},
//             leadId: widget.leadId,
//             onEdit: widget.onFavoriteToggled,
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildNavigationButton(BuildContext context) {
//     return GestureDetector(
//       onTap: () {
//         if (widget.leadId.isNotEmpty) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => FollowupsDetails(leadId: widget.leadId,
//                 isFromFreshlead: false,
//               ),
//             ),
//           );
//         } else {
//           print("Invalid leadId");
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.all(3),
//         decoration: BoxDecoration(
//           color: AppColors.arrowContainerColor,
//           borderRadius: BorderRadius.circular(30),
//         ),
//         child: const Icon(
//           Icons.arrow_forward_ios_rounded,
//           size: 25,
//           color: Colors.white,
//         ),
//       ),
//     );
//   }

//   Widget _buildUserDetails(BuildContext context) {
//     return Text(
//       widget.name,
//       textAlign: TextAlign.end,
//       style: AppFont.dashboardName(context),
//     );
//   }

//   Widget _buildSubjectDetails(BuildContext context) {
//     String mobile = widget.number;
//     String hiddenMobile = _hideMobileNumber(mobile);
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [Text(hiddenMobile, style: AppFont.smallText(context))],
//     );
//   }

//   String _hideMobileNumber(String mobile) {
//     if (mobile.length >= 10) {
//       // Example: 98765XXXXX
//       return mobile.substring(0, 3) + '*****' + mobile.substring(8);
//     } else {
//       return mobile; // fallback
//     }
//   }

//   Widget _date(BuildContext context) {
//     String formattedDate = '';

//     try {
//       DateTime parseDate = DateTime.parse(widget.date);

//       // Check if the date is today
//       if (parseDate.year == DateTime.now().year &&
//           parseDate.month == DateTime.now().month &&
//           parseDate.day == DateTime.now().day) {
//         formattedDate = 'Today';
//       } else {
//         // If not today, format it as "26th March"
//         int day = parseDate.day;
//         String suffix = _getDaySuffix(day);
//         String month = DateFormat('MMM').format(parseDate); // Full month name
//         formattedDate = '${day}$suffix $month';
//       }
//     } catch (e) {
//       formattedDate = widget.date; // Fallback if date parsing fails
//     }

//     return Row(
//       children: [
//         const SizedBox(width: 5),
//         Text(formattedDate, style: AppFont.smallText(context)),
//       ],
//     );
//   }

//   // Helper method to get the suffix for the day (e.g., "st", "nd", "rd", "th")
//   String _getDaySuffix(int day) {
//     if (day >= 11 && day <= 13) {
//       return 'th';
//     }
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
//       margin: const EdgeInsets.only(bottom: 3, left: 10, right: 10),
//       height: height,
//       width: 0.1,
//       decoration: const BoxDecoration(
//         border: Border(right: BorderSide(color: AppColors.fontColor)),
//       ),
//     );
//   }

//   Widget _buildCarModel(BuildContext context) {
//     return Text(
//       widget.vehicle,
//       textAlign: TextAlign.start,
//       style: AppFont.dashboardCarName(context),
//       softWrap: true,
//       overflow: TextOverflow.visible,
//     );
//   }
// }

// class FlexibleButton extends StatelessWidget {
//   final String title;
//   final VoidCallback onPressed;
//   final BoxDecoration decoration;
//   final TextStyle textStyle;

//   const FlexibleButton({
//     super.key,
//     required this.title,
//     required this.onPressed,
//     required this.decoration,
//     required this.textStyle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
//       height: 30,
//       decoration: decoration,
//       child: TextButton(
//         style: TextButton.styleFrom(
//           backgroundColor: const Color(0xffF3F9FF),
//           padding: const EdgeInsets.symmetric(horizontal: 10),
//           minimumSize: const Size(0, 0),
//           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//         ),
//         onPressed: onPressed,
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(title, style: textStyle, textAlign: TextAlign.center),
//             const SizedBox(width: 4), // small space between text and icon
//             const Icon(
//               Icons.keyboard_arrow_down_rounded,
//               size: 20,
//               // color: AppColors.fontColor,
//             ),
//           ],
//         ),
//       ),
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
//       borderRadius: BorderRadius.circular(10),
//       onPressed: (context) => onPressed(),
//       backgroundColor: backgroundColor,
//       padding: EdgeInsets.zero,
//       child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/lead_update.dart';

class AllLeads extends StatefulWidget {
  const AllLeads({super.key});

  @override
  State<AllLeads> createState() => _AllLeadsState();
}

class _AllLeadsState extends State<AllLeads> {
  bool isLoading = true;
  int _selectedButtonIndex = 0;
  final Map<String, double> _swipeOffsets = {};
  List<dynamic> upcomingTasks = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _filteredTasks = []; // Local filtered results
  bool _isLoadingSearch = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

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
          _updateFilteredResults();
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

  // Local search function for name, email, phone
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

  void _updateFilteredResults() {
    if (_query.isEmpty) {
      _filteredTasks = List.from(upcomingTasks);
    } else {
      _performLocalSearch(_query);
    }
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BottomNavigation()),
            );
          },
          icon: const Icon(FontAwesomeIcons.angleLeft, color: Colors.white),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'My Enquiries',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF1380FE),
        automaticallyImplyLeading: false,
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
            onFavoriteToggled: () {
              fetchTasksData();
              _updateFilteredResults();
            },
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
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  late bool isFav;

  void updateFavoriteStatus(bool newStatus) {
    setState(() {
      isFav = newStatus;
    });
  }

  @override
  void initState() {
    super.initState();
    isFav = widget.isFavorite;
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

    return Slidable(
      key: ValueKey(widget.leadId),
      startActionPane: ActionPane(
        extentRatio: isTablet ? 0.15 : 0.2,
        motion: const ScrollMotion(),
        children: [
          ReusableSlidableAction(
            onPressed: widget.onToggleFavorite,
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
            onPressed: _mailAction,
            backgroundColor: const Color.fromARGB(255, 231, 225, 225),
            icon: Icons.edit,
            foregroundColor: Colors.white,
            iconSize: isTablet ? 45 : 40,
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
                        isFav ? Icons.star_outline_rounded : Icons.star_rounded,
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
    );
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

  Widget _buildNavigationButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return GestureDetector(
      onTap: () {
        if (widget.leadId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowupsDetails(
                leadId: widget.leadId,
                isFromFreshlead: false,
                isFromManager: false,
              ),
            ),
          );
        } else {
          print("Invalid leadId");
        }
      },
      child: Container(
        padding: EdgeInsets.all(isTablet ? 6 : 3),
        decoration: BoxDecoration(
          color: AppColors.arrowContainerColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          size: isTablet ? 30 : 25,
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
