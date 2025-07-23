import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
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
          // String comment = task['remarks'] ?? 'No Remarks';

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

          return TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.25,
            isFirst: index == (reversedTasks.length - 1),
            isLast: index == 0,
            beforeLineStyle: const LineStyle(color: Colors.transparent),
            afterLineStyle: const LineStyle(color: Colors.transparent),

            indicatorStyle: IndicatorStyle(
              width: 30,
              height: 30,
              padding: const EdgeInsets.only(left: 5),
              drawGap: true,
              indicator: Container(
                decoration: const BoxDecoration(
                  color: AppColors.colorsBlue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  style: const ButtonStyle(
                    // padding:
                    minimumSize: WidgetStatePropertyAll(Size.zero),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                  icon: Icon(size: 20, icon, color: Colors.white),
                  onPressed: isFromTeams
                      ? null
                      : () {
                          if (subject == 'Call') {
                            // Example: Launch phone dialer (you'll need url_launcher package)
                            launchUrl(Uri.parse('tel:$mobile'));
                          } else if (subject == 'Send SMS') {
                            // Example: Open SMS
                            launchUrl(Uri.parse('sms:$mobile'));
                          } else {
                            // fallback action
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
            ),
            startChild: Text(
              dueDate, // Show the due date
              style: AppFont.dropDowmLabel(context),
            ),
            endChild: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xffE7F2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.fromLTRB(10.0, 10, 0, 10),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Action : ',
                            style: AppFont.dropDowmLabel(context),
                          ),
                          TextSpan(
                            text: '$subject\n',
                            style: AppFont.smallText12(context),
                          ),
                          TextSpan(
                            text: 'Remarks : ',
                            style: AppFont.dropDowmLabel(context),
                          ),
                          TextSpan(
                            text: remarks,
                            style: AppFont.smallText12(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // event

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
          } else if (eventSubject == 'Showroom appointment') {
            icon = FontAwesomeIcons.solidCalendar;
          } else {
            icon = Icons.phone;
          }

          return TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.25,
            isFirst: index == (reversedUpcomingEvents.length - 1),
            isLast: index == 0,
            beforeLineStyle: const LineStyle(color: Colors.transparent),
            afterLineStyle: const LineStyle(color: Colors.transparent),
            indicatorStyle: IndicatorStyle(
              width: 30,
              height: 30,
              padding: const EdgeInsets.only(left: 5),
              drawGap: true,
              indicator: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1380FE),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  style: const ButtonStyle(
                    // padding:
                    minimumSize: WidgetStatePropertyAll(Size.zero),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                  icon: Icon(size: 20, icon, color: Colors.white),
                  onPressed: isFromTeams
                      ? null
                      : () {
                          if (eventSubject == 'Call') {
                            // if (isFromTeams) return;
                            // Example: Launch phone dialer (you'll need url_launcher package)
                            launchUrl(Uri.parse('tel:$mobile'));
                          } else if (eventSubject == 'Send SMS') {
                            // Example: Open SMS
                            launchUrl(Uri.parse('sms:$mobile'));
                          } else if (eventSubject == 'Test Drive') {
                            // Example: Open Test Drive UR
                            // _getOtp(eventId);
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => TestdriveVerifyotp(
                            //       email: gmail,
                            //       eventId: eventId,
                            //       leadId: leadId,
                            //       mobile: mobile,
                            //     ),
                            //   ),
                            // );
                            _showAleart(
                              eventId,
                              gmail,
                              leadId,
                              mobile,
                              context,
                            );
                          } else {
                            // fallback action
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
            ),

            // indicatorStyle: IndicatorStyle(
            //   padding: const EdgeInsets.only(left: 5),
            //   width: 30,
            //   height: 30,
            //   color: AppColors.sideGreen, // Green for upcoming events
            //   iconStyle: IconStyle(
            //     iconData: Icons.event_available,
            //     color: Colors.white,
            //   ),
            // ),
            startChild: Text(
              eventDate, // Show the event date
              style: AppFont.dropDowmLabel(context),
            ),
            endChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xffE7F2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.fromLTRB(10.0, 10, 0, 10),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Action : ',
                            style: AppFont.dropDowmLabel(context),
                          ),
                          TextSpan(
                            text: '$eventSubject\n',
                            style: AppFont.smallText12(context),
                          ),
                          TextSpan(
                            text: 'Remarks : ',
                            style: AppFont.dropDowmLabel(context),
                          ),
                          TextSpan(
                            text: remarks,
                            style: AppFont.smallText12(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }
}
