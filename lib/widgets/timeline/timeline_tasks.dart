// // // import 'package:flutter/material.dart';
// // // import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// // // import 'package:google_fonts/google_fonts.dart';  
// // // import 'package:smartassist/config/component/font/font.dart';
// // // import 'package:smartassist/services/api_srv.dart';
// // // import 'package:smartassist/widgets/testdrive_verifyotp.dart';
// // // import 'package:timeline_tile/timeline_tile.dart';
// // // import 'package:intl/intl.dart';
// // // import 'package:url_launcher/url_launcher.dart';

// // // class TimelineUpcoming extends StatelessWidget {
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

// // //   String _formatDate(String date) {
// // //     try {
// // //       final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
// // //       return DateFormat("d MMM").format(parsedDate); // Outputs "22 May"
// // //     } catch (e) {
// // //       print('Error formatting date: $e');
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
// // //       barrierDismissible: false, // User must tap button to close dialog
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
// // //                 overlayColor: Colors.blue.withOpacity(0.1),
// // //                 foregroundColor: Colors.blue,
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
// // //                 style: GoogleFonts.poppins(color: Colors.blue),
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

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     // Reverse the tasks list to show from bottom to top
// // //     final reversedTasks = tasks.reversed.toList();

// // //     // Reverse the upcomingEvents list to show from bottom to top
// // //     final reversedUpcomingEvents = upcomingEvents.reversed.toList();

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
// // //         // Loop through tasks and display them
// // //         ...List.generate(reversedTasks.length, (index) {
// // //           final task = reversedTasks[index];
// // //           String remarks = task['remarks'] ?? 'No remarks';
// // //           String mobile = task['mobile'] ?? 'No Subject';
// // //           String dueDate = _formatDate(task['due_date'] ?? 'N/A');
// // //           String subject = task['subject'] ?? 'No Subject';
// // //           // String comment = task['remarks'] ?? 'No Remarks';

// // //           IconData icon;

// // //           if (subject == 'Provide Quotation') {
// // //             icon = Icons.receipt_long;
// // //           } else if (subject == 'Send SMS') {
// // //             icon = Icons.message_rounded;
// // //           } else if (subject == 'Call') {
// // //             icon = Icons.phone;
// // //           } else if (subject == 'Send Email') {
// // //             icon = Icons.mail;
// // //           } else if (subject == 'Showroom appointment') {
// // //             icon = Icons.person_2_outlined;
// // //           } else if (subject == 'Trade in evaluation') {
// // //             icon = Icons.handshake;
// // //           } else if (subject == 'Test Drive') {
// // //             icon = carIcon as IconData;
// // //           } else {
// // //             icon = Icons.phone; // default fallback icon
// // //           }

// // //           return TimelineTile(
// // //             alignment: TimelineAlign.manual,
// // //             lineXY: 0.25,
// // //             isFirst: index == (reversedTasks.length - 1),
// // //             isLast: index == 0,
// // //             beforeLineStyle: const LineStyle(color: Colors.transparent),
// // //             afterLineStyle: const LineStyle(color: Colors.transparent),

// // //             indicatorStyle: IndicatorStyle(
// // //               width: 30,
// // //               height: 30,
// // //               padding: const EdgeInsets.only(left: 5),
// // //               drawGap: true,
// // //               indicator: Container(
// // //                 decoration: const BoxDecoration(
// // //                   color: Colors.blueAccent,
// // //                   shape: BoxShape.circle,
// // //                 ),
// // //                 child: IconButton(
// // //                   style: const ButtonStyle(
// // //                     // padding:
// // //                     minimumSize: WidgetStatePropertyAll(Size.zero),
// // //                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
// // //                     padding: WidgetStatePropertyAll(EdgeInsets.zero),
// // //                   ),
// // //                   icon: Icon(size: 20, icon, color: Colors.white),
// // //                   onPressed: isFromTeams
// // //                       ? null
// // //                       : () {
// // //                           if (subject == 'Call') {
// // //                             // Example: Launch phone dialer (you'll need url_launcher package)
// // //                             launchUrl(Uri.parse('tel:$mobile'));
// // //                           } else if (subject == 'Send SMS') {
// // //                             // Example: Open SMS
// // //                             launchUrl(Uri.parse('sms:$mobile'));
// // //                           } else {
// // //                             // fallback action
// // //                             ScaffoldMessenger.of(context).showSnackBar(
// // //                               const SnackBar(
// // //                                 content: Text(
// // //                                   'No action defined for this subject',
// // //                                 ),
// // //                               ),
// // //                             );
// // //                           }
// // //                         },
// // //                 ),
// // //               ),
// // //             ),
// // //             startChild: Text(
// // //               dueDate, // Show the due date
// // //               style: AppFont.dropDowmLabel(context),
// // //             ),
// // //             endChild: Padding(
// // //               padding: const EdgeInsets.only(left: 10.0),
// // //               child: Column(
// // //                 children: [
// // //                   const SizedBox(height: 10),
// // //                   Container(
// // //                     width: double.infinity,
// // //                     decoration: BoxDecoration(
// // //                       color: const Color(0xffE7F2FF),
// // //                       borderRadius: BorderRadius.circular(10),
// // //                     ),
// // //                     padding: const EdgeInsets.fromLTRB(10.0, 10, 0, 10),
// // //                     child: RichText(
// // //                       text: TextSpan(
// // //                         children: [
// // //                           TextSpan(
// // //                             text: 'Action : ',
// // //                             style: AppFont.dropDowmLabel(context),
// // //                           ),
// // //                           TextSpan(
// // //                             text: '$subject\n',
// // //                             style: AppFont.smallText12(context),
// // //                           ),
// // //                           TextSpan(
// // //                             text: 'Remarks : ',
// // //                             style: AppFont.dropDowmLabel(context),
// // //                           ),
// // //                           TextSpan(
// // //                             text: remarks,
// // //                             style: AppFont.smallText12(context),
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //           );
// // //         }),

// // //         // event

// // //         // Loop through upcomingEvents and display them
// // //         ...List.generate(reversedUpcomingEvents.length, (index) {
// // //           final event = reversedUpcomingEvents[index];
// // //           String eventId = event['event_id'] ?? 'No ID';
// // //           String leadId = event['lead_id'] ?? 'No ID';
// // //           String gmail = event['lead_email'] ?? 'No email ID';
// // //           String remarks = event['remarks'] ?? 'No Remarks';
// // //           String mobile = event['mobile'] ?? 'No Number';
// // //           String eventDate = _formatDate(event['start_date'] ?? 'N/A');
// // //           String eventSubject = event['subject'] ?? 'No Subject';

// // //           IconData icon;

// // //           if (eventSubject == 'Test Drive') {
// // //             icon = Icons.directions_car;
// // //           } else if (eventSubject == 'Showroom appointment') {
// // //             icon = FontAwesomeIcons.solidCalendar;
// // //           } else if (eventSubject == 'Quotation') {
// // //             icon = FontAwesomeIcons.solidCalendar;
// // //           } else if (eventSubject == 'Showroom appointment') {
// // //             icon = FontAwesomeIcons.solidCalendar;
// // //           } else {
// // //             icon = Icons.phone;
// // //           }

// // //           return TimelineTile(
// // //             alignment: TimelineAlign.manual,
// // //             lineXY: 0.25,
// // //             isFirst: index == (reversedUpcomingEvents.length - 1),
// // //             isLast: index == 0,
// // //             beforeLineStyle: const LineStyle(color: Colors.transparent),
// // //             afterLineStyle: const LineStyle(color: Colors.transparent),
// // //             indicatorStyle: IndicatorStyle(
// // //               width: 30,
// // //               height: 30,
// // //               padding: const EdgeInsets.only(left: 5),
// // //               drawGap: true,
// // //               indicator: Container(
// // //                 decoration: const BoxDecoration(
// // //                   color: Colors.blueAccent,
// // //                   shape: BoxShape.circle,
// // //                 ),
// // //                 child: IconButton(
// // //                   style: const ButtonStyle(
// // //                     // padding:
// // //                     minimumSize: WidgetStatePropertyAll(Size.zero),
// // //                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
// // //                     padding: WidgetStatePropertyAll(EdgeInsets.zero),
// // //                   ),
// // //                   icon: Icon(size: 20, icon, color: Colors.white),
// // //                   onPressed: isFromTeams
// // //                       ? null
// // //                       : () {
// // //                           if (eventSubject == 'Call') {
// // //                             // if (isFromTeams) return;
// // //                             // Example: Launch phone dialer (you'll need url_launcher package)
// // //                             launchUrl(Uri.parse('tel:$mobile'));
// // //                           } else if (eventSubject == 'Send SMS') {
// // //                             // Example: Open SMS
// // //                             launchUrl(Uri.parse('sms:$mobile'));
// // //                           } else if (eventSubject == 'Test Drive') {
// // //                             // Example: Open Test Drive UR
// // //                             // _getOtp(eventId);
// // //                             // Navigator.push(
// // //                             //   context,
// // //                             //   MaterialPageRoute(
// // //                             //     builder: (context) => TestdriveVerifyotp(
// // //                             //       email: gmail,
// // //                             //       eventId: eventId,
// // //                             //       leadId: leadId,
// // //                             //       mobile: mobile,
// // //                             //     ),
// // //                             //   ),
// // //                             // );
// // //                             _showAleart(
// // //                               eventId,
// // //                               gmail,
// // //                               leadId,
// // //                               mobile,
// // //                               context,
// // //                             );
// // //                           } else {
// // //                             // fallback action
// // //                             ScaffoldMessenger.of(context).showSnackBar(
// // //                               const SnackBar(
// // //                                 content: Text(
// // //                                   'No action defined for this subject',
// // //                                 ),
// // //                               ),
// // //                             );
// // //                           }
// // //                         },
// // //                 ),
// // //               ),
// // //             ),

// // //             // indicatorStyle: IndicatorStyle(
// // //             //   padding: const EdgeInsets.only(left: 5),
// // //             //   width: 30,
// // //             //   height: 30,
// // //             //   color: AppColors.sideGreen, // Green for upcoming events
// // //             //   iconStyle: IconStyle(
// // //             //     iconData: Icons.event_available,
// // //             //     color: Colors.white,
// // //             //   ),
// // //             // ),
// // //             startChild: Text(
// // //               eventDate, // Show the event date
// // //               style: AppFont.dropDowmLabel(context),
// // //             ),
// // //             endChild: Padding(
// // //               padding: const EdgeInsets.symmetric(horizontal: 10.0),
// // //               child: Column(
// // //                 children: [
// // //                   const SizedBox(height: 10),
// // //                   Container(
// // //                     width: double.infinity,
// // //                     decoration: BoxDecoration(
// // //                       color: const Color(0xffE7F2FF),
// // //                       borderRadius: BorderRadius.circular(10),
// // //                     ),
// // //                     padding: const EdgeInsets.fromLTRB(10.0, 10, 0, 10),
// // //                     child: RichText(
// // //                       text: TextSpan(
// // //                         children: [
// // //                           TextSpan(
// // //                             text: 'Action : ',
// // //                             style: AppFont.dropDowmLabel(context),
// // //                           ),
// // //                           TextSpan(
// // //                             text: '$eventSubject\n',
// // //                             style: AppFont.smallText12(context),
// // //                           ),
// // //                           TextSpan(
// // //                             text: 'Remarks : ',
// // //                             style: AppFont.dropDowmLabel(context),
// // //                           ),
// // //                           TextSpan(
// // //                             text: remarks,
// // //                             style: AppFont.smallText12(context),
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //           );
// // //         }),
// // //         const SizedBox(height: 10),
// // //       ],
// // //     );
// // //   }
// // // }


// // import 'package:flutter/material.dart';
// // import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// // import 'package:google_fonts/google_fonts.dart';  
// // import 'package:smartassist/config/component/font/font.dart';
// // import 'package:smartassist/services/api_srv.dart';
// // import 'package:smartassist/widgets/testdrive_verifyotp.dart';
// // import 'package:timeline_tile/timeline_tile.dart';
// // import 'package:intl/intl.dart';
// // import 'package:url_launcher/url_launcher.dart';

// // class TimelineUpcoming extends StatelessWidget {
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

// //   String _formatDate(String date) {
// //     try {
// //       final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
// //       return DateFormat("d MMM").format(parsedDate); // Outputs "22 May"
// //     } catch (e) {
// //       print('Error formatting date: $e');
// //       return 'N/A';
// //     }
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
// //       barrierDismissible: false, // User must tap button to close dialog
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
// //                 overlayColor: Colors.blue.withOpacity(0.1),
// //                 foregroundColor: Colors.blue,
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
// //                 style: GoogleFonts.poppins(color: Colors.blue),
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

// //   @override
// //   Widget build(BuildContext context) {
// //     // Reverse the tasks list to show from bottom to top
// //     final reversedTasks = tasks.reversed.toList();

// //     // Reverse the upcomingEvents list to show from bottom to top
// //     final reversedUpcomingEvents = upcomingEvents.reversed.toList();

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
// //         // Loop through tasks and display them
// //         ...List.generate(reversedTasks.length, (index) {
// //           final task = reversedTasks[index];
// //           String remarks = task['remarks'] ?? 'No remarks';
// //           String mobile = task['mobile'] ?? 'No Subject';
// //           String dueDate = _formatDate(task['due_date'] ?? 'N/A');
// //           String subject = task['subject'] ?? 'No Subject';

// //           IconData icon;

// //           if (subject == 'Provide Quotation') {
// //             icon = Icons.receipt_long;
// //           } else if (subject == 'Send SMS') {
// //             icon = Icons.message_rounded;
// //           } else if (subject == 'Call') {
// //             icon = Icons.phone;
// //           } else if (subject == 'Send Email') {
// //             icon = Icons.mail;
// //           } else if (subject == 'Showroom appointment') {
// //             icon = Icons.person_2_outlined;
// //           } else if (subject == 'Trade in evaluation') {
// //             icon = Icons.handshake;
// //           } else if (subject == 'Test Drive') {
// //             icon = carIcon as IconData;
// //           } else {
// //             icon = Icons.phone; // default fallback icon
// //           }

// //           return Container(
// //             margin: const EdgeInsets.only(bottom: 16),
// //             child: Row(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 // Left side - Timeline indicator
// //                 SizedBox(
// //                   width: 50,
// //                   child: Column(
// //                     children: [
// //                       // Date above the icon
// //                       Container(
// //                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// //                         decoration: BoxDecoration(
// //                           color: Colors.grey.shade100,
// //                           borderRadius: BorderRadius.circular(12),
// //                         ),
// //                         child: Text(
// //                           dueDate,
// //                           style: AppFont.dropDowmLabel(context)?.copyWith(
// //                             fontSize: 10,
// //                             fontWeight: FontWeight.w600,
// //                           ),
// //                           textAlign: TextAlign.center,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 8),
// //                       // Icon circle
// //                       Container(
// //                         width: 40,
// //                         height: 40,
// //                         decoration: const BoxDecoration(
// //                           color: Colors.blueAccent,
// //                           shape: BoxShape.circle,
// //                         ),
// //                         child: IconButton(
// //                           style: const ButtonStyle(
// //                             minimumSize: WidgetStatePropertyAll(Size.zero),
// //                             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
// //                             padding: WidgetStatePropertyAll(EdgeInsets.zero),
// //                           ),
// //                           icon: Icon(size: 20, icon, color: Colors.white),
// //                           onPressed: isFromTeams
// //                               ? null
// //                               : () {
// //                                   if (subject == 'Call') {
// //                                     launchUrl(Uri.parse('tel:$mobile'));
// //                                   } else if (subject == 'Send SMS') {
// //                                     launchUrl(Uri.parse('sms:$mobile'));
// //                                   } else {
// //                                     ScaffoldMessenger.of(context).showSnackBar(
// //                                       const SnackBar(
// //                                         content: Text(
// //                                           'No action defined for this subject',
// //                                         ),
// //                                       ),
// //                                     );
// //                                   }
// //                                 },
// //                         ),
// //                       ),
// //                       // Connecting line (except for last item)
// //                       if (index != reversedTasks.length - 1)
// //                         Container(
// //                           width: 2,
// //                           height: 30,
// //                           color: Colors.grey.shade300,
// //                           margin: const EdgeInsets.only(top: 8),
// //                         ),
// //                     ],
// //                   ),
// //                 ),
// //                 const SizedBox(width: 16),
// //                 // Right side - Content box
// //                 Expanded(
// //                   child: Container(
// //                     width: double.infinity,
// //                     margin: const EdgeInsets.only(top: 32), // Align with icon
// //                     decoration: BoxDecoration(
// //                       color: const Color(0xffE7F2FF),
// //                       borderRadius: BorderRadius.circular(10),
// //                     ),
// //                     padding: const EdgeInsets.all(12),
// //                     child: RichText(
// //                       text: TextSpan(
// //                         children: [
// //                           TextSpan(
// //                             text: 'Action : ',
// //                             style: AppFont.dropDowmLabel(context),
// //                           ),
// //                           TextSpan(
// //                             text: '$subject\n',
// //                             style: AppFont.smallText12(context),
// //                           ),
// //                           TextSpan(
// //                             text: 'Remarks : ',
// //                             style: AppFont.dropDowmLabel(context),
// //                           ),
// //                           TextSpan(
// //                             text: remarks,
// //                             style: AppFont.smallText12(context),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           );
// //         }),

// //         // Loop through upcomingEvents and display them
// //         ...List.generate(reversedUpcomingEvents.length, (index) {
// //           final event = reversedUpcomingEvents[index];
// //           String eventId = event['event_id'] ?? 'No ID';
// //           String leadId = event['lead_id'] ?? 'No ID';
// //           String gmail = event['lead_email'] ?? 'No email ID';
// //           String remarks = event['remarks'] ?? 'No Remarks';
// //           String mobile = event['mobile'] ?? 'No Number';
// //           String eventDate = _formatDate(event['start_date'] ?? 'N/A');
// //           String eventSubject = event['subject'] ?? 'No Subject';

// //           IconData icon;

// //           if (eventSubject == 'Test Drive') {
// //             icon = Icons.directions_car;
// //           } else if (eventSubject == 'Showroom appointment') {
// //             icon = FontAwesomeIcons.solidCalendar;
// //           } else if (eventSubject == 'Quotation') {
// //             icon = FontAwesomeIcons.solidCalendar;
// //           } else {
// //             icon = Icons.phone;
// //           }

// //           return Container(
// //             margin: const EdgeInsets.only(bottom: 16),
// //             child: Row(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 // Left side - Timeline indicator
// //                 SizedBox(
// //                   width: 50,
// //                   child: Column(
// //                     children: [
// //                       // Date above the icon
// //                       Container(
// //                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// //                         decoration: BoxDecoration(
// //                           color: Colors.green.shade100,
// //                           borderRadius: BorderRadius.circular(12),
// //                         ),
// //                         child: Text(
// //                           eventDate,
// //                           style: AppFont.dropDowmLabel(context)?.copyWith(
// //                             fontSize: 10,
// //                             fontWeight: FontWeight.w600,
// //                             color: Colors.green.shade700,
// //                           ),
// //                           textAlign: TextAlign.center,
// //                         ),
// //                       ),
// //                       const SizedBox(height: 8),
// //                       // Icon circle
// //                       Container(
// //                         width: 40,
// //                         height: 40,
// //                         decoration: const BoxDecoration(
// //                           color: Colors.green,
// //                           shape: BoxShape.circle,
// //                         ),
// //                         child: IconButton(
// //                           style: const ButtonStyle(
// //                             minimumSize: WidgetStatePropertyAll(Size.zero),
// //                             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
// //                             padding: WidgetStatePropertyAll(EdgeInsets.zero),
// //                           ),
// //                           icon: Icon(size: 20, icon, color: Colors.white),
// //                           onPressed: isFromTeams
// //                               ? null
// //                               : () {
// //                                   if (eventSubject == 'Call') {
// //                                     launchUrl(Uri.parse('tel:$mobile'));
// //                                   } else if (eventSubject == 'Send SMS') {
// //                                     launchUrl(Uri.parse('sms:$mobile'));
// //                                   } else if (eventSubject == 'Test Drive') {
// //                                     _showAleart(
// //                                       eventId,
// //                                       gmail,
// //                                       leadId,
// //                                       mobile,
// //                                       context,
// //                                     );
// //                                   } else {
// //                                     ScaffoldMessenger.of(context).showSnackBar(
// //                                       const SnackBar(
// //                                         content: Text(
// //                                           'No action defined for this subject',
// //                                         ),
// //                                       ),
// //                                     );
// //                                   }
// //                                 },
// //                         ),
// //                       ),
// //                       // Connecting line (except for last item)
// //                       if (index != reversedUpcomingEvents.length - 1)
// //                         Container(
// //                           width: 2,
// //                           height: 30,
// //                           color: Colors.grey.shade300,
// //                           margin: const EdgeInsets.only(top: 8),
// //                         ),
// //                     ],
// //                   ),
// //                 ),
// //                 const SizedBox(width: 16),
// //                 // Right side - Content box
// //                 Expanded(
// //                   child: Container(
// //                     width: double.infinity,
// //                     margin: const EdgeInsets.only(top: 32), // Align with icon
// //                     decoration: BoxDecoration(
// //                       color: const Color(0xffE7F2FF),
// //                       borderRadius: BorderRadius.circular(10),
// //                     ),
// //                     padding: const EdgeInsets.all(12),
// //                     child: RichText(
// //                       text: TextSpan(
// //                         children: [
// //                           TextSpan(
// //                             text: 'Action : ',
// //                             style: AppFont.dropDowmLabel(context),
// //                           ),
// //                           TextSpan(
// //                             text: '$eventSubject\n',
// //                             style: AppFont.smallText12(context),
// //                           ),
// //                           TextSpan(
// //                             text: 'Remarks : ',
// //                             style: AppFont.dropDowmLabel(context),
// //                           ),
// //                           TextSpan(
// //                             text: remarks,
// //                             style: AppFont.smallText12(context),
// //                           ),
// //                         ],
// //                       ),
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
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/services/api_srv.dart';
// import 'package:smartassist/widgets/testdrive_verifyotp.dart';
// import 'package:timeline_tile/timeline_tile.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';

// class TimelineUpcoming extends StatelessWidget {
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

//   String _formatDate(String date) {
//     try {
//       final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
//       return DateFormat("d MMM").format(parsedDate); // Outputs "22 May"
//     } catch (e) {
//       print('Error formatting date: $e');
//       return 'N/A';
//     }
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
//       barrierDismissible: false, // User must tap button to close dialog
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
//                 overlayColor: Colors.blue.withOpacity(0.1),
//                 foregroundColor: Colors.blue,
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
//                 style: GoogleFonts.poppins(color: Colors.blue),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _showContentPopup(
//     BuildContext context,
//     String subject,
//     String remarks,
//     String type,
//   ) async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           title: Text(
//             type == 'task' ? 'Task Details' : 'Event Details',
//             style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
//           ),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 RichText(
//                   text: TextSpan(
//                     children: [
//                       TextSpan(
//                         text: 'Action: ',
//                         style: GoogleFonts.poppins(
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       TextSpan(
//                         text: '$subject\n\n',
//                         style: GoogleFonts.poppins(
//                           color: Colors.black54,
//                         ),
//                       ),
//                       TextSpan(
//                         text: 'Remarks: ',
//                         style: GoogleFonts.poppins(
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       TextSpan(
//                         text: remarks,
//                         style: GoogleFonts.poppins(
//                           color: Colors.black54,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: Text(
//                 'Close',
//                 style: GoogleFonts.poppins(color: Colors.blue),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   String _truncateText(String text, int maxLines) {
//     List<String> words = text.split(' ');
//     if (words.length <= 15) return text; // Roughly 3 lines
//     return '${words.take(15).join(' ')}...';
//   }

//   bool _isTextLong(String subject, String remarks) {
//     String fullText = 'Action: $subject\nRemarks: $remarks';
//     return fullText.split(' ').length > 15;
//   }

//   Future<void> _getOtp(String eventId) async {
//     final success = await LeadsSrv.getOtp(eventId: eventId);

//     if (success) {
//       print('✅ Test drive started successfully');
//     } else {
//       print('❌ Failed to start test drive');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Reverse the tasks list to show from bottom to top
//     final reversedTasks = tasks.reversed.toList();

//     // Reverse the upcomingEvents list to show from bottom to top
//     final reversedUpcomingEvents = upcomingEvents.reversed.toList();

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
//         // Loop through tasks and display them
//         ...List.generate(reversedTasks.length, (index) {
//           final task = reversedTasks[index];
//           String remarks = task['remarks'] ?? 'No remarks';
//           String mobile = task['mobile'] ?? 'No Subject';
//           String dueDate = _formatDate(task['due_date'] ?? 'N/A');
//           String subject = task['subject'] ?? 'No Subject';

//           IconData icon;

//           if (subject == 'Provide Quotation') {
//             icon = Icons.receipt_long;
//           } else if (subject == 'Send SMS') {
//             icon = Icons.message_rounded;
//           } else if (subject == 'Call') {
//             icon = Icons.phone;
//           } else if (subject == 'Send Email') {
//             icon = Icons.mail;
//           } else if (subject == 'Showroom appointment') {
//             icon = Icons.person_2_outlined;
//           } else if (subject == 'Trade in evaluation') {
//             icon = Icons.handshake;
//           } else if (subject == 'Test Drive') {
//             icon = carIcon as IconData;
//           } else {
//             icon = Icons.phone; // default fallback icon
//           }

//           bool isLongText = _isTextLong(subject, remarks);

//           return Container(
//             margin: const EdgeInsets.only(bottom: 20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Date Badge at the top
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: Colors.blue.shade200),
//                   ),
//                   child: Text(
//                     dueDate,
//                     style: AppFont.dropDowmLabel(context)?.copyWith(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.blue.shade700,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 // Icon and Content Box in the same line
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Icon
//                     Container(
//                       width: 45,
//                       height: 45,
//                       decoration: const BoxDecoration(
//                         color: Colors.blueAccent,
//                         shape: BoxShape.circle,
//                       ),
//                       child: IconButton(
//                         style: const ButtonStyle(
//                           minimumSize: WidgetStatePropertyAll(Size.zero),
//                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           padding: WidgetStatePropertyAll(EdgeInsets.zero),
//                         ),
//                         icon: Icon(size: 22, icon, color: Colors.white),
//                         onPressed: isFromTeams
//                             ? null
//                             : () {
//                                 if (subject == 'Call') {
//                                   launchUrl(Uri.parse('tel:$mobile'));
//                                 } else if (subject == 'Send SMS') {
//                                   launchUrl(Uri.parse('sms:$mobile'));
//                                 } else {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     const SnackBar(
//                                       content: Text(
//                                         'No action defined for this subject',
//                                       ),
//                                     ),
//                                   );
//                                 }
//                               },
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     // Content Box
//                     Expanded(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: const Color(0xffE7F2FF),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         padding: const EdgeInsets.all(14),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             RichText(
//                               text: TextSpan(
//                                 children: [
//                                   TextSpan(
//                                     text: 'Action: ',
//                                     style: AppFont.dropDowmLabel(context),
//                                   ),
//                                   TextSpan(
//                                     text: '$subject\n',
//                                     style: AppFont.smallText12(context),
//                                   ),
//                                   TextSpan(
//                                     text: 'Remarks: ',
//                                     style: AppFont.dropDowmLabel(context),
//                                   ),
//                                   TextSpan(
//                                     text: isLongText ? _truncateText(remarks, 3) : remarks,
//                                     style: AppFont.smallText12(context),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             if (isLongText)
//                               Padding(
//                                 padding: const EdgeInsets.only(top: 8),
//                                 child: GestureDetector(
//                                   onTap: () => _showContentPopup(context, subject, remarks, 'task'),
//                                   child: Text(
//                                     'See more',
//                                     style: GoogleFonts.poppins(
//                                       color: Colors.blue.shade600,
//                                       fontWeight: FontWeight.w500,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           );
//         }),

//         // Loop through upcomingEvents and display them
//         ...List.generate(reversedUpcomingEvents.length, (index) {
//           final event = reversedUpcomingEvents[index];
//           String eventId = event['event_id'] ?? 'No ID';
//           String leadId = event['lead_id'] ?? 'No ID';
//           String gmail = event['lead_email'] ?? 'No email ID';
//           String remarks = event['remarks'] ?? 'No Remarks';
//           String mobile = event['mobile'] ?? 'No Number';
//           String eventDate = _formatDate(event['start_date'] ?? 'N/A');
//           String eventSubject = event['subject'] ?? 'No Subject';

//           IconData icon;

//           if (eventSubject == 'Test Drive') {
//             icon = Icons.directions_car;
//           } else if (eventSubject == 'Showroom appointment') {
//             icon = FontAwesomeIcons.solidCalendar;
//           } else if (eventSubject == 'Quotation') {
//             icon = FontAwesomeIcons.solidCalendar;
//           } else {
//             icon = Icons.phone;
//           }

//           bool isLongText = _isTextLong(eventSubject, remarks);

//           return Container(
//             margin: const EdgeInsets.only(bottom: 20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Date Badge at the top
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.green.shade50,
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: Colors.green.shade200),
//                   ),
//                   child: Text(
//                     eventDate,
//                     style: AppFont.dropDowmLabel(context)?.copyWith(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.green.shade700,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 // Icon and Content Box in the same line
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Icon
//                     Container(
//                       width: 45,
//                       height: 45,
//                       decoration: const BoxDecoration(
//                         color: Colors.green,
//                         shape: BoxShape.circle,
//                       ),
//                       child: IconButton(
//                         style: const ButtonStyle(
//                           minimumSize: WidgetStatePropertyAll(Size.zero),
//                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                           padding: WidgetStatePropertyAll(EdgeInsets.zero),
//                         ),
//                         icon: Icon(size: 22, icon, color: Colors.white),
//                         onPressed: isFromTeams
//                             ? null
//                             : () {
//                                 if (eventSubject == 'Call') {
//                                   launchUrl(Uri.parse('tel:$mobile'));
//                                 } else if (eventSubject == 'Send SMS') {
//                                   launchUrl(Uri.parse('sms:$mobile'));
//                                 } else if (eventSubject == 'Test Drive') {
//                                   _showAleart(
//                                     eventId,
//                                     gmail,
//                                     leadId,
//                                     mobile,
//                                     context,
//                                   );
//                                 } else {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     const SnackBar(
//                                       content: Text(
//                                         'No action defined for this subject',
//                                       ),
//                                     ),
//                                   );
//                                 }
//                               },
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     // Content Box
//                     Expanded(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: const Color(0xffE7F2FF),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         padding: const EdgeInsets.all(14),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             RichText(
//                               text: TextSpan(
//                                 children: [
//                                   TextSpan(
//                                     text: 'Action: ',
//                                     style: AppFont.dropDowmLabel(context),
//                                   ),
//                                   TextSpan(
//                                     text: '$eventSubject\n',
//                                     style: AppFont.smallText12(context),
//                                   ),
//                                   TextSpan(
//                                     text: 'Remarks: ',
//                                     style: AppFont.dropDowmLabel(context),
//                                   ),
//                                   TextSpan(
//                                     text: isLongText ? _truncateText(remarks, 3) : remarks,
//                                     style: AppFont.smallText12(context),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             if (isLongText)
//                               Padding(
//                                 padding: const EdgeInsets.only(top: 8),
//                                 child: GestureDetector(
//                                   onTap: () => _showContentPopup(context, eventSubject, remarks, 'event'),
//                                   child: Text(
//                                     'See more',
//                                     style: GoogleFonts.poppins(
//                                       color: Colors.blue.shade600,
//                                       fontWeight: FontWeight.w500,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
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
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/testdrive_verifyotp.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TimelineUpcoming extends StatelessWidget {
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

  String _formatDate(String date) {
    try {
      final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
      return DateFormat("d MMM").format(parsedDate); // Outputs "22 May"
    } catch (e) {
      print('Error formatting date: $e');
      return 'N/A';
    }
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
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
              style: TextButton.styleFrom(
                overlayColor: Colors.grey.withOpacity(0.1),
                foregroundColor: Colors.grey,
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                overlayColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blue,
              ),
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
              child: Text(
                'Yes',
                style: GoogleFonts.poppins(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showContentPopup(
    BuildContext context,
    String subject,
    String remarks,
    String type,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            type == 'task' ? 'Task Details' : 'Event Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Action: ',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: '$subject\n\n',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                        ),
                      ),
                      TextSpan(
                        text: 'Remarks: ',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: remarks,
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  bool _isTextLong(String remarks) {
    // Check if remarks text is longer than approximately 3 lines (around 100 characters)
    return remarks.length > 100;
  }

  Future<void> _getOtp(String eventId) async {
    final success = await LeadsSrv.getOtp(eventId: eventId);

    if (success) {
      print('✅ Test drive started successfully');
    } else {
      print('❌ Failed to start test drive');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reverse the tasks list to show from bottom to top
    final reversedTasks = tasks.reversed.toList();

    // Reverse the upcomingEvents list to show from bottom to top
    final reversedUpcomingEvents = upcomingEvents.reversed.toList();

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
        // Loop through tasks and display them
        ...List.generate(reversedTasks.length, (index) {
          final task = reversedTasks[index];
          String remarks = task['remarks'] ?? 'No remarks';
          String mobile = task['mobile'] ?? 'No Subject';
          String dueDate = _formatDate(task['due_date'] ?? 'N/A');
          String subject = task['subject'] ?? 'No Subject';

          IconData icon;

          if (subject == 'Provide Quotation') {
            icon = Icons.receipt_long;
          } else if (subject == 'Send SMS') {
            icon = Icons.message_rounded;
          } else if (subject == 'Call') {
            icon = Icons.phone;
          } else if (subject == 'Send Email') {
            icon = Icons.mail;
          } else if (subject == 'Showroom appointment') {
            icon = Icons.person_2_outlined;
          } else if (subject == 'Trade in evaluation') {
            icon = Icons.handshake;
          } else if (subject == 'Test Drive') {
            icon = carIcon as IconData;
          } else {
            icon = Icons.phone; // default fallback icon
          }

          bool isLongText = _isTextLong(remarks);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Badge at the top
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    dueDate,
                    style: AppFont.dropDowmLabel(context)?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Icon and Content Box in the same line
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size.zero),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: WidgetStatePropertyAll(EdgeInsets.zero),
                        ),
                        icon: Icon(size: 22, icon, color: Colors.white),
                        onPressed: isFromTeams
                            ? null
                            : () {
                                if (subject == 'Call') {
                                  launchUrl(Uri.parse('tel:$mobile'));
                                } else if (subject == 'Send SMS') {
                                  launchUrl(Uri.parse('sms:$mobile'));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No action defined for this subject',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Content Box
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xffE7F2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Action: ',
                                    style: AppFont.dropDowmLabel(context),
                                  ),
                                  TextSpan(
                                    text: '$subject\n',
                                    style: AppFont.smallText12(context),
                                  ),
                                  TextSpan(
                                    text: 'Remarks: ',
                                    style: AppFont.dropDowmLabel(context),
                                  ),
                                  TextSpan(
                                    text: isLongText ? _truncateText(remarks, 100) : remarks,
                                    style: AppFont.smallText12(context),
                                  ),
                                ],
                              ),
                            ),
                            if (isLongText)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: GestureDetector(
                                  onTap: () => _showContentPopup(context, subject, remarks, 'task'),
                                  child: Text(
                                    'See more',
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        // Loop through upcomingEvents and display them
        ...List.generate(reversedUpcomingEvents.length, (index) {
          final event = reversedUpcomingEvents[index];
          String eventId = event['event_id'] ?? 'No ID';
          String leadId = event['lead_id'] ?? 'No ID';
          String gmail = event['lead_email'] ?? 'No email ID';
          String remarks = event['remarks'] ?? 'No Remarks';
          String mobile = event['mobile'] ?? 'No Number';
          String eventDate = _formatDate(event['start_date'] ?? 'N/A');
          String eventSubject = event['subject'] ?? 'No Subject';

          IconData icon;

          if (eventSubject == 'Test Drive') {
            icon = Icons.directions_car;
          } else if (eventSubject == 'Showroom appointment') {
            icon = FontAwesomeIcons.solidCalendar;
          } else if (eventSubject == 'Quotation') {
            icon = FontAwesomeIcons.solidCalendar;
          } else {
            icon = Icons.phone;
          }

          bool isLongText = _isTextLong(remarks);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Badge at the top
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    eventDate,
                    style: AppFont.dropDowmLabel(context)?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Icon and Content Box in the same line
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size.zero),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: WidgetStatePropertyAll(EdgeInsets.zero),
                        ),
                        icon: Icon(size: 22, icon, color: Colors.white),
                        onPressed: isFromTeams
                            ? null
                            : () {
                                if (eventSubject == 'Call') {
                                  launchUrl(Uri.parse('tel:$mobile'));
                                } else if (eventSubject == 'Send SMS') {
                                  launchUrl(Uri.parse('sms:$mobile'));
                                } else if (eventSubject == 'Test Drive') {
                                  _showAleart(
                                    eventId,
                                    gmail,
                                    leadId,
                                    mobile,
                                    context,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No action defined for this subject',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Content Box
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xffE7F2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Action: ',
                                    style: AppFont.dropDowmLabel(context),
                                  ),
                                  TextSpan(
                                    text: '$eventSubject\n',
                                    style: AppFont.smallText12(context),
                                  ),
                                  TextSpan(
                                    text: 'Remarks: ',
                                    style: AppFont.dropDowmLabel(context),
                                  ),
                                  TextSpan(
                                    text: isLongText ? _truncateText(remarks, 100) : remarks,
                                    style: AppFont.smallText12(context),
                                  ),
                                ],
                              ),
                            ),
                            if (isLongText)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: GestureDetector(
                                  onTap: () => _showContentPopup(context, eventSubject, remarks, 'event'),
                                  child: Text(
                                    'See more',
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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