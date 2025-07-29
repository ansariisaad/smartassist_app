// // // import 'package:flutter/material.dart';
// // // import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// // // import 'package:google_fonts/google_fonts.dart';
// // // import 'package:smartassist/config/component/font/font.dart';
// // // import 'package:smartassist/services/api_srv.dart';
// // // import 'package:smartassist/widgets/testdrive_verifyotp.dart';
// // // import 'package:intl/intl.dart';
// // // import 'package:url_launcher/url_launcher.dart';

// // // class TimelineUpcoming extends StatefulWidget {
// // //   final bool isFromTeams;
// // //   final carIcon = '/assets/caricon.png';
// // //   final List<Map<String, dynamic>> tasks;
// // //   final List<Map<String, dynamic>> upcomingEvents;
// // //   const TimelineUpcoming({
// // //     super.key,
// // //     required this.tasks,
// // //     required this.upcomingEvents,
// // //     required this.isFromTeams,
// // //   });

// // //   @override
// // //   State<TimelineUpcoming> createState() => _TimelineUpcomingState();
// // // }

// // // class _TimelineUpcomingState extends State<TimelineUpcoming> {
// // //   final Set<int> expandedTaskIndexes = {};
// // //   final Set<int> expandedEventIndexes = {};

// // //   String _formatDate(String date) {
// // //     try {
// // //       final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
// // //       return DateFormat("d MMM").format(parsedDate);
// // //     } catch (e) {
// // //       return 'N/A';
// // //     }
// // //   }

// // //   Future<void> _showAleart(
// // //     String eventId,
// // //     String gmail,
// // //     String leadId,
// // //     String mobile,
// // //     BuildContext context,
// // //   ) async {
// // //     return showDialog<void>(
// // //       context: context,
// // //       barrierDismissible: false,
// // //       builder: (BuildContext context) {
// // //         return AlertDialog(
// // //           shape: RoundedRectangleBorder(
// // //             borderRadius: BorderRadius.circular(10),
// // //           ),
// // //           title: Text(
// // //             'Ready to start test drive?',
// // //             style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
// // //           ),
// // //           content: Text(
// // //             'Please make sure you have all the necessary documents(license) and permissions(OTP) ready before starting test drive.',
// // //             style: GoogleFonts.poppins(),
// // //           ),
// // //           actions: [
// // //             TextButton(
// // //               style: TextButton.styleFrom(
// // //                 overlayColor: Colors.grey.withOpacity(0.1),
// // //                 foregroundColor: Colors.grey,
// // //               ),
// // //               onPressed: () => Navigator.of(context).pop(false),
// // //               child: Text('No', style: GoogleFonts.poppins(color: Colors.grey)),
// // //             ),
// // //             TextButton(
// // //               style: TextButton.styleFrom(
// // //                 overlayColor: AppColors.colorsBlue.withOpacity(0.1),
// // //                 foregroundColor: AppColors.colorsBlue,
// // //               ),
// // //               onPressed: () {
// // //                 _getOtp(eventId);
// // //                 Navigator.push(
// // //                   context,
// // //                   MaterialPageRoute(
// // //                     builder: (context) => TestdriveVerifyotp(
// // //                       email: gmail,
// // //                       eventId: eventId,
// // //                       leadId: leadId,
// // //                       mobile: mobile,
// // //                     ),
// // //                   ),
// // //                 );
// // //               },
// // //               child: Text(
// // //                 'Yes',
// // //                 style: GoogleFonts.poppins(color: AppColors.colorsBlue),
// // //               ),
// // //             ),
// // //           ],
// // //         );
// // //       },
// // //     );
// // //   }

// // //   Future<void> _getOtp(String eventId) async {
// // //     final success = await LeadsSrv.getOtp(eventId: eventId);
// // //     if (success) {
// // //       print('✅ Test drive started successfully');
// // //     } else {
// // //       print('❌ Failed to start test drive');
// // //     }
// // //   }

// // //   bool _shouldShowSeeMore(String remarks) {
// // //     return remarks.length > 60;
// // //   }

// // //   bool _isTestDrive(String subject) {
// // //     return subject.toLowerCase().contains('test drive');
// // //   }

// // //   // Helper method to determine container height based on content
// // //   double _getContainerHeight(String remarks, bool isExpanded, bool showSeeMore) {
// // //     if (remarks.isEmpty) {
// // //       return 45.0; // Minimal height for empty content
// // //     }

// // //     // Estimate text lines based on character count (rough estimation)
// // //     int estimatedLines;
// // //     if (showSeeMore && !isExpanded) {
// // //       estimatedLines = 2; // Clamped to 2 lines when collapsed
// // //     } else {
// // //       // Rough estimation: ~50 characters per line on average mobile screen
// // //       estimatedLines = (remarks.length / 50).ceil();
// // //     }

// // //     // Base height calculation
// // //     double baseHeight = 40; // Height for "Remarks:" label + padding
// // //     double lineHeight = 18; // Approximate height per line of text
// // //     double seeMoreButtonHeight = showSeeMore ? 30 : 0; // Height for see more/less button

// // //     double calculatedHeight = baseHeight + (estimatedLines * lineHeight) + seeMoreButtonHeight;

// // //     // Ensure minimum readable height
// // //     return calculatedHeight < 60 ? 60 : calculatedHeight;
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final reversedTasks = widget.tasks.reversed.toList();
// // //     final reversedUpcomingEvents = widget.upcomingEvents.reversed.toList();

// // //     if (reversedTasks.isEmpty && reversedUpcomingEvents.isEmpty) {
// // //       return Center(
// // //         child: Padding(
// // //           padding: const EdgeInsets.symmetric(vertical: 20),
// // //           child: Text(
// // //             "No upcoming task available",
// // //             style: AppFont.smallText12(context),
// // //           ),
// // //         ),
// // //       );
// // //     }

// // //     return Column(
// // //       children: [
// // //         // TASKS
// // //         ...List.generate(reversedTasks.length, (index) {
// // //           final task = reversedTasks[index];
// // //           String remarks = task['remarks'] ?? '';
// // //           String mobile = task['mobile'] ?? '';
// // //           String dueDate = _formatDate(task['due_date'] ?? 'N/A');
// // //           String subject = task['subject'] ?? 'No Subject';

// // //           bool isExpanded = expandedTaskIndexes.contains(index);
// // //           bool showSeeMore = _shouldShowSeeMore(remarks);

// // //           return Column(
// // //             crossAxisAlignment: CrossAxisAlignment.start,
// // //             children: [
// // //               // Date & Action Row (NO icon)
// // //               Row(
// // //                 crossAxisAlignment: CrossAxisAlignment.center,
// // //                 children: [
// // //                   // Date Badge
// // //                   Text(
// // //                     dueDate,
// // //                     style: AppFont.dropDowmLabel(context)?.copyWith(
// // //                       fontSize: 14,
// // //                       fontWeight: FontWeight.w600,
// // //                       color: const Color(0xFF3497F9),
// // //                     ),
// // //                   ),
// // //                   const SizedBox(width: 12),
// // //                   // Action Text
// // //                   Text(
// // //                     subject,
// // //                     style: AppFont.dropDowmLabel(context)?.copyWith(
// // //                       fontWeight: FontWeight.w600,
// // //                       fontSize: 12.5,
// // //                       color: const Color(0xFF3497F9),
// // //                     ),
// // //                   ),
// // //                 ],
// // //               ),
// // //               const SizedBox(height: 10),

// // //               // Card with dynamic height based on content
// // //               Container(
// // //                 width: double.infinity,
// // //                 decoration: BoxDecoration(
// // //                   color: const Color(0xffE7F2FF),
// // //                   borderRadius: BorderRadius.circular(12),
// // //                 ),
// // //                 padding: const EdgeInsets.all(14),
// // //                 margin: const EdgeInsets.only(top: 4, bottom: 20),
// // //                 child: IntrinsicHeight( // This makes container height fit content
// // //                   child: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     mainAxisSize: MainAxisSize.min,
// // //                     children: [
// // //                       Text(
// // //                         'Remarks:',
// // //                         style: AppFont.dropDowmLabel(context)?.copyWith(
// // //                           color: Colors.black,
// // //                         ),
// // //                       ),
// // //                       const SizedBox(height: 4),
// // //                       if (remarks.isNotEmpty) ...[
// // //                         Text(
// // //                           remarks,
// // //                           maxLines: (!showSeeMore || isExpanded) ? null : 2,
// // //                           overflow: (!showSeeMore || isExpanded)
// // //                               ? TextOverflow.visible
// // //                               : TextOverflow.ellipsis,
// // //                           style: AppFont.smallText12(context)?.copyWith(
// // //                             color: Colors.black,
// // //                             height: 1.4, // Line height for better readability
// // //                           ),
// // //                         ),
// // //                         if (showSeeMore) ...[
// // //                           const SizedBox(height: 8),
// // //                           GestureDetector(
// // //                             onTap: () {
// // //                               setState(() {
// // //                                 if (isExpanded) {
// // //                                   expandedTaskIndexes.remove(index);
// // //                                 } else {
// // //                                   expandedTaskIndexes.add(index);
// // //                                 }
// // //                               });
// // //                             },
// // //                             child: Text(
// // //                               isExpanded ? 'See less' : 'See more',
// // //                               style: GoogleFonts.poppins(
// // //                                 color: Colors.black,
// // //                                 fontWeight: FontWeight.w500,
// // //                                 fontSize: 12,
// // //                               ),
// // //                             ),
// // //                           ),
// // //                         ],
// // //                       ] else ...[
// // //                         Text(
// // //                           'No remarks ',
// // //                           style: AppFont.smallText12(context)?.copyWith(
// // //                             color: Colors.grey[600],

// // //                           ),
// // //                         ),
// // //                       ],
// // //                     ],
// // //                   ),
// // //                 ),
// // //               ),
// // //             ],
// // //           );
// // //         }),

// // //         // EVENTS
// // //         ...List.generate(reversedUpcomingEvents.length, (index) {
// // //           final event = reversedUpcomingEvents[index];
// // //           String eventId = event['event_id'] ?? 'No ID';
// // //           String leadId = event['lead_id'] ?? 'No ID';
// // //           String gmail = event['lead_email'] ?? '';
// // //           String remarks = event['remarks'] ?? '';
// // //           String mobile = event['mobile'] ?? '';
// // //           String eventDate = _formatDate(event['start_date'] ?? 'N/A');
// // //           String eventSubject = event['subject'] ?? 'No Subject';

// // //           bool isExpanded = expandedEventIndexes.contains(index);
// // //           bool showSeeMore = _shouldShowSeeMore(remarks);
// // //           bool isTestDriveEvent = _isTestDrive(eventSubject);

// // //           // Choose colors based on whether it's a test drive
// // //           Color badgeColor = isTestDriveEvent ? const Color(0xFF3497F9) : const Color(0xFF3497F9);

// // //           return Container(
// // //             margin: const EdgeInsets.only(bottom: 20),
// // //             child: Column(
// // //               crossAxisAlignment: CrossAxisAlignment.start,
// // //               children: [
// // //                 // Date & Action Row (NO icon)
// // //                 Row(
// // //                   crossAxisAlignment: CrossAxisAlignment.center,
// // //                   children: [
// // //                     // Date Badge
// // //                     Text(
// // //                       eventDate,
// // //                       style: AppFont.dropDowmLabel(context)?.copyWith(
// // //                         fontSize: 14,
// // //                         fontWeight: FontWeight.w600,
// // //                         color: badgeColor,
// // //                       ),
// // //                     ),
// // //                     const SizedBox(width: 12),
// // //                     // Action Text
// // //                     Text(
// // //                       eventSubject,
// // //                       style: AppFont.dropDowmLabel(context)?.copyWith(
// // //                         fontWeight: FontWeight.w600,
// // //                         fontSize: 14,
// // //                         color: const Color(0xFF3497F9),
// // //                       ),
// // //                     ),
// // //                   ],
// // //                 ),
// // //                 const SizedBox(height: 10),

// // //                 // Card with dynamic height based on content
// // //                 Container(
// // //                   width: double.infinity,
// // //                   decoration: BoxDecoration(
// // //                     color: const Color(0xffE7F2FF),
// // //                     borderRadius: BorderRadius.circular(12),
// // //                   ),
// // //                   padding: const EdgeInsets.all(14),
// // //                   margin: const EdgeInsets.only(top: 4),
// // //                   child: IntrinsicHeight( // This makes container height fit content
// // //                     child: Column(
// // //                       crossAxisAlignment: CrossAxisAlignment.start,
// // //                       mainAxisSize: MainAxisSize.min,
// // //                       children: [
// // //                         Text(
// // //                           'Remarks:',
// // //                           style: AppFont.dropDowmLabel(context)?.copyWith(
// // //                             color: Colors.black,
// // //                           ),
// // //                         ),
// // //                         const SizedBox(height: 4),
// // //                         if (remarks.isNotEmpty) ...[
// // //                           Text(
// // //                             remarks,
// // //                             maxLines: (!showSeeMore || isExpanded) ? null : 2,
// // //                             overflow: (!showSeeMore || isExpanded)
// // //                                 ? TextOverflow.visible
// // //                                 : TextOverflow.ellipsis,
// // //                             style: AppFont.smallText12(context)?.copyWith(
// // //                               color: Colors.black,
// // //                               height: 1.4, // Line height for better readability
// // //                             ),
// // //                           ),
// // //                           if (showSeeMore) ...[
// // //                             const SizedBox(height: 8),
// // //                             GestureDetector(
// // //                               onTap: () {
// // //                                 setState(() {
// // //                                   if (isExpanded) {
// // //                                     expandedEventIndexes.remove(index);
// // //                                   } else {
// // //                                     expandedEventIndexes.add(index);
// // //                                   }
// // //                                 });
// // //                               },
// // //                               child: Text(
// // //                                 isExpanded ? 'See less' : 'See more',
// // //                                 style: GoogleFonts.poppins(
// // //                                   color: Colors.black,
// // //                                   fontWeight: FontWeight.w500,
// // //                                   fontSize: 12,
// // //                                 ),
// // //                               ),
// // //                             ),
// // //                           ],
// // //                         ] else ...[
// // //                           Text(
// // //                             'No remarks available',
// // //                             style: AppFont.smallText12(context)?.copyWith(
// // //                               color: Colors.grey[600],

// // //                             ),
// // //                           ),
// // //                         ],
// // //                       ],
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ],
// // //             ),
// // //           );
// // //         }),

// // //         const SizedBox(height: 10),
// // //       ],
// // //     );
// // //   }
// // // }
//  //without icon code //





// // import 'package:flutter/material.dart';
// // import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// // import 'package:google_fonts/google_fonts.dart';
// // import 'package:smartassist/config/component/color/colors.dart';
// // import 'package:smartassist/config/component/font/font.dart';
// // import 'package:smartassist/services/api_srv.dart';
// // import 'package:smartassist/widgets/testdrive_verifyotp.dart';
// // import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/followups.dart';
// // import 'package:intl/intl.dart';
// // import 'package:url_launcher/url_launcher.dart';

// // class TimelineUpcoming extends StatefulWidget {
// //   final bool isFromTeams;
// //   final carIcon = '/assets/caricon.png';
// //   final List<Map<String, dynamic>> tasks;
// //   final List<Map<String, dynamic>> upcomingEvents;
// //   const TimelineUpcoming({
// //     super.key,
// //     required this.tasks,
// //     required this.upcomingEvents,
// //     required this.isFromTeams,
// //   });

// //   @override
// //   State<TimelineUpcoming> createState() => _TimelineUpcomingState();
// // }

// // class _TimelineUpcomingState extends State<TimelineUpcoming> {
// //   final Set<int> expandedTaskIndexes = {};
// //   final Set<int> expandedEventIndexes = {};

// //   String _formatDate(String date) {
// //     try {
// //       final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
// //       return DateFormat("d MMM").format(parsedDate);
// //     } catch (e) {
// //       return 'N/A';
// //     }
// //   }

// //   // Icon logic from old code
// //   IconData _getIconFromSubject(String subject) {
// //     if (subject == 'Provide Quotation') {
// //       return Icons.receipt_long;
// //     } else if (subject == 'Send SMS') {
// //       return Icons.message_rounded;
// //     } else if (subject == 'Call') {
// //       return Icons.phone;
// //     } else if (subject == 'Send Email') {
// //       return Icons.mail;
// //     } else if (subject == 'Showroom appointment') {
// //       return Icons.person_2_outlined;
// //     } else if (subject == 'Trade in evaluation') {
// //       return Icons.handshake;
// //     } else if (subject == 'Test Drive') {
// //       return Icons.directions_car;
// //     } else if (subject == 'Quotation') {
// //       return FontAwesomeIcons.solidCalendar;
// //     } else {
// //       return Icons.info_outline; // default fallback icon
// //     }
// //   }


// //  void Function(String) _getActionFromSubjectEdit(String subject) {

// //     if (subject == 'Provide Quotation') {
// //       return _showEditFollowupDialog;
// //     } else if (subject == 'Send SMS') {
// //       return _showEditFollowupDialog;
// //     } else if (subject == 'Call') {
// //       return _showEditFollowupDialog;
// //     } else if (subject == 'Send Email') {
// //      return _showEditFollowupDialog;
// //     } else if (subject == 'Showroom appointment') {
// //       return _showEditFollowupDialog;
// //     } else if (subject == 'Trade in evaluation') {
// //        return _showEditFollowupDialog;
// //     } else if (subject == 'Test Drive') {
// //      return _showEditFollowupDialog;
// //     } else if (subject == 'Quotation') {
// //        return _showEditFollowupDialog;
// //     } else {
// //        return _showEditFollowupDialog;
// //     }
// //   }

// //   // Route handling logic from old code - SNACKBAR REMOVED
// //   void _handleIconPress(
// //     String subject,
// //     String mobile,
// //     String eventId,
// //     String gmail,
// //     String leadId,
// //     BuildContext context,
// //   ) {
// //     if (widget.isFromTeams) return; // Don't handle actions if from teams

// //     if (subject == 'Call') {
// //       launchUrl(Uri.parse('tel:$mobile'));
// //     } else if (subject == 'Send SMS') {
// //       launchUrl(Uri.parse('sms:$mobile'));
// //     } else if (subject == 'Test Drive') {
// //       _showAleart(eventId, gmail, leadId, mobile, context);
// //     }
// //     // Removed the else clause that showed the snackbar
// //   }

// //   // Function to show edit follow-up popup
// //   void _showEditFollowupDialog(String taskId) {
// //     showDialog(
// //       barrierDismissible: false,
// //       context: context,
// //       builder: (context) {
// //         return Dialog(
// //           insetPadding: const EdgeInsets.symmetric(horizontal: 10),
// //           backgroundColor: Colors.white,
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(10),
// //           ),
// //           child: FollowupsEdit(onFormSubmit: () {}, taskId: taskId),
// //         );
// //       },
// //     );
// //   }

// //   Future<void> _showAleart(
// //     String eventId,
// //     String gmail,
// //     String leadId,
// //     String mobile,
// //     BuildContext context,
// //   ) async {
// //     return showDialog<void>(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           shape: RoundedRectangleBorder(
// //             borderRadius: BorderRadius.circular(10),
// //           ),
// //           title: Text(
// //             'Ready to start test drive?',
// //             style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
// //           ),
// //           content: Text(
// //             'Please make sure you have all the necessary documents(license) and permissions(OTP) ready before starting test drive.',
// //             style: GoogleFonts.poppins(),
// //           ),
// //           actions: [
// //             TextButton(
// //               style: TextButton.styleFrom(
// //                 overlayColor: Colors.grey.withOpacity(0.1),
// //                 foregroundColor: Colors.grey,
// //               ),
// //               onPressed: () => Navigator.of(context).pop(false),
// //               child: Text('No', style: GoogleFonts.poppins(color: Colors.grey)),
// //             ),
// //             TextButton(
// //               style: TextButton.styleFrom(
// //                 overlayColor: AppColors.colorsBlue.withOpacity(0.1),
// //                 foregroundColor: AppColors.colorsBlue,
// //               ),
// //               onPressed: () {
// //                 _getOtp(eventId);
// //                 Navigator.push(
// //                   context,
// //                   MaterialPageRoute(
// //                     builder: (context) => TestdriveVerifyotp(
// //                       email: gmail,
// //                       eventId: eventId,
// //                       leadId: leadId,
// //                       mobile: mobile,
// //                     ),
// //                   ),
// //                 );
// //               },
// //               child: Text(
// //                 'Yes',
// //                 style: GoogleFonts.poppins(color: AppColors.colorsBlue),
// //               ),
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   Future<void> _getOtp(String eventId) async {
// //     final success = await LeadsSrv.getOtp(eventId: eventId);
// //     if (success) {
// //       print('✅ Test drive started successfully');
// //     } else {
// //       print('❌ Failed to start test drive');
// //     }
// //   }

// //   // Updated method to check if text needs "See more" based on line count
// //   bool _shouldShowSeeMore(String text) {
// //     // Rough estimation: ~40-50 characters per line on average mobile screen
// //     // For 2 lines, that's approximately 80-100 characters
// //     return text.length > 100;
// //   }

// //   bool _isTestDrive(String subject) {
// //     return subject.toLowerCase().contains('test drive');
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final reversedTasks = widget.tasks.reversed.toList();
// //     final reversedUpcomingEvents = widget.upcomingEvents.reversed.toList();

// //     if (reversedTasks.isEmpty && reversedUpcomingEvents.isEmpty) {
// //       return Center(
// //         child: Padding(
// //           padding: const EdgeInsets.symmetric(vertical: 20),
// //           child: Text(
// //             "No upcoming task available",
// //             style: AppFont.smallText12(context),
// //           ),
// //         ),
// //       );
// //     }

// //     return Column(
// //       children: [
// //         // TASKS
// //         ...List.generate(reversedTasks.length, (index) {
// //           final task = reversedTasks[index];
// //           String remarks = task['remarks'] ?? '';
// //           String mobile = task['mobile'] ?? '';
// //           String dueDate = _formatDate(task['due_date'] ?? 'N/A');
// //           String subject = task['subject'] ?? 'No Subject';
// //           String taskId = task['id']?.toString() ?? ''; 

// //           bool isExpanded = expandedTaskIndexes.contains(index);
// //           bool showSeeMore = _shouldShowSeeMore(remarks);

// //           // Get icon from old code logic
// //           IconData iconData = _getIconFromSubject(subject);

// //           return Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               // Date & Action Row WITH ICON AND ROUTING
// //               Row(
// //                 crossAxisAlignment: CrossAxisAlignment.center,
// //                 children: [
// //                   // Clickable Icon with routing functionality
// //                   GestureDetector(
// //                     onTap: () {
// //                       _handleIconPress(subject, mobile, '', '', '', context);
// //                     },
// //                     child: Container(
// //                       width: 32,
// //                       height: 32,
// //                       padding: const EdgeInsets.all(6),
// //                       decoration: BoxDecoration(
// //                         color: const Color(0xFF3497F9),
// //                         borderRadius: BorderRadius.circular(8),
// //                       ),
// //                       child: Icon(iconData, size: 18, color: Colors.white),
// //                     ),
// //                   ),
// //                   const SizedBox(width: 12),
// //                   // Date Badge
// //                   Text(
// //                     dueDate,
// //                     style: AppFont.dropDowmLabel(context)?.copyWith(
// //                       fontSize: 14,
// //                       fontWeight: FontWeight.w600,
// //                       color: const Color(0xFF3497F9),
// //                     ),
// //                   ),
// //                   const SizedBox(width: 12),
// //                   // Action Text
// //                   Expanded(
// //                     child: Text(
// //                       subject,
// //                       style: AppFont.dropDowmLabel(context)?.copyWith(
// //                         fontWeight: FontWeight.w600,
// //                         fontSize: 12.5,
// //                         color: const Color(0xFF3497F9),
// //                       ),
// //                       overflow: TextOverflow.ellipsis,
// //                     ),
// //                   ),
// //                 // Inside task's Column (after remarks container)
// // Padding(
// //   padding: const EdgeInsets.only(bottom: 20),
// //   child: Align(
// //     alignment: Alignment.centerRight,
// //     child: ElevatedButton.icon(
// //       onPressed: () =>
// //         _getActionFromSubjectEdit
// //       ,
// //       icon: const Icon(Icons.edit, size: 16),
// //       label: const Text("Edit Follow-up"),
// //       style: ElevatedButton.styleFrom(
// //         backgroundColor: Colors.blueGrey,
// //         foregroundColor: Colors.white,
// //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //         textStyle: GoogleFonts.poppins(fontSize: 12),
// //       ),
// //     ),
// //   ),
// // ),
// //  ],
// //                 // ],
// //               ),
// //               const SizedBox(height: 10),

// //               // Card with only Remarks
// //               Container(
// //                 width: double.infinity,
// //                 decoration: BoxDecoration(
// //                   color: const Color(0xffE7F2FF),
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //                 padding: const EdgeInsets.all(14),
// //                 margin: const EdgeInsets.only(top: 4, bottom: 20),
// //                 child: IntrinsicHeight(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     mainAxisSize: MainAxisSize.min,
// //                     children: [
// //                       Text(
// //                         'Remarks:',
// //                         style: AppFont.dropDowmLabel(
// //                           context,
// //                         )?.copyWith(color: Colors.black),
// //                       ),
// //                       const SizedBox(height: 4),
// //                       Text(
// //                         remarks.isNotEmpty ? remarks : 'No remarks',
// //                         style: AppFont.smallText12(context)?.copyWith(
// //                           color: remarks.isNotEmpty
// //                               ? Colors.black
// //                               : Colors.grey[600],
// //                           height: 1.4,
// //                         ),
// //                         maxLines: (!showSeeMore || isExpanded) ? null : 2,
// //                         overflow: (!showSeeMore || isExpanded)
// //                             ? TextOverflow.visible
// //                             : TextOverflow.ellipsis,
// //                       ),
// //                       if (showSeeMore) ...[
// //                         const SizedBox(height: 8),
// //                         GestureDetector(
// //                           onTap: () {
// //                             setState(() {
// //                               if (isExpanded) {
// //                                 expandedTaskIndexes.remove(index);
// //                               } else {
// //                                 expandedTaskIndexes.add(index);
// //                               }
// //                             });
// //                           },
// //                           child: Text(
// //                             isExpanded ? 'See less' : 'See more',
// //                             style: GoogleFonts.poppins(
// //                               color: Colors.black,
// //                               fontWeight: FontWeight.w500,
// //                               fontSize: 12,
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           );
// //         }),

// //         // EVENTS
// //         ...List.generate(reversedUpcomingEvents.length, (index) {
// //           final event = reversedUpcomingEvents[index];
// //           String eventId = event['event_id'] ?? 'No ID';
// //           String taskId = event['event_id'] ?? 'No ID';
// //           String leadId = event['lead_id'] ?? 'No ID';
// //           String gmail = event['lead_email'] ?? '';
// //           String remarks = event['remarks'] ?? '';
// //           String mobile = event['mobile'] ?? '';
// //           String eventDate = _formatDate(event['start_date'] ?? 'N/A');
// //           String eventSubject = event['subject'] ?? 'No Subject';

// //           bool isExpanded = expandedEventIndexes.contains(index);
// //           bool showSeeMore = _shouldShowSeeMore(remarks);

// //           // Get icon from old code logic
// //           IconData iconData = _getIconFromSubject(eventSubject);

// //           return Container(
// //             margin: const EdgeInsets.only(bottom: 20),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 // Date & Action Row WITH ICON AND ROUTING
// //                 Row(
// //                   crossAxisAlignment: CrossAxisAlignment.center,
// //                   children: [
// //                     // Clickable Icon with routing functionality
// //                     GestureDetector(
// //                       onTap: () {
// //                         _handleIconPress(
// //                           eventSubject,
// //                           mobile,
// //                           eventId,
// //                           gmail,
// //                           leadId,
// //                           context,
// //                         );
// //                       },
// //                       child: Container(
// //                         width: 32,
// //                         height: 32,
// //                         padding: const EdgeInsets.all(6),
// //                         decoration: BoxDecoration(
// //                           color: const Color(0xFF3497F9),
// //                           borderRadius: BorderRadius.circular(8),
// //                         ),
// //                         child: Icon(iconData, size: 18, color: Colors.white),
// //                       ),
// //                     ),
// //                     const SizedBox(width: 12),
// //                     // Date Badge
// //                     Text(
// //                       eventDate,
// //                       style: AppFont.dropDowmLabel(context)?.copyWith(
// //                         fontSize: 14,
// //                         fontWeight: FontWeight.w600,
// //                         color: const Color(0xFF3497F9),
// //                       ),
// //                     ),
// //                     const SizedBox(width: 12),
// //                     // Action Text
// //                     Expanded(
// //                       child: Text(
// //                         eventSubject,
// //                         style: AppFont.dropDowmLabel(context)?.copyWith(
// //                           fontWeight: FontWeight.w600,
// //                           fontSize: 14,
// //                           color: const Color(0xFF3497F9),
// //                         ),
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //                 const SizedBox(height: 10),

// //                 // Card with only Remarks
// //                 Container(
// //                   width: double.infinity,
// //                   decoration: BoxDecoration(
// //                     color: const Color(0xffE7F2FF),
// //                     borderRadius: BorderRadius.circular(12),
// //                   ),
// //                   padding: const EdgeInsets.all(14),
// //                   margin: const EdgeInsets.only(top: 4),
// //                   child: IntrinsicHeight(
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       mainAxisSize: MainAxisSize.min,
// //                       children: [
// //                         Text(
// //                           'Remarks:',
// //                           style: AppFont.dropDowmLabel(
// //                             context,
// //                           )?.copyWith(color: Colors.black),
// //                         ),
// //                         const SizedBox(height: 4),
// //                         Text(
// //                           remarks.isNotEmpty ? remarks : 'No remarks available',
// //                           style: AppFont.smallText12(context)?.copyWith(
// //                             color: remarks.isNotEmpty
// //                                 ? Colors.black
// //                                 : Colors.grey[600],
// //                             height: 1.4,
// //                           ),
// //                           maxLines: (!showSeeMore || isExpanded) ? null : 2,
// //                           overflow: (!showSeeMore || isExpanded)
// //                               ? TextOverflow.visible
// //                               : TextOverflow.ellipsis,
// //                         ),
// //                         if (showSeeMore) ...[
// //                           const SizedBox(height: 8),
// //                           GestureDetector(
// //                             onTap: () {
// //                               setState(() {
// //                                 if (isExpanded) {
// //                                   expandedEventIndexes.remove(index);
// //                                 } else {
// //                                   expandedEventIndexes.add(index);
// //                                 }
// //                               });
// //                             },
// //                             child: Text(
// //                               isExpanded ? 'See less' : 'See more',
// //                               style: GoogleFonts.poppins(
// //                                 color: Colors.black,
// //                                 fontWeight: FontWeight.w500,
// //                                 fontSize: 12,
// //                               ),
// //                             ),
// //                           ),
// //                         ],// Inside task's Column (after remarks container)
// // Padding(
// //   padding: const EdgeInsets.only(bottom: 20),
// //   child: Align(
// //     alignment: Alignment.centerRight,
// //     child: ElevatedButton.icon(
// //          onPressed: () =>
// //         _getActionFromSubjectEdit
// //       ,
// //       icon: const Icon(Icons.edit, size: 16),
// //       label: const Text("Edit Follow-up"),
// //       style: ElevatedButton.styleFrom(
// //         backgroundColor: Colors.blueGrey,
// //         foregroundColor: Colors.white,
// //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //         textStyle: GoogleFonts.poppins(fontSize: 12),
// //       ),
// //     ),
// //   ),
// // ),

// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           );
// //         }),

// //         const SizedBox(height: 10),
// //       ],
// //     );
// //   }
// // }



// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/services/api_srv.dart';
// import 'package:smartassist/widgets/testdrive_verifyotp.dart';
// import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/followups.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';

// class TimelineUpcoming extends StatefulWidget {
//   final bool isFromTeams;
//   final carIcon = '/assets/caricon.png';
//   final List<Map<String, dynamic>> tasks;
//   final List<Map<String, dynamic>> upcomingEvents;
//   const TimelineUpcoming({
//     super.key,
//     required this.tasks,
//     required this.upcomingEvents,
//     required this.isFromTeams,
//   });

//   @override
//   State<TimelineUpcoming> createState() => _TimelineUpcomingState();
// }

// class _TimelineUpcomingState extends State<TimelineUpcoming> {
//   final Set<int> expandedTaskIndexes = {};
//   final Set<int> expandedEventIndexes = {};

//   String _formatDate(String date) {
//     try {
//       final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
//       return DateFormat("d MMM").format(parsedDate);
//     } catch (e) {
//       return 'N/A';
//     }
//   }

//   // Icon logic from old code
//   IconData _getIconFromSubject(String subject) {
//     if (subject == 'Provide Quotation') {
//       return Icons.receipt_long;
//     } else if (subject == 'Send SMS') {
//       return Icons.message_rounded;
//     } else if (subject == 'Call') {
//       return Icons.phone;
//     } else if (subject == 'Send Email') {
//       return Icons.mail;
//     } else if (subject == 'Showroom appointment') {
//       return Icons.person_2_outlined;
//     } else if (subject == 'Trade in evaluation') {
//       return Icons.handshake;
//     } else if (subject == 'Test Drive') {
//       return Icons.directions_car;
//     } else if (subject == 'Quotation') {
//       return FontAwesomeIcons.solidCalendar;
//     } else {
//       return Icons.info_outline; // default fallback icon
//     }
//   }

//   // Route handling logic from old code - SNACKBAR REMOVED
//   void _handleIconPress(
//     String subject,
//     String mobile,
//     String eventId,
//     String gmail,
//     String leadId,
//     BuildContext context,
//   ) {
//     if (widget.isFromTeams) return; // Don't handle actions if from teams

//     if (subject == 'Call') {
//       launchUrl(Uri.parse('tel:$mobile'));
//     } else if (subject == 'Send SMS') {
//       launchUrl(Uri.parse('sms:$mobile'));
//     } else if (subject == 'Test Drive') {
//       _showAleart(eventId, gmail, leadId, mobile, context);
//     }
//     // Removed the else clause that showed the snackbar
//   }

//   Future<void> _showAleart(
//     String eventId,
//     String gmail,
//     String leadId,
//     String mobile,
//     BuildContext context,
//   ) async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           title: Text(
//             'Ready to start test drive?',
//             style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
//           ),
//           content: Text(
//             'Please make sure you have all the necessary documents(license) and permissions(OTP) ready before starting test drive.',
//             style: GoogleFonts.poppins(),
//           ),
//           actions: [
//             TextButton(
//               style: TextButton.styleFrom(
//                 overlayColor: Colors.grey.withOpacity(0.1),
//                 foregroundColor: Colors.grey,
//               ),
//               onPressed: () => Navigator.of(context).pop(false),
//               child: Text('No', style: GoogleFonts.poppins(color: Colors.grey)),
//             ),
//             TextButton(
//               style: TextButton.styleFrom(
//                 overlayColor: AppColors.colorsBlue.withOpacity(0.1),
//                 foregroundColor: AppColors.colorsBlue,
//               ),
//               onPressed: () {
//                 _getOtp(eventId);
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => TestdriveVerifyotp(
//                       email: gmail,
//                       eventId: eventId,
//                       leadId: leadId,
//                       mobile: mobile,
//                     ),
//                   ),
//                 );
//               },
//               child: Text(
//                 'Yes',
//                 style: GoogleFonts.poppins(color: AppColors.colorsBlue),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _getOtp(String eventId) async {
//     final success = await LeadsSrv.getOtp(eventId: eventId);
//     if (success) {
//       print('✅ Test drive started successfully');
//     } else {
//       print('❌ Failed to start test drive');
//     }
//   }

//   // Updated method to check if text needs "See more" based on line count
//   bool _shouldShowSeeMore(String text) {
//     // Rough estimation: ~40-50 characters per line on average mobile screen
//     // For 2 lines, that's approximately 80-100 characters
//     return text.length > 100;
//   }

//   bool _isTestDrive(String subject) {
//     return subject.toLowerCase().contains('test drive');
//   }

//   @override
//   Widget build(BuildContext context) {
//     final reversedTasks = widget.tasks.reversed.toList();
//     final reversedUpcomingEvents = widget.upcomingEvents.reversed.toList();

//     if (reversedTasks.isEmpty && reversedUpcomingEvents.isEmpty) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 20),
//           child: Text(
//             "No upcoming task available",
//             style: AppFont.smallText12(context),
//           ),
//         ),
//       );
//     }

//     return Column(
//       children: [
//         // TASKS
//         ...List.generate(reversedTasks.length, (index) {
//           final task = reversedTasks[index];
//           String remarks = task['remarks'] ?? '';
//           String mobile = task['mobile'] ?? '';
//           String dueDate = _formatDate(task['due_date'] ?? 'N/A');
//           String subject = task['subject'] ?? 'No Subject';

//           bool isExpanded = expandedTaskIndexes.contains(index);
//           bool showSeeMore = _shouldShowSeeMore(remarks);

//           // Get icon from old code logic
//           IconData iconData = _getIconFromSubject(subject);

//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Date & Action Row WITH ICON AND ROUTING
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // Clickable Icon with routing functionality
//                   GestureDetector(
//                     onTap: () {
//                       _handleIconPress(subject, mobile, '', '', '', context);
//                     },
//                     child: Container(
//                       width: 32,
//                       height: 32,
//                       padding: const EdgeInsets.all(6),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF3497F9),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Icon(iconData, size: 18, color: Colors.white),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   // Date Badge
//                   Text(
//                     dueDate,
//                     style: AppFont.dropDowmLabel(context)?.copyWith(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w600,
//                       color: const Color(0xFF3497F9),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   // Action Text
//                   Expanded(
//                     child: Text(
//                       subject,
//                       style: AppFont.dropDowmLabel(context)?.copyWith(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 12.5,
//                         color: const Color(0xFF3497F9),
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),

//               // Card with only Remarks
//               Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: const Color(0xffE7F2FF),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 padding: const EdgeInsets.all(14),
//                 margin: const EdgeInsets.only(top: 4, bottom: 20),
//                 child: IntrinsicHeight(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         'Remarks:',
//                         style: AppFont.dropDowmLabel(
//                           context,
//                         )?.copyWith(color: Colors.black),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         remarks.isNotEmpty ? remarks : 'No remarks',
//                         style: AppFont.smallText12(context)?.copyWith(
//                           color: remarks.isNotEmpty
//                               ? Colors.black
//                               : Colors.grey[600],
//                           height: 1.4,
//                         ),
//                         maxLines: (!showSeeMore || isExpanded) ? null : 2,
//                         overflow: (!showSeeMore || isExpanded)
//                             ? TextOverflow.visible
//                             : TextOverflow.ellipsis,
//                       ),
//                       if (showSeeMore) ...[
//                         const SizedBox(height: 8),
//                         GestureDetector(
//                           onTap: () {
//                             setState(() {
//                               if (isExpanded) {
//                                 expandedTaskIndexes.remove(index);
//                               } else {
//                                 expandedTaskIndexes.add(index);
//                               }
//                             });
//                           },
//                           child: Text(
//                             isExpanded ? 'See less' : 'See more',
//                             style: GoogleFonts.poppins(
//                               color: Colors.black,
//                               fontWeight: FontWeight.w500,
//                               fontSize: 12,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           );
//         }),

//         // EVENTS
//         ...List.generate(reversedUpcomingEvents.length, (index) {
//           final event = reversedUpcomingEvents[index];
//           String eventId = event['event_id'] ?? 'No ID';
//           String leadId = event['lead_id'] ?? 'No ID';
//           String gmail = event['lead_email'] ?? '';
//           String remarks = event['remarks'] ?? '';
//           String mobile = event['mobile'] ?? '';
//           String eventDate = _formatDate(event['start_date'] ?? 'N/A');
//           String eventSubject = event['subject'] ?? 'No Subject';

//           bool isExpanded = expandedEventIndexes.contains(index);
//           bool showSeeMore = _shouldShowSeeMore(remarks);

//           // Get icon from old code logic
//           IconData iconData = _getIconFromSubject(eventSubject);

//           return Container(
//             margin: const EdgeInsets.only(bottom: 20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Date & Action Row WITH ICON AND ROUTING
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     // Clickable Icon with routing functionality
//                     GestureDetector(
//                       onTap: () {
//                         _handleIconPress(
//                           eventSubject,
//                           mobile,
//                           eventId,
//                           gmail,
//                           leadId,
//                           context,
//                         );
//                       },
//                       child: Container(
//                         width: 32,
//                         height: 32,
//                         padding: const EdgeInsets.all(6),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF3497F9),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Icon(iconData, size: 18, color: Colors.white),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     // Date Badge
//                     Text(
//                       eventDate,
//                       style: AppFont.dropDowmLabel(context)?.copyWith(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: const Color(0xFF3497F9),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     // Action Text
//                     Expanded(
//                       child: Text(
//                         eventSubject,
//                         style: AppFont.dropDowmLabel(context)?.copyWith(
//                           fontWeight: FontWeight.w600,
//                           fontSize: 14,
//                           color: const Color(0xFF3497F9),
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),

//                 // Card with only Remarks
//                 Container(
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: const Color(0xffE7F2FF),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.all(14),
//                   margin: const EdgeInsets.only(top: 4),
//                   child: IntrinsicHeight(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           'Remarks:',
//                           style: AppFont.dropDowmLabel(
//                             context,
//                           )?.copyWith(color: Colors.black),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           remarks.isNotEmpty ? remarks : 'No remarks available',
//                           style: AppFont.smallText12(context)?.copyWith(
//                             color: remarks.isNotEmpty
//                                 ? Colors.black
//                                 : Colors.grey[600],
//                             height: 1.4,
//                           ),
//                           maxLines: (!showSeeMore || isExpanded) ? null : 2,
//                           overflow: (!showSeeMore || isExpanded)
//                               ? TextOverflow.visible
//                               : TextOverflow.ellipsis,
//                         ),
//                         if (showSeeMore) ...[
//                           const SizedBox(height: 8),
//                           GestureDetector(
//                             onTap: () {
//                               setState(() {
//                                 if (isExpanded) {
//                                   expandedEventIndexes.remove(index);
//                                 } else {
//                                   expandedEventIndexes.add(index);
//                                 }
//                               });
//                             },
//                             child: Text(
//                               isExpanded ? 'See less' : 'See more',
//                               style: GoogleFonts.poppins(
//                                 color: Colors.black,
//                                 fontWeight: FontWeight.w500,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }),

//         const SizedBox(height: 10),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/testdrive_verifyotp.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/followups.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/testdrive.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/appointments.dart';

class TimelineUpcoming extends StatefulWidget {
  final bool isFromTeams;
  final carIcon = '/assets/caricon.png';
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> upcomingEvents;

  const TimelineUpcoming({
    super.key,
    required this.tasks,
    required this.upcomingEvents,
    required this.isFromTeams,
  });

  @override
  State<TimelineUpcoming> createState() => _TimelineUpcomingState();
}

class _TimelineUpcomingState extends State<TimelineUpcoming> {
  final Set<int> expandedTaskIndexes = {};
  final Set<int> expandedEventIndexes = {};

  String _formatDate(String date) {
    try {
      final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
      return DateFormat("d MMM").format(parsedDate);
    } catch (e) {
      return 'N/A';
    }
  }

  IconData _getIconFromSubject(String subject) {
    switch (subject.trim().toLowerCase()) {
      case 'provide quotation':
        return Icons.receipt_long;
      case 'send sms':
        return Icons.message_rounded;
      case 'call':
        return Icons.phone;
      case 'send email':
        return Icons.mail;
      case 'showroom appointment':
        return Icons.person_2_outlined;
      case 'trade in evaluation':
        return Icons.handshake;
      case 'test drive':
        return Icons.directions_car;
      case 'quotation':
        return FontAwesomeIcons.solidCalendar;
      case 'meeting':
        return Icons.groups;
      case 'vehicle selection':
        return Icons.directions_car_filled;
      default:
        return Icons.info_outline;
    }
  }

  void _handleIconPress(
    String subject,
    String mobile,
    String eventId,
    String gmail,
    String leadId,
    BuildContext context,
  ) {
    if (widget.isFromTeams) return;
    final lower = subject.trim().toLowerCase();
    if (lower == 'call') {
      launchUrl(Uri.parse('tel:$mobile'));
    } else if (lower == 'send sms') {
      launchUrl(Uri.parse('sms:$mobile'));
    } else if (lower == 'test drive') {
      _showAleart(eventId, gmail, leadId, mobile, context);
    }
  }

  // ======== UPDATED LOGIC: show AppointmentsEdit for meeting, vehicle selection, showroom appointment, trade in evaluation ========
  // void _handleEditPress(String taskId, String subject) {
  //   final lower = subject.trim().toLowerCase();
  //   final shouldShowAppointmentEdit = lower == "meeting" ||
  //       lower == "vehicle selection" ||
  //       lower == "showroom appointment" ||
  //       lower == "trade in evaluation";
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => Dialog(
  //       insetPadding: const EdgeInsets.all(16),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       backgroundColor: Colors.white,
  //       child: shouldShowAppointmentEdit
  //             ?  AppointmentsEdit(
  //     taskId: taskId,
  //     onFormSubmit: () {
  //       Navigator.pop(context);
  //       setState(() {
  //         print('this is the taskid $taskId');
  //       });
  //     },
  //   )
  //           : FollowupsEdit(
  //               taskId: taskId,
  //               onFormSubmit: () {
  //                 Navigator.pop(context);
  //                 setState(() {});
  //               },
  //             ),
  //     ),
  //   );
  // }

void _handleFollowupsEdit(String taskId) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: FollowupsEdit(
        taskId: taskId,
        onFormSubmit: () {
          Navigator.pop(context);
          setState(() {});
        },
      ),
    ),
  );
}

void handleAppointmentsEdit(String taskId) {
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: AppointmentsEdit(
          onFormSubmit: () {
            Navigator.pop(context);
            setState(() {
              print('this is the taskid $taskId');
            });
          },
          taskId: taskId,
        ),
      );
    },
  );
}
 void _handleTestDriveEdit(String eventId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        child: Testdrive(
          eventId: eventId,
          onFormSubmit: () {
            Navigator.pop(context);
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _showAleart(
    String eventId,
    String gmail,
    String leadId,
    String mobile,
    BuildContext context,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.white,
          title: Text(
            'Ready to start test drive?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Please make sure you have all the necessary documents(license) and permissions(OTP) ready before starting test drive.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                _getOtp(eventId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TestdriveVerifyotp(
                      email: gmail,
                      eventId: eventId,
                      leadId: leadId,
                      mobile: mobile,
                    ),
                  ),
                );
              },
              child: Text('Yes', style: GoogleFonts.poppins(color: AppColors.colorsBlue)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getOtp(String eventId) async {
    final success = await LeadsSrv.getOtp(eventId: eventId);
    print(success ? '✅ Test drive started successfully' : '❌ Failed to start test drive');
  }

  bool _shouldShowSeeMore(String text) => text.length > 100;

  @override
  Widget build(BuildContext context) {
    final reversedTasks = widget.tasks.reversed.toList();
    final reversedUpcomingEvents = widget.upcomingEvents.reversed.toList();

    if (reversedTasks.isEmpty && reversedUpcomingEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "No upcoming task available",
            style: AppFont.smallText12(context),
          ),
        ),
      );
    }

    return Column(
      children: [
        // TASKS
        ...List.generate(reversedTasks.length, (index) {
          final task = reversedTasks[index];
          final remarks = task['remarks'] ?? '';
          final mobile = task['mobile'] ?? '';
          final dueDate = _formatDate(task['due_date'] ?? 'N/A');
          final subject = (task['subject'] ?? 'No Subject').toString();
          final taskId = task['task_id'];

          final isExpanded = expandedTaskIndexes.contains(index);
          final showSeeMore = _shouldShowSeeMore(remarks);
          final iconData = _getIconFromSubject(subject);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _handleIconPress(subject, mobile, '', '', '', context),
                    child: Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3497F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconData, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dueDate,
                    style: AppFont.dropDowmLabel(context)?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3497F9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: AppFont.dropDowmLabel(context)?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: const Color(0xFF3497F9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      IconButton(
  icon: Icon(Icons.edit, size: 18, color: Colors.black),
  onPressed: () {
    final lower = subject.trim().toLowerCase();

    // These subjects open FollowupsEdit
    if (lower == 'provide quotation' ||
        lower == 'send sms' ||
        lower == 'call' ||
        lower == 'send email' ||
        lower == 'showroom appointment' ||
        lower == 'trade in evaluation') {
      _handleFollowupsEdit(taskId);
    } 
    // These subjects open AppointmentsEdit
    else if (lower == 'quotation' ||
        lower == 'meeting' ||
        lower == 'vehicle selection') {
      handleAppointmentsEdit(taskId);
    }
    // Otherwise, fallback to followup (optional)
    else {
      _handleFollowupsEdit(taskId);
    }
  },
  tooltip: 'Edit Remarks',
  splashRadius: 18,
  padding: EdgeInsets.zero,
  constraints: BoxConstraints(),
),

                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xffE7F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(top: 4, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remarks:',
                        style: AppFont.dropDowmLabel(context)?.copyWith(color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(
                      remarks.isNotEmpty ? remarks : 'No remarks',
                      style: AppFont.smallText12(context)?.copyWith(
                        color: remarks.isNotEmpty ? Colors.black : Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: (!showSeeMore || isExpanded) ? null : 2,
                      overflow: (!showSeeMore || isExpanded)
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (showSeeMore)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isExpanded
                                ? expandedTaskIndexes.remove(index)
                                : expandedTaskIndexes.add(index);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isExpanded ? 'See less' : 'See more',
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }),

        // EVENTS
        ...List.generate(reversedUpcomingEvents.length, (index) {
          final event = reversedUpcomingEvents[index];
          final eventId = event['event_id'] ?? '';
          final leadId = event['lead_id'] ?? '';
          final gmail = event['lead_email'] ?? '';
          final remarks = event['remarks'] ?? '';
          final mobile = event['mobile'] ?? '';
          final eventDate = _formatDate(event['start_date'] ?? 'N/A');
          final eventSubject = (event['subject'] ?? 'No Subject').toString();

          final isExpanded = expandedEventIndexes.contains(index);
          final showSeeMore = _shouldShowSeeMore(remarks);
          final iconData = _getIconFromSubject(eventSubject);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _handleIconPress(eventSubject, mobile, eventId, gmail, leadId, context);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3497F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      eventDate,
                      style: AppFont.dropDowmLabel(context)?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3497F9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              eventSubject,
                              style: AppFont.dropDowmLabel(context)?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: const Color(0xFF3497F9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (eventSubject.trim().toLowerCase() == 'test drive')
                            IconButton(
                              icon: Icon(Icons.edit, size: 18, color: Colors.black),
                              onPressed: () => _handleTestDriveEdit(eventId),
                              tooltip: 'Edit Test Drive',
                              splashRadius: 18,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xffE7F2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Remarks:',
                          style: AppFont.dropDowmLabel(context)
                              ?.copyWith(color: Colors.black)),
                      const SizedBox(height: 4),
                      Text(
                        remarks.isNotEmpty ? remarks : 'No remarks',
                        style: AppFont.smallText12(context)?.copyWith(
                          color: remarks.isNotEmpty ? Colors.black : Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: (!showSeeMore || isExpanded) ? null : 2,
                        overflow: (!showSeeMore || isExpanded)
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                      if (showSeeMore)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isExpanded
                                  ? expandedEventIndexes.remove(index)
                                  : expandedEventIndexes.add(index);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              isExpanded ? 'See less' : 'See more',
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 10),
      ],
    );
  }
}
