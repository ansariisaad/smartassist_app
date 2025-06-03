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
                  icon: Icons.people_alt_outlined,
                  label: 'My Teams',
                  index: 0,
                  isIcon: true,
                  isImg: false,
                ),
              );
              // Home comes second at index 1
              navItems.add(
                _buildNavItem(
                  icon: Icons.home,
                  label: 'Home',
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
                  icon: Icons.people_alt_outlined,
                  label: 'My Calendar',
                  index: 2,
                  isIcon: true,
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
                icon: Icons.settings,
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
              leading: const Icon(Icons.people_alt_outlined, size: 28),
              title: Text(
                'My Enquiries',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              onTap: () => Get.to(() => const AllLeads()),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined, size: 28),
              title: Text(
                'My Call Analytics',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              onTap: () => Get.to(
                () =>
                    const //CallLogs()
                    CallAnalytics(userId: ''),
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
