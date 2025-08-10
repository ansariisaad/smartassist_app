import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/widgets/home_btn.dart/edit_dashboardpopup.dart/testdrive.dart';
import 'package:smartassist/widgets/testdrive_verifyotp.dart';

class TestOverdue extends StatefulWidget {
  final Future<void> Function() refreshDashboard;
  final List<dynamic> overdueTestDrive;
  final bool isNested;
  final Function(String, bool)? onFavoriteToggle;
  const TestOverdue({
    super.key,
    required this.overdueTestDrive,
    required this.isNested,
    this.onFavoriteToggle,
    required this.refreshDashboard,
  });

  @override
  State<TestOverdue> createState() => _TestOverdueState();
}

class _TestOverdueState extends State<TestOverdue> {
  List<dynamic> upcomingTestDrives = [];
  final Map<String, double> _swipeOffsets = {};

  @override
  void initState() {
    super.initState();
    upcomingTestDrives = widget.overdueTestDrive;
    print('this is testdrive');
    print(widget.overdueTestDrive);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, String eventId) {
    setState(() {
      _swipeOffsets[eventId] =
          (_swipeOffsets[eventId] ?? 0) + (details.primaryDelta ?? 0);
    });
  }

  // void _onHorizontalDragEnd(DragEndDetails details, dynamic item, int index) {
  //   String eventId = item['event_id'];

  //   double swipeOffset = _swipeOffsets[eventId] ?? 0;

  //   if (swipeOffset > 100) {
  //     // Right Swipe (Favorite)
  //     _toggleFavorite(eventId, index);
  //   } else if (swipeOffset < -100) {
  //     // Left Swipe (Call)
  //     _handleTestDrive(item);
  //   }

  //   // Reset animation
  //   setState(() {
  //     _swipeOffsets[eventId] = 0.0;
  //   });
  // }

  void _handleTestDrive(dynamic item) {
    String email = item['updated_by'] ?? '';
    String mobile = item['mobile'] ?? '';
    String eventId = item['event_id'] ?? '';
    String leadId = item['lead_id'] ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestdriveVerifyotp(
          email: email,
          leadId: leadId,
          eventId: eventId,
          mobile: mobile,
        ),
      ),
    );
    print("Call action triggered for ${item['name']}");
  }

  Future<void> _toggleFavorite(String eventId, int index) async {
    bool currentStatus = widget.overdueTestDrive[index]['favourite'] ?? false;
    bool newFavoriteStatus = !currentStatus;

    final success = await LeadsSrv.favoriteTestDrive(eventId: eventId);

    if (success) {
      setState(() {
        widget.overdueTestDrive[index]['favourite'] = newFavoriteStatus;
      });

      if (widget.onFavoriteToggle != null) {
        widget.onFavoriteToggle!(eventId, newFavoriteStatus);
      }
    }
  }

  // Future<void> _toggleFavorite(String eventId, int index) async {
  //   final token = await Storage.getToken();
  //   try {
  //     // Get the current favorite status before toggling
  //     bool currentStatus = widget.overdueTestDrive[index]['favourite'] ?? false;
  //     bool newFavoriteStatus = !currentStatus;

  //     final response = await http.put(
  //       Uri.parse(
  //         'https://api.smartassistapps.in/api/favourites/mark-fav/event/$eventId',
  //       ),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //       // No need to send in body since taskId is already in the URL
  //     );

  //     if (response.statusCode == 200) {
  //       setState(() {
  //         widget.overdueTestDrive[index]['favourite'] = newFavoriteStatus;
  //       });

  //       // Notify the parent if the callback is provided
  //       if (widget.onFavoriteToggle != null) {
  //         widget.onFavoriteToggle!(eventId, newFavoriteStatus);
  //       }
  //     } else {
  //       print('Failed to toggle favorite: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error toggling favorite: $e');
  //   }
  // }

  Future<void> _getOtp(String eventId) async {
    final success = await LeadsSrv.getOtp(eventId: eventId);

    if (success) {
      print('✅ OTP send successfully');
    } else {
      print('❌ Failed to start test drive');
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.overdueTestDrive.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No Overdue TestDrive available',
            style: AppFont.smallText12(context),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: widget.isNested
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: widget.overdueTestDrive.length,
      itemBuilder: (context, index) {
        var item = widget.overdueTestDrive[index];

        String eventId = item['event_id'];
        double swipeOffset = _swipeOffsets[eventId] ?? 0;

        return GestureDetector(
          child: upcomingTestDrivesItem(
            key: ValueKey(item['event_id']),
            name: item['name'],
            vehicle: item['PMI'] ?? 'Range Rover Velar',
            subject: item['subject'] ?? 'Meeting',
            date: item['start_date'],
            leadId: item['lead_id'],
            taskId: item['task_id'] ?? '',
            // startTime: item['start_time'],
            startTime:
                (item['start_time'] != null &&
                    item['start_time'].toString().isNotEmpty)
                ? item['start_time'].toString()
                : "00:00:00",
            eventId: item['event_id'],
            isFavorite: item['favourite'] ?? false,
            swipeOffset: swipeOffset,
            refreshDashboard: widget.refreshDashboard,
            onToggleFavorite: () {
              _toggleFavorite(eventId, index);
            },
            otpTrigger: () {
              _getOtp(eventId);
            },
            fetchDashboardData: () {},
            handleTestDrive: () {
              _handleTestDrive(item);
            }, // Placeholder, replace with actual method
          ),
        );
      },
    );
  }
}

class upcomingTestDrivesItem extends StatefulWidget {
  final String name, date, vehicle, taskId, leadId, eventId, subject, startTime;
  final bool isFavorite;
  final double swipeOffset;
  final Future<void> Function() refreshDashboard;
  final VoidCallback fetchDashboardData;
  final VoidCallback onToggleFavorite;
  final VoidCallback handleTestDrive;
  final dynamic item;
  final VoidCallback otpTrigger;
  const upcomingTestDrivesItem({
    super.key,
    required this.name,
    required this.date,
    required this.leadId,
    required this.fetchDashboardData,
    required this.eventId,
    required this.startTime,
    required this.subject,
    required this.swipeOffset,
    required this.isFavorite,
    required this.vehicle,
    required this.onToggleFavorite,
    required this.taskId,
    this.item,
    required this.handleTestDrive,
    required this.otpTrigger,
    required this.refreshDashboard,
  });

  @override
  State<upcomingTestDrivesItem> createState() => _upcomingTestDrivesItemState();
}

class _upcomingTestDrivesItemState extends State<upcomingTestDrivesItem>
    with SingleTickerProviderStateMixin {
  late SlidableController _slidableController;
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
  }

  @override
  void dispose() {
    _slidableController.dispose();
    super.dispose();
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
                  refreshDashboard: widget.refreshDashboard,
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

  Widget _buildFollowupCard(BuildContext context) {
    bool isFavoriteSwipe = widget.swipeOffset > 50;
    bool isCallSwipe = widget.swipeOffset < -50;

    return Slidable(
      controller: _slidableController,
      key: ValueKey(widget.leadId), // Always good to set keys
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
        motion: const StretchMotion(),
        children: [
          if (widget.subject == 'Test Drive')
            ReusableSlidableAction(
              onPressed: _showAleart,
              // onPressed: () {
              //   widget.handleTestDrive();
              //   widget.otpTrigger();
              // },
              backgroundColor: AppColors.colorsBlue,
              icon: Icons.directions_car,
              foregroundColor: Colors.white,
            ),
          if (widget.subject == 'Send SMS')
            ReusableSlidableAction(
              onPressed: _messageAction,
              backgroundColor: AppColors.colorsBlue,
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
                      const SizedBox(width: 15),
                      Icon(
                        widget.isFavorite
                            ? Icons.star_outline_rounded
                            : Icons.star_rounded,
                        color: const Color.fromRGBO(226, 195, 34, 1),
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.isFavorite ? 'Unfavorite' : 'Favorite',
                        style: GoogleFonts.poppins(
                          color: const Color.fromRGBO(187, 158, 0, 1),
                          fontSize: 18,
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
                  gradient: const LinearGradient(
                    colors: [AppColors.colorsBlue, AppColors.colorsBlue],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 20),
                      const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Start Test Drive',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                  ),
                ),
              ),
            ),

          // Main Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.containerBg,
              // gradient: _buildSwipeGradient(),
              borderRadius: BorderRadius.circular(5),
              border: Border(
                left: BorderSide(
                  width: 8.0,
                  color: widget.isFavorite
                      ? (isCallSwipe
                            ? AppColors.colorsBlue.withOpacity(
                                0.2,
                              ) // Green when swiping for a call
                            : Colors.yellow.withOpacity(
                                isFavoriteSwipe ? 0.1 : 0.9,
                              )) // Keep yellow when favorite
                      : (isFavoriteSwipe
                            ? Colors.yellow.withOpacity(0.1)
                            : (isCallSwipe
                                  ? AppColors.colorsBlue.withOpacity(0.2)
                                  : AppColors.sideRed)),
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

  Future<void> _showAleart() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Are You Sure?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to start a testdrive?',
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
              // onPressed: () => Navigator.of(context).pop(
              // true),
              onPressed: () {
                // initwhatsappChat(context); // Pass context to submit
                widget.handleTestDrive();
                widget.otpTrigger();
              },
              child: Text(
                'Yes',
                style: GoogleFonts.poppins(color: AppColors.colorsBlue),
              ),
            ),
          ],
        );

        // return AlertDialog(
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(15),
        //   ),
        //   backgroundColor: Colors.white,
        //   insetPadding: const EdgeInsets.all(10),
        //   contentPadding: EdgeInsets.zero,
        //   title: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Align(
        //         alignment: Alignment.bottomLeft,
        //         child: Text(
        //           textAlign: TextAlign.center,
        //           'Share your gmail?',
        //           style: AppFont.mediumText14(context),
        //         ),
        //       ),
        //       const SizedBox(height: 10),
        //     ],
        //   ),
        //   actions: [
        //     TextButton(
        //       onPressed: () {
        //         Navigator.pop(context);
        //       },
        //       child: Text(
        //         'Cancel',
        //         // style: TextStyle(color: AppColors.colorsBlue),
        //         style: AppFont.mediumText14blue(context),
        //       ),
        //     ),
        //     TextButton(
        //       onPressed: () {
        //         whatsappChat(context); // Pass context to submit
        //       },
        //       child: Text('Submit', style: AppFont.mediumText14blue(context)),
        //     ),
        //   ],
        // );
      },
    );
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
          child: Testdrive(onFormSubmit: () {}, eventId: widget.eventId),
        );
      },
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.directions_car, color: AppColors.colorsBlue, size: 18),
        const SizedBox(width: 5),
        Text('${widget.subject},', style: AppFont.smallText(context)),
      ],
    );
  }

  Widget _time() {
    DateTime parsedTime = DateFormat("HH:mm:ss").parse(widget.startTime);
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
    //   borderRadius: BorderRadius.circular(8),
    // );
    return CustomSlidableAction(
      onPressed: (context) => onPressed(),
      backgroundColor: backgroundColor,
      child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
    );
  }
}
