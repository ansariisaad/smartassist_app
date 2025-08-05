import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:url_launcher/url_launcher.dart';

class MenuListWidget extends StatefulWidget {
  @override
  _MenuListWidgetState createState() => _MenuListWidgetState();
}

class _MenuListWidgetState extends State<MenuListWidget> {
  // Track expanded state for each expandable item
  Map<int, bool> expandedStates = {};

  // List of menu items with nested sub-items
  final List<Map<String, dynamic>> menuItems = [
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
    {
      'icon': Icons.analytics,
      'title': 'Call Analysis',
      'hasSubItems': true,
      'subItems': [
        {
          'title': 'Call Reports',
          'url':
              'https://www.youtube.com/watch?v=kcg_U_ubQgY&list=PLFyjjoCMAPtzn7tFLRV3eny7G74LnlMRt&index=8',
        },
        {'title': 'Performance Metrics', 'url': 'https://www.youtube.com/'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(FontAwesomeIcons.angleLeft, color: Colors.white, size: 20),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text('Tutorial', style: AppFont.appbarfontWhite(context)),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main Menu Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.colorsBlue.withOpacity(0.08),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: menuItems.length,
                separatorBuilder: (context, index) => Container(
                  height: 1,
                  color: AppColors.colorsBlue.withOpacity(0.1),
                  margin: EdgeInsets.only(left: 60),
                ),
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final isExpanded = expandedStates[index] ?? false;

                  return Column(
                    children: [
                      // Main item
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.colorsBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item['icon'],
                            size: 28,
                            color: AppColors.colorsBlue,
                          ),
                        ),
                        title: Text(
                          item['title'],
                          style: AppFont.dropDowmLabel(context),
                        ),
                        trailing: item['hasSubItems']
                            ? Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 24,
                                color: AppColors.colorsBlue,
                              )
                            : Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: AppColors.colorsBlue.withOpacity(0.6),
                              ),
                        onTap: () {
                          if (item['hasSubItems']) {
                            setState(() {
                              expandedStates[index] = !isExpanded;
                            });
                          } else {
                            _handleNavigation(item['title'], item['url']);
                          }
                        },
                      ),

                      // Sub-items (nested list)
                      if (item['hasSubItems'] && isExpanded)
                        Container(
                          color: Colors.grey[50],
                          child: Column(
                            children: (item['subItems'] as List).map<Widget>((
                              subItem,
                            ) {
                              return ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 80,
                                  right: 20,
                                  top: 4,
                                  bottom: 4,
                                ),
                                title: Text(
                                  subItem['title'],
                                  style: AppFont.dropDowmLabelLightcolors(
                                    context,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: AppColors.colorsBlue.withOpacity(0.4),
                                ),
                                onTap: () {
                                  _handleNavigation(
                                    subItem['title'],
                                    subItem['url'],
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(String title, String url) async {
    print('Navigating to: $title');
    print('URL: $url');

    // Launch URL using url_launcher
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // You can implement different navigation logic based on the item
    switch (title) {
      case 'Tutorial':
        // Get.to(() => BottomTutorial());
        print('Navigate to Tutorial: $url');
        break;
      case 'Call Analysis':
        print('Navigate to Call Analysis: $url');
        break;
      case 'Call Reports':
        // Handle YouTube URL or any specific navigation
        print('Navigate to Call Reports: $url');
        // You can use url_launcher here for external URLs
        // await launchUrl(Uri.parse(url));
        break;
      case 'Performance Metrics':
        print('Navigate to Performance Metrics: $url');
        break;
      case 'Dashboard':
        print('Navigate to Dashboard: $url');
        break;
      case 'Settings':
        print('Navigate to Settings: $url');
        break;
      case 'Account Settings':
        print('Navigate to Account Settings: $url');
        break;
      case 'Privacy Settings':
        print('Navigate to Privacy Settings: $url');
        break;
      case 'Push Notifications':
        print('Navigate to Push Notifications: $url');
        break;
      case 'FAQ':
        print('Navigate to FAQ: $url');
        break;
      case 'Contact Support':
        print('Navigate to Contact Support: $url');
        break;
      case 'Version Info':
        print('Navigate to Version Info: $url');
        break;
      default:
        print('Navigate to $title: $url');
        break;
    }
  }
}
