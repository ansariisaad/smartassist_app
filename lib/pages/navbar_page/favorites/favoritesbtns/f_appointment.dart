import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/appointments.dart';
import 'package:url_launcher/url_launcher.dart';

class FAppointment extends StatefulWidget {
  const FAppointment({super.key});

  @override
  State<FAppointment> createState() => _FAppointmentState();
}

class _FAppointmentState extends State<FAppointment> {
  bool isLoading = true;
  final Map<String, double> _swipeOffsets = {};
  List<dynamic> upcomingTasks = [];
  List<dynamic> overdueTasks = [];

  void _onHorizontalDragUpdate(DragUpdateDetails details, String eventId) {
    setState(() {
      _swipeOffsets[eventId] =
          (_swipeOffsets[eventId] ?? 0) + (details.primaryDelta ?? 0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, dynamic item, int index) {
    String eventId = item['event_id'];
    double swipeOffset = _swipeOffsets[eventId] ?? 0;

    if (swipeOffset > 100) {
      // Right Swipe (Favorite)
      _toggleFavorite(eventId, index);
    } else if (swipeOffset < -100) {
      // Left Swipe (Call)
      _handleCall(item);
    }

    // Reset animation
    setState(() {
      _swipeOffsets[eventId] = 0.0;
    });
  }

  Future<void> _toggleFavorite(String eventId, int index) async {
    final token = await Storage.getToken();
    try {
      // Get the current favorite status before toggling
      bool currentStatus = upcomingTasks[index]['favourite'] ?? false;
      bool newFavoriteStatus = !currentStatus;

      final response = await http.put(
        Uri.parse(
          'https://api.smartassistapp.in/api/favourites/mark-fav/event/$eventId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Parse the response to get the updated favorite status
        final responseData = json.decode(response.body);

        // Update only the specific item in the list
        setState(() {
          upcomingTasks[index]['favourite'] = newFavoriteStatus;
          overdueTasks[index]['favourite'] = newFavoriteStatus;
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
  }

  Future<void> fetchTasksData() async {
    final token = await Storage.getToken();
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/favourites/events/appointments/all',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          upcomingTasks = data['data']['upcomingAppointments']['rows'] ?? [];
          overdueTasks = data['data']['overdueAppointments']['rows'] ?? [];
          isLoading = false;
          print('this is from FOppointment ${Uri.parse}');
        });
      } else {
        print("Failed to load data: ${response.statusCode}");
        print('this is the api appoinment${Uri}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (upcomingTasks.isEmpty && overdueTasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet
              ? screenSize.width * 0.15
              : screenSize.width * 0.1,
          vertical: isTablet ? 30 : 20,
        ),
        child: Center(
          child: Text(
            'Nothing to see here...',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: AppColors.iconGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTasksList(upcomingTasks, isUpcoming: true),
          _buildTasksList(overdueTasks, isUpcoming: false),
        ],
      ),
    );
  }

  Widget _buildTasksList(List<dynamic> tasks, {required bool isUpcoming}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        var item = tasks[index];

        if (!(item.containsKey('assigned_to') &&
            item.containsKey('start_date') &&
            item.containsKey('lead_id') &&
            item.containsKey('event_id'))) {
          return ListTile(title: Text('Invalid data at index $index'));
        }

        String eventId = item['event_id'];
        double swipeOffset = _swipeOffsets[eventId] ?? 0;

        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _onHorizontalDragUpdate(details, eventId),
          onHorizontalDragEnd: (details) =>
              _onHorizontalDragEnd(details, item, index),
          child: TaskItem(
            key: ValueKey(item['event_id']),
            name: item['name'],
            subject: item['subject'] ?? 'Meeting',
            date: item['start_date'],
            vehicle: item['PMI'] ?? 'Discovery Sport',
            leadId: item['lead_id'],
            time: item['start_time'],
            eventId: item['event_id'],
            mobile: item['mobile'] ?? '',
            isFavorite: item['favourite'] ?? false,
            swipeOffset: swipeOffset,
            fetchDashboardData: () {},
            onFavoriteToggled: () {},
            isUpcoming: isUpcoming, // Placeholder, replace with actual method
            onToggleFavorite: () {
              _toggleFavorite(eventId, index);
            },
          ),
        );
      },
    );
  }
}

class TaskItem extends StatefulWidget {
  final String name, subject, mobile;
  final String date;
  final String vehicle;
  final String leadId;
  final String eventId;
  final bool isFavorite;
  final bool isUpcoming;
  final String time;
  final VoidCallback onFavoriteToggled;
  final double swipeOffset;
  final VoidCallback fetchDashboardData;

  final VoidCallback onToggleFavorite;

  const TaskItem({
    super.key,
    required this.name,
    required this.date,
    required this.vehicle,
    required this.leadId,
    required this.eventId,
    required this.isFavorite,
    required this.isUpcoming,
    required this.onFavoriteToggled,
    required this.time,
    required this.swipeOffset,
    required this.fetchDashboardData,
    required this.subject,
    required this.onToggleFavorite,
    required this.mobile,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late bool isFav;

  bool _wasCallingPhone = false;

  late SlidableController _slidableController;

  @override
  void initState() {
    super.initState();
    // Register this class as an observer to track app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _slidableController = SlidableController(this);
  }

  @override
  void dispose() {
    // Remove observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    _slidableController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // This gets called when app lifecycle state changes
    if (state == AppLifecycleState.resumed && _wasCallingPhone) {
      // App is resumed and we marked that user was making a call
      _wasCallingPhone = false;
      // Show the mail action dialog after a short delay to ensure app is fully resumed
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _mailAction();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
      child: InkWell(
        onTap: () {
          if (widget.leadId.isNotEmpty) {
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
        child: _buildFollowupCard(context),
      ),
    );
  }

  // Widget _buildFollowupCard(BuildContext context) {
  //   bool isFavoriteSwipe = widget.swipeOffset > 50;
  //   bool isCallSwipe = widget.swipeOffset < -50;
  //   // Gradient background for swipe
  //   LinearGradient _buildSwipeGradient() {
  //     if (isFavoriteSwipe) {
  //       return const LinearGradient(
  //         colors: [
  //           Color.fromRGBO(239, 206, 29, 0.67),
  //           // Colors.yellow.withOpacity(0.2),
  //           // Colors.yellow.withOpacity(0.8)
  //           Color.fromRGBO(239, 206, 29, 0.67),
  //         ],
  //         begin: Alignment.centerLeft,
  //         end: Alignment.centerRight,
  //       );
  //     } else if (isCallSwipe) {
  //       return LinearGradient(
  //         colors: [
  //           Colors.green.withOpacity(0.2),
  //           Colors.green.withOpacity(0.8),
  //         ],
  //         begin: Alignment.centerRight,
  //         end: Alignment.centerLeft,
  //       );
  //     }
  //     return const LinearGradient(
  //       colors: [AppColors.containerBg, AppColors.containerBg],
  //       begin: Alignment.centerLeft,
  //       end: Alignment.centerRight,
  //     );
  //   }

  //   return Stack(
  //     children: [
  //       // Favorite Swipe Overlay
  //       if (isFavoriteSwipe)
  //         Positioned.fill(
  //           child: Container(
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [
  //                   Colors.yellow.withOpacity(0.2),
  //                   Colors.yellow.withOpacity(0.8),
  //                 ],
  //                 begin: Alignment.centerLeft,
  //                 end: Alignment.centerRight,
  //               ),
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //             child: Center(
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.start,
  //                 children: [
  //                   const SizedBox(width: 15),
  //                   Icon(
  //                     widget.isFavorite
  //                         ? Icons.star_outline_rounded
  //                         : Icons.star_rounded,
  //                     color: const Color.fromRGBO(226, 195, 34, 1),
  //                     size: 40,
  //                   ),
  //                   const SizedBox(width: 10),
  //                   Text(
  //                     widget.isFavorite ? 'Unfavorite' : 'Favorite',
  //                     style: GoogleFonts.poppins(
  //                       color: Color.fromRGBO(187, 158, 0, 1),
  //                       fontSize: 18,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),

  //       // Call Swipe Overlay
  //       if (isCallSwipe)
  //         Positioned.fill(
  //           child: Container(
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [
  //                   Colors.green.withOpacity(0.2),
  //                   Colors.green.withOpacity(0.8),
  //                 ],
  //                 begin: Alignment.centerRight,
  //                 end: Alignment.centerLeft,
  //               ),
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //             child: Center(
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.start,
  //                 children: [
  //                   const SizedBox(width: 10),
  //                   const Icon(
  //                     Icons.phone_in_talk,
  //                     color: Colors.white,
  //                     size: 30,
  //                   ),
  //                   const SizedBox(width: 10),
  //                   Text(
  //                     'Call',
  //                     style: GoogleFonts.poppins(
  //                       color: Colors.white,
  //                       fontSize: 18,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 5),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),

  //       // Main Container
  //       Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
  //         decoration: BoxDecoration(
  //           gradient: _buildSwipeGradient(),
  //           borderRadius: BorderRadius.circular(5),
  //           border: Border(
  //             left: BorderSide(
  //               width: 8.0,
  //               color: widget.isFavorite
  //                   ? (isCallSwipe
  //                         ? Colors.green.withOpacity(
  //                             0.9,
  //                           ) // Green when swiping for a call
  //                         : Colors.yellow.withOpacity(
  //                             isFavoriteSwipe ? 0.1 : 0.9,
  //                           )) // Keep yellow when favorite
  //                   : (isFavoriteSwipe
  //                         ? Colors.yellow.withOpacity(0.1)
  //                         : (isCallSwipe
  //                               ? AppColors.sideGreen.withOpacity(0.5)
  //                               : AppColors.sideGreen)),
  //             ),
  //           ),
  //         ),
  //         child: Opacity(
  //           opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //               Row(
  //                 children: [
  //                   const SizedBox(width: 8),
  //                   Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Row(
  //                         children: [
  //                           _buildUserDetails(context),
  //                           _buildVerticalDivider(15),
  //                           _buildCarModel(context),
  //                         ],
  //                       ),
  //                       const SizedBox(height: 4),
  //                       Row(
  //                         children: [
  //                           _buildSubjectDetails(context),
  //                           _date(context),
  //                           _time(),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //               _buildNavigationButton(context),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildFollowupCard(BuildContext context) {
    bool isFavoriteSwipe = widget.swipeOffset > 50;
    bool isCallSwipe = widget.swipeOffset < -50;

    return Slidable(
      key: ValueKey(widget.eventId), // Always good to set keys
      controller: _slidableController,
      startActionPane: ActionPane(
        extentRatio: 0.2,
        motion: const ScrollMotion(),
        children: [
          ReusableSlidableAction(
            onPressed: widget.onToggleFavorite, // handle fav toggle
            backgroundColor: Colors.amber,
            icon: widget.isFavorite
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            foregroundColor: Colors.white,
          ),
        ],
      ),

      endActionPane: ActionPane(
        extentRatio: 0.4,
        motion: const StretchMotion(),
        children: [
          // if (widget.subject == 'Meeting')
          ReusableSlidableAction(
            onPressed: _phoneAction,
            backgroundColor: Colors.blue,
            icon: Icons.phone,
            foregroundColor: Colors.white,
          ),
          if (widget.subject == 'Quetations')
            ReusableSlidableAction(
              onPressed: _messageAction,
              backgroundColor: Colors.blueGrey,
              icon: Icons.message_rounded,
              foregroundColor: Colors.white,
            ),
          // Edit is always shown
          ReusableSlidableAction(
            onPressed: _mailAction,
            backgroundColor: const Color.fromARGB(255, 231, 225, 225),
            icon: Icons.edit,
            foregroundColor: Colors.white,
          ),
        ],
      ),

      child: Stack(
        children: [
          // Main Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.backgroundLightGrey,
              // gradient: _buildSwipeGradient(),
              borderRadius: BorderRadius.circular(5),
              border: Border(
                left: BorderSide(
                  width: 8.0,
                  color: widget.isFavorite
                      ? (isCallSwipe
                            ? Colors.green.withOpacity(
                                0.9,
                              ) // Green when swiping for a call
                            : Colors.yellow.withOpacity(
                                isFavoriteSwipe ? 0.1 : 0.9,
                              )) // Keep yellow when favorite
                      : (isFavoriteSwipe
                            ? Colors.yellow.withOpacity(0.1)
                            : (isCallSwipe
                                  ? Colors.green
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
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildUserDetails(context),
                              _buildVerticalDivider(15),
                              _buildCarModel(context),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildSubjectDetails(context),
                              _date(context),
                              _time(),
                            ],
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildUserDetails(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * .35,
      ),
      child: Text(
        maxLines: 1, // Allow up to 2 lines
        overflow: TextOverflow
            .ellipsis, // Show ellipsis if it overflows beyond 2 lines
        softWrap: true,
        widget.name,
        style: AppFont.dashboardName(context),
      ),
    );
  }

  Widget _buildSubjectDetails(BuildContext context) {
    IconData icon;
    if (widget.subject == 'Meeting') {
      icon = Icons.phone_in_talk;
    } else if (widget.subject == 'Provide Quotation') {
      icon = Icons.mail_rounded;
    } else if (widget.subject == 'Showroom appointment') {
      icon = Icons.mail_rounded;
    } else {
      icon = Icons.phone; // fallback icon
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 18),
        const SizedBox(width: 5),
        Text('${widget.subject},', style: AppFont.smallText(context)),
      ],
    );
  }

  Widget _time() {
    DateTime parsedTime = DateFormat("HH:mm:ss").parse(widget.time);
    String formattedTime = DateFormat("ha").format(parsedTime);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        Text(
          formattedTime,
          style: GoogleFonts.poppins(
            color: AppColors.fontColor,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _date(BuildContext context) {
    String formattedDate = '';
    try {
      DateTime parseDate = DateTime.parse(widget.date);
      // formattedDate = DateFormat('dd MMM').format(parseDate);
      // Check if the date is today
      if (parseDate.year == DateTime.now().year &&
          parseDate.month == DateTime.now().month &&
          parseDate.day == DateTime.now().day) {
        formattedDate = 'Today';
      } else {
        // If not today, format it as "26th March"
        int day = parseDate.day;
        String suffix = _getDaySuffix(day);
        String month = DateFormat('MMM').format(parseDate); // Full month name
        formattedDate = '${day}$suffix $month';
      }
    } catch (e) {
      formattedDate = widget.date;
    }
    return Row(
      children: [
        const SizedBox(width: 5),
        Text(formattedDate, style: AppFont.smallText(context)),
      ],
    );
  }

  // Helper method to get the suffix for the day (e.g., "st", "nd", "rd", "th")
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildVerticalDivider(double height) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: height,
      width: 0.1,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.fontColor)),
      ),
    );
  }

  Widget _buildCarModel(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * .30,
      ),
      child: Text(
        widget.vehicle,
        style: AppFont.dashboardCarName(context),
        maxLines: 1, // Allow up to 2 lines
        overflow: TextOverflow
            .ellipsis, // Show ellipsis if it overflows beyond 2 lines
        softWrap: true, // Allow wrapping
      ),
    );
  }

  bool _isActionPaneOpen = false;
  Widget _buildNavigationButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isActionPaneOpen) {
          _slidableController.close();
          setState(() {
            _isActionPaneOpen = false;
          });
        } else {
          _slidableController.close();
          Future.delayed(Duration(milliseconds: 100), () {
            _slidableController.openEndActionPane();
            setState(() {
              _isActionPaneOpen = true;
            });
          });
        }
      },

      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.arrowContainerColor,
          borderRadius: BorderRadius.circular(30),
        ),

        child: Icon(
          _isActionPaneOpen
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_rounded,

          size: 25,
          color: Colors.white,
        ),
      ),
    );
  }

  void _phoneAction() {
    print("Call action triggered for ${widget.mobile}");

    if (widget.mobile.isNotEmpty) {
      try {
        // Set flag that we're making a phone call
        _wasCallingPhone = true;

        // Use the same approach as _handleCall - no launch mode specified
        launchUrl(Uri.parse('tel:${widget.mobile}'));

        print('Phone dialer launched');
      } catch (e) {
        print('Error launching phone app: $e');

        // Reset flag if there was an error
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

  void _messageAction() {
    print("Message action triggered");
  }

  void _mailAction() {
    print("Mail action triggered");

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
          child: AppointmentsEdit(onFormSubmit: () {}, eventId: widget.eventId),
        );
      },
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
    // return SlidableAction(
    //   onPressed: (context) => onPressed(),
    //   backgroundColor: backgroundColor,
    //   foregroundColor: foregroundColor ?? Colors.white,
    //   icon: icon,
    //   borderRadius: BorderRadius.circular(0),
    // );

    return CustomSlidableAction(
      padding: EdgeInsets.zero,
      onPressed: (context) => onPressed(),
      backgroundColor: backgroundColor,
      child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
    );
  }
}
