// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/services/api_srv.dart';
// import 'package:smartassist/widgets/testdrive_verifyotp.dart';
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

//   bool _shouldShowSeeMore(String remarks) {
//     return remarks.length > 60;
//   }

//   bool _isTestDrive(String subject) {
//     return subject.toLowerCase().contains('test drive');
//   }

//   // Helper method to determine container height based on content
//   double _getContainerHeight(String remarks, bool isExpanded, bool showSeeMore) {
//     if (remarks.isEmpty) {
//       return 45.0; // Minimal height for empty content
//     }

//     // Estimate text lines based on character count (rough estimation)
//     int estimatedLines;
//     if (showSeeMore && !isExpanded) {
//       estimatedLines = 2; // Clamped to 2 lines when collapsed
//     } else {
//       // Rough estimation: ~50 characters per line on average mobile screen
//       estimatedLines = (remarks.length / 50).ceil();
//     }

//     // Base height calculation
//     double baseHeight = 40; // Height for "Remarks:" label + padding
//     double lineHeight = 18; // Approximate height per line of text
//     double seeMoreButtonHeight = showSeeMore ? 30 : 0; // Height for see more/less button

//     double calculatedHeight = baseHeight + (estimatedLines * lineHeight) + seeMoreButtonHeight;

//     // Ensure minimum readable height
//     return calculatedHeight < 60 ? 60 : calculatedHeight;
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

//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Date & Action Row (NO icon)
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
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
//                   Text(
//                     subject,
//                     style: AppFont.dropDowmLabel(context)?.copyWith(
//                       fontWeight: FontWeight.w600,
//                       fontSize: 12.5,
//                       color: const Color(0xFF3497F9),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),

//               // Card with dynamic height based on content
//               Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: const Color(0xffE7F2FF),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 padding: const EdgeInsets.all(14),
//                 margin: const EdgeInsets.only(top: 4, bottom: 20),
//                 child: IntrinsicHeight( // This makes container height fit content
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         'Remarks:',
//                         style: AppFont.dropDowmLabel(context)?.copyWith(
//                           color: Colors.black,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       if (remarks.isNotEmpty) ...[
//                         Text(
//                           remarks,
//                           maxLines: (!showSeeMore || isExpanded) ? null : 2,
//                           overflow: (!showSeeMore || isExpanded)
//                               ? TextOverflow.visible
//                               : TextOverflow.ellipsis,
//                           style: AppFont.smallText12(context)?.copyWith(
//                             color: Colors.black,
//                             height: 1.4, // Line height for better readability
//                           ),
//                         ),
//                         if (showSeeMore) ...[
//                           const SizedBox(height: 8),
//                           GestureDetector(
//                             onTap: () {
//                               setState(() {
//                                 if (isExpanded) {
//                                   expandedTaskIndexes.remove(index);
//                                 } else {
//                                   expandedTaskIndexes.add(index);
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
//                       ] else ...[
//                         Text(
//                           'No remarks ',
//                           style: AppFont.smallText12(context)?.copyWith(
//                             color: Colors.grey[600],

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
//           bool isTestDriveEvent = _isTestDrive(eventSubject);

//           // Choose colors based on whether it's a test drive
//           Color badgeColor = isTestDriveEvent ? const Color(0xFF3497F9) : const Color(0xFF3497F9);

//           return Container(
//             margin: const EdgeInsets.only(bottom: 20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Date & Action Row (NO icon)
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     // Date Badge
//                     Text(
//                       eventDate,
//                       style: AppFont.dropDowmLabel(context)?.copyWith(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: badgeColor,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     // Action Text
//                     Text(
//                       eventSubject,
//                       style: AppFont.dropDowmLabel(context)?.copyWith(
//                         fontWeight: FontWeight.w600,
//                         fontSize: 14,
//                         color: const Color(0xFF3497F9),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),

//                 // Card with dynamic height based on content
//                 Container(
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: const Color(0xffE7F2FF),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   padding: const EdgeInsets.all(14),
//                   margin: const EdgeInsets.only(top: 4),
//                   child: IntrinsicHeight( // This makes container height fit content
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           'Remarks:',
//                           style: AppFont.dropDowmLabel(context)?.copyWith(
//                             color: Colors.black,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         if (remarks.isNotEmpty) ...[
//                           Text(
//                             remarks,
//                             maxLines: (!showSeeMore || isExpanded) ? null : 2,
//                             overflow: (!showSeeMore || isExpanded)
//                                 ? TextOverflow.visible
//                                 : TextOverflow.ellipsis,
//                             style: AppFont.smallText12(context)?.copyWith(
//                               color: Colors.black,
//                               height: 1.4, // Line height for better readability
//                             ),
//                           ),
//                           if (showSeeMore) ...[
//                             const SizedBox(height: 8),
//                             GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   if (isExpanded) {
//                                     expandedEventIndexes.remove(index);
//                                   } else {
//                                     expandedEventIndexes.add(index);
//                                   }
//                                 });
//                               },
//                               child: Text(
//                                 isExpanded ? 'See less' : 'See more',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.w500,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ] else ...[
//                           Text(
//                             'No remarks available',
//                             style: AppFont.smallText12(context)?.copyWith(
//                               color: Colors.grey[600],

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

//without icon code //

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/followups.dart';
import 'package:smartassist/widgets/testdrive_verifyotp.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TimelineUpcoming extends StatefulWidget {
  final bool isFromTeams;
  final String mobile = '';
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

class _TimelineUpcomingState extends State<TimelineUpcoming>
    with WidgetsBindingObserver {
  bool _wasCallingPhone = false;
  final Set<int> expandedTaskIndexes = {};
  final Set<int> expandedEventIndexes = {};
  String? currentTaskId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasCallingPhone) {
      _wasCallingPhone = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && currentTaskId != null) {
          _wsCall(currentTaskId!);
        }
      });
    }
  }

  void _wsCall(String taskId) {
    print("WS Call triggered for task: $taskId");

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
          child: FollowupsEdit(onFormSubmit: () {}, taskId: taskId),
        );
      },
    );
  }

  void _phoneAction(String mobileNumber, String taskId) async {
    if (mobileNumber.isNotEmpty) {
      try {
        _wasCallingPhone = true;
        currentTaskId = taskId;
        await launchUrl(Uri.parse('tel:$mobileNumber'));
      } catch (e) {
        _wasCallingPhone = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
    }
  }

  String _formatDate(String date) {
    try {
      final DateTime parsedDate = DateFormat("yyyy-MM-dd").parse(date);
      return DateFormat("d MMM").format(parsedDate);
    } catch (e) {
      return 'N/A';
    }
  }

  IconData _getIconFromSubject(String subject) {
    switch (subject) {
      case 'Provide Quotation':
        return Icons.receipt_long;
      case 'Send SMS':
        return Icons.message_rounded;
      case 'Call':
        return Icons.phone;
      case 'Send Email':
        return Icons.mail;
      case 'Showroom appointment':
        return Icons.person_2_outlined;
      case 'Trade in evaluation':
        return Icons.handshake;
      case 'Test Drive':
        return Icons.directions_car;
      case 'Quotation':
        return FontAwesomeIcons.solidCalendar;
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

    switch (subject) {
      case 'Call':
        _phoneAction(mobile, '');
        break;
      case 'Send SMS':
        launchUrl(Uri.parse('sms:$mobile'));
        break;
      case 'Test Drive':
        _showAleart(eventId, gmail, leadId, mobile, context);
        break;
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
      barrierDismissible: false,
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
                overlayColor: AppColors.colorsBlue.withOpacity(0.1),
                foregroundColor: AppColors.colorsBlue,
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
                style: GoogleFonts.poppins(color: AppColors.colorsBlue),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getOtp(String eventId) async {
    final success = await LeadsSrv.getOtp(eventId: eventId);
    if (success) {
      print('✅ Test drive started successfully');
    } else {
      print('❌ Failed to start test drive');
    }
  }

  bool _shouldShowSeeMore(String text) {
    return text.length > 100;
  }

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
        ...List.generate(reversedTasks.length, (index) {
          final task = reversedTasks[index];
          String remarks = task['remarks'] ?? '';
          String mobile = task['mobile'] ?? '';
          String dueDate = _formatDate(task['due_date'] ?? 'N/A');
          String subject = task['subject'] ?? 'No Subject';

          bool isExpanded = expandedTaskIndexes.contains(index);
          bool showSeeMore = _shouldShowSeeMore(remarks);
          IconData iconData = _getIconFromSubject(subject);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _handleIconPress(subject, mobile, '', '', '', context);
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
                    dueDate,
                    style: AppFont.dropDowmLabel(context)?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3497F9),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                    Text(
                      'Remarks:',
                      style: AppFont.dropDowmLabel(
                        context,
                      )?.copyWith(color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remarks.isNotEmpty ? remarks : 'No remarks',
                      style: AppFont.smallText12(context)?.copyWith(
                        color: remarks.isNotEmpty
                            ? Colors.black
                            : Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: (!showSeeMore || isExpanded) ? null : 2,
                      overflow: (!showSeeMore || isExpanded)
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (showSeeMore) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              expandedTaskIndexes.remove(index);
                            } else {
                              expandedTaskIndexes.add(index);
                            }
                          });
                        },
                        child: Text(
                          isExpanded ? 'See less' : 'See more',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),

        ...List.generate(reversedUpcomingEvents.length, (index) {
          final event = reversedUpcomingEvents[index];
          String eventId = event['event_id'] ?? 'No ID';
          String leadId = event['lead_id'] ?? 'No ID';
          String gmail = event['lead_email'] ?? '';
          String remarks = event['remarks'] ?? '';
          String mobile = event['mobile'] ?? '';
          String eventDate = _formatDate(event['start_date'] ?? 'N/A');
          String subject = event['subject'] ?? 'No Subject';

          bool isExpanded = expandedEventIndexes.contains(index);
          bool showSeeMore = _shouldShowSeeMore(remarks);
          IconData iconData = _getIconFromSubject(subject);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _handleIconPress(
                          subject,
                          mobile,
                          eventId,
                          gmail,
                          leadId,
                          context,
                        );
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
                      child: Text(
                        subject,
                        style: AppFont.dropDowmLabel(context)?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF3497F9),
                        ),
                        overflow: TextOverflow.ellipsis,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remarks:',
                        style: AppFont.dropDowmLabel(
                          context,
                        )?.copyWith(color: Colors.black),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remarks.isNotEmpty ? remarks : 'No remarks available',
                        style: AppFont.smallText12(context)?.copyWith(
                          color: remarks.isNotEmpty
                              ? Colors.black
                              : Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: (!showSeeMore || isExpanded) ? null : 2,
                        overflow: (!showSeeMore || isExpanded)
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                      if (showSeeMore) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                expandedEventIndexes.remove(index);
                              } else {
                                expandedEventIndexes.add(index);
                              }
                            });
                          },
                          child: Text(
                            isExpanded ? 'See less' : 'See more',
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
