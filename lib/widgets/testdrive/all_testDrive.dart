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
import 'package:url_launcher/url_launcher.dart';

class AllTestrive extends StatefulWidget {
  final String name, mobile, taskId, eventId, startTime;
  final String subject;
  final String date;
  final String vehicle;
  final String leadId;
  final double swipeOffset;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback handleTestDrive;
  // final dynamic item;
  final VoidCallback otpTrigger;

  const AllTestrive({
    super.key,
    required this.name,
    required this.subject,
    required this.date,
    required this.vehicle,
    required this.leadId,
    this.swipeOffset = 0.0,
    this.isFavorite = false,
    required this.onToggleFavorite,
    required this.mobile,
    required this.taskId,
    required this.startTime,
    required this.eventId,
    required this.handleTestDrive,
    // this.item,
    required this.otpTrigger,
  });

  @override
  State<AllTestrive> createState() => _AllFollowupsItemState();
}

class _AllFollowupsItemState extends State<AllTestrive>
    with SingleTickerProviderStateMixin {
  bool _wasCallingPhone = false;

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

  // void _handleTestDrive(dynamic item) {
  //   String email = item['updated_by'] ?? '';
  //   String mobile = item['mobile'] ?? '';
  //   String eventId = item['event_id'] ?? '';
  //   String leadId = item['lead_id'] ?? '';
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => TestdriveVerifyotp(
  //         email: email,
  //         mobile: mobile,
  //         leadId: leadId,
  //         eventId: eventId,
  //       ),
  //     ),
  //   );
  //   print("Call action triggered for ${item['name']}");
  // }

  //   Future<void> _getOtp(String eventId) async {
  //   final success = await LeadsSrv.getOtp(eventId: eventId);

  //   if (success) {
  //     print('✅ Test drive started successfully');
  //   } else {
  //     print('❌ Failed to start test drive');
  //   }

  //   if (mounted) setState(() {});
  // }

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
        child: _buildOverdueCard(context),
      ),
    );
  }

  Widget _buildOverdueCard(BuildContext context) {
    bool isFavoriteSwipe = widget.swipeOffset > 50;
    bool isCallSwipe = widget.swipeOffset < -50;

    return Slidable(
      key: ValueKey(widget.leadId), // Always good to set keys
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
            handleTestDrive: '',
            otpTrigger: '',
          ),
        ],
      ),

      endActionPane: ActionPane(
        extentRatio: 0.4,
        motion: const StretchMotion(),
        children: [
          if (widget.subject == 'Test Drive')
            ReusableSlidableAction(
              onPressed: _showAleart,
              backgroundColor: AppColors.colorsBlue,
              icon: Icons.directions_car,
              foregroundColor: Colors.white,
              handleTestDrive: '',
              otpTrigger: '',
            ),
          if (widget.subject == 'Send SMS')
            ReusableSlidableAction(
              onPressed: _messageAction,
              backgroundColor: AppColors.colorsBlueGrey,
              icon: Icons.message_rounded,
              foregroundColor: Colors.white,
              handleTestDrive: '',
              otpTrigger: '',
            ),
          // Edit is always shown
          ReusableSlidableAction(
            onPressed: _mailAction,
            backgroundColor: const Color.fromARGB(255, 231, 225, 225),
            icon: Icons.edit,
            foregroundColor: Colors.white,
            handleTestDrive: '',
            otpTrigger: '',
          ),
        ],
      ),
      child: Stack(
        children: [
          // Favorite Swipe Overlay
          if (isFavoriteSwipe) Positioned.fill(child: _buildFavoriteOverlay()),

          // Call Swipe Overlay
          if (isCallSwipe) Positioned.fill(child: _buildCallOverlay()),

          // Main Card
          Opacity(
            opacity: (isFavoriteSwipe || isCallSwipe) ? 0 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.containerBg,
                borderRadius: BorderRadius.circular(5),
                border: Border(
                  left: BorderSide(
                    width: 8.0,
                    color: widget.isFavorite
                        ? Colors.yellow
                        : AppColors.colorsBlueBar,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
      },
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

  Widget _buildFavoriteOverlay() {
    return Container(
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
      child: Row(
        children: [
          const SizedBox(width: 15),
          Icon(
            widget.isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
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
    );
  }

  Widget _buildCallOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.green],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.phone_in_talk, color: Colors.white, size: 30),
          const SizedBox(width: 10),
          Text(
            'Call',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
    if (widget.subject == 'Test Drive') {
      icon = Icons.directions_car_filled_rounded;
    } else if (widget.subject == 'Send SMS') {
      icon = Icons.mail_rounded;
    } else {
      icon = Icons.phone; // fallback icon
    }

    return Row(
      children: [
        Icon(icon, color: AppColors.colorsBlue, size: 18),
        const SizedBox(width: 5),
        Text('${widget.subject},', style: AppFont.smallText(context)),
      ],
    );
  }

  // Widget _buildSubjectDetails(BuildContext context) {
  //   return Row(
  //     children: [
  //       const Icon(Icons.phone_in_talk, color: AppColors.colorsBlue, size: 18),
  //       const SizedBox(width: 5),
  //       Text('${widget.subject},', style: AppFont.smallText(context)),
  //     ],
  //   );
  // }

  Widget _date(BuildContext context) {
    String formattedDate = '';
    try {
      DateTime parseDate = DateTime.parse(widget.date);
      if (parseDate.year == DateTime.now().year &&
          parseDate.month == DateTime.now().month &&
          parseDate.day == DateTime.now().day) {
        formattedDate = 'Today';
      } else {
        int day = parseDate.day;
        String suffix = _getDaySuffix(day);
        String month = DateFormat('MMM').format(parseDate);
        formattedDate = '$day$suffix $month';
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

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
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

    // String mobile = item['mobile'] ?? '';

    if (widget.mobile.isNotEmpty) {
      try {
        // Set flag that we're making a phone call
        _wasCallingPhone = true;

        // Simple approach without canLaunchUrl check
        final phoneNumber = 'tel:${widget.mobile}';
        launchUrl(
          Uri.parse(phoneNumber),
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (e) {
        print('Error launching phone app: $e');

        // Reset flag if there was an error
        _wasCallingPhone = false;
        // Show error message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No phone number available')));
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
          child: Testdrive(onFormSubmit: () {}, eventId: widget.eventId),
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
  final String handleTestDrive;
  final String otpTrigger;

  const ReusableSlidableAction({
    Key? key,
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.handleTestDrive,
    required this.otpTrigger,
    this.foregroundColor,
    this.iconSize = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      padding: EdgeInsets.zero,
      onPressed: (context) => onPressed(),
      backgroundColor: backgroundColor,
      child: Icon(icon, size: iconSize, color: foregroundColor ?? Colors.white),
    );
  }
}

class AllTestDrive extends StatefulWidget {
  final List<dynamic> allTestDrive;
  final bool isNested;

  const AllTestDrive({
    super.key,
    required this.allTestDrive,
    this.isNested = false,
  });

  @override
  State<AllTestDrive> createState() => _AllTestDriveState();
}

class _AllTestDriveState extends State<AllTestDrive> {
  List<bool> _favorites = [];

  @override
  void initState() {
    super.initState();
    _initializeFavorites();
  }

  @override
  void didUpdateWidget(AllTestDrive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allTestDrive != oldWidget.allTestDrive) {
      _initializeFavorites();
    }
  }

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
          mobile: mobile,
          leadId: leadId,
          eventId: eventId,
        ),
      ),
    );
    print("Call action triggered for ${item['name']}");
  }

  Future<void> _getOtp(String eventId) async {
    final success = await LeadsSrv.getOtp(eventId: eventId);

    if (success) {
      print('✅ Test drive started successfully');
    } else {
      print('❌ Failed to start test drive');
    }

    if (mounted) setState(() {});
  }

  void _initializeFavorites() {
    _favorites = List.generate(
      widget.allTestDrive.length,
      (index) => widget.allTestDrive[index]['favourite'] == true,
    );
  }

  void _toggleFavorite(int index) {
    setState(() {
      _favorites[index] = !_favorites[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allTestDrive.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "No Testdrive available",
            style: AppFont.smallText12(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isNested)
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 15, 0, 0),
            child: Text(
              "All Followups",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: widget.allTestDrive.length,
          itemBuilder: (context, index) {
            final item = widget.allTestDrive[index];
            return AllTestrive(
              name: item['name'] ?? '',
              subject: item['subject'] ?? '',
              date: item['due_date'] ?? '',
              vehicle: item['PMI'] ?? '',
              leadId: item['lead_id'] ?? '',
              mobile: item['mobile'] ?? '',
              taskId: item['task_id'] ?? '',

              // startTime: item['start_time'],
              startTime:
                  (item['start_time'] != null &&
                      item['start_time'].toString().isNotEmpty)
                  ? item['start_time'].toString()
                  : "00:00:00",

              eventId: item['event_id'],
              isFavorite: _favorites[index],
              onToggleFavorite: () => _toggleFavorite(index),

              handleTestDrive: () {
                _handleTestDrive(item);
              },
              otpTrigger: () {
                _getOtp(item['event_id'] ?? '');
              },
            );
          },
        ),
      ],
    );
  }
}
