import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// TokenManager.dart - Fixed class to handle authentication
class TokenManager {
  static const String TOKEN_KEY = 'auth_token';
  static const String USER_ID_KEY = 'user_id';
  static const String USER_ROLE = 'user_role';
  static const String USER_EMAIL = 'email';
  static const String ACCESS_KEY = 'access_token';
  static const String USER_ADMIN = 'admin';

  // Add this debugging method to check what's stored
  static Future<void> debugStoredValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(TOKEN_KEY);
    String? accessToken = prefs.getString(ACCESS_KEY);
    String? userId = prefs.getString(USER_ID_KEY);
    String? role = prefs.getString(USER_ROLE);
    String? email = prefs.getString(USER_EMAIL);
    bool? isAdmin = prefs.getBool(USER_ADMIN);

    print("DEBUG - Stored Values:");
    print("Token exists: ${token != null}");
    print("User ID: $userId");
    print("User Role: $role");
    print("User Role: $isAdmin");
    print("User Role: $accessToken");

    // Also check all keys in preferences to find mismatches
    print("All keys in SharedPreferences:");
    prefs.getKeys().forEach((key) {
      print("$key: ${prefs.get(key)}");
    });
  }

  // Check token validity without clearing or redirecting
  static Future<bool> isTokenValid() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(TOKEN_KEY);

      if (token == null) return false;

      bool isExpired = JwtDecoder.isExpired(token);
      return !isExpired;
    } catch (e) {
      print('Error checking token validity: $e');
      return false;
    }
  }

  // Save token and user data
  static Future<void> saveAuthData(
    String token,
    String accessToken,
    String userId,
    String userRole,
    String userEmail,
    bool isAdmin,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(TOKEN_KEY, token);
    await prefs.setString(ACCESS_KEY, accessToken);
    await prefs.setString(USER_ID_KEY, userId);
    await prefs.setString(USER_ROLE, userRole); // Fixed key usage
    await prefs.setString(USER_EMAIL, userEmail);
    await prefs.setBool(USER_ADMIN, isAdmin);

    // Verify it was saved
    print("Saved role: ${prefs.getString(USER_ROLE)}");
    print("Saved admin: ${prefs.getBool(USER_ADMIN)}");
    print("acesstoken: ${prefs.getString(ACCESS_KEY)}");
  }

  static Future<void> clearAuthData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(TOKEN_KEY);
    await prefs.remove(ACCESS_KEY);
    await prefs.remove(USER_ID_KEY);
    await prefs.remove(USER_ROLE);
  }

  // Get stored token
  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(TOKEN_KEY);
  }

  // Get stored token
  static Future<String?> getAcessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(ACCESS_KEY);
  }

  // Get user ID
  static Future<String?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_ID_KEY);
  }

  // Get user role
  static Future<String?> getUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_ROLE);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(USER_EMAIL);
  }

  // static Future<bool> getAdmin() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   return prefs.getBool(USER_ADMIN) ?? false;
  // }

  static Future<bool> getIsAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(USER_ADMIN) ?? false;
  }

  // ✅ Keep this method for backward compatibility
  static Future<bool> getAdmin() async {
    return await getIsAdmin();
  }
}

// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:jwt_decoder/jwt_decoder.dart';

// // TokenManager.dart - Fixed class to handle authentication
// class TokenManager {
//   static const String TOKEN_KEY = 'auth_token';
//   static const String USER_ID_KEY = 'user_id';
//   static const String USER_ROLE = 'user_role';
//   static const String USER_EMAIL = 'email';
//   static const String ACCESS_KEY = 'access_token';
//   static const String USER_ADMIN =
//       'is_admin'; // ✅ Changed key name for consistency

//   // Add this debugging method to check what's stored
//   static Future<void> debugStoredValues() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? token = prefs.getString(TOKEN_KEY);
//     String? accessToken = prefs.getString(ACCESS_KEY);
//     String? userId = prefs.getString(USER_ID_KEY);
//     String? role = prefs.getString(USER_ROLE);
//     String? email = prefs.getString(USER_EMAIL);
//     bool? isAdmin = prefs.getBool(USER_ADMIN);

//     print("DEBUG - Stored Values:");
//     print("Token exists: ${token != null}");
//     print("User ID: $userId");
//     print("User Role: $role");
//     print("Is Admin: $isAdmin");
//     print("Access Token: $accessToken");

//     // Also check all keys in preferences to find mismatches
//     print("All keys in SharedPreferences:");
//     prefs.getKeys().forEach((key) {
//       print("$key: ${prefs.get(key)}");
//     });
//   }

//   // Check token validity without clearing or redirecting
//   static Future<bool> isTokenValid() async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? token = prefs.getString(TOKEN_KEY);

//       if (token == null) return false;

//       bool isExpired = JwtDecoder.isExpired(token);
//       return !isExpired;
//     } catch (e) {
//       print('Error checking token validity: $e');
//       return false;
//     }
//   }

//   // ✅ Fixed parameter order to match your login code
//   static Future<void> saveAuthData(
//     String token, // authToken
//     String userId, // userId
//     String userRole, // userRole
//     String userEmail, // userEmail
//     String accessToken, // accessToken
//     bool isAdmin, // isAdmin
//   ) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setString(TOKEN_KEY, token);
//     await prefs.setString(ACCESS_KEY, accessToken);
//     await prefs.setString(USER_ID_KEY, userId);
//     await prefs.setString(USER_ROLE, userRole);
//     await prefs.setString(USER_EMAIL, userEmail);
//     await prefs.setBool(USER_ADMIN, isAdmin);

//     // Verify it was saved
//     print("Saved role: ${prefs.getString(USER_ROLE)}");
//     print("Saved admin: ${prefs.getBool(USER_ADMIN)}");
//     print("Access token: ${prefs.getString(ACCESS_KEY)}");
//   }

//   static Future<void> clearAuthData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.remove(TOKEN_KEY);
//     await prefs.remove(ACCESS_KEY);
//     await prefs.remove(USER_ID_KEY);
//     await prefs.remove(USER_ROLE);
//     await prefs.remove(USER_EMAIL);
//     await prefs.remove(USER_ADMIN); // ✅ Also clear admin status
//   }

//   // Get stored token
//   static Future<String?> getToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString(TOKEN_KEY);
//   }

//   // Get stored access token
//   static Future<String?> getAccessToken() async {
//     // ✅ Fixed typo
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString(ACCESS_KEY);
//   }

//   // Get user ID
//   static Future<String?> getUserId() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString(USER_ID_KEY);
//   }

//   // Get user role
//   static Future<String?> getUserRole() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString(USER_ROLE);
//   }

//   // Get user email
//   static Future<String?> getUserEmail() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString(USER_EMAIL);
//   }

//   // ✅ Added the missing getIsAdmin method
//   static Future<bool> getIsAdmin() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getBool(USER_ADMIN) ?? false;
//   }

//   // ✅ Keep this method for backward compatibility
//   static Future<bool> getAdmin() async {
//     return await getIsAdmin();
//   }
// }
