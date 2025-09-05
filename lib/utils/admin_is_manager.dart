import 'package:shared_preferences/shared_preferences.dart';

class AdminUserIdManager {
  static const String ADMIN_USER_ID_KEY = 'admin_user_id';

  // ✅ In-memory cache
  static String? _cachedAdminUserId;

  /// Save admin user ID
  static Future<void> saveAdminUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ADMIN_USER_ID_KEY, userId);
    _cachedAdminUserId = userId; // ✅ Keep in memory
  }

  /// Get admin user ID
  static Future<String?> getAdminUserId() async {
    if (_cachedAdminUserId != null) {
      return _cachedAdminUserId; // ✅ Fast return from memory
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedAdminUserId = prefs.getString(
      ADMIN_USER_ID_KEY,
    ); // ✅ Load from storage
    return _cachedAdminUserId;
  }

  //   static Future<String?> getAdminUserId() async {
  //   if (_cachedAdminUserId != null) return _cachedAdminUserId;
  //   final prefs = await SharedPreferences.getInstance();
  //   _cachedAdminUserId = prefs.getString(ADMIN_USER_ID_KEY);
  //   return _cachedAdminUserId;
  // }

  /// Clear admin user ID
  static Future<void> clearAdminUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ADMIN_USER_ID_KEY);
    _cachedAdminUserId = null; // ✅ Clear memory too
  }
}
