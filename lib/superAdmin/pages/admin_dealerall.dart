import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/login_steps/login_page.dart';
import 'package:smartassist/services/api_srv.dart' show LeadsSrv;
import 'package:smartassist/superAdmin/pages/admin_userlist.dart';
import 'package:smartassist/utils/admin_bottomnavigation.dart';
import 'package:smartassist/utils/admin_is_manager.dart';

class AdminDealerall extends StatefulWidget {
  const AdminDealerall({super.key});

  @override
  State<AdminDealerall> createState() => _AdminDealerallState();
}

class _AdminDealerallState extends State<AdminDealerall> {
  // Data variables
  List<Map<String, dynamic>> dealersWithUsers = [];

  // Loading states
  bool isDashboardLoading = true;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    fetchDealer();
  }

  Future<void> fetchDealer({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        isDashboardLoading = true;
      });
    } else {
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      final data = await LeadsSrv.fetchDealer();
      if (mounted) {
        setState(() {
          dealersWithUsers = List<Map<String, dynamic>>.from(
            data['dealersWithUsers'] ?? [],
          );
          isDashboardLoading = false;
          isRefreshing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Dashboard fetch error: $e');
      setState(() {
        isDashboardLoading = false;
        isRefreshing = false;
      });
    }
  }

  // void onDealerTapped(Map<String, dynamic> dealer) {
  //   final users = List<Map<String, dynamic>>.from(dealer['Users'] ?? []);

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => _buildUserSelectionModal(dealer, users),
  //   );
  // }
  void onDealerTapped(Map<String, dynamic> dealer) {
    final users = List<Map<String, dynamic>>.from(dealer['Users'] ?? []);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminUserlist(dealer: dealer, users: users),
      ),
    );
  }

  // void onUserSelected(
  //   Map<String, dynamic> user,
  //   Map<String, dynamic> dealer,
  // ) async {
  //   Navigator.of(context).pop(); // Close the modal first

  //   // ✅ Save the admin ID BEFORE navigation
  //   await AdminUserIdManager.saveAdminUserId(user['user_id']);
  //   await AdminUserIdManager.saveAdminRole(user['user_role']);

  //   // Now navigate
  //   navigateToUserDetails(user, dealer);
  // }

  void onUserSelected(
    Map<String, dynamic> user,
    Map<String, dynamic> dealer,
  ) async {
    Navigator.of(context).pop();

    // Save ID + Role, and WAIT until both are stored
    await AdminUserIdManager.saveAdminUserId(user['user_id']);
    await AdminUserIdManager.saveAdminRole(user['user_role']);

    // ✅ Only navigate after saving completes
    navigateToUserDetails(user, dealer);
  }

  void navigateToUserDetails(
    Map<String, dynamic> user,
    Map<String, dynamic> dealer,
  ) async {
    final adminId = await AdminUserIdManager.getAdminUserId();
    final role = await AdminUserIdManager.getAdminRole();
    print("mustafa chor: $adminId $role");

    print('Navigating to user: ${user['name']} from ${dealer['dealer_name']}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminBottomnavigation(role: user['user_role']),
      ),
    );
  }

  Widget _buildUserSelectionModal(
    Map<String, dynamic> dealer,
    List<Map<String, dynamic>> users,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Modal header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.colorsBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select User',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dealer['dealer_name'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Text(
              '${users.length} users available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Users list
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: users.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserListItem(
                        user,
                        dealer,
                        index == users.length - 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(
    Map<String, dynamic> user,
    Map<String, dynamic> dealer,
    bool isLast,
  ) {
    return InkWell(
      onTap: () => onUserSelected(user, dealer),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(top: 8, bottom: isLast ? 16 : 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with role
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.colorsBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  (user['user_role'] ?? 'U').toString().toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.colorsBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] ?? 'Unknown User',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? 'No email',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildDealerListItem(Map<String, dynamic> dealer, bool isLast) {
    final userCount = (dealer['Users'] as List?)?.length ?? 0;

    return InkWell(
      onTap: () => onDealerTapped(dealer),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: isLast ? 16 : 8,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dealer icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.colorsBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.store, size: 28, color: AppColors.colorsBlue),
            ),
            const SizedBox(width: 16),

            // Dealer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dealer['dealer_name'] ?? 'Unknown Dealer',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Code: ${dealer['dealer_code'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$userCount users',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // User count badge and arrow
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: userCount > 0
                        ? AppColors.colorsBlue.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$userCount',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: userCount > 0
                          ? AppColors.colorsBlue
                          : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.colorsBlue,
        title: Text('Dealers & Users', style: AppFont.appbarfontWhite(context)),
        actions: [
          IconButton(
            onPressed: () async {
              await AdminUserIdManager.clearAll(); // Step 2: clear ID

              if (!mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LoginPage(email: '', onLoginSuccess: () {}),
                ),
              );
            },
            tooltip: "Logout",
            icon: Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: isDashboardLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading dealers...'),
                ],
              ),
            )
          : Column(
              children: [
                // Stats header
                if (dealersWithUsers.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${dealersWithUsers.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.colorsBlue,
                              ),
                            ),
                            Text(
                              'Dealers',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        Column(
                          children: [
                            Text(
                              '${dealersWithUsers.fold<int>(0, (sum, dealer) => sum + ((dealer['Users'] as List?)?.length ?? 0))}',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.colorsBlue,
                              ),
                            ),
                            Text(
                              'Total Users',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Section header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Select a dealer to view users',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Dealers list
                Expanded(
                  child: dealersWithUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.store_mall_directory,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No dealers found',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => fetchDealer(isRefresh: true),
                          child: ListView.builder(
                            itemCount: dealersWithUsers.length,
                            itemBuilder: (context, index) {
                              final dealer = dealersWithUsers[index];
                              return _buildDealerListItem(
                                dealer,
                                index == dealersWithUsers.length - 1,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
