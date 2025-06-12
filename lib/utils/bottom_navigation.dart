import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:smartassist/pages/navbar_page/app_setting.dart';
import 'package:smartassist/pages/navbar_page/call_analytics.dart';
import 'package:smartassist/pages/navbar_page/call_logs.dart';
import 'package:smartassist/pages/navbar_page/favorite.dart';
import 'package:smartassist/pages/navbar_page/leads_all.dart';
import 'package:smartassist/pages/navbar_page/logout_page.dart';
import 'package:smartassist/pages/navbar_page/my_teams.dart';
import 'package:smartassist/widgets/profile_screen.dart';

// Import with alias to avoid conflicts
import 'package:smartassist/utils/navigation_controller.dart' as nav_utils;

class BottomNavigation extends StatelessWidget {
  BottomNavigation({super.key});

  final nav_utils.NavigationController controller = Get.put(
    nav_utils.NavigationController(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(() => controller.screens[controller.selectedIndex.value]),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Update the method to not require a parameter
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Obx(() {
            List<Widget> navItems = [];

            //  List<Widget> navItems = [
            //   _buildNavItem(
            //     icon: Icons.home,
            //     label: 'Home',
            //     index: 0,
            //     isIcon: true,
            //     isImg: false,
            //   ),
            // ];

            // Insert Teams navigation only for SM role
            if (controller.userRole.value == "SM") {
              navItems.add(
                _buildNavItem(
                  icon: Icons.people,
                  label: 'My Team',
                  index: 0,
                  isIcon: true,
                  isImg: false,
                ),
              );
              // Home comes second at index 1
              navItems.add(
                _buildNavItem(
                  icon: Icons.auto_graph,
                  label: 'Dashboard',
                  index: 1,
                  isIcon: true,
                  isImg: false,
                ),
              );
            }

            if (controller.userRole.value == "SM") {
              // SM users: show icon-based Calendar nav item
              navItems.add(
                _buildNavItem(
                  isImg: true,
                  isIcon: false,
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendar',
                  index: 2,
                  // isIcon: true,
                  img: Image.asset('assets/calendar.png', fit: BoxFit.contain),
                ),
              );
            } else {
              // Other users: show image-based Calendar nav item
              navItems.add(
                _buildNavItem(
                  isImg: true,
                  isIcon: false,
                  img: Image.asset('assets/calendar.png', fit: BoxFit.contain),
                  label: 'Calendar',
                  index: 1,
                ),
              );

              navItems.add(
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isIcon: true,
                  isImg: false,
                ),
              );
            }

            // Add Calendar - index needs to be adjusted based on whether Teams is present
            // int calendarIndex = controller.userRole.value == "SM" ? 2 : 1;
            // navItems.add(
            //   _buildNavItem(
            //     isImg: true,
            //     isIcon: false,
            //     img: Image.asset('assets/calendar.png', fit: BoxFit.contain),
            //     label: 'Calendar',
            //     index: calendarIndex,
            //   ),
            // );

            // Add More/Settings - index needs to be adjusted based on whether Teams is present
            int moreIndex = controller.userRole.value == "SM" ? 3 : 2;
            navItems.add(
              _buildNavItem(
                icon: Icons.more_horiz_sharp,
                label: 'More',
                index: moreIndex,
                isIcon: true,
                isImg: false,
                onTap: _showMoreBottomSheet,
              ),
            );

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems,
            );
          }),
        ),
      ),
    );
    //   child: SafeArea(
    //     child: Padding(
    //       padding: const EdgeInsets.symmetric(vertical: 0),
    //       child: Obx(
    //         () => Row(
    //           mainAxisAlignment: MainAxisAlignment.spaceAround,
    //           children: [
    //             _buildNavItem(
    //                 icon: Icons.home,
    //                 label: 'Home',
    //                 index: 0,
    //                 isIcon: true,
    //                 isImg: false),
    //             _buildNavItem(
    //                 icon: Icons.people_alt_outlined,
    //                 label: 'My Teams',
    //                 index: 1,
    //                 isIcon: true,
    //                 isImg: false),
    //             _buildNavItem(
    //                 isImg: true,
    //                 isIcon: false,
    //                 img: Image.asset(
    //                   'assets/calendar.png',
    //                   fit: BoxFit.contain,
    //                 ),
    //                 label: 'Calendar',
    //                 index: 2),
    //             _buildNavItem(
    //                 icon: Icons.settings,
    //                 label: 'More',
    //                 index: 3,
    //                 isIcon: true,
    //                 isImg: false,

    //                 onTap: _showMoreBottomSheet),
    //           ],
    //         ),
    //       ),
    //     ),
    //   ),
    // );
  }

  // Update this method to not require a controller parameter
  Widget _buildNavItem({
    Image? img,
    IconData? icon,
    required String label,
    required int index,
    bool isImg = false,
    bool isIcon = false,
    VoidCallback? onTap,
  }) {
    final isSelected = controller.selectedIndex.value == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (onTap != null) {
            onTap();
          } else {
            HapticFeedback.lightImpact();
            controller.selectedIndex.value = index;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isSelected ? 1.2 : 1.0,
                child: isImg && img != null
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            isSelected
                                ? AppColors.colorsBlue
                                : AppColors.iconGrey,
                            BlendMode.srcIn,
                          ),
                          child: img,
                        ),
                      )
                    : isIcon && icon != null
                    ? Icon(
                        icon,
                        color: isSelected
                            ? AppColors.colorsBlue
                            : AppColors.iconGrey,
                        size: 22,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? AppColors.colorsBlue : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Show Bottom Sheet for More options
  void _showMoreBottomSheet() async {
    // String? teamRole = await SharedPreferences.getInstance()
    //     .then((prefs) => prefs.getString('USER_ROLE'));

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        // height: teamRole == "Owner" ? 320 : 300,
        height: 310,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, size: 28),
              title: Text(
                'My Enquiries',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              onTap: () => Get.to(() => const AllLeads()),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined, size: 28),
              title: Text(
                'My Call Analysis',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              onTap: () => Get.to(
                () =>
                    const //CallLogs()
                    CallAnalytics(userId: '', userName: ''),
              ),
            ),
            // if (teamRole == "Owner")
            //   ListTile(
            //     leading: const Icon(Icons.group, size: 28),
            //     title:
            //         Text('My Team ', style: GoogleFonts.poppins(fontSize: 18)),
            //     onTap: () => Get.to(() => const MyTeams()),
            //   ),
            ListTile(
              leading: const Icon(Icons.star_border_rounded, size: 28),
              title: Text(
                'Favourites',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              onTap: () => Get.to(() => const FavoritePage(leadId: '')),
            ),
            // ListTile(
            //   leading: const Icon(Icons.person_outline, size: 28),
            //   title: Text('Profile', style: GoogleFonts.poppins(fontSize: 18)),
            //   onTap: () => Get.to(() => const ProfileScreen()),
            // ),
            // ListTile(
            //   leading: const Icon(Icons.settings_outlined, size: 28),
            //   title: Text('App Settings',
            //       style: GoogleFonts.poppins(fontSize: 18)),
            //   onTap: () => Get.to(() => const AppSetting()),
            // ),
            ListTile(
              leading: const Icon(Icons.logout_outlined, size: 28),
              title: Text('Logout', style: GoogleFonts.poppins(fontSize: 18)),
              onTap: () => Get.to(() => const LogoutPage()),
            ),
          ],
        ),
      ),
    );
  }
}

// SAAD ANSARI CODE ABOVE....FROM BELOW MY CODE

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:flutter/services.dart';
// import 'package:smartassist/pages/navbar_page/app_setting.dart';
// import 'package:smartassist/pages/navbar_page/call_analytics.dart';
// import 'package:smartassist/pages/navbar_page/call_logs.dart';
// import 'package:smartassist/pages/navbar_page/favorite.dart';
// import 'package:smartassist/pages/navbar_page/leads_all.dart';
// import 'package:smartassist/pages/navbar_page/logout_page.dart';
// import 'package:smartassist/pages/navbar_page/my_teams.dart';
// import 'package:smartassist/widgets/profile_screen.dart';

// // Import with alias to avoid conflicts
// import 'package:smartassist/utils/navigation_controller.dart' as nav_utils;

// class BottomNavigation extends StatelessWidget {
//   BottomNavigation({super.key});

//   final nav_utils.NavigationController controller = Get.put(
//     nav_utils.NavigationController(),
//   );

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Obx(() => controller.screens[controller.selectedIndex.value]),
//         ],
//       ),
//       bottomNavigationBar: _buildBottomNavigationBar(context),
//     );
//   }

//   // Add context parameter for responsive design
//   Widget _buildBottomNavigationBar(BuildContext context) {
//     final screenHeight = MediaQuery.of(context).size.height;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isSmallScreen = screenHeight < 600 || screenWidth < 350;

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 10,
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: ConstrainedBox(
//           constraints: BoxConstraints(
//             minHeight: isSmallScreen ? 60 : 70,
//             maxHeight: isSmallScreen ? 85 : 95, // Ensure maxHeight > minHeight
//           ),
//           child: Padding(
//             padding: EdgeInsets.symmetric(
//               vertical: isSmallScreen ? 4 : 8,
//               horizontal: 8,
//             ),
//             child: Obx(() {
//               List<Widget> navItems = [];

//               //               // Insert Teams navigation only for SM role
//               //               if (controller.userRole.value == "SM") {
//               //                 navItems.add(
//               //                   _buildNavItem(
//               //                     context: context,
//               //                     icon: Icons.people,
//               //                     label: 'My Team',
//               //                     index: 0,
//               //                     isIcon: true,
//               //                     isImg: false,
//               //                   ),
//               //                 );
//               //                 // Home comes second at index 1
//               //                 navItems.add(
//               //                   _buildNavItem(
//               //                     context: context,
//               //                     icon: Icons.auto_graph,
//               //                     label: 'Dashboard',
//               //                     index: 1,
//               //                     isIcon: true,
//               //                     isImg: false,
//               //                   ),
//               //                 );
//               //               }

//               //               if (controller.userRole.value == "SM") {
//               //                 // SM users: show icon-based Calendar nav item
//               //                 navItems.add(
//               //                   _buildNavItem(
//               //                     context: context,
//               //                     isImg: true,
//               //                     isIcon: false,
//               //                     icon: Icons.calendar_month_outlined,
//               //                     label: 'Calendar',
//               //                     index: 2,
//               //                     img: Image.asset('assets/calendar.png', fit: BoxFit.contain),
//               //                   ),
//               //                 );
//               //               } else {
//               //                 // Other users: show image-based Calendar nav item
//               //                 navItems.add(
//               //                   _buildNavItem(
//               //                     context: context,
//               //                     isImg: true,
//               //                     isIcon: false,
//               //                     img: Image.asset('assets/calendar.png', fit: BoxFit.contain),
//               //                     label: 'Calendar',
//               //                     index: 1,
//               //                   ),
//               //                 );

//               //                 navItems.add(
//               //                   _buildNavItem(
//               //                     context: context,
//               //                     icon: Icons.home,
//               //                     label: 'Home',
//               //                     index: 0,
//               //                     isIcon: true,
//               //                     isImg: false,
//               //                   ),
//               //                 );
//               //               }

//               //               // Add More/Settings - index needs to be adjusted based on whether Teams is present
//               //               int moreIndex = controller.userRole.value == "SM" ? 3 : 2;
//               //               navItems.add(
//               //                 _buildNavItem(
//               //                   context: context,
//               //                   icon: Icons.more_horiz_sharp,
//               //                   label: 'More',
//               //                   index: moreIndex,
//               //                   isIcon: true,
//               //                   isImg: false,
//               //                   onTap: _showMoreBottomSheet,
//               //                 ),
//               //               );
//               if (controller.userRole.value == "SM") {
//                 // SM users: show icon-based Calendar nav item
//                 navItems.add(
//                   _buildNavItem(
//                     context: context,
//                     isImg: true,
//                     isIcon: false,
//                     icon: Icons.calendar_month_outlined,
//                     label: 'Calendar',
//                     index: 2,
//                     // isIcon: true,
//                     img: Image.asset(
//                       'assets/calendar.png',
//                       fit: BoxFit.contain,
//                     ),
//                   ),
//                 );
//               } else {
//                 navItems.add(
//                   _buildNavItem(
//                     context: context,
//                     icon: Icons.home,
//                     label: 'Home',
//                     index: 0,
//                     isIcon: true,
//                     isImg: false,
//                   ),
//                 );
//                 // Other users: show image-based Calendar nav item
//                 navItems.add(
//                   _buildNavItem(
//                     context: context,
//                     isImg: true,
//                     isIcon: false,
//                     img: Image.asset(
//                       'assets/calendar.png',
//                       fit: BoxFit.contain,
//                     ),
//                     label: 'Calendar',
//                     index: 1,
//                   ),
//                 );
//               }

//               // Add More/Settings - index needs to be adjusted based on whether Teams is present
//               int moreIndex = controller.userRole.value == "SM" ? 3 : 2;
//               navItems.add(
//                 _buildNavItem(
//                   context: context,
//                   icon: Icons.more_horiz_sharp,
//                   label: 'More',
//                   index: moreIndex,
//                   isIcon: true,
//                   isImg: false,
//                   onTap: _showMoreBottomSheet,
//                 ),
//               );

//               return Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: navItems
//                     .map((item) => Flexible(child: item))
//                     .toList(),
//               );
//             }),
//           ),
//         ),
//       ),
//     );
//   }

//   // Update this method to include responsive sizing
//   Widget _buildNavItem({
//     required BuildContext context,
//     Image? img,
//     IconData? icon,
//     required String label,
//     required int index,
//     bool isImg = false,
//     bool isIcon = false,
//     VoidCallback? onTap,
//   }) {
//     final isSelected = controller.selectedIndex.value == index;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isSmallScreen = screenHeight < 600 || screenWidth < 350;

//     // Responsive sizing
//     final iconSize = isSmallScreen ? 18.0 : 22.0;
//     final fontSize = isSmallScreen ? 10.0 : 12.0;
//     final verticalPadding = isSmallScreen ? 2.0 : 5.0;
//     final horizontalPadding = isSmallScreen ? 2.0 : 5.0;
//     final spacing = isSmallScreen ? 2.0 : 4.0;
//     final imageSize = isSmallScreen ? 18.0 : 24.0;

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () {
//           if (onTap != null) {
//             onTap();
//           } else {
//             HapticFeedback.lightImpact();
//             controller.selectedIndex.value = index;
//           }
//         },
//         child: Padding(
//           padding: EdgeInsets.symmetric(
//             horizontal: horizontalPadding,
//             vertical: verticalPadding,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               AnimatedScale(
//                 duration: const Duration(milliseconds: 200),
//                 scale: isSelected ? (isSmallScreen ? 1.1 : 1.2) : 1.0,
//                 child: isImg && img != null
//                     ? SizedBox(
//                         height: imageSize,
//                         width: imageSize,
//                         child: ColorFiltered(
//                           colorFilter: ColorFilter.mode(
//                             isSelected
//                                 ? AppColors.colorsBlue
//                                 : AppColors.iconGrey,
//                             BlendMode.srcIn,
//                           ),
//                           child: img,
//                         ),
//                       )
//                     : isIcon && icon != null
//                     ? Icon(
//                         icon,
//                         color: isSelected
//                             ? AppColors.colorsBlue
//                             : AppColors.iconGrey,
//                         size: iconSize,
//                       )
//                     : const SizedBox.shrink(),
//               ),
//               SizedBox(height: spacing),
//               Flexible(
//                 child: Text(
//                   label,
//                   style: GoogleFonts.poppins(
//                     fontSize: fontSize,
//                     fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
//                     color: isSelected ? AppColors.colorsBlue : Colors.black54,
//                   ),
//                   textAlign: TextAlign.center,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Update bottom sheet to be responsive
//   void _showMoreBottomSheet() async {
//     final context = Get.context!;
//     final screenHeight = MediaQuery.of(context).size.height;
//     final calculatedHeight = screenHeight * 0.3; // 50% of screen height
//     final minHeight = 280.0;
//     final maxHeight = calculatedHeight > minHeight
//         ? calculatedHeight
//         : minHeight;

//     Get.bottomSheet(
//       Container(
//         padding: const EdgeInsets.all(16),
//         height: maxHeight,
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
//         ),
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Add a handle indicator
//               Container(
//                 width: 40,
//                 height: 4,
//                 margin: const EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[300],
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.receipt_long_rounded, size: 28),
//                 title: Text(
//                   'My Enquiries',
//                   style: GoogleFonts.poppins(fontSize: 18),
//                 ),
//                 onTap: () => Get.to(() => const AllLeads()),
//               ),

//               ListTile(
//                 leading: const Icon(Icons.call_outlined, size: 28),
//                 title: Text(
//                   'My Call Analysis',
//                   style: GoogleFonts.poppins(fontSize: 18),
//                 ),
//                 onTap: () =>
//                     Get.to(() => const CallAnalytics(userId: '', userName: '')),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.star_border_rounded, size: 28),
//                 title: Text(
//                   'Favourites',
//                   style: GoogleFonts.poppins(fontSize: 18),
//                 ),
//                 onTap: () => Get.to(() => const FavoritePage(leadId: '')),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.logout_outlined, size: 28),
//                 title: Text('Logout', style: GoogleFonts.poppins(fontSize: 18)),
//                 onTap: () => Get.to(() => const LogoutPage()),
//               ),
//             ],
//           ),
//         ),
//       ),
//       isScrollControlled: true,
//     );
//   }
// }
