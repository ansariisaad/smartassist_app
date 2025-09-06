import 'package:shared_preferences/shared_preferences.dart';

class AdminUserIdManager {
  static const String ADMIN_USER_ID_KEY = 'admin_user_id';
  static const String USER_ROLE = 'user_role';

  // ✅ In-memory cache
  static String? _cachedAdminUserId;
  static String? _cachedAdminRole;

  /// Save admin user ID
  static Future<void> saveAdminUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ADMIN_USER_ID_KEY, userId);
    _cachedAdminUserId = userId; // ✅ Keep in memory
  }

  static Future<void> saveAdminRole(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(USER_ROLE, userRole);
    _cachedAdminRole = userRole; // ✅ Keep in memory
  }

  static Future<String?> getAdminRole() async {
    if (_cachedAdminRole != null) {
      return _cachedAdminRole; // ✅ Fast return from memory
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedAdminRole = prefs.getString(USER_ROLE);
    return _cachedAdminRole;
  }

  /// Get admin user ID
  static Future<String?> getAdminUserId() async {
    if (_cachedAdminUserId != null) {
      return _cachedAdminUserId; // ✅ Fast return from memory
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedAdminUserId = prefs.getString(ADMIN_USER_ID_KEY);
    return _cachedAdminUserId;
  }

  //   static Future<String?> getAdminUserId() async {
  //   if (_cachedAdminUserId != null) return _cachedAdminUserId;
  //   final prefs = await SharedPreferences.getInstance();
  //   _cachedAdminUserId = prefs.getString(ADMIN_USER_ID_KEY);
  //   return _cachedAdminUserId;
  // }

  /// Clear admin user ID
  // static Future<void> clearAdminUserId() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove(ADMIN_USER_ID_KEY);
  //   _cachedAdminUserId = null;
  // }
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ADMIN_USER_ID_KEY);
    await prefs.remove(USER_ROLE);
    _cachedAdminUserId = null;
    _cachedAdminRole = null;
  }

  //  static Future<void> clearAdminRole() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove(USER_ROLE);
  //   _cachedAdminRole = null;
  // }
}
