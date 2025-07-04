import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/bottom_navigation.dart';
import 'package:smartassist/utils/storage.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _selectedButtonIndex = 0;
  List<dynamic> notifications = [];
  bool result = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // Fixed: Make sure keys match the categories list exactly
  final Map<String, String> categoryMap = {
    'All': 'All',
    'Leads': 'leads',
    'Followups': 'followups',
    'Appointments':
        'appointment', // Fixed: Changed to plural to match categories
    'Test drives':
        'test%20drive', // Fixed: Changed to plural to match categories
  };

  final List<String> categories = [
    'All',
    // 'Read',
    'Leads',
    'Followups',
    'Appointments',
    'Test drives',
  ];

  Future<void> _fetchNotifications({String? category}) async {
    final token = await Storage.getToken();
    String url = 'https://dev.smartassistapp.in/api/users/notifications/all';

    if (category != null && category != 'All') {
      // Use the categoryMap to get the correct URL parameter
      String? urlCategory = categoryMap[category];

      // Debug prints to see what's happening
      print('Selected category: $category');
      print('Mapped URL category: $urlCategory');

      if (urlCategory != null && urlCategory != 'All') {
        url += '?category=$urlCategory';
      }
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Fetching notifications from URL: $url');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        List<dynamic> allNotifications = [];
        if (data['data']['unread'] != null &&
            data['data']['unread']['rows'] != null) {
          allNotifications.addAll(data['data']['unread']['rows']);
        }
        if (data['data']['read'] != null &&
            data['data']['read']['rows'] != null) {
          allNotifications.addAll(data['data']['read']['rows']);
        }

        print('Total notifications loaded: ${allNotifications.length}');
        print(data);

        setState(() {
          notifications = allNotifications;
        });
      } else {
        print("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final token = await Storage.getToken();
    final url =
        'https://dev.smartassistapp.in/api/users/notifications/$notificationId';

    print('Marking notification as read with URL: $url');

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'read': true}),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Successfully marked notification as read');
        setState(() {
          // Mark the notification as read and filter out all read notifications
          notifications = notifications.where((notification) {
            if (notification['data']['notification_id'] == notificationId) {
              notification['data']['read'] = true;
              return false; // Exclude this notification from the list
            }
            return true; // Keep all other notifications
          }).toList();
        });
      } else {
        print("Failed to mark as read: ${response.statusCode}");
      }
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    final token = await Storage.getToken();
    final url =
        'https://dev.smartassistapp.in/api/users/notifications/read/all';

    print('Marking all notifications as read with URL: $url');

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'read': true}),
      );

      print('Mark all as read response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Successfully marked all notifications as read');
        // Refresh the notifications after marking all as read
        await _fetchNotifications(category: categories[_selectedButtonIndex]);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All notifications marked as read',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior
                  .floating, // Optional: Makes it float above UI
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  10,
                ), // Optional: rounded corners
              ),
            ),
          );
        }
      } else {
        print("Failed to mark all as read: ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to mark all notifications as read',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print("Error marking all notifications as read: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error occurred while marking notifications as read',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildButton(String title, int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * .034,
          decoration: BoxDecoration(
            border: _selectedButtonIndex == index
                ? Border.all(color: Colors.blue)
                : Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xffF3F9FF),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              setState(() {
                _selectedButtonIndex = index;
              });

              String selectedCategory = categories[index];
              print('Button $index selected: $selectedCategory'); // Debug print

              // Fixed: Pass the category directly, not through categoryMap lookup
              _fetchNotifications(category: selectedCategory);
            },
            child: Text(
              categories[index],
              style: GoogleFonts.poppins(
                color: _selectedButtonIndex == index
                    ? Colors.blue
                    : AppColors.fontColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
        actions: [
          // Add "Mark All as Read" button in the app bar
          IconButton(
            onPressed: () async {
              // Adjust key based on your map structure
              bool hasUnread = notifications.any((n) => n['read'] == false);

              if (!hasUnread) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color.fromARGB(
                      255,
                      132,
                      132,
                      132,
                    ), // Change this to any color you like
                    content: Text(
                      'Nothing to read',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                      ), // Ensure text is readable
                    ),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior
                        .floating, // Optional: Makes it float above UI
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        10,
                      ), // Optional: rounded corners
                    ),
                  ),
                );
                return;
              }

              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(
                      'Mark all as read?',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    content: Text(
                      'Are you sure you want to mark all notifications as read?',
                      style: GoogleFonts.poppins(),
                    ),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          overlayColor: Colors.grey.withOpacity(0.1),
                          foregroundColor: Colors.grey,
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'No',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          overlayColor: Colors.blue.withOpacity(0.1),
                          foregroundColor: Colors.blue,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          'Yes',
                          style: GoogleFonts.poppins(color: Colors.blue),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                await markAllAsRead();
              }
            },
            icon: const Icon(Icons.done_all, color: Colors.white, size: 24),
            tooltip: 'Mark All as Read?',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: List.generate(categories.length, (index) {
              return _buildButton(categories[index], index);
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 5, 0, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Notification',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.fontColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notifications.isNotEmpty
                  ? notifications
                        .where((notification) => notification['read'] == false)
                        .length
                  : 0,
              itemBuilder: (context, index) {
                // Only show notifications that are unread
                final notification = notifications
                    .where((notification) => notification['read'] == false)
                    .toList()[index];

                bool isRead = notification['read'] ?? false;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: GestureDetector(
                        onTap: () async {
                          if (!isRead) {
                            await markAsRead(notification['notification_id']);
                          }

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FollowupsDetails(
                                leadId: notification['recordId'] ?? '',
                                isFromFreshlead: false,
                                isFromManager: false,
                                isFromTestdriveOverview: false,
                                refreshDashboard: () async {},
                              ),
                            ),
                          );

                          // Refresh only if something changed
                          if (result == true) {
                            _fetchNotifications(
                              category: categories[_selectedButtonIndex],
                            );
                          }
                        },
                        child: Card(
                          color: isRead ? Colors.white : Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          semanticContainer: false,
                          borderOnForeground: false,
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            leading: Icon(
                              Icons.circle,
                              color: isRead ? Colors.grey : Colors.blue,
                              size: 10,
                            ),
                            title: Text(
                              notification['title'] ?? 'No Title',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              notification['body'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(
                      thickness: 0.1,
                      color: Colors.black,
                      indent: 10,
                      endIndent: 10,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
