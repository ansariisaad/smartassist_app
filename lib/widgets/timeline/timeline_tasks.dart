 
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
