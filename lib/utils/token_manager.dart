import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// Updated TokenManager.dart - Enhanced class to handle both access and refresh tokens
class TokenManager {
  static const String ACCESS_TOKEN_KEY = 'access_token';
  static const String REFRESH_TOKEN_KEY = 'refresh_token';
  static const String USER_ID_KEY = 'user_id';
  static const String USER_ROLE = 'user_role';
  static const String USER_EMAIL = 'user_email';

  // Add this debugging method to check what's stored
  static Future<void> debugStoredValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString(ACCESS_TOKEN_KEY);
    String? refreshToken = prefs.getString(REFRESH_TOKEN_KEY);
    String? userId = prefs.getString(USER_ID_KEY);
    String? role = prefs.getString(USER_ROLE);
    String? email = prefs.getString(USER_EMAIL);

    print("DEBUG - Stored Values:");
    print("Access Token exists: ${accessToken != null}");
    print("Refresh Token exists: ${refreshToken != null}");
    print("User ID: $userId");
    print("User Role: $role");
    print("User Email: $email");

    // Also check all keys in preferences to find mismatches
    print("All keys in SharedPreferences:");
    prefs.getKeys().forEach((key) {
      print("$key: ${prefs.get(key)}");
    });
  }

  // Check if access token is valid
  static Future<bool> isTokenValid() async {
    try {
      String? token = await getAccessToken();
      if (token == null) return false;

      bool isExpired = JwtDecoder.isExpired(token);
      return !isExpired;
    } catch (e) {
      print('Error checking token validity: $e');
      return false;
    }
  }

  // Check if refresh token is valid
  static Future<bool> isRefreshTokenValid() async {
    try {
      String? token = await getRefreshToken();
      if (token == null) return false;

      bool isExpired = JwtDecoder.isExpired(token);
      return !isExpired;
    } catch (e) {
      print('Error checking refresh token validity: $e');
      return false;
    }
  }

  // Save authentication data including both tokens
  static Future<void> saveAuthData(
    String accessToken,
    String refreshToken,
    String userId,
    String userRole,
    String userEmail,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(ACCESS_TOKEN_KEY, accessToken);
    await prefs.setString(REFRESH_TOKEN_KEY, refreshToken);
    await prefs.setString(USER_ID_KEY, userId);
    await prefs.setString(USER_ROLE, userRole);
    await prefs.setString(USER_EMAIL, userEmail);

    // Verify it was saved
    print("Saved access token: ${accessToken.substring(0, 200)}...");
    print("Saved refresh token: ${refreshToken.substring(0, 200)}...");
    print("Saved role: ${prefs.getString(USER_ROLE)}");
  }

  // Clear all authentication data
  static Future<void> clearAuthData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(ACCESS_TOKEN_KEY);
    await prefs.remove(REFRESH_TOKEN_KEY);
    await prefs.remove(USER_ID_KEY);
    await prefs.remove(USER_ROLE);
    await prefs.remove(USER_EMAIL);
    print("Auth data cleared");
  }

  // Get stored access token
  static Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(ACCESS_TOKEN_KEY);
  }

  // Get stored refresh token
  static Future<String?> getRefreshToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // print('this is refresh manger $')
    return prefs.getString(REFRESH_TOKEN_KEY);
  }

  // Update only the access token (useful after refresh)
  static Future<void> updateAccessToken(String newAccessToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(ACCESS_TOKEN_KEY, newAccessToken);
    print("Access token updated: ${newAccessToken.substring(0, 20)}...");
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

  // Check if user is logged in (has valid access token or valid refresh token)
  static Future<bool> isLoggedIn() async {
    bool hasValidAccessToken = await isTokenValid();
    if (hasValidAccessToken) return true;

    // If access token is invalid, check if refresh token is valid
    bool hasValidRefreshToken = await isRefreshTokenValid();
    return hasValidRefreshToken;
  }

  // Get token expiration time
  static Future<DateTime?> getTokenExpirationTime() async {
    try {
      String? token = await getAccessToken();
      if (token == null) return null;

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      int? exp = decodedToken['exp'];
      if (exp != null) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      return null;
    } catch (e) {
      print('Error getting token expiration: $e');
      return null;
    }
  }

  // Get refresh token expiration time
  static Future<DateTime?> getRefreshTokenExpirationTime() async {
    try {
      String? token = await getRefreshToken();
      if (token == null) return null;

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      int? exp = decodedToken['exp'];
      if (exp != null) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      return null;
    } catch (e) {
      print('Error getting refresh token expiration: $e');
      return null;
    }
  }

  // Get user data from token
  static Future<Map<String, dynamic>?> getUserDataFromToken() async {
    try {
      String? token = await getAccessToken();
      if (token == null) return null;

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return {
        'userId': decodedToken['userId'],
        'role': decodedToken['role'],
        'userEmail': decodedToken['userEmail'],
        'fname': decodedToken['fname'],
        'lname': decodedToken['lname'],
        'dealerId': decodedToken['dealerId'],
      };
    } catch (e) {
      print('Error decoding token: $e');
      return null;
    }
  }
}

// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:jwt_decoder/jwt_decoder.dart';

// // TokenManager.dart - Fixed class to handle authentication
// class TokenManager {
//   static const String TOKEN_KEY = 'auth_token';
//   static const String USER_ID_KEY = 'user_id';
//   static const String USER_ROLE = 'user_role';
//   static const String USER_EMAIL = 'email'; // Fixed key name to be consistent

//   // Add this debugging method to check what's stored
//   static Future<void> debugStoredValues() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? token = prefs.getString(TOKEN_KEY);
//     String? userId = prefs.getString(USER_ID_KEY);
//     String? role = prefs.getString(USER_ROLE);
//     String? email = prefs.getString(USER_EMAIL);

//     print("DEBUG - Stored Values:");
//     print("Token exists: ${token != null}");
//     print("User ID: $userId");
//     print("User Role: $role");

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

//   // Save token and user data
//   static Future<void> saveAuthData(
//     String token,
//     String userId,
//     String userRole,
//     String userEmail,
//   ) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setString(TOKEN_KEY, token);
//     await prefs.setString(USER_ID_KEY, userId);
//     await prefs.setString(USER_ROLE, userRole); // Fixed key usage
//     await prefs.setString(USER_EMAIL, userEmail);

//     // Verify it was saved
//     print("Saved role: ${prefs.getString(USER_ROLE)}");
//   }

//   static Future<void> clearAuthData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.remove(TOKEN_KEY);
//     await prefs.remove(USER_ID_KEY);
//     await prefs.remove(USER_ROLE);
//   }

//   // Get stored token
//   static Future<String?> getToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString(TOKEN_KEY);
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
// }
