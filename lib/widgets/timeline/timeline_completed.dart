import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/testdrive_overview.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TimelineCompleted extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> completedEvents;
  const TimelineCompleted({
    super.key,
    required this.events,
    required this.completedEvents,
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

  Future<void> _getOtp(String eventId) async {
    final success = await LeadsSrv.getOtp(eventId: eventId);

    if (success) {
      print('✅ Test drive started successfully');
    } else {
      print('❌ Failed to start test drive');
    }

    // if (mounted) setState(() {});
  }

  // String formattedTime = _formatTo12HourFormat(taskSubject);

  String _formatTo12HourFormat(String time24) {
    try {
      // Parse the 24-hour time string to DateTime
      DateFormat inputFormat = DateFormat("HH:mm"); // 24-hour format
      DateTime dateTime = inputFormat.parse(time24);

      // Convert it to 12-hour format with AM/PM
      DateFormat outputFormat = DateFormat(
        "hh:mm a",
      ); // 12-hour format with AM/PM
      return outputFormat.format(dateTime);
    } catch (e) {
      return "Invalid time"; // Handle error if time format is incorrect
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reverse the events and completedEvents list to show from bottom to top
    final reversedEvents = events.reversed.toList();
    final reversedCompletedEvents = completedEvents.reversed.toList();

    if (reversedEvents.isEmpty && reversedCompletedEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'No completed task available',
            style: AppFont.smallText12(context),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Loop through events and display them
        ...List.generate(reversedEvents.length, (index) {
          final task = reversedEvents[index];
          String dueDate = _formatDate(task['due_date'] ?? 'N/A');
          String mobile = task['mobile'] ?? 'N/A';
          // String subject = _formatDate(task['subject'] ?? 'No Date');
          String subject = task['subject'] ?? 'N/A';

          String time = _formatDate(task['completed_at'] ?? 'No Time');
          String eventId = task['event_id'] ?? 'No Time';
          String taskId = task['task_id'] ?? 'empty';
          String comment = task['remarks'] ?? 'No Remarks';

          IconData icon;

          if (subject == 'Provide Quotation') {
            icon = Icons.sms;
          } else if (subject == 'Send SMS') {
            icon = Icons.mail_rounded;
          } else if (subject == 'Call') {
            icon = Icons.phone;
          } else if (subject == 'Send Email') {
            icon = Icons.mail;
          } else {
            icon = Icons.phone; // default fallback icon
          }

          return InkWell(
            onTap: () {
              if (subject == 'Test Drive') {
                // Navigate only if subject is "Test Drive"
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TestdriveOverview(eventId: eventId, leadId: ''),
                  ),
                );
              }
            },
            child: TimelineTile(
              alignment: TimelineAlign.manual,
              lineXY: 0.25,
              isFirst: index == (reversedEvents.length - 1),
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
                    color: AppColors.sideGreen,
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
                    onPressed: () {},
                    // onPressed: () {
                    //   if (subject == 'Call') {
                    //     // Example: Launch phone dialer (you'll need url_launcher package)
                    //     launchUrl(Uri.parse('tel:$mobile'));
                    //   } else if (subject == 'Send SMS') {
                    //     // Example: Open SMS
                    //     launchUrl(Uri.parse('sms:$mobile'));
                    //   } else {
                    //     // fallback action
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(
                    //           content:
                    //               Text('No action defined for this subject')),
                    //     );
                    //   }
                    // },
                  ),
                ),
              ),
              // indicatorStyle: IndicatorStyle(
              //   padding: const EdgeInsets.only(left: 5),
              //   width: 30,
              //   height: 30,
              //   color: Colors.green,
              //   iconStyle: IconStyle(
              //     iconData: Icons.check,
              //     color: Colors.white,
              //   ),
              // ),
              startChild: Text(dueDate, style: AppFont.dropDowmLabel(context)),
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
                      padding: const EdgeInsets.all(10.0),
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
                              text: '$comment\n',
                              style: AppFont.smallText12(context),
                            ),
                            TextSpan(
                              text: 'Completed at : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: time,
                              style: AppFont.smallText12(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // this is event

        // Loop through completedEvents and display them
        ...List.generate(reversedCompletedEvents.length, (index) {
          final task = reversedCompletedEvents[index];
          // String remarks = _formatDate(task['remarks'] ?? 'No Remarks');
          String remarks = task['remarks'] ?? '';
          String startDate = _formatDate(task['start_date'] ?? 'No date');
          // String completeAt =
          //     _formatDate(task['completed_at' ?? 'No complete date']);
          String completeAt = task['completed_at'] != null
              ? _formatDate(task['completed_at'])
              : 'No complete date';

          String startTime = task['start_time'] ?? 'No Start time';
          String endTime = task['end_time'] ?? 'No end time';
          String duration = task['duration'] ?? 'No duration';
          String distance = task['distance'] ?? 'No distance';
          String rating = task['avg_rating'] ?? 'No rating';
          String mobile = task['mobile'] ?? 'N/A';
          String date = _formatDate(task['start_date'] ?? 'No Date');
          String taskSubject = task['subject'] ?? 'No Subject';
          String eventId = task['event_id'] ?? 'No Time';

          IconData icon;

          if (taskSubject == 'Test Drive') {
            icon = Icons.directions_car;
          } else if (taskSubject == 'Showroom appointment') {
            icon = FontAwesomeIcons.solidCalendar;
          } else if (taskSubject == 'Quotation') {
            icon = FontAwesomeIcons.solidCalendar;
          } else if (taskSubject == 'Showroom appointment') {
            icon = FontAwesomeIcons.solidCalendar;
          } else {
            icon = Icons.phone;
          }

          return InkWell(
            onTap: () {
              if (taskSubject == 'Test Drive') {
                // Navigate only if subject is "Test Drive"
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TestdriveOverview(eventId: eventId, leadId: ''),
                  ),
                );
              }
            },
            child: TimelineTile(
              alignment: TimelineAlign.manual,
              lineXY: 0.25,
              isFirst: index == (reversedCompletedEvents.length - 1),
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
                    color: AppColors.sideGreen,
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
                    onPressed: () {},
                    // onPressed: () {
                    //   if (taskSubject == 'Call') {
                    //     // Example: Launch phone dialer (you'll need url_launcher package)
                    //     launchUrl(Uri.parse('tel:$mobile'));
                    //   } else if (taskSubject == 'Send SMS') {
                    //     // Example: Open SMS
                    //     launchUrl(Uri.parse('sms:$mobile'));
                    //   } else {
                    //     // fallback action
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(
                    //           content:
                    //               Text('No action defined for this subject')),
                    //     );
                    //   }
                    // },
                  ),
                ),
              ),

              // indicatorStyle: IndicatorStyle(
              //   padding: const EdgeInsets.only(left: 5),
              //   width: 30,
              //   height: 30,
              //   color: Colors.green, // Green color for completed events
              //   iconStyle: IconStyle(
              //     iconData: Icons.check,
              //     color: Colors.white,
              //   ),
              // ),
              startChild: Text(date, style: AppFont.dropDowmLabel(context)),
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
                      padding: const EdgeInsets.all(10.0),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Subject : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$taskSubject\n',
                              style: AppFont.smallText12(context),
                            ),
                            //
                            TextSpan(
                              text: 'Completed at : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$completeAt\n',
                              style: AppFont.smallText12(context),
                            ),
                            TextSpan(
                              text: 'Start Time : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$startTime\n',
                              style: AppFont.smallText12(context),
                            ),
                            TextSpan(
                              text: 'End Time : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$endTime\n',
                              style: AppFont.smallText12(context),
                            ),
                            TextSpan(
                              text: 'Duration : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$duration\n',
                              style: AppFont.smallText12(context),
                            ),
                            TextSpan(
                              text: 'Distance : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$distance\n',
                              style: AppFont.smallText12(context),
                            ),
                            TextSpan(
                              text: 'Average rating : ',
                              style: AppFont.dropDowmLabel(context),
                            ),
                            TextSpan(
                              text: '$rating\n',
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
            ),
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }
}
