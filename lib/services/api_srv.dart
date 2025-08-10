import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/model/login/login_model.dart';
import 'package:smartassist/config/route/route_name.dart';
import 'package:smartassist/pages/login_steps/login_page.dart';
import 'package:smartassist/utils/connection_service.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/utils/token_manager.dart';

class LeadsSrv {
  static const String baseUrl = 'https://api.smartassistapp.in/api/';
  static final ConnectionService _connectionService = ConnectionService();

  static Future<Map<String, dynamic>> onLogin(Map<String, dynamic> body) async {
    const url = '${baseUrl}login';
    final uri = Uri.parse(url);

    try {
      final response = await http.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          responseData['status'] == 200 &&
          responseData.containsKey('data')) {
        final data = responseData['data'];
        final String accessToken = data['accessToken'];
        final String refreshToken = data['refreshToken'];
        final Map<String, dynamic>? user = data['user'];

        // DEBUG: Print the tokens we're about to save
        print('🔑 ACCESS TOKEN TO SAVE: ${accessToken.substring(0, 50)}...');
        print('🔄 REFRESH TOKEN TO SAVE: ${refreshToken.substring(0, 50)}...');
        print('👤 USER DATA: ${user?['user_id']} - ${user?['email']}');

        if (user != null && accessToken.isNotEmpty && refreshToken.isNotEmpty) {
          // Save both tokens using TokenManager
          await TokenManager.saveAuthData(
            accessToken,
            refreshToken,
            user['user_id'] ?? '',
            user['user_role'] ?? '',
            user['email'] ?? '',
          );

          // VERIFY tokens were saved correctly
          final savedAccessToken = await TokenManager.getAccessToken();
          final savedRefreshToken = await TokenManager.getRefreshToken();
          print(
            '✅ VERIFIED ACCESS TOKEN SAVED: ${savedAccessToken?.substring(0, 50)}...',
          );
          print(
            '✅ VERIFIED REFRESH TOKEN SAVED: ${savedRefreshToken?.substring(0, 50)}...',
          );

          return {
            'isSuccess': true,
            'accessToken': accessToken,
            'refreshToken': refreshToken,
            'user': user,
            'message': responseData['message'],
          };
        } else {
          print(
            '❌ ERROR: Missing required data - user: ${user != null}, accessToken: ${accessToken.isNotEmpty}, refreshToken: ${refreshToken.isNotEmpty}',
          );
          return {
            'isSuccess': false,
            'message': 'Required authentication data missing in response',
          };
        }
      } else {
        return {
          'isSuccess': false,
          'message': responseData['message'] ?? 'Login failed',
        };
      }
    } catch (error) {
      print('❌ LOGIN ERROR: $error');
      return {'isSuccess': false, 'error': error.toString()};
    }
  }

  // Updated login method to return TokenModel
  static Future<TokenModel> login(Map<String, dynamic> map) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}login'),
        body: jsonEncode(map),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tokenModel = TokenModel.fromJson(data);

        // Save tokens after successful login
        await TokenManager.saveAuthData(
          tokenModel.data.accessToken,
          tokenModel.data.refreshToken,
          tokenModel.data.user.userId,
          tokenModel.data.user.userRole,
          tokenModel.data.user.email,
        );

        return tokenModel;
      } else {
        throw Exception('Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during login: $e');
    }
  }

  // Method to refresh access token using refresh token
  static Future<String?> refreshAccessToken() async {
    try {
      // Debug what we have stored
      await TokenManager.debugStoredValues();
      final refreshToken = await TokenManager.getRefreshToken();
      print('🔄 REFRESH TOKEN FROM STORAGE: $refreshToken');

      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ NO REFRESH TOKEN AVAILABLE');
        throw Exception('No refresh token available');
      }

      print('🌐 MAKING REFRESH REQUEST TO: ${baseUrl}refresh-token');

      final response = await http.post(
        Uri.parse('${baseUrl}refresh-token'),
        headers: {
          'Authorization':
              'Bearer $refreshToken', // ✅ FIXED: Added "Bearer " prefix
          'Content-Type': 'application/json',
        },
      );

      print('📡 REFRESH RESPONSE STATUS: ${response.statusCode}');
      print('📡 REFRESH RESPONSE BODY: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ FIXED: Updated to match your API response structure
        final newAccessToken =
            data['data']?['accessToken']; // Note: data.accessToken, not just accessToken

        print(
          '🆕 NEW ACCESS TOKEN RECEIVED: ${newAccessToken?.substring(0, 50)}...',
        );

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          // Update only the access token, keep other data
          final currentUserId = await TokenManager.getUserId();
          final currentUserRole = await TokenManager.getUserRole();
          final currentUserEmail = await TokenManager.getUserEmail();

          await TokenManager.saveAuthData(
            newAccessToken,
            refreshToken, // Keep the same refresh token
            currentUserId ?? '',
            currentUserRole ?? '',
            currentUserEmail ?? '',
          );

          print('✅ ACCESS TOKEN UPDATED SUCCESSFULLY');
          return newAccessToken;
        } else {
          print('❌ NEW ACCESS TOKEN IS NULL OR EMPTY');
        }
      } else {
        print('❌ REFRESH FAILED WITH STATUS: ${response.statusCode}');
        print('❌ REFRESH ERROR BODY: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ ERROR REFRESHING TOKEN: $e');
      return null;
    }
  }

  // Method to make authenticated HTTP requests with automatic token refresh
  static Future<http.Response> authenticatedRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    Map<String, String>? queryParams, // NEW: Add query parameters support
  }) async {
    String? accessToken = await TokenManager.getAccessToken();

    if (accessToken == null || !await TokenManager.isTokenValid()) {
      // Try to refresh the token
      accessToken = await refreshAccessToken();
      print('access token $accessToken');
      if (accessToken == null) {
        await TokenManager.clearAuthData();
        throw Exception('Authentication failed - please login again');
      }
    }

    // Build URI with query parameters
    Uri uri;
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
    } else {
      uri = Uri.parse('$baseUrl$endpoint');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      ...?additionalHeaders,
    };

    print('Making ${method.toUpperCase()} request to: $uri');
    print('Headers: $headers');

    http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // If we get 401, try to refresh token once
    if (response.statusCode == 401) {
      final newAccessToken = await refreshAccessToken();
      if (newAccessToken != null) {
        // Retry the request with new token
        headers['Authorization'] = 'Bearer $newAccessToken';
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: headers);
            break;
          case 'POST':
            response = await http.post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: headers);
            break;
        }
      } else {
        // Refresh failed, clear auth data
        await TokenManager.clearAuthData();
        throw Exception('Session expired - please login again');
      }
    }

    return response;
  }

  static Future<http.Response> authenticatedMultipartRequest({
    required String method,
    required String endpoint,
    required File file,
    String fieldName = 'file',
    Map<String, String>? additionalFields,
    Map<String, String>? additionalHeaders,
  }) async {
    String? accessToken = await TokenManager.getAccessToken();

    if (accessToken == null || !await TokenManager.isTokenValid()) {
      // Try to refresh the token
      accessToken = await refreshAccessToken();
      print('access token $accessToken');
      if (accessToken == null) {
        await TokenManager.clearAuthData();
        throw Exception('Authentication failed - please login again');
      }
    }

    final uri = Uri.parse('$baseUrl$endpoint');

    final request = http.MultipartRequest(method.toUpperCase(), uri)
      ..headers['Authorization'] = 'Bearer $accessToken';

    // Add additional headers if provided
    if (additionalHeaders != null) {
      request.headers.addAll(additionalHeaders);
    }

    // Add the file
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: MediaType('image', 'jpeg'), // Adjust based on file type
      ),
    );

    // Add additional fields if provided
    if (additionalFields != null) {
      request.fields.addAll(additionalFields);
    }

    print('Making ${method.toUpperCase()} multipart request to: $uri');
    print('Headers: ${request.headers}');

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Handle 401 responses - retry with refreshed token
      if (response.statusCode == 401) {
        final newAccessToken = await refreshAccessToken();
        if (newAccessToken != null) {
          // Retry the request with new token
          final retryRequest = http.MultipartRequest(method.toUpperCase(), uri)
            ..headers['Authorization'] = 'Bearer $newAccessToken';

          if (additionalHeaders != null) {
            retryRequest.headers.addAll(additionalHeaders);
          }

          retryRequest.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              file.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );

          if (additionalFields != null) {
            retryRequest.fields.addAll(additionalFields);
          }

          final retryStreamedResponse = await retryRequest.send();
          return await http.Response.fromStream(retryStreamedResponse);
        } else {
          await TokenManager.clearAuthData();
          throw Exception('Session expired - please login again');
        }
      }

      return response;
    } catch (e) {
      print('Error in multipart request: $e');
      rethrow;
    }
  }

  // static Future<http.Response> authenticatedRequest({
  //   required String method,
  //   required String endpoint,
  //   Map<String, dynamic>? body,
  //   Map<String, String>? additionalHeaders,
  //   Map<String, String>? queryParams,
  // }) async {
  //   String? accessToken = await TokenManager.getAccessToken();

  //   if (accessToken == null || !await TokenManager.isTokenValid()) {
  //     // Try to refresh the token
  //     accessToken = await refreshAccessToken();
  //     print('access token $accessToken');
  //     if (accessToken == null) {
  //       await TokenManager.clearAuthData();
  //       throw Exception('Authentication failed - please login again');
  //     }
  //   }

  //   final headers = {
  //     'Content-Type': 'application/json',
  //     'Authorization': 'Bearer $accessToken',
  //     ...?additionalHeaders,
  //   };

  //   final uri = Uri.parse('$baseUrl$endpoint');

  //   http.Response response;

  //   switch (method.toUpperCase()) {
  //     case 'GET':
  //       response = await http.get(uri, headers: headers);
  //       break;
  //     case 'POST':
  //       response = await http.post(
  //         uri,
  //         headers: headers,
  //         body: body != null ? jsonEncode(body) : null,
  //       );
  //       break;
  //     case 'PUT':
  //       response = await http.put(
  //         uri,
  //         headers: headers,
  //         body: body != null ? jsonEncode(body) : null,
  //       );
  //       break;
  //     case 'DELETE':
  //       response = await http.delete(uri, headers: headers);
  //       break;
  //     default:
  //       throw Exception('Unsupported HTTP method: $method');
  //   }

  //   // If we get 401, try to refresh token once
  //   if (response.statusCode == 401) {
  //     final newAccessToken = await refreshAccessToken();
  //     if (newAccessToken != null) {
  //       // Retry the request with new token
  //       headers['Authorization'] = 'Bearer $newAccessToken';

  //       switch (method.toUpperCase()) {
  //         case 'GET':
  //           response = await http.get(uri, headers: headers);
  //           break;
  //         case 'POST':
  //           response = await http.post(
  //             uri,
  //             headers: headers,
  //             body: body != null ? jsonEncode(body) : null,
  //           );
  //           break;
  //         case 'PUT':
  //           response = await http.put(
  //             uri,
  //             headers: headers,
  //             body: body != null ? jsonEncode(body) : null,
  //           );
  //           break;
  //         case 'DELETE':
  //           response = await http.delete(uri, headers: headers);
  //           break;
  //       }
  //     } else {
  //       // Refresh failed, clear auth data
  //       await TokenManager.clearAuthData();
  //       throw Exception('Session expired - please login again');
  //     }
  //   }

  //   return response;
  // }

  static Future<void> handleUnauthorizedIfNeeded(
    int statusCode,
    String errorMessage,
  ) async {
    if (statusCode == 401 ||
        errorMessage.toLowerCase().contains("unauthorized")) {
      await TokenManager.clearAuthData();
      await Future.delayed(Duration(seconds: 2));
      Get.offAll(() => LoginPage(email: '', onLoginSuccess: () {}));
      showErrorMessageGetx(
        message:
            "You have been logged out because your account was used on another device.",
      );
      throw Exception('Unauthorized. Redirecting to login.');
    }
  }

  // Add this to your API helper file
  static Future<http.Response> makeAuthenticatedRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final token = await Storage.getToken();

    final defaultHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }

    http.Response response;

    if (method.toUpperCase() == 'GET') {
      response = await http.get(Uri.parse(url), headers: defaultHeaders);
    } else if (method.toUpperCase() == 'POST') {
      response = await http.post(
        Uri.parse(url),
        headers: defaultHeaders,
        body: body,
      );
    } else if (method.toUpperCase() == 'PUT') {
      response = await http.put(
        Uri.parse(url),
        headers: defaultHeaders,
        body: body,
      );
    } else if (method.toUpperCase() == 'DELETE') {
      response = await http.delete(Uri.parse(url), headers: defaultHeaders);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    // Handle 401 here for ALL API calls
    if (response.statusCode == 401) {
      await TokenManager.clearAuthData();
      Get.offAllNamed(RoutesName.login);

      Future.delayed(Duration(milliseconds: 300), () {
        Get.snackbar(
          'Session Expired',
          "Please login again",
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );
      });

      throw Exception('Unauthorized. Redirecting to login.');
    }

    return response;
  }

  // mustafa.sayyed@ariantechsolutions.com
  // Testing@01
  static Future<Map<String, dynamic>> verifyEmail(Map body) async {
    const url = '${baseUrl}login/verify-email';
    final uri = Uri.parse(url);

    try {
      final response = await http.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      print(uri);

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'isSuccess': true, 'data': decoded};
      } else {
        // Try to get message from backend response
        return {
          'isSuccess': false,
          'message': decoded['message'] ?? 'Something went wrong',
          'data': decoded,
        };
      }
    } catch (error) {
      print('Error: $error');
      return {
        'isSuccess': false,
        'message': 'Network error occurred',
        'error': error.toString(),
      };
    }
  }

  // static Future<Map<String, dynamic>> verifyEmail(Map body) async {
  //   const url = '${baseUrl}login/verify-email';
  //   final uri = Uri.parse(url);

  //   try {
  //     final response = await http.post(
  //       uri,
  //       body: jsonEncode(body),
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     // Log the response for debugging
  //     print('API Status Code: ${response.statusCode}');
  //     print('API Response Body: ${response.body}');
  //     print(uri);

  //     if (response.statusCode == 200) {
  //       return {'isSuccess': true, 'data': jsonDecode(response.body)};
  //     } else {
  //       return {'isSuccess': false, 'data': jsonDecode(response.body)};
  //     }
  //   } catch (error) {
  //     // Log any error that occurs during the API call
  //     print('Error: $error');
  //     return {'isSuccess': false, 'error': error.toString()};
  //   }
  // }

  static Future<Map<String, dynamic>> forgetPwd(Map body) async {
    const url = '${baseUrl}login/forgot-pwd/verify-email';
    final uri = Uri.parse(url);

    try {
      final response = await http.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the response for debugging
      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return {'isSuccess': true, 'data': jsonDecode(response.body)};
      } else {
        return {'isSuccess': false, 'data': jsonDecode(response.body)};
      }
    } catch (error) {
      // Log any error that occurs during the API call
      print('Error: $error');
      return {'isSuccess': false, 'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(Map body) async {
    const url = '${baseUrl}login/verify-otp';
    final uri = Uri.parse(url);

    try {
      final response = await http.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the response for debugging
      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Parsed verification response: $responseData');
        return {'isSuccess': true, 'data': responseData};
      } else {
        final errorData = jsonDecode(response.body);
        print('Error verification response: $errorData');
        return {'isSuccess': false, 'data': errorData};
      }
    } catch (error) {
      print('Error during OTP verification: $error');
      return {'isSuccess': false, 'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> forgetOtp(Map body) async {
    const url = '${baseUrl}events/forgot-pwd/verify-otp';
    final uri = Uri.parse(url);

    try {
      final response = await http.post(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the response for debugging
      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Parsed verification response: $responseData');
        return {'isSuccess': true, 'data': responseData};
      } else {
        final errorData = jsonDecode(response.body);
        print('Error verification response: $errorData');
        return {'isSuccess': false, 'data': errorData};
      }
    } catch (error) {
      print('Error during OTP verification: $error');
      return {'isSuccess': false, 'error': error.toString()};
    }
  }

  // login api

  // static Future<Map<String, dynamic>> onLogin(Map body) async {
  //   const url = '${baseUrl}login';
  //   final uri = Uri.parse(url);

  //   try {
  //     final response = await http.post(
  //       uri,
  //       body: jsonEncode(body),
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     print('API Status Code: ${response.statusCode}');
  //     print('API Response Body: ${response.body}');

  //     final responseData = jsonDecode(response.body);

  //     // Check for success in both HTTP status and response body
  //     if (response.statusCode == 200 &&
  //         responseData['status'] == 200 &&
  //         responseData.containsKey('data')) {
  //       final data = responseData['data'];
  //       final String token = data['token'];
  //       final Map<String, dynamic>? user = data['user'];

  //       // Save token for subsequent calls.
  //       await Storage.saveToken(token);

  //       if (user != null) {
  //         return {'isSuccess': true, 'token': token, 'user': user};
  //       } else {
  //         return {
  //           'isSuccess': false,
  //           'message': 'User data missing in response',
  //         };
  //       }
  //     } else {
  //       // Return the backend error message if available.
  //       return {
  //         'isSuccess': false,
  //         'message': responseData['message'] ?? 'Login failed',
  //       };
  //     }
  //   } catch (error) {
  //     print('Error: $error');
  //     return {'isSuccess': false, 'error': error.toString()};
  //   }
  // }

  static Future<Map<String, dynamic>> setPwd(Map body) async {
    const url = '${baseUrl}login/create-pwd';
    final uri = Uri.parse(url);

    try {
      final response = await http.put(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the response for debugging
      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Parsed response data: $responseData');
        return {'isSuccess': true, 'data': responseData};
      } else {
        final errorData = jsonDecode(response.body);
        print('Error response: $errorData');
        return {'isSuccess': false, 'data': errorData};
      }
    } catch (error) {
      // Log any error that occurs during the API call
      print('Error in setPwd: $error');
      return {'isSuccess': false, 'error': error.toString()};
    }
  }

  static Future<Map<String, dynamic>> setNewPwd(Map body) async {
    const url = '${baseUrl}login/forgot-pwd/new-pwd';
    final uri = Uri.parse(url);

    try {
      final response = await http.put(
        uri,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the response for debugging
      print('API Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('Parsed response data: $responseData');
        return {'isSuccess': true, 'data': responseData};
      } else {
        final errorData = jsonDecode(response.body);
        print('Error response: $errorData');
        return {'isSuccess': false, 'data': errorData};
      }
    } catch (error) {
      // Log any error that occurs during the API call
      print('Error in setPwd: $error');
      return {'isSuccess': false, 'error': error.toString()};
    }
  }

  static Future<List?> loadFollowups(Map body) async {
    // const url = '${baseUrl}admin/leads/all';

    // final uri = Uri.parse(url);

    // final response = await http.get(uri);
    final response = await authenticatedRequest(
      method: 'GET',
      endpoint: 'admin/leads/all',
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map;
      final result = json['items'] as List;
      return result;
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final String errorMessage =
          errorData['message'] ?? 'Failed to load dashboard data';

      await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
      ();
      return null;
    }
  }

  //fetch users
  // Add this method to your LeadsSrv class
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final token = await Storage.getToken();
    try {
      // print('🔍 Fetching users from: ${baseUrl}admin/users/all');
      // print('🔑 Using token: ${token?.substring(0, 10)}...');

      // final response = await http.get(
      //   Uri.parse('${baseUrl}admin/users/all'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'admin/users/all',
      );

      print('📊 Response status code: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if the response has the expected structure
        if (data['data'] != null && data['data']['rows'] != null) {
          final rows = data['data']['rows'] as List;
          print('✅ Found ${rows.length} users');

          // Convert to List<Map<String, dynamic>>
          return List<Map<String, dynamic>>.from(rows);
        } else {
          print('❌ Unexpected response structure: $data');
          throw Exception('Invalid response structure - missing data.rows');
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error body: ${response.body}');
        throw Exception(
          'Failed to fetch users. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (error) {
      print('💥 Error in fetchUsers: $error');
      rethrow; // Re-throw so the UI can handle it
    }
  }
  //end

  static Future<List<String>> fetchDropdownOptions() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'admin/users/all',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return List<String>.from(data['options']);
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to fetch options');
      }
    } catch (error) {
      print('Error fetching options: $error');
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchProfileData() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/show-profile',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchTeamData() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/sm/analytics/team-dashboard',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchSlot(String vehicleId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'slots/$vehicleId/slots/all',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchLead() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/all',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchAllTasks() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'tasks/all-tasks',
        additionalHeaders: {
          'X-Request-Type': 'all-tasks',
          'X-Include-Counts': 'true',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // ✅ ENHANCED: Return the full response with success indicator
        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchAppointment() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'tasks/all-appointments',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // ✅ ENHANCED: Return the full response with success indicator
        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchTestdrive() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'events/all-events',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // ✅ ENHANCED: Return the full response with success indicator
        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchFavFollowups() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'favourites/follow-ups/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchTasksData() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/fetch/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchTestDriveData({
    String? eventId,
    String? completedEventId,
    bool isFromTestdrive = true,
  }) async {
    try {
      // Determine which eventId to use
      String targetEventId = isFromTestdrive
          ? (eventId ?? '')
          : (completedEventId ?? '');

      if (targetEventId.isEmpty) {
        return {
          'success': false,
          'data': {},
          'message': 'Event ID is required',
        };
      }

      String endpoint = 'events/$targetEventId';

      print('Fetching test drive data from endpoint: $endpoint');

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Test drive data fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load test drive data';

        print("Failed to load test drive data: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching test drive data: $e');
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchDashboardDataAn({
    String? timeRange,
    String? userId,
    bool isFromSM = false,
  }) async {
    try {
      // Build the endpoint with parameters
      String endpoint = 'users/ps/dashboard/call-analytics';

      // Add time range parameter
      String periodParam = '';
      switch (timeRange) {
        case '1D':
          periodParam = '?type=DAY';
          break;
        case '1W':
          periodParam = '?type=WEEK';
          break;
        case '1M':
          periodParam = '?type=MTD';
          break;
        case '1Q':
          periodParam = '?type=QTD';
          break;
        case '1Y':
          periodParam = '?type=YTD';
          break;
        default:
          periodParam = '?type=DAY';
      }

      // Add user_id parameter if needed
      if (isFromSM && userId != null) {
        periodParam += '&user_id=$userId';
      }

      endpoint += periodParam;

      print('API Endpoint: $endpoint'); // Debug print

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse,
          'message': 'Dashboard data fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';

        print("Failed to load dashboard data: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchSingleCalllogTeams({
    String? timeRange,
    String? userId,
    bool isFromSM = false, // Add this parameter
  }) async {
    try {
      // Build the endpoint with parameters
      String endpoint = 'users/ps/dashboard/call-analytics';

      // Add time range parameter
      String periodParam = '';
      switch (timeRange) {
        case '1D':
          periodParam = '?type=DAY';
          break;
        case '1W':
          periodParam = '?type=WEEK';
          break;
        case '1M':
          periodParam = '?type=MTD';
          break;
        case '1Q':
          periodParam = '?type=QTD';
          break;
        case '1Y':
          periodParam = '?type=YTD';
          break;
        default:
          periodParam = '?type=DAY';
      }

      // Add user_id parameter if needed
      if (isFromSM && userId != null && userId.isNotEmpty) {
        periodParam += '&user_id=$userId';
      }

      endpoint += periodParam;

      print('API Endpoint: $endpoint'); // Debug print

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse,
          'message': 'Dashboard data fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';

        print("Failed to load dashboard data: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchAllCalllogTeams({
    String? timeRange,
    int? periodIndex, // Add this to handle the index-based system
  }) async {
    try {
      // Build the endpoint with parameters
      String endpoint = 'users/sm/dashboard/call-analytics';

      // Add time range parameter
      String periodParam = '';

      // Handle both timeRange string and periodIndex int
      if (periodIndex != null) {
        switch (periodIndex) {
          case 1:
            periodParam = '?type=MTD';
            break;
          case 0:
            periodParam = '?type=QTD';
            break;
          case 2:
            periodParam = '?type=YTD';
            break;
          default:
            periodParam = '?type=QTD';
        }
      } else if (timeRange != null) {
        switch (timeRange) {
          case '1D':
            periodParam = '?type=DAY';
            break;
          case '1W':
            periodParam = '?type=WEEK';
            break;
          case '1M':
            periodParam = '?type=MTD';
            break;
          case '1Q':
            periodParam = '?type=QTD';
            break;
          case '1Y':
            periodParam = '?type=YTD';
            break;
          default:
            periodParam = '?type=QTD';
        }
      } else {
        periodParam = '?type=QTD'; // Default
      }

      endpoint += periodParam;

      print('API Endpoint: $endpoint'); // Debug print

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'], // Return the data directly
          'message': 'Call analytics fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load call analytics';

        print("Failed to load call analytics: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching call analytics: $e');
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchDetailsTeams({
    int? periodIndex,
    String? timeRange,
    bool isComparing = false,
    List<String>? selectedUserIds,
    String? selectedUserId,
    int selectedProfileIndex = 0,
    bool avatarAll = false,
    List<String>? totalPerformanceIds,
    bool isAlphabetLogsMode = false,
    List<String>? logStatusAlphabet,
  }) async {
    try {
      // Build the endpoint with parameters
      String endpoint = 'users/sm/analytics/team-dashboard';

      // Build query parameters map
      final Map<String, String> queryParams = {};

      // Add time range parameter based on periodIndex or timeRange
      String? periodParam;
      if (periodIndex != null) {
        switch (periodIndex) {
          case 1:
            periodParam = 'MTD';
            break;
          case 0:
            periodParam = 'QTD';
            break;
          case 2:
            periodParam = 'YTD';
            break;
          default:
            periodParam = 'QTD';
        }
      } else if (timeRange != null) {
        switch (timeRange) {
          case '1D':
            periodParam = 'DAY';
            break;
          case '1W':
            periodParam = 'WEEK';
            break;
          case '1M':
            periodParam = 'MTD';
            break;
          case '1Q':
            periodParam = 'QTD';
            break;
          case '1Y':
            periodParam = 'YTD';
            break;
          default:
            periodParam = 'QTD';
        }
      } else {
        periodParam = 'QTD'; // Default
      }

      if (periodParam != null) {
        queryParams['type'] = periodParam;
      }

      // Handle user selection based on comparison mode
      if (isComparing &&
          selectedUserIds != null &&
          selectedUserIds.isNotEmpty) {
        // If comparison mode is ON, ONLY pass userIds (NO user_id)
        queryParams['userIds'] = selectedUserIds.join(',');
      } else if (!isComparing &&
          selectedProfileIndex != 0 &&
          selectedUserId != null &&
          selectedUserId.isNotEmpty) {
        // If comparison mode is OFF and specific user is selected, pass user_id
        queryParams['user_id'] = selectedUserId;
      }

      if (avatarAll &&
          totalPerformanceIds != null &&
          totalPerformanceIds.isNotEmpty) {
        queryParams['total_performance'] = totalPerformanceIds.join(',');
      }

      if (isAlphabetLogsMode &&
          logStatusAlphabet != null &&
          logStatusAlphabet.isNotEmpty) {
        queryParams['logs_userIds'] = logStatusAlphabet.join(',');
        queryParams['total_performance'] = logStatusAlphabet.join(',');
        print('📤 Sending logs_userIds: ${logStatusAlphabet.join(',')}');
      }

      // Build the final endpoint with query parameters
      if (queryParams.isNotEmpty) {
        final uri = Uri.parse('dummy').replace(queryParameters: queryParams);
        endpoint += uri.query.isNotEmpty ? '?${uri.query}' : '';
      }

      print('📤 API Endpoint: $endpoint'); // Debug print

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Team details fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load team details';

        print("Failed to load team details: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching team details: $e');
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  // static Future<Map<String, dynamic>> fetchSingleCalllog({
  //   String? timeRange,
  //   String? userId,
  //   bool isFromSM = false, // Add this parameter
  // }) async {
  //   try {
  //     // Build the endpoint with parameters
  //     String endpoint = 'users/ps/dashboard/call-analytics';

  //     // Add time range parameter
  //     String periodParam = '';
  //     switch (timeRange) {
  //       case '1D':
  //         periodParam = '?type=DAY';
  //         break;
  //       case '1W':
  //         periodParam = '?type=WEEK';
  //         break;
  //       case '1M':
  //         periodParam = '?type=MTD';
  //         break;
  //       case '1Q':
  //         periodParam = '?type=QTD';
  //         break;
  //       case '1Y':
  //         periodParam = '?type=YTD';
  //         break;
  //       default:
  //         periodParam = '?type=DAY';
  //     }

  //     // Add user_id parameter if needed
  //     if (isFromSM && userId != null && userId.isNotEmpty) {
  //       periodParam += '&user_id=$userId';
  //     }

  //     endpoint += periodParam;

  //     print('API Endpoint: $endpoint'); // Debug print

  //     final response = await authenticatedRequest(
  //       method: 'GET',
  //       endpoint: endpoint,
  //     );

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> jsonResponse = json.decode(response.body);

  //       return {
  //         'success': true,
  //         'data': jsonResponse,
  //         'message': 'Dashboard data fetched successfully',
  //         'timestamp': DateTime.now().toIso8601String(),
  //       };
  //     } else {
  //       final Map<String, dynamic> errorData = json.decode(response.body);
  //       final String errorMessage =
  //           errorData['message'] ?? 'Failed to load dashboard data';

  //       print("Failed to load dashboard data: $errorMessage");
  //       await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

  //       return {
  //         'success': false,
  //         'data': {},
  //         'message': errorMessage,
  //         'status_code': response.statusCode,
  //       };
  //     }
  //   } catch (e) {
  //     print('Error fetching dashboard data: $e');
  //     return {
  //       'success': false,
  //       'data': {},
  //       'message': 'Network error: ${e.toString()}',
  //     };
  //   }
  // }

  static Future<Map<String, dynamic>> fetchLeads() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'favourites/leads/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchFavTestdrive() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'favourites/events/test-drives/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchFavAppointment() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'favourites/events/appointments/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchTeamsAll() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/my-teams/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Tasks fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load tasks';

        print("Failed to load tasks: $errorMessage");
        // await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        // ✅ FIXED: Return error response instead of throwing
        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      // ✅ FIXED: Return error response instead of throwing
      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchCalllogs(
    String encodedMobile,
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/call-logs/all?mobile=$encodedMobile',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        return {
          'success': true,
          'data': jsonResponse['data'],
          'message': 'Call logs fetched successfully',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load call logs';

        print("Failed to load call logs: $errorMessage");

        return {
          'success': false,
          'data': {},
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error fetching call logs: $e');

      return {
        'success': false,
        'data': {},
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> smCalendarAsondate(
    Map<String, String>
    queryParams, // ✅ FIXED: Changed from String? to Map<String, String>
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'calendar/activities/all/asondate',
        queryParams: queryParams, // ✅ FIXED: Pass the Map directly
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load calendar data';
        print("Failed to load data: $errorMessage");
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching calendar data: $e');
      throw Exception('Error fetching calendar data: $e');
    }
  }

  static Future<Map<String, dynamic>?> submitLead(
    Map<String, dynamic> leadData,
  ) async {
    const String apiUrl = "${baseUrl}admin/leads/create";

    final token = await Storage.getToken();
    if (token == null) {
      return {"error": "No token found. Please login."};
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(leadData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return responseData;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessageGetx(
          message: 'Submission failed: ${response.statusCode}',
        );
        // return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      // return false;
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      // return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      // return false;
    }
  }

  static Future<Map<String, dynamic>?> submitCalllogs(
    List<Map<String, dynamic>>
    formattedLogs, // ✅ FIXED: Changed from Map to List
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: 'leads/create-call-logs',
        body: {'call_logs': formattedLogs},
      );

      final responseData = json.decode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return responseData;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessageGetx(
          message:
              'Submission failed: ${responseData['message'] ?? 'Unknown error'}',
        );
        return null; // ✅ FIXED: Return null instead of nothing
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return null; // ✅ FIXED: Return null
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return null; // ✅ FIXED: Return null
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return null; // ✅ FIXED: Return null
    }
  }
  // create followups

  static Future<bool> submitFollowups(
    Map<String, dynamic> followupsData,
    String leadId,
    BuildContext context,
  ) async {
    final token = await Storage.getToken();

    // Debugging: print the headers and body
    print(
      'Headers: ${{'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'recordId': leadId}}',
    );

    print('Request body: ${jsonEncode(followupsData)}');

    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'POST',
        endpoint: 'admin/leads/$leadId/create-task',
        body: followupsData,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessage(
          context,
          message: 'Submission failed : ${responseData['message']}',
        );
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessage(
        context,
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessage(
        context,
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> updateFollowups(
    Map<String, dynamic> newTaskForLead,
    String taskId,
    BuildContext context,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'tasks/$taskId/update',
        body: newTaskForLead,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessage(
          context,
          message: 'Submission failed : ${responseData['message']}',
        );
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessage(
        context,
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessage(
        context,
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> updateLost(
    Map<String, dynamic> requestBody,
    String leadId,
    BuildContext context,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'leads/mark-lost/$leadId',
        body: requestBody,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final successMessage =
            responseData['message'] ?? 'Lead marked as lost successfully';

        // Show success message
        Get.snackbar(
          'Success',
          successMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        return true;
      } else {
        final responseData = json.decode(response.body);
        final errorMessage =
            responseData['message'] ?? 'Failed to mark lead as lost';

        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');

        showErrorMessage(context, message: 'Submission failed: $errorMessage');
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessage(
        context,
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessage(
        context,
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> updateTestdrive(
    Map<String, dynamic> newTaskForLead,
    String eventId,
    BuildContext context,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'events/update/$eventId',
        body: newTaskForLead,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessage(
          context,
          message: 'Submission failed : ${responseData['message']}',
        );
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessage(
        context,
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessage(
        context,
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> updateAppointment(
    Map<String, dynamic> newTaskForLead,
    String taskId,
    BuildContext context,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'tasks/$taskId/update',
        body: newTaskForLead,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessage(
          context,
          message: 'Submission failed : ${responseData['message']}',
        );
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessage(
        context,
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessage(
        context,
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> uploadImage(File imageFile) async {
    try {
      final response = await authenticatedMultipartRequest(
        method: 'POST',
        endpoint: 'users/profile/set',
        file: imageFile,
        fieldName: 'file', // or whatever field name your API expects
        additionalHeaders: {'X-Upload-Type': 'profile-image'},
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessageGetx(
          message:
              'Upload failed: ${responseData['message'] ?? 'Unknown error'}',
        );
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<Map<String, dynamic>> uploadImageTestdrive(
    File imageFile,
    String eventId,
  ) async {
    try {
      final response = await authenticatedMultipartRequest(
        method: 'POST',
        endpoint: 'events/$eventId/upload-map',
        file: imageFile,
        fieldName: 'file', // Field name your API expects
        additionalHeaders: {'X-Upload-Type': 'map-image'},
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? uploadedUrl;
        if (responseData['data'] is String) {
          uploadedUrl = responseData['data'];
        } else {
          uploadedUrl =
              responseData['data']?['map_img'] ?? responseData['map_img'];
        }

        return {
          'success': true,
          'message': responseData['message'] ?? 'Image uploaded successfully',
          'uploadedUrl': uploadedUrl,
          'data': responseData,
        };
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');

        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to upload image',
          'status_code': response.statusCode,
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Please try again later.',
      };
    } catch (e) {
      print('Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // create appoinment
  static Future<bool> submitAppoinment(
    Map<String, dynamic> followupsData,
    String leadId,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'POST',
        endpoint: 'admin/records/$leadId/tasks/create-appointment',
        body: followupsData,
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        showErrorMessageGetx(
          message: 'Submission failed: ${responseData['message']}',
        );
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false; // Added return statement
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> submitQualify(
    Map<String, dynamic> followupsData,
    String leadId,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'POST',
        endpoint: 'leads/convert-to-opp/$leadId',
        body: followupsData,
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final successMessage =
            responseData['message'] ??
            'Lead converted to opportunity successfully';

        // Show success message
        Get.snackbar(
          'Success',
          successMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Error details: ${response.body}');

        final errorMessage =
            responseData['message'] ?? 'Failed to convert lead';
        showErrorMessageGetx(message: 'Submission failed: $errorMessage');
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }
  // static Future<bool> submitAppoinment(
  //   Map<String, dynamic> followupsData,
  //   String leadId,

  // ) async {
  //   final token = await Storage.getToken();

  //   // Debugging: print the headers and body
  //   print(
  //     'Headers: ${{'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'recordId': leadId}}',
  //   );
  //   print('Request body: ${jsonEncode(followupsData)}');

  //   try {
  //     final response = await http.post(
  //       Uri.parse('${baseUrl}admin/records/$leadId/tasks/create-appointment'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //         'recordId': leadId,
  //       },
  //       body: jsonEncode(followupsData),
  //     );

  //     print('API Response Status: ${response.statusCode}');
  //     print('API Response Body: ${response.body}');

  //     if (response.statusCode == 201) {
  //       return true;
  //     } else {
  //       print('Error: ${response.statusCode}');
  //       print('Error details: ${response.body}');
  //       showErrorMessageGetx(
  //         message: 'Submission failed: ${response.statusCode}',
  //       );
  //       return false;
  //     }
  //   } on SocketException {
  //     showErrorMessageGetx(
  //       message: 'No internet connection. Please check your network.',
  //     );
  //     // return false;
  //   } on TimeoutException {
  //     showErrorMessageGetx(
  //       message: 'Request timed out. Please try again later.',
  //     );
  //     return false;
  //   } catch (e) {
  //     print('Unexpected error: $e');
  //     showErrorMessageGetx(
  //       message: 'An unexpected error occurred. Please try again.',
  //     );
  //     return false;
  //   }
  // }

  static Future<bool> startTestDrive(
    Map<String, dynamic> testdriveData,
    String eventId,
  ) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'POST',
        endpoint: 'events/$eventId/start-drive',
        body: testdriveData,
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Show success message
        Get.snackbar(
          'Success',
          responseData['message'] ?? 'Test drive started successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        final errorMessage =
            responseData['message'] ?? 'Failed to start test drive';
        showErrorMessageGetx(message: 'Submission failed: $errorMessage');
        print('Error details: ${response.body}');
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> endTestDrive(
    Map<String, dynamic> testdriveData,
    String eventId, {
    bool sendFeedback = false,
  }) async {
    try {
      // Add the sendFeedback parameter to the endpoint
      String endpoint =
          'events/$eventId/end-drive?send_feedback=${sendFeedback.toString()}';

      final response = await LeadsSrv.authenticatedRequest(
        method: 'POST',
        endpoint: endpoint,
        body: testdriveData,
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Show success message
        Get.snackbar(
          'Success',
          responseData['message'] ?? 'Test drive ended successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        final errorMessage =
            responseData['message'] ?? 'Failed to end test drive';
        showErrorMessageGetx(message: 'Submission failed: $errorMessage');
        print('Error details: ${response.body}');
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<bool> submitTestDrive(
    Map<String, dynamic> testdriveData,
    String leadId,
  ) async {
    final token = await Storage.getToken();

    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'POST',
        endpoint: 'admin/records/$leadId/events/create-test-drive',
        body: testdriveData,
      );

      final responseData = jsonDecode(response.body);

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        return true;
      } else {
        showErrorMessageGetx(
          message: 'Submission failed: ${responseData['message']}',
        );
        print('Error details: ${response.body}');
        return false;
      }
    } on SocketException {
      showErrorMessageGetx(
        message: 'No internet connection. Please check your network.',
      );
      return false;
    } on TimeoutException {
      showErrorMessageGetx(
        message: 'Request timed out. Please try again later.',
      );
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      showErrorMessageGetx(
        message: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  static Future<Map<String, dynamic>> fetchLeadsById(String leadId) async {
    // const String apiUrl = "${baseUrl}leads/";

    // final token = await Storage.getToken();
    // if (token == null) {
    //   print("No token found. Please login.");
    //   throw Exception("No token found. Please login.");
    // }

    try {
      // Debug: Print the full URL with leadId
      // final fullUrl = Uri.parse('$apiUrl$leadId');
      // print('Fetching data from URL: $fullUrl');

      // final response = await http.get(
      //   fullUrl, // Use the full URL
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //     'leadId': leadId,
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/$leadId',
        additionalHeaders: {'leadId': leadId},
      );

      // Debug: Print response details
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('data')) {
          return responseData['data'];
        } else {
          throw Exception('Unexpected response structure: ${response.body}');
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception(
          'Failed to load data: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> singleFollowupsById(String leadId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/by-id/$leadId',
        additionalHeaders: {'leadId': leadId},
      );

      // Debug: Print the response status code and body
      print('this is upper api');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> getFollowupsById(String taskId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'tasks/$taskId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> getTestdriveById(String eventId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'events/$eventId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<Map<String, dynamic>> getAppointmentById(String taskId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'tasks/$taskId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  // history data api

  static Future<List<Map<String, dynamic>>> singleTaskById(
    String leadId,
  ) async {
    const String apiUrl = "${baseUrl}admin/leads/tasks/all/";

    final token = await Storage.getToken();
    if (token == null) {
      print("No token found. Please login.");
      throw Exception("No token found. Please login.");
    }

    try {
      print('Fetching data for Lead ID: $leadId');
      print('API URL: ${apiUrl + leadId}');

      // final response = await http.get(
      //   Uri.parse('$apiUrl$leadId'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'admin/leads/tasks/all/$leadId',
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Handle the nested structure with allEvents.rows
        if (data.containsKey('data') &&
            data['data'].containsKey('allTasks') &&
            data['data']['allTasks'].containsKey('rows')) {
          // Extract the rows containing the task data
          return List<Map<String, dynamic>>.from(
            data['data']['allTasks']['rows'],
          );
        } else {
          return []; // Return empty list if no tasks found
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  // static Future<List<Map<String, dynamic>>> singleTasksById(
  //     String leadId) async {
  //   const String apiUrl =
  //       "https://api.smartassistapps.in/api/admin/leads/tasks/all/";

  //   final token = await Storage.getToken();
  //   if (token == null) {
  //     print("No token found. Please login.");
  //     throw Exception("No token found. Please login.");
  //   }

  //   try {
  //     print('Fetching data for Lead ID: $leadId');
  //     print('API URL: ${apiUrl + leadId}');

  //     final response = await http.get(
  //       Uri.parse('$apiUrl$leadId'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     print('Response status code: ${response.statusCode}');
  //     print('Response body: ${response.body}');

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> data = json.decode(response.body);

  //       // Handle the nested structure with allEvents.rows
  //       if (data.containsKey('allTasks') &&
  //           data['allTasks'] is Map<String, dynamic> &&
  //           data['allTasks'].containsKey('rows')) {
  //         return List<Map<String, dynamic>>.from(data['allTasks']['rows']);
  //       } else {
  //         return []; // Return empty list if no events found
  //       }
  //     } else {
  //       throw Exception('Failed to load data: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error fetching data: $e');
  //     throw Exception('Error fetching data: $e');
  //   }
  // }

  static Future<Map<String, dynamic>> eventTaskByLead(String leadId) async {
    const String apiUrl = "${baseUrl}leads/events-&-tasks/";
    final token = await Storage.getToken();

    try {
      // Append the leadId and subject to the API URL
      print('Fetching data for Lead ID: $leadId');
      print('API URL: ${apiUrl + leadId}');
      // final response = await http.get(
      //   Uri.parse('${apiUrl + leadId}'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/events-&-tasks/$leadId',
      );

      print('Response status code: ${response.statusCode}');
      print('Response body for both data task and event: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final Map<String, dynamic> data = jsonResponse['data'];
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  // for teams only
  static Future<Map<String, dynamic>> eventTaskByLeadTeams(
    String leadId,
    String userId,
  ) async {
    // const String apiUrl = "${baseUrl}leads/events-&-tasks/";
    // final token = await Storage.getToken();

    try {
      // final fullUrl = '$apiUrl$leadId?user_id=$userId';
      // print('Fetching data for Lead ID: $leadId');
      // print('API URL: $fullUrl');

      // final response = await http.get(
      //   Uri.parse(fullUrl),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'leads/events-&-tasks/$leadId',
      );

      print('Response status code: ${response.statusCode}');
      print('Response body for both data task and event: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final Map<String, dynamic> data = jsonResponse['data'];
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> singleTestDriveById(
    String leadId,
    String subject,
  ) async {
    const String apiUrl = "${baseUrl}admin/leads/events/all/";

    final token = await Storage.getToken();

    try {
      // Append the leadId and subject to the API URL
      // final response = await http.get(
      //   Uri.parse('${apiUrl + leadId + '?' + subject}'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'admin/leads/events/all/$leadId?$subject',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Handle the nested structure with allEvents.rows
        if (data.containsKey('data') &&
            data['data'].containsKey('allEvents') &&
            data['data']['allEvents'].containsKey('rows')) {
          // Extract the rows containing the task data
          return List<Map<String, dynamic>>.from(
            data['data']['allEvents']['rows'],
          );
        } else {
          return []; // Return empty list if no events found
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> singleTasksById(
    String leadId,
  ) async {
    // const String apiUrl = "${baseUrl}admin/leads/events/all/";

    // final token = await Storage.getToken();
    // if (token == null) {
    //   print("No token found. Please login.");
    //   throw Exception("No token found. Please login.");
    // }

    try {
      // print('Fetching data for Lead ID: $leadId');
      // print('API URL: ${apiUrl + leadId}');

      // final response = await http.get(
      //   Uri.parse('$apiUrl$leadId'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'admin/leads/events/all/$leadId',
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Ensure the data structure contains 'allTasks' and 'rows'
        if (data.containsKey('data') &&
            data['data'].containsKey('allEvents') &&
            data['data']['allEvents'].containsKey('rows')) {
          // Extract the rows containing the task data
          return List<Map<String, dynamic>>.from(
            data['data']['allEvents']['rows'],
          );
        } else {
          return []; // Return empty list if no tasks found
        }
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  //
  static Future<Map<String, dynamic>> singleAppointmentById(
    String eventId,
  ) async {
    // const String apiUrl = "${baseUrl}admin/events/";

    // final token = await Storage.getToken();
    // if (token == null) {
    //   print("No token found. Please login.");
    //   throw Exception("No token found. Please login.");
    // }

    try {
      // Ensure the actual leadId is being passed correctly
      // print('Fetching data for Lead ID: $eventId');
      // print(
      //   'API URL: ${apiUrl + eventId}',
      // ); // Concatenate the leadId with the API URL

      // final response = await http.get(
      //   Uri.parse('$apiUrl$eventId'), // Correct URL with leadId appended
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //     'eventId': eventId,
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'admin/events/$eventId',
        additionalHeaders: {'eventId': eventId},
      );

      // Debug: Print the response status code and body
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data; // Return the response data
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      throw Exception('Error fetching data: $e');
    }
  }

  // Fetch appointments (tasks) for a selected date
  static Future<List<dynamic>> fetchAppointments(DateTime selectedDate) async {
    final DateTime finalDate = selectedDate ?? DateTime.now();
    final String formattedDate = DateFormat('dd-MM-yyyy').format(finalDate);
    // final String apiUrl =
    //     '${baseUrl}calendar/events/all/asondate?date=$formattedDate';

    // final token = await Storage.getToken();

    try {
      // final response = await http.get(
      //   Uri.parse(apiUrl),
      //   headers: {'Authorization': 'Bearer $token'},
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'calendar/events/all/asondate?date=$formattedDate',
      );

      if (response.statusCode == 200) {
        print("Error: ${response.statusCode}");
        final Map<String, dynamic> data = json.decode(response.body);
        print("Total Appointments Fetched: ${data['data']['rows']?.length}");
        return data['data']['rows'] ?? [];
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        print("Error: ${response.statusCode}");
        return [];
      }
    } catch (error) {
      print("Error fetching appointments: $error");

      return [];
    }
  }

  // fetch tasks change the url calendar

  static Future<List<dynamic>> fetchtasks(DateTime selectedDate) async {
    final DateTime finalDate = selectedDate ?? DateTime.now();
    final String formattedDate = DateFormat('dd-MM-yyyy').format(finalDate);
    final String apiUrl =
        '${baseUrl}calendar/tasks/all/asondate?date=$formattedDate';

    final token = await Storage.getToken();

    try {
      // final response = await http.get(
      //   Uri.parse(apiUrl),
      //   headers: {'Authorization': 'Bearer $token'},
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'calendar/tasks/all/asondate?date=$formattedDate',
      );

      if (response.statusCode == 200) {
        print("Error: ${response.statusCode}");
        final Map<String, dynamic> data = json.decode(response.body);
        return data['data']['rows'] ?? [];
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        print("Error: ${response.statusCode}");
        return [];
      }
    } catch (error) {
      print("Error fetching appointments: $error");

      return [];
    }
  }

  // Fetch event counts for a selected date
  static Future<Map<String, int>> fetchCount(DateTime selectedDate) async {
    final String formattedDate = DateFormat('dd-MM-yyyy').format(selectedDate);
    final String apiUrl =
        '${baseUrl}calendar/data-count/asondate?date=$formattedDate';
    print("Calling API for count on: $formattedDate");
    final token = await Storage.getToken();

    try {
      // final response = await http.get(
      //   Uri.parse(apiUrl),
      //   headers: {'Authorization': 'Bearer $token'},
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'calendar/data-count/asondate?date=$formattedDate',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {
          'upcomingFollowupsCount': data['data']['upcomingFollowupsCount'] ?? 0,
          'overdueFollowupsCount': data['data']['overdueFollowupsCount'] ?? 0,
          'upcomingAppointmentsCount':
              data['data']['upcomingAppointmentsCount'] ?? 0,
          'overdueAppointmentsCount':
              data['data']['overdueAppointmentsCount'] ?? 0,
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        print('API Error: ${response.statusCode}');
        return {};
      }
    } catch (error) {
      print("Error fetching event counts: $error");
      return {};
    }
  }

  static Future<Map<String, dynamic>> fetchDashboardData() async {
    // final token = await Storage.getToken();
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/dashboard?filterType=MTD&category=Leads',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        // Dashboard data is nested under "data"
        final Map<String, dynamic> data = jsonResponse['data'];
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        throw Exception(
          'Failed to load dashboard data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // static Future<Map<String, dynamic>> fetchDashboardDataapi() async {
  //   const url = '${baseUrl}users/dashboard?filterType=MTD&category=Leads';
  //   final uri = Uri.parse(url);
  //   try {
  //     // final response = await http.get(uri);

  //     final response = await makeAuthenticatedRequest(
  //       'GET',
  //       '${baseUrl}users/dashboard?filterType=MTD&category=Leads',
  //     );

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> jsonResponse = json.decode(response.body);
  //       final Map<String, dynamic> data = jsonResponse['data'];
  //       return data;
  //     } else {
  //       final Map<String, dynamic> errorData = json.decode(response.body);
  //       final String errorMessage =
  //           errorData['message'] ?? 'Failed to load dashboard data';
  //       throw Exception(errorMessage);
  //     }
  //   } catch (e) {
  //     throw Exception(e.toString());
  //   }
  // }

  // static Future<Map<String, dynamic>> fetchDashboardAnalytics() async {
  //   try {
  //     // Use the new authenticatedRequest method instead of manual token handling
  //     final response = await authenticatedRequest(
  //       method: 'GET',
  //       endpoint: 'users/dashboard/analytics',
  //     );

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> jsonResponse = json.decode(response.body);
  //       final Map<String, dynamic> data = jsonResponse['data'];
  //       return data;
  //     } else {
  //       final Map<String, dynamic> errorData = json.decode(response.body);
  //       final String errorMessage =
  //           errorData['message'] ?? 'Failed to load dashboard data';
  //       print("Failed to load data: $errorMessage");

  //       // No need to manually handle unauthorized - authenticatedRequest handles it
  //       throw Exception(errorMessage);
  //     }
  //   } catch (e) {
  //     print('Error in fetchDashboardAnalytics: $e');
  //     throw Exception(e.toString());
  //   }
  // }

  static Future<Map<String, dynamic>> fetchDashboardAnalytics() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/dashboard/analytics',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final Map<String, dynamic> data = jsonResponse['data'];
        return data;
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        throw Exception('');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>?> fetchGlobalSearch(String query) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'search/global',
        queryParams: {'query': query},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse['data']; // Return the data part directly
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to fetch search results';
        print("Search failed: $errorMessage");
        return null; // ✅ FIXED: Return null instead of throwing
      }
    } catch (e) {
      print('Error in fetchGlobalSearch: $e');
      return null; // ✅ FIXED: Return null instead of throwing
    }
  }

  static Future<Map<String, dynamic>> fetchSingleCallLogData({
    required int periodIndex,
    required String selectedUserId,
  }) async {
    try {
      final token = await Storage.getToken();

      String periodParam;
      switch (periodIndex) {
        case 0:
          periodParam = 'DAY';
          break;
        case 1:
          periodParam = 'WEEK';
          break;
        case 2:
          periodParam = 'MTD';
          break;
        case 3:
          periodParam = 'QTD';
          break;
        case 4:
          periodParam = 'YTD';
          break;
        default:
          periodParam = 'DAY';
      }

      final Map<String, String> queryParams = {
        'type': periodParam,
        if (selectedUserId.isNotEmpty) 'userId': selectedUserId,
      };

      // final uri = Uri.parse(
      //   '${baseUrl}users/sm/dashboard/individual/call-analytics',
      // ).replace(queryParameters: queryParams);

      // final response = await http.get(
      //   uri,
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/sm/dashboard/individual/call-analytics',
        queryParams: queryParams,
      );

      final Map<String, dynamic> errorData = json.decode(response.body);
      final String errorMessage =
          errorData['message'] ?? 'Failed to load dashboard data';

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        throw Exception(
          'Failed to fetch single call log data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print(e.toString());
      throw Exception('Error fetching single call log data: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchAllCalllog({
    required int periodIndex,
  }) async {
    try {
      // final token = await Storage.getToken();

      // Determine the period parameter
      String periodParam;
      switch (periodIndex) {
        case 1:
          periodParam = 'DAY';
          break;
        case 2:
          periodParam = 'WEEK';
          break;
        case 3:
          periodParam = 'MTD';
          break;
        case 4:
          periodParam = 'QTD';
          break;
        case 5:
          periodParam = 'YTD';
          break;
        default:
          periodParam = 'QTD';
      }

      final queryParams = {'type': periodParam};

      // final uri = Uri.parse(
      //   '${baseUrl}users/sm/dashboard/call-analytics',
      // ).replace(queryParameters: queryParams);

      // final response = await http.get(
      //   uri,
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/sm/dashboard/call-analytics',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'analyticsData': responseData['data'],
          'membersData': List<Map<String, dynamic>>.from(
            responseData['data']['members'],
          ),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception(
          'Failed to fetch call analytics: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in fetchAllCalllog: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> fetchTeamDetails({
    required int periodIndex,
    required int metricIndex,
    required int selectedProfileIndex,
    required String selectedUserId,
    required List<String> selectedCheckboxIds,
    required int upcomingButtonIndex,
  }) async {
    try {
      // final token = await Storage.getToken();

      // Build query parameters
      final periodParam =
          ['DAY', 'WEEK', 'MTD', 'QTD', 'YTD'].elementAtOrNull(periodIndex) ??
          'QTD';

      final summaryParam =
          [
            'enquiries',
            'testDrives',
            'orders',
            'cancellation',
            'netOrders',
            'retail',
          ].elementAtOrNull(metricIndex) ??
          'enquiries';

      final queryParams = {'type': periodParam, 'summary': summaryParam};

      if (selectedProfileIndex != 0 && selectedUserId.isNotEmpty) {
        queryParams['user_id'] = selectedUserId;
      }

      if (selectedCheckboxIds.isNotEmpty) {
        queryParams['userIds'] = selectedCheckboxIds.join(',');
      }

      // final uri = Uri.parse(
      //   '${baseUrl}users/sm/dashboard/team-dashboard',
      // ).replace(queryParameters: queryParams);

      // final response = await http.get(
      //   uri,
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/sm/dashboard/team-dashboard',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final performance = data['data']?['selectedUserPerformance'] ?? {};
        final upcoming = performance['Upcoming'] ?? {};
        final overdue = performance['Overdue'] ?? {};

        return {
          'teamData': data['data'] ?? {},
          'allMember': data['data']?['allMember'] ?? [],
          'summary': data['data']?['summary'] ?? {},
          'totalPerformance': data['data']?['totalPerformance'] ?? {},
          'upcomingFollowups': List<Map<String, dynamic>>.from(
            upcomingButtonIndex == 0
                ? upcoming['upComingFollowups'] ?? []
                : overdue['overdueFollowups'] ?? [],
          ),
          'upcomingAppointments': List<Map<String, dynamic>>.from(
            upcomingButtonIndex == 0
                ? upcoming['upComingAppointment'] ?? []
                : overdue['overdueAppointments'] ?? [],
          ),
          'upcomingTestDrives': List<Map<String, dynamic>>.from(
            upcomingButtonIndex == 0
                ? upcoming['upComingTestDrive'] ?? []
                : overdue['overdueTestDrives'] ?? [],
          ),
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        throw Exception('Failed to fetch data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in LeadsSrv.fetchTeamDetails: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> fetchNotifications({
    String? category,
  }) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/notifications/all',
        queryParams: category != null && category != 'All'
            ? {'category': category.replaceAll(' ', '')}
            : null,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Combine unread and read notifications
        List<dynamic> allNotifications = [];
        if (data['data']['unread']?['rows'] != null) {
          allNotifications.addAll(data['data']['unread']['rows']);
        }
        if (data['data']['read']?['rows'] != null) {
          allNotifications.addAll(data['data']['read']['rows']);
        }

        return {
          'success': true,
          'data': allNotifications,
          'message': 'Notifications fetched successfully',
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        return {
          'success': false,
          'data': [],
          'message': 'Failed to load notifications: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'message': 'Error fetching notifications: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> fetchAllNotifications({
    String? category,
  }) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/notifications/all',
        queryParams: category != null && category != 'All'
            ? {'category': category.replaceAll(' ', '')}
            : null,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Combine unread and read notifications
        List<dynamic> allNotifications = [];
        if (data['data']['unread']?['rows'] != null) {
          allNotifications.addAll(data['data']['unread']['rows']);
        }
        if (data['data']['read']?['rows'] != null) {
          allNotifications.addAll(data['data']['read']['rows']);
        }

        return {
          'success': true,
          'data': allNotifications,
          'message': 'Notifications fetched successfully',
          'unread_count': data['data']['unread']?['rows']?.length ?? 0,
          'read_count': data['data']['read']?['rows']?.length ?? 0,
          'total_count': allNotifications.length,
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load notifications';
        print("Failed to load notifications: $errorMessage");

        // ✅ FIXED: Remove the extra () and handle unauthorized properly
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'data': [],
          'message': 'Failed to load notifications: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      return {
        'success': false,
        'data': [],
        'message': 'Error fetching notifications: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      final response = await authenticatedRequest(
        method: 'PUT',
        endpoint: 'users/notifications/$notificationId',
        body: {'read': true},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': 'Notification marked as read successfully',
          'data': responseData,
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to mark as read';

        // Handle unauthorized
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'message': 'Failed to mark as read: $errorMessage',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error marking notification as read: $e');
      return {
        'success': false,
        'message': 'Error marking notification as read: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> submitFeedbackTestdrive(
    Map<String, dynamic> requestBody,
    String eventId,
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'PUT',
        endpoint: 'events/update/$eventId',
        body: requestBody,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message':
              responseData['message'] ??
              'License verification skipped successfully',
          'data': responseData,
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to update event';

        print('Failed to update event: $errorMessage');

        // Handle unauthorized
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'message': errorMessage,
          'status_code': response.statusCode,
        };
      }
    } on SocketException {
      const errorMessage = 'No internet connection. Please check your network.';
      print(errorMessage);
      return {'success': false, 'message': errorMessage};
    } on TimeoutException {
      const errorMessage = 'Request timed out. Please try again later.';
      print(errorMessage);
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      final errorMessage = 'Error updating event: $e';
      print(errorMessage);
      return {'success': false, 'message': errorMessage};
    }
  }

  // Mark all notifications as read
  static Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final response = await authenticatedRequest(
        method: 'PUT',
        endpoint: 'users/notifications/read/all',
        body: {'read': true},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': 'All notifications marked as read successfully',
          'data': responseData,
          'affected_count': responseData['affected_count'] ?? 0,
        };
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to mark all as read';

        // Handle unauthorized
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);

        return {
          'success': false,
          'message': 'Failed to mark all as read: $errorMessage',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return {
        'success': false,
        'message': 'Error marking all notifications as read: $e',
      };
    }
  }
  // static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
  //   try {
  //     final response = await LeadsSrv.authenticatedRequest(
  //       method: 'PUT',
  //       endpoint: 'users/notifications/$notificationId',
  //       body: {'read': true},
  //     );

  //     if (response.statusCode == 200) {
  //       return {
  //         'success': true,
  //         'message': 'Notification marked as read successfully',
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'message': 'Failed to mark as read: ${response.statusCode}',
  //       };
  //     }
  //   } catch (e) {
  //     return {
  //       'success': false,
  //       'message': 'Error marking notification as read: $e',
  //     };
  //   }
  // }

  // static Future<Map<String, dynamic>> readAll() async {
  //   try {
  //     final response = await LeadsSrv.authenticatedRequest(
  //       method: 'PUT',
  //       endpoint: 'users/notifications/read/all',
  //       body: {'read': true},
  //     );

  //     if (response.statusCode == 200) {
  //       return {
  //         'success': true,
  //         'message': 'Notification marked as read successfully',
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'message': 'Failed to mark as read: ${response.statusCode}',
  //       };
  //     }
  //   } catch (e) {
  //     return {
  //       'success': false,
  //       'message': 'Error marking notification as read: $e',
  //     };
  //   }
  // }

  static Future<bool> favorite({required String taskId}) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'favourites/mark-fav/task/$taskId',
        // body: {'read': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Failed to mark favorite: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in favorite(): $e');
      return false;
    }
  }

  static Future<bool> leadFavorite({required String leadId}) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'favourites/mark-fav/lead/$leadId',
        // body: {'read': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Failed to mark favorite: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in favorite(): $e');
      return false;
    }
  }

  static Future<bool> submitLost({required String leadId}) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'favourites/mark-fav/lead/$leadId',
        // body: {'read': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Failed to mark favorite: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in favorite(): $e');
      return false;
    }
  }

  static Future<bool> favoriteTestdrive({required String eventId}) async {
    try {
      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'favourites//mark-fav/event/$eventId',
        // body: {'read': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Failed to mark favorite: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in favorite(): $e');
      return false;
    }
  }

  static Future<bool> favoriteEvent({required String taskId}) async {
    try {
      // final token = await Storage.getToken();
      // final response = await http.put(
      //   Uri.parse('${baseUrl}favourites/mark-fav/task/$taskId'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'favourites/mark-fav/task/$taskId',
        // body: {'read': true},
      );

      if (response.statusCode == 200) {
        print(response.body.toString());
        return true;
      } else {
        print(Uri.parse.toString());
        print('❌ Failed to mark favorite: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in favorite(): $e');
      return false;
    }
  }

  static Future<bool> favoriteTestDrive({required String eventId}) async {
    try {
      final token = await Storage.getToken();
      // final response = await http.put(
      //   Uri.parse('${baseUrl}favourites/mark-fav/event/$eventId'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await LeadsSrv.authenticatedRequest(
        method: 'PUT',
        endpoint: 'favourites/mark-fav/event/$eventId',
        // body: {'read': true},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Failed to mark favorite: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in favorite(): $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getAllVehicles() async {
    try {
      // final token = await Storage.getToken();
      // final response = await http.get(
      //   Uri.parse('${baseUrl}users/vehicles/all'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'users/vehicles/all',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {'success': true, 'data': data['data']['rows'] ?? []};
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // static Future<Map<String, dynamic>> vehicleSearch(String query) async {
  //   try {
  //     final token = await Storage.getToken();
  //     final response = await http.get(
  //       Uri.parse(
  //         '${baseUrl}search/vehicles?vehicle=${Uri.encodeComponent(query)}',
  //       ),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> data = json.decode(response.body);
  //       return {'success': true, 'data': data['data']['suggestions'] ?? []};
  //     } else {
  //       return {
  //         'success': false,
  //         'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
  //       };
  //     }
  //   } catch (e) {
  //     return {'success': false, 'error': e.toString()};
  //   }
  // }

  static Future<Map<String, dynamic>> globalSearch(String query) async {
    try {
      // final token = await Storage.getToken();

      // final response = await http.get(
      //   Uri.parse('${baseUrl}search/global?query=$query'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'search/global?query=$query',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {'success': true, 'data': data['data']['results'] ?? []};
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getVehicle(String query) async {
    try {
      // final token = await Storage.getToken();

      // final response = await http.get(
      //   Uri.parse('${baseUrl}search/global?query=$query'),
      //   headers: {
      //     'Authorization': 'Bearer $token',
      //     'Content-Type': 'application/json',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: 'search/global?query=$query',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return {'success': true, 'data': data['data']['suggestions'] ?? []};
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        final String errorMessage =
            errorData['message'] ?? 'Failed to load dashboard data';
        print("Failed to load data: $errorMessage");

        // Check if unauthorized: status 401 or error message includes "unauthorized"
        await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
        ();
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> getOtp({required String eventId}) async {
    try {
      // final token = await Storage.getToken();
      // final url = Uri.parse(
      //   'https://api.smartassistapps.in/api/events/$eventId/send-consent',
      // );

      // final response = await http.post(
      //   url,
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      // );

      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: 'events/$eventId/send-consent',
      );

      print('📨 Sent OTP request for eventId: $eventId');
      print('📥 Status Code: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error in getOtp(): $e');
      return false;
    }
  }
}





// ////////////






// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:smartassist/config/model/login/login_model.dart';
// import 'package:smartassist/config/route/route_name.dart';
// import 'package:smartassist/pages/login_steps/login_page.dart';
// import 'package:smartassist/utils/connection_service.dart';
// import 'package:smartassist/utils/snackbar_helper.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/utils/token_manager.dart';

// class LeadsSrv {
//   static const String baseUrl = 'https://api.smartassistapps.in/api/';
//   static final ConnectionService _connectionService = ConnectionService();

//   static Future<Map<String, dynamic>> onLogin(Map<String, dynamic> body) async {
//     const url = '${baseUrl}login';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.post(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       final responseData = jsonDecode(response.body);

//       if (response.statusCode == 200 &&
//           responseData['status'] == 200 &&
//           responseData.containsKey('data')) {
//         final data = responseData['data'];
//         final String accessToken = data['accessToken'];
//         final String refreshToken = data['refreshToken'];
//         final Map<String, dynamic>? user = data['user'];

//         // DEBUG: Print the tokens we're about to save
//         print('🔑 ACCESS TOKEN TO SAVE: ${accessToken.substring(0, 50)}...');
//         print('🔄 REFRESH TOKEN TO SAVE: ${refreshToken.substring(0, 50)}...');
//         print('👤 USER DATA: ${user?['user_id']} - ${user?['email']}');

//         if (user != null && accessToken.isNotEmpty && refreshToken.isNotEmpty) {
//           // Save both tokens using TokenManager
//           await TokenManager.saveAuthData(
//             accessToken,
//             refreshToken,
//             user['user_id'] ?? '',
//             user['user_role'] ?? '',
//             user['email'] ?? '',
//           );

//           // VERIFY tokens were saved correctly
//           final savedAccessToken = await TokenManager.getAccessToken();
//           final savedRefreshToken = await TokenManager.getRefreshToken();
//           print(
//             '✅ VERIFIED ACCESS TOKEN SAVED: ${savedAccessToken?.substring(0, 50)}...',
//           );
//           print(
//             '✅ VERIFIED REFRESH TOKEN SAVED: ${savedRefreshToken?.substring(0, 50)}...',
//           );

//           return {
//             'isSuccess': true,
//             'accessToken': accessToken,
//             'refreshToken': refreshToken,
//             'user': user,
//             'message': responseData['message'],
//           };
//         } else {
//           print(
//             '❌ ERROR: Missing required data - user: ${user != null}, accessToken: ${accessToken.isNotEmpty}, refreshToken: ${refreshToken.isNotEmpty}',
//           );
//           return {
//             'isSuccess': false,
//             'message': 'Required authentication data missing in response',
//           };
//         }
//       } else {
//         return {
//           'isSuccess': false,
//           'message': responseData['message'] ?? 'Login failed',
//         };
//       }
//     } catch (error) {
//       print('❌ LOGIN ERROR: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   // Updated login method to return TokenModel
//   static Future<TokenModel> login(Map<String, dynamic> map) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${baseUrl}login'),
//         body: jsonEncode(map),
//         headers: {'Content-Type': 'application/json'},
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final tokenModel = TokenModel.fromJson(data);

//         // Save tokens after successful login
//         await TokenManager.saveAuthData(
//           tokenModel.data.accessToken,
//           tokenModel.data.refreshToken,
//           tokenModel.data.user.userId,
//           tokenModel.data.user.userRole,
//           tokenModel.data.user.email,
//         );

//         return tokenModel;
//       } else {
//         throw Exception('Failed to login: ${response.statusCode}');
//       }
//     } catch (e) {
//       throw Exception('Error during login: $e');
//     }
//   }

//   // Method to refresh access token using refresh token
//   static Future<String?> refreshAccessToken() async {
//     try {
//       // Debug what we have stored
//       await TokenManager.debugStoredValues();
//       final refreshToken = await TokenManager.getRefreshToken();
//       print('🔄 REFRESH TOKEN FROM STORAGE: $refreshToken');

//       if (refreshToken == null || refreshToken.isEmpty) {
//         print('❌ NO REFRESH TOKEN AVAILABLE');
//         throw Exception('No refresh token available');
//       }

//       print('🌐 MAKING REFRESH REQUEST TO: ${baseUrl}refresh-token');

//       final response = await http.post(
//         Uri.parse('${baseUrl}refresh-token'),
//         headers: {
//           'Authorization':
//               'Bearer $refreshToken', // ✅ FIXED: Added "Bearer " prefix
//           'Content-Type': 'application/json',
//         },
//       );

//       print('📡 REFRESH RESPONSE STATUS: ${response.statusCode}');
//       print('📡 REFRESH RESPONSE BODY: ${response.body}');

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         // ✅ FIXED: Updated to match your API response structure
//         final newAccessToken =
//             data['data']?['accessToken']; // Note: data.accessToken, not just accessToken

//         print(
//           '🆕 NEW ACCESS TOKEN RECEIVED: ${newAccessToken?.substring(0, 50)}...',
//         );

//         if (newAccessToken != null && newAccessToken.isNotEmpty) {
//           // Update only the access token, keep other data
//           final currentUserId = await TokenManager.getUserId();
//           final currentUserRole = await TokenManager.getUserRole();
//           final currentUserEmail = await TokenManager.getUserEmail();

//           await TokenManager.saveAuthData(
//             newAccessToken,
//             refreshToken, // Keep the same refresh token
//             currentUserId ?? '',
//             currentUserRole ?? '',
//             currentUserEmail ?? '',
//           );

//           print('✅ ACCESS TOKEN UPDATED SUCCESSFULLY');
//           return newAccessToken;
//         } else {
//           print('❌ NEW ACCESS TOKEN IS NULL OR EMPTY');
//         }
//       } else {
//         print('❌ REFRESH FAILED WITH STATUS: ${response.statusCode}');
//         print('❌ REFRESH ERROR BODY: ${response.body}');
//       }
//       return null;
//     } catch (e) {
//       print('❌ ERROR REFRESHING TOKEN: $e');
//       return null;
//     }
//   }

//   // Method to make authenticated HTTP requests with automatic token refresh
//   static Future<http.Response> authenticatedRequest({
//     required String method,
//     required String endpoint,
//     Map<String, dynamic>? body,
//     Map<String, String>? additionalHeaders,
//   }) async {
//     String? accessToken = await TokenManager.getAccessToken();

//     if (accessToken == null || !await TokenManager.isTokenValid()) {
//       // Try to refresh the token
//       accessToken = await refreshAccessToken();
//       print('access token $accessToken');
//       if (accessToken == null) {
//         await TokenManager.clearAuthData();
//         throw Exception('Authentication failed - please login again');
//       }
//     }

//     final headers = {
//       'Content-Type': 'application/json',
//       'Authorization': 'Bearer $accessToken',
//       ...?additionalHeaders,
//     };

//     final uri = Uri.parse('$baseUrl$endpoint');

//     http.Response response;

//     switch (method.toUpperCase()) {
//       case 'GET':
//         response = await http.get(uri, headers: headers);
//         break;
//       case 'POST':
//         response = await http.post(
//           uri,
//           headers: headers,
//           body: body != null ? jsonEncode(body) : null,
//         );
//         break;
//       case 'PUT':
//         response = await http.put(
//           uri,
//           headers: headers,
//           body: body != null ? jsonEncode(body) : null,
//         );
//         break;
//       case 'DELETE':
//         response = await http.delete(uri, headers: headers);
//         break;
//       default:
//         throw Exception('Unsupported HTTP method: $method');
//     }

//     // If we get 401, try to refresh token once
//     if (response.statusCode == 401) {
//       final newAccessToken = await refreshAccessToken();
//       if (newAccessToken != null) {
//         // Retry the request with new token
//         headers['Authorization'] = 'Bearer $newAccessToken';

//         switch (method.toUpperCase()) {
//           case 'GET':
//             response = await http.get(uri, headers: headers);
//             break;
//           case 'POST':
//             response = await http.post(
//               uri,
//               headers: headers,
//               body: body != null ? jsonEncode(body) : null,
//             );
//             break;
//           case 'PUT':
//             response = await http.put(
//               uri,
//               headers: headers,
//               body: body != null ? jsonEncode(body) : null,
//             );
//             break;
//           case 'DELETE':
//             response = await http.delete(uri, headers: headers);
//             break;
//         }
//       } else {
//         // Refresh failed, clear auth data
//         await TokenManager.clearAuthData();
//         throw Exception('Session expired - please login again');
//       }
//     }

//     return response;
//   }

//   static Future<void> handleUnauthorizedIfNeeded(
//     int statusCode,
//     String errorMessage,
//   ) async {
//     if (statusCode == 401 ||
//         errorMessage.toLowerCase().contains("unauthorized")) {
//       await TokenManager.clearAuthData();
//       await Future.delayed(Duration(seconds: 2));
//       Get.offAll(() => LoginPage(email: '', onLoginSuccess: () {}));
//       showErrorMessageGetx(
//         message:
//             "You have been logged out because your account was used on another device.",
//       );
//       throw Exception('Unauthorized. Redirecting to login.');
//     }
//   }

//   // Add this to your API helper file
//   static Future<http.Response> makeAuthenticatedRequest(
//     String method,
//     String url, {
//     Map<String, String>? headers,
//     Object? body,
//   }) async {
//     final token = await Storage.getToken();

//     final defaultHeaders = {
//       'Authorization': 'Bearer $token',
//       'Content-Type': 'application/json',
//     };

//     if (headers != null) {
//       defaultHeaders.addAll(headers);
//     }

//     http.Response response;

//     if (method.toUpperCase() == 'GET') {
//       response = await http.get(Uri.parse(url), headers: defaultHeaders);
//     } else if (method.toUpperCase() == 'POST') {
//       response = await http.post(
//         Uri.parse(url),
//         headers: defaultHeaders,
//         body: body,
//       );
//     } else if (method.toUpperCase() == 'PUT') {
//       response = await http.put(
//         Uri.parse(url),
//         headers: defaultHeaders,
//         body: body,
//       );
//     } else if (method.toUpperCase() == 'DELETE') {
//       response = await http.delete(Uri.parse(url), headers: defaultHeaders);
//     } else {
//       throw Exception('Unsupported HTTP method: $method');
//     }

//     // Handle 401 here for ALL API calls
//     if (response.statusCode == 401) {
//       await TokenManager.clearAuthData();
//       Get.offAllNamed(RoutesName.login);

//       Future.delayed(Duration(milliseconds: 300), () {
//         Get.snackbar(
//           'Session Expired',
//           "Please login again",
//           duration: Duration(seconds: 3),
//           snackPosition: SnackPosition.TOP,
//         );
//       });

//       throw Exception('Unauthorized. Redirecting to login.');
//     }

//     return response;
//   }

//   // mustafa.sayyed@ariantechsolutions.com
//   // Testing@01

//   static Future<Map<String, dynamic>> verifyEmail(Map body) async {
//     const url = '${baseUrl}login/verify-email';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.post(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       // Log the response for debugging
//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');
//       print(uri);

//       if (response.statusCode == 200) {
//         return {'isSuccess': true, 'data': jsonDecode(response.body)};
//       } else {
//         return {'isSuccess': false, 'data': jsonDecode(response.body)};
//       }
//     } catch (error) {
//       // Log any error that occurs during the API call
//       print('Error: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   static Future<Map<String, dynamic>> forgetPwd(Map body) async {
//     const url = '${baseUrl}login/forgot-pwd/verify-email';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.post(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       // Log the response for debugging
//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 200) {
//         return {'isSuccess': true, 'data': jsonDecode(response.body)};
//       } else {
//         return {'isSuccess': false, 'data': jsonDecode(response.body)};
//       }
//     } catch (error) {
//       // Log any error that occurs during the API call
//       print('Error: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   static Future<Map<String, dynamic>> verifyOtp(Map body) async {
//     const url = '${baseUrl}login/verify-otp';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.post(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       // Log the response for debugging
//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         print('Parsed verification response: $responseData');
//         return {'isSuccess': true, 'data': responseData};
//       } else {
//         final errorData = jsonDecode(response.body);
//         print('Error verification response: $errorData');
//         return {'isSuccess': false, 'data': errorData};
//       }
//     } catch (error) {
//       print('Error during OTP verification: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   static Future<Map<String, dynamic>> forgetOtp(Map body) async {
//     const url = '${baseUrl}events/forgot-pwd/verify-otp';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.post(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       // Log the response for debugging
//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         print('Parsed verification response: $responseData');
//         return {'isSuccess': true, 'data': responseData};
//       } else {
//         final errorData = jsonDecode(response.body);
//         print('Error verification response: $errorData');
//         return {'isSuccess': false, 'data': errorData};
//       }
//     } catch (error) {
//       print('Error during OTP verification: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   // login api

//   // static Future<Map<String, dynamic>> onLogin(Map body) async {
//   //   const url = '${baseUrl}login';
//   //   final uri = Uri.parse(url);

//   //   try {
//   //     final response = await http.post(
//   //       uri,
//   //       body: jsonEncode(body),
//   //       headers: {'Content-Type': 'application/json'},
//   //     );

//   //     print('API Status Code: ${response.statusCode}');
//   //     print('API Response Body: ${response.body}');

//   //     final responseData = jsonDecode(response.body);

//   //     // Check for success in both HTTP status and response body
//   //     if (response.statusCode == 200 &&
//   //         responseData['status'] == 200 &&
//   //         responseData.containsKey('data')) {
//   //       final data = responseData['data'];
//   //       final String token = data['token'];
//   //       final Map<String, dynamic>? user = data['user'];

//   //       // Save token for subsequent calls.
//   //       await Storage.saveToken(token);

//   //       if (user != null) {
//   //         return {'isSuccess': true, 'token': token, 'user': user};
//   //       } else {
//   //         return {
//   //           'isSuccess': false,
//   //           'message': 'User data missing in response',
//   //         };
//   //       }
//   //     } else {
//   //       // Return the backend error message if available.
//   //       return {
//   //         'isSuccess': false,
//   //         'message': responseData['message'] ?? 'Login failed',
//   //       };
//   //     }
//   //   } catch (error) {
//   //     print('Error: $error');
//   //     return {'isSuccess': false, 'error': error.toString()};
//   //   }
//   // }

//   static Future<Map<String, dynamic>> setPwd(Map body) async {
//     const url = '${baseUrl}login/create-pwd';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.put(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       // Log the response for debugging
//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 201) {
//         final responseData = jsonDecode(response.body);
//         print('Parsed response data: $responseData');
//         return {'isSuccess': true, 'data': responseData};
//       } else {
//         final errorData = jsonDecode(response.body);
//         print('Error response: $errorData');
//         return {'isSuccess': false, 'data': errorData};
//       }
//     } catch (error) {
//       // Log any error that occurs during the API call
//       print('Error in setPwd: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   static Future<Map<String, dynamic>> setNewPwd(Map body) async {
//     const url = '${baseUrl}login/forgot-pwd/new-pwd';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.put(
//         uri,
//         body: jsonEncode(body),
//         headers: {'Content-Type': 'application/json'},
//       );

//       // Log the response for debugging
//       print('API Status Code: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 201) {
//         final responseData = jsonDecode(response.body);
//         print('Parsed response data: $responseData');
//         return {'isSuccess': true, 'data': responseData};
//       } else {
//         final errorData = jsonDecode(response.body);
//         print('Error response: $errorData');
//         return {'isSuccess': false, 'data': errorData};
//       }
//     } catch (error) {
//       // Log any error that occurs during the API call
//       print('Error in setPwd: $error');
//       return {'isSuccess': false, 'error': error.toString()};
//     }
//   }

//   static Future<List?> loadFollowups(Map body) async {
//     const url = '${baseUrl}admin/leads/all';

//     final uri = Uri.parse(url);

//     final response = await http.get(uri);

//     if (response.statusCode == 200) {
//       final json = jsonDecode(response.body) as Map;
//       final result = json['items'] as List;
//       return result;
//     } else {
//       final Map<String, dynamic> errorData = json.decode(response.body);
//       final String errorMessage =
//           errorData['message'] ?? 'Failed to load dashboard data';

//       await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//       ();
//       return null;
//     }
//   }

//   //fetch users
//   // Add this method to your LeadsSrv class
//   static Future<List<Map<String, dynamic>>> fetchUsers() async {
//     final token = await Storage.getToken();
//     try {
//       print('🔍 Fetching users from: ${baseUrl}admin/users/all');
//       print('🔑 Using token: ${token?.substring(0, 10)}...');

//       final response = await http.get(
//         Uri.parse('${baseUrl}admin/users/all'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       print('📊 Response status code: ${response.statusCode}');
//       print('📄 Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         // Check if the response has the expected structure
//         if (data['data'] != null && data['data']['rows'] != null) {
//           final rows = data['data']['rows'] as List;
//           print('✅ Found ${rows.length} users');

//           // Convert to List<Map<String, dynamic>>
//           return List<Map<String, dynamic>>.from(rows);
//         } else {
//           print('❌ Unexpected response structure: $data');
//           throw Exception('Invalid response structure - missing data.rows');
//         }
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         print('❌ HTTP Error: ${response.statusCode}');
//         print('❌ Error body: ${response.body}');
//         throw Exception(
//           'Failed to fetch users. Status: ${response.statusCode}, Body: ${response.body}',
//         );
//       }
//     } catch (error) {
//       print('💥 Error in fetchUsers: $error');
//       rethrow; // Re-throw so the UI can handle it
//     }
//   }
//   //end

//   static Future<List<String>> fetchDropdownOptions() async {
//     const url = '${baseUrl}admin/users/all';
//     final uri = Uri.parse(url);

//     try {
//       final response = await http.get(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         // Assuming the API response is a list of strings:
//         // Example: { "options": ["Option 1", "Option 2", "Option 3"] }

//         return List<String>.from(data['options']);
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to fetch options');
//       }
//     } catch (error) {
//       print('Error fetching options: $error');
//       return [];
//     }
//   }

//   static Future<Map<String, dynamic>?> submitLead(
//     Map<String, dynamic> leadData,
//   ) async {
//     const String apiUrl = "${baseUrl}admin/leads/create";

//     final token = await Storage.getToken();
//     if (token == null) {
//       return {"error": "No token found. Please login."};
//     }

//     try {
//       final response = await http.post(
//         Uri.parse(apiUrl),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode(leadData),
//       );

//       final responseData = json.decode(response.body);

//       //   if (response.statusCode == 201) {
//       //     return responseData;
//       //   } else {
//       //     return {"error": responseData['message'] ?? "Failed."};
//       //   }
//       // } catch (e) {
//       //   return {"error": "An error occurred: $e"};
//       // }

//       if (response.statusCode == 201) {
//         return responseData;
//       } else {
//         print('Error: ${response.statusCode}');
//         print('Error details: ${response.body}');
//         showErrorMessageGetx(
//           message: 'Submission failed: ${response.statusCode}',
//         );
//         // return false;
//       }
//     } on SocketException {
//       showErrorMessageGetx(
//         message: 'No internet connection. Please check your network.',
//       );
//       // return false;
//     } on TimeoutException {
//       showErrorMessageGetx(
//         message: 'Request timed out. Please try again later.',
//       );
//       // return false;
//     } catch (e) {
//       print('Unexpected error: $e');
//       showErrorMessageGetx(
//         message: 'An unexpected error occurred. Please try again.',
//       );
//       // return false;
//     }
//   }

//   // create followups

//   static Future<bool> submitFollowups(
//     Map<String, dynamic> followupsData,
//     String leadId,
//     BuildContext context,
//   ) async {
//     final token = await Storage.getToken();

//     // Debugging: print the headers and body
//     print(
//       'Headers: ${{'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'recordId': leadId}}',
//     );

//     print('Request body: ${jsonEncode(followupsData)}');

//     try {
//       final response = await http.post(
//         Uri.parse('${baseUrl}admin/leads/$leadId/create-task'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//           'recordId': leadId,
//         },
//         body: jsonEncode(followupsData),
//       );

//       print('API Response Status: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       final responseData = json.decode(response.body);

//       if (response.statusCode == 201) {
//         return true;
//       } else {
//         print('Error: ${response.statusCode}');
//         print('Error details: ${response.body}');
//         showErrorMessage(
//           context,
//           // message: 'Submission failed: ${response.statusCode}',
//           message: 'Submission failed : ${responseData['message']}',
//         );
//         return false;
//       }
//     } on SocketException {
//       showErrorMessageGetx(
//         message: 'No internet connection. Please check your network.',
//       );
//       return false;
//     } on TimeoutException {
//       showErrorMessage(
//         context,
//         message: 'Request timed out. Please try again later.',
//       );
//       return false;
//     } catch (e) {
//       print('Unexpected error: $e');
//       showErrorMessage(
//         context,
//         message: 'An unexpected error occurred. Please try again.',
//       );
//       return false;
//     }
//   }

//   // create appoinment
//   static Future<bool> submitAppoinment(
//     Map<String, dynamic> followupsData,
//     String leadId,
//   ) async {
//     final token = await Storage.getToken();

//     // Debugging: print the headers and body
//     print(
//       'Headers: ${{'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'recordId': leadId}}',
//     );
//     print('Request body: ${jsonEncode(followupsData)}');

//     try {
//       final response = await http.post(
//         Uri.parse('${baseUrl}admin/records/$leadId/tasks/create-appointment'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//           'recordId': leadId,
//         },
//         body: jsonEncode(followupsData),
//       );

//       final responseData = jsonDecode(response.body);

//       print('API Response Status: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 201) {
//         return true;
//       } else {
//         print('Error: ${response.statusCode}');
//         print('Error details: ${response.body}');
//         showErrorMessageGetx(
//           message: 'Submission failed: ${responseData['message']}',
//         );
//         return false;
//       }
//     } on SocketException {
//       showErrorMessageGetx(
//         message: 'No internet connection. Please check your network.',
//       );
//       return false; // Added return statement
//     } on TimeoutException {
//       showErrorMessageGetx(
//         message: 'Request timed out. Please try again later.',
//       );
//       return false;
//     } catch (e) {
//       print('Unexpected error: $e');
//       showErrorMessageGetx(
//         message: 'An unexpected error occurred. Please try again.',
//       );
//       return false;
//     }
//   }
//   // static Future<bool> submitAppoinment(
//   //   Map<String, dynamic> followupsData,
//   //   String leadId,

//   // ) async {
//   //   final token = await Storage.getToken();

//   //   // Debugging: print the headers and body
//   //   print(
//   //     'Headers: ${{'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'recordId': leadId}}',
//   //   );
//   //   print('Request body: ${jsonEncode(followupsData)}');

//   //   try {
//   //     final response = await http.post(
//   //       Uri.parse('${baseUrl}admin/records/$leadId/tasks/create-appointment'),
//   //       headers: {
//   //         'Authorization': 'Bearer $token',
//   //         'Content-Type': 'application/json',
//   //         'recordId': leadId,
//   //       },
//   //       body: jsonEncode(followupsData),
//   //     );

//   //     print('API Response Status: ${response.statusCode}');
//   //     print('API Response Body: ${response.body}');

//   //     if (response.statusCode == 201) {
//   //       return true;
//   //     } else {
//   //       print('Error: ${response.statusCode}');
//   //       print('Error details: ${response.body}');
//   //       showErrorMessageGetx(
//   //         message: 'Submission failed: ${response.statusCode}',
//   //       );
//   //       return false;
//   //     }
//   //   } on SocketException {
//   //     showErrorMessageGetx(
//   //       message: 'No internet connection. Please check your network.',
//   //     );
//   //     // return false;
//   //   } on TimeoutException {
//   //     showErrorMessageGetx(
//   //       message: 'Request timed out. Please try again later.',
//   //     );
//   //     return false;
//   //   } catch (e) {
//   //     print('Unexpected error: $e');
//   //     showErrorMessageGetx(
//   //       message: 'An unexpected error occurred. Please try again.',
//   //     );
//   //     return false;
//   //   }
//   // }

//   static Future<bool> submitTestDrive(
//     Map<String, dynamic> testdriveData,
//     String leadId,
//   ) async {
//     final token = await Storage.getToken();

//     try {
//       final response = await http.post(
//         Uri.parse('${baseUrl}admin/records/$leadId/events/create-test-drive'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//           'recordId': leadId,
//         },
//         body: jsonEncode(testdriveData),
//       );

//       final responseData = jsonDecode(response.body);

//       print('API Response Status: ${response.statusCode}');
//       print('API Response Body: ${response.body}');

//       if (response.statusCode == 201) {
//         return true;
//       } else {
//         showErrorMessageGetx(
//           message: 'Submission failed: ${responseData['message']}',
//         );
//         print('Error details: ${response.body}');
//         return false;
//       }
//     } on SocketException {
//       showErrorMessageGetx(
//         message: 'No internet connection. Please check your network.',
//       );
//       return false;
//     } on TimeoutException {
//       showErrorMessageGetx(
//         message: 'Request timed out. Please try again later.',
//       );
//       return false;
//     } catch (e) {
//       print('Unexpected error: $e');
//       showErrorMessageGetx(
//         message: 'An unexpected error occurred. Please try again.',
//       );
//       return false;
//     }
//   }

//   static Future<Map<String, dynamic>> fetchLeadsById(String leadId) async {
//     const String apiUrl = "${baseUrl}leads/";

//     final token = await Storage.getToken();
//     if (token == null) {
//       print("No token found. Please login.");
//       throw Exception("No token found. Please login.");
//     }

//     try {
//       // Debug: Print the full URL with leadId
//       final fullUrl = Uri.parse('$apiUrl$leadId');
//       print('Fetching data from URL: $fullUrl');

//       final response = await http.get(
//         fullUrl, // Use the full URL
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//           'leadId': leadId,
//         },
//       );

//       // Debug: Print response details
//       print('Response status code: ${response.statusCode}');
//       print('Response body: ${response.body}');
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);

//         if (responseData.containsKey('data')) {
//           return responseData['data'];
//         } else {
//           throw Exception('Unexpected response structure: ${response.body}');
//         }
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception(
//           'Failed to load data: ${response.statusCode} - ${response.body}',
//         );
//       }
//     } catch (e) {
//       print('Error fetching data: $e');
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   static Future<Map<String, dynamic>> singleFollowupsById(String leadId) async {
//     const String apiUrl = "${baseUrl}leads/by-id/";

//     final token = await Storage.getToken();
//     if (token == null) {
//       // print("No token found. Please login.");
//       throw Exception("No token found. Please login.");
//     }

//     try {
//       final response = await http.get(
//         Uri.parse('$apiUrl$leadId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//           'leadId': leadId,
//         },
//       );

//       // Debug: Print the response status code and body
//       print('this is upper api');
//       print('Response status code: ${response.statusCode}');
//       print('Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data;
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching data: $e');
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   // history data api

//   static Future<List<Map<String, dynamic>>> singleTaskById(
//     String leadId,
//   ) async {
//     const String apiUrl = "${baseUrl}admin/leads/tasks/all/";

//     final token = await Storage.getToken();
//     if (token == null) {
//       print("No token found. Please login.");
//       throw Exception("No token found. Please login.");
//     }

//     try {
//       print('Fetching data for Lead ID: $leadId');
//       print('API URL: ${apiUrl + leadId}');

//       final response = await http.get(
//         Uri.parse('$apiUrl$leadId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       print('Response status code: ${response.statusCode}');
//       print('Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);

//         // Handle the nested structure with allEvents.rows
//         if (data.containsKey('data') &&
//             data['data'].containsKey('allTasks') &&
//             data['data']['allTasks'].containsKey('rows')) {
//           // Extract the rows containing the task data
//           return List<Map<String, dynamic>>.from(
//             data['data']['allTasks']['rows'],
//           );
//         } else {
//           return []; // Return empty list if no tasks found
//         }
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching data: $e');
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   // static Future<List<Map<String, dynamic>>> singleTasksById(
//   //     String leadId) async {
//   //   const String apiUrl =
//   //       "https://api.smartassistapps.in/api/admin/leads/tasks/all/";

//   //   final token = await Storage.getToken();
//   //   if (token == null) {
//   //     print("No token found. Please login.");
//   //     throw Exception("No token found. Please login.");
//   //   }

//   //   try {
//   //     print('Fetching data for Lead ID: $leadId');
//   //     print('API URL: ${apiUrl + leadId}');

//   //     final response = await http.get(
//   //       Uri.parse('$apiUrl$leadId'),
//   //       headers: {
//   //         'Authorization': 'Bearer $token',
//   //         'Content-Type': 'application/json',
//   //       },
//   //     );

//   //     print('Response status code: ${response.statusCode}');
//   //     print('Response body: ${response.body}');

//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> data = json.decode(response.body);

//   //       // Handle the nested structure with allEvents.rows
//   //       if (data.containsKey('allTasks') &&
//   //           data['allTasks'] is Map<String, dynamic> &&
//   //           data['allTasks'].containsKey('rows')) {
//   //         return List<Map<String, dynamic>>.from(data['allTasks']['rows']);
//   //       } else {
//   //         return []; // Return empty list if no events found
//   //       }
//   //     } else {
//   //       throw Exception('Failed to load data: ${response.statusCode}');
//   //     }
//   //   } catch (e) {
//   //     print('Error fetching data: $e');
//   //     throw Exception('Error fetching data: $e');
//   //   }
//   // }

//   static Future<Map<String, dynamic>> eventTaskByLead(String leadId) async {
//     const String apiUrl = "${baseUrl}leads/events-&-tasks/";
//     final token = await Storage.getToken();

//     try {
//       // Append the leadId and subject to the API URL
//       print('Fetching data for Lead ID: $leadId');
//       print('API URL: ${apiUrl + leadId}');
//       final response = await http.get(
//         Uri.parse('${apiUrl + leadId}'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       print('Response status code: ${response.statusCode}');
//       print('Response body for both data task and event: ${response.body}');

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> jsonResponse = json.decode(response.body);
//         final Map<String, dynamic> data = jsonResponse['data'];
//         return data;
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   // for teams only
//   static Future<Map<String, dynamic>> eventTaskByLeadTeams(
//     String leadId,
//     String userId,
//   ) async {
//     const String apiUrl = "${baseUrl}leads/events-&-tasks/";
//     final token = await Storage.getToken();

//     try {
//       final fullUrl = '$apiUrl$leadId?user_id=$userId';
//       print('Fetching data for Lead ID: $leadId');
//       print('API URL: $fullUrl');

//       final response = await http.get(
//         Uri.parse(fullUrl),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       print('Response status code: ${response.statusCode}');
//       print('Response body for both data task and event: ${response.body}');

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> jsonResponse = json.decode(response.body);
//         final Map<String, dynamic> data = jsonResponse['data'];
//         return data;
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   static Future<List<Map<String, dynamic>>> singleTestDriveById(
//     String leadId,
//     String subject,
//   ) async {
//     const String apiUrl = "${baseUrl}admin/leads/events/all/";

//     final token = await Storage.getToken();

//     try {
//       // Append the leadId and subject to the API URL
//       final response = await http.get(
//         Uri.parse('${apiUrl + leadId + '?' + subject}'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);

//         // Handle the nested structure with allEvents.rows
//         if (data.containsKey('data') &&
//             data['data'].containsKey('allEvents') &&
//             data['data']['allEvents'].containsKey('rows')) {
//           // Extract the rows containing the task data
//           return List<Map<String, dynamic>>.from(
//             data['data']['allEvents']['rows'],
//           );
//         } else {
//           return []; // Return empty list if no events found
//         }
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   static Future<List<Map<String, dynamic>>> singleTasksById(
//     String leadId,
//   ) async {
//     const String apiUrl = "${baseUrl}admin/leads/events/all/";

//     final token = await Storage.getToken();
//     if (token == null) {
//       print("No token found. Please login.");
//       throw Exception("No token found. Please login.");
//     }

//     try {
//       print('Fetching data for Lead ID: $leadId');
//       print('API URL: ${apiUrl + leadId}');

//       final response = await http.get(
//         Uri.parse('$apiUrl$leadId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       print('Response status code: ${response.statusCode}');
//       print('Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);

//         // Ensure the data structure contains 'allTasks' and 'rows'
//         if (data.containsKey('data') &&
//             data['data'].containsKey('allEvents') &&
//             data['data']['allEvents'].containsKey('rows')) {
//           // Extract the rows containing the task data
//           return List<Map<String, dynamic>>.from(
//             data['data']['allEvents']['rows'],
//           );
//         } else {
//           return []; // Return empty list if no tasks found
//         }
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching data: $e');
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   //
//   static Future<Map<String, dynamic>> singleAppointmentById(
//     String eventId,
//   ) async {
//     const String apiUrl = "${baseUrl}admin/events/";

//     final token = await Storage.getToken();
//     if (token == null) {
//       print("No token found. Please login.");
//       throw Exception("No token found. Please login.");
//     }

//     try {
//       // Ensure the actual leadId is being passed correctly
//       print('Fetching data for Lead ID: $eventId');
//       print(
//         'API URL: ${apiUrl + eventId}',
//       ); // Concatenate the leadId with the API URL

//       final response = await http.get(
//         Uri.parse('$apiUrl$eventId'), // Correct URL with leadId appended
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//           'eventId': eventId,
//         },
//       );

//       // Debug: Print the response status code and body
//       print('Response status code: ${response.statusCode}');
//       print('Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data; // Return the response data
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching data: $e');
//       throw Exception('Error fetching data: $e');
//     }
//   }

//   // Fetch appointments (tasks) for a selected date
//   static Future<List<dynamic>> fetchAppointments(DateTime selectedDate) async {
//     final DateTime finalDate = selectedDate ?? DateTime.now();
//     final String formattedDate = DateFormat('dd-MM-yyyy').format(finalDate);
//     final String apiUrl =
//         '${baseUrl}calendar/events/all/asondate?date=$formattedDate';

//     final token = await Storage.getToken();

//     try {
//       final response = await http.get(
//         Uri.parse(apiUrl),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (response.statusCode == 200) {
//         print("Error: ${response.statusCode}");
//         final Map<String, dynamic> data = json.decode(response.body);
//         print("Total Appointments Fetched: ${data['data']['rows']?.length}");
//         return data['data']['rows'] ?? [];
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         print("Error: ${response.statusCode}");
//         return [];
//       }
//     } catch (error) {
//       print("Error fetching appointments: $error");

//       return [];
//     }
//   }

//   // fetch tasks change the url calendar

//   static Future<List<dynamic>> fetchtasks(DateTime selectedDate) async {
//     final DateTime finalDate = selectedDate ?? DateTime.now();
//     final String formattedDate = DateFormat('dd-MM-yyyy').format(finalDate);
//     final String apiUrl =
//         '${baseUrl}calendar/tasks/all/asondate?date=$formattedDate';

//     final token = await Storage.getToken();

//     try {
//       final response = await http.get(
//         Uri.parse(apiUrl),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (response.statusCode == 200) {
//         print("Error: ${response.statusCode}");
//         final Map<String, dynamic> data = json.decode(response.body);
//         return data['data']['rows'] ?? [];
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         print("Error: ${response.statusCode}");
//         return [];
//       }
//     } catch (error) {
//       print("Error fetching appointments: $error");

//       return [];
//     }
//   }

//   // Fetch event counts for a selected date
//   static Future<Map<String, int>> fetchCount(DateTime selectedDate) async {
//     final String formattedDate = DateFormat('dd-MM-yyyy').format(selectedDate);
//     final String apiUrl =
//         '${baseUrl}calendar/data-count/asondate?date=$formattedDate';
//     print("Calling API for count on: $formattedDate");
//     final token = await Storage.getToken();

//     try {
//       final response = await http.get(
//         Uri.parse(apiUrl),
//         headers: {'Authorization': 'Bearer $token'},
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         return {
//           'upcomingFollowupsCount': data['data']['upcomingFollowupsCount'] ?? 0,
//           'overdueFollowupsCount': data['data']['overdueFollowupsCount'] ?? 0,
//           'upcomingAppointmentsCount':
//               data['data']['upcomingAppointmentsCount'] ?? 0,
//           'overdueAppointmentsCount':
//               data['data']['overdueAppointmentsCount'] ?? 0,
//         };
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         print('API Error: ${response.statusCode}');
//         return {};
//       }
//     } catch (error) {
//       print("Error fetching event counts: $error");
//       return {};
//     }
//   }

//   static Future<Map<String, dynamic>> fetchDashboardData() async {
//     final token = await Storage.getToken();
//     try {
//       final response = await http.get(
//         Uri.parse('${baseUrl}users/dashboard?filterType=MTD&category=Leads'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> jsonResponse = json.decode(response.body);
//         // Dashboard data is nested under "data"
//         final Map<String, dynamic> data = jsonResponse['data'];
//         return data;
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         throw Exception(
//           'Failed to load dashboard data: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       throw Exception(e.toString());
//     }
//   }

//   // static Future<Map<String, dynamic>> fetchDashboardDataapi() async {
//   //   const url = '${baseUrl}users/dashboard?filterType=MTD&category=Leads';
//   //   final uri = Uri.parse(url);
//   //   try {
//   //     // final response = await http.get(uri);

//   //     final response = await makeAuthenticatedRequest(
//   //       'GET',
//   //       '${baseUrl}users/dashboard?filterType=MTD&category=Leads',
//   //     );

//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> jsonResponse = json.decode(response.body);
//   //       final Map<String, dynamic> data = jsonResponse['data'];
//   //       return data;
//   //     } else {
//   //       final Map<String, dynamic> errorData = json.decode(response.body);
//   //       final String errorMessage =
//   //           errorData['message'] ?? 'Failed to load dashboard data';
//   //       throw Exception(errorMessage);
//   //     }
//   //   } catch (e) {
//   //     throw Exception(e.toString());
//   //   }
//   // }

//   static Future<Map<String, dynamic>> fetchDashboardAnalytics() async {
//     try {
//       // Use the new authenticatedRequest method instead of manual token handling
//       final response = await authenticatedRequest(
//         method: 'GET',
//         endpoint: 'users/dashboard/analytics',
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> jsonResponse = json.decode(response.body);
//         final Map<String, dynamic> data = jsonResponse['data'];
//         return data;
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // No need to manually handle unauthorized - authenticatedRequest handles it
//         throw Exception(errorMessage);
//       }
//     } catch (e) {
//       print('Error in fetchDashboardAnalytics: $e');
//       throw Exception(e.toString());
//     }
//   }

//   // static Future<Map<String, dynamic>> fetchDashboardAnalytics() async {
//   //   final token = await Storage.getToken();
//   //   try {
//   //     final response = await http.get(
//   //       Uri.parse('${baseUrl}users/dashboard/analytics'),
//   //       headers: {
//   //         'Authorization': 'Bearer $token',
//   //         'Content-Type': 'application/json',
//   //       },
//   //     );

//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> jsonResponse = json.decode(response.body);
//   //       final Map<String, dynamic> data = jsonResponse['data'];
//   //       return data;
//   //     } else {
//   //       final Map<String, dynamic> errorData = json.decode(response.body);
//   //       final String errorMessage =
//   //           errorData['message'] ?? 'Failed to load dashboard data';
//   //       print("Failed to load data: $errorMessage");

//   //       // Check if unauthorized: status 401 or error message includes "unauthorized"
//   //       await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//   //       ();
//   //       throw Exception('');
//   //     }
//   //   } catch (e) {
//   //     throw Exception(e.toString());
//   //   }
//   // }

//   static Future<Map<String, dynamic>> fetchSingleCallLogData({
//     required int periodIndex,
//     required String selectedUserId,
//   }) async {
//     try {
//       final token = await Storage.getToken();

//       String periodParam;
//       switch (periodIndex) {
//         case 0:
//           periodParam = 'DAY';
//           break;
//         case 1:
//           periodParam = 'WEEK';
//           break;
//         case 2:
//           periodParam = 'MTD';
//           break;
//         case 3:
//           periodParam = 'QTD';
//           break;
//         case 4:
//           periodParam = 'YTD';
//           break;
//         default:
//           periodParam = 'DAY';
//       }

//       final Map<String, String> queryParams = {
//         'type': periodParam,
//         if (selectedUserId.isNotEmpty) 'userId': selectedUserId,
//       };

//       final uri = Uri.parse(
//         '${baseUrl}users/sm/dashboard/individual/call-analytics',
//       ).replace(queryParameters: queryParams);

//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );
//       final Map<String, dynamic> errorData = json.decode(response.body);
//       final String errorMessage =
//           errorData['message'] ?? 'Failed to load dashboard data';

//       if (response.statusCode == 200) {
//         final jsonData = json.decode(response.body);
//         return jsonData['data'];
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         throw Exception(
//           'Failed to fetch single call log data: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       print(e.toString());
//       throw Exception('Error fetching single call log data: $e');
//     }
//   }

//   static Future<Map<String, dynamic>> fetchAllCalllog({
//     required int periodIndex,
//   }) async {
//     try {
//       final token = await Storage.getToken();

//       // Determine the period parameter
//       String periodParam;
//       switch (periodIndex) {
//         case 1:
//           periodParam = 'DAY';
//           break;
//         case 2:
//           periodParam = 'WEEK';
//           break;
//         case 3:
//           periodParam = 'MTD';
//           break;
//         case 4:
//           periodParam = 'QTD';
//           break;
//         case 5:
//           periodParam = 'YTD';
//           break;
//         default:
//           periodParam = 'QTD';
//       }

//       final queryParams = {'type': periodParam};

//       final uri = Uri.parse(
//         '${baseUrl}users/sm/dashboard/call-analytics',
//       ).replace(queryParameters: queryParams);

//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final responseData = json.decode(response.body);
//         return {
//           'analyticsData': responseData['data'],
//           'membersData': List<Map<String, dynamic>>.from(
//             responseData['data']['members'],
//           ),
//         };
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception(
//           'Failed to fetch call analytics: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       print('Error in fetchAllCalllog: $e');
//       rethrow;
//     }
//   }

//   static Future<Map<String, dynamic>> fetchTeamDetails({
//     required int periodIndex,
//     required int metricIndex,
//     required int selectedProfileIndex,
//     required String selectedUserId,
//     required List<String> selectedCheckboxIds,
//     required int upcomingButtonIndex,
//   }) async {
//     try {
//       final token = await Storage.getToken();

//       // Build query parameters
//       final periodParam =
//           ['DAY', 'WEEK', 'MTD', 'QTD', 'YTD'].elementAtOrNull(periodIndex) ??
//           'QTD';

//       final summaryParam =
//           [
//             'enquiries',
//             'testDrives',
//             'orders',
//             'cancellation',
//             'netOrders',
//             'retail',
//           ].elementAtOrNull(metricIndex) ??
//           'enquiries';

//       final queryParams = {'type': periodParam, 'summary': summaryParam};

//       if (selectedProfileIndex != 0 && selectedUserId.isNotEmpty) {
//         queryParams['user_id'] = selectedUserId;
//       }

//       if (selectedCheckboxIds.isNotEmpty) {
//         queryParams['userIds'] = selectedCheckboxIds.join(',');
//       }

//       final uri = Uri.parse(
//         '${baseUrl}users/sm/dashboard/team-dashboard',
//       ).replace(queryParameters: queryParams);

//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final performance = data['data']?['selectedUserPerformance'] ?? {};
//         final upcoming = performance['Upcoming'] ?? {};
//         final overdue = performance['Overdue'] ?? {};

//         return {
//           'teamData': data['data'] ?? {},
//           'allMember': data['data']?['allMember'] ?? [],
//           'summary': data['data']?['summary'] ?? {},
//           'totalPerformance': data['data']?['totalPerformance'] ?? {},
//           'upcomingFollowups': List<Map<String, dynamic>>.from(
//             upcomingButtonIndex == 0
//                 ? upcoming['upComingFollowups'] ?? []
//                 : overdue['overdueFollowups'] ?? [],
//           ),
//           'upcomingAppointments': List<Map<String, dynamic>>.from(
//             upcomingButtonIndex == 0
//                 ? upcoming['upComingAppointment'] ?? []
//                 : overdue['overdueAppointments'] ?? [],
//           ),
//           'upcomingTestDrives': List<Map<String, dynamic>>.from(
//             upcomingButtonIndex == 0
//                 ? upcoming['upComingTestDrive'] ?? []
//                 : overdue['overdueTestDrives'] ?? [],
//           ),
//         };
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         throw Exception('Failed to fetch data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('❌ Error in LeadsSrv.fetchTeamDetails: $e');
//       rethrow;
//     }
//   }

//   static Future<Map<String, dynamic>> fetchNotifications({
//     String? category,
//   }) async {
//     try {
//       final token = await Storage.getToken();
//       String url = '${baseUrl}users/notifications/all';

//       // Add category filter if provided
//       if (category != null && category != 'All') {
//         String formattedCategory = category.replaceAll(' ', '');
//         url += '?category=$formattedCategory';
//       }

//       final response = await http.get(
//         Uri.parse(url),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);

//         // Combine unread and read notifications
//         List<dynamic> allNotifications = [];
//         if (data['data']['unread']?['rows'] != null) {
//           allNotifications.addAll(data['data']['unread']['rows']);
//         }
//         if (data['data']['read']?['rows'] != null) {
//           allNotifications.addAll(data['data']['read']['rows']);
//         }

//         return {
//           'success': true,
//           'data': allNotifications,
//           'message': 'Notifications fetched successfully',
//         };
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         return {
//           'success': false,
//           'data': [],
//           'message': 'Failed to load notifications: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'data': [],
//         'message': 'Error fetching notifications: $e',
//       };
//     }
//   }

//   static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
//     try {
//       final token = await Storage.getToken();
//       final url = '${baseUrl}users/notifications/$notificationId';

//       final response = await http.put(
//         Uri.parse(url),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({'read': true}),
//       );

//       if (response.statusCode == 200) {
//         return {
//           'success': true,
//           'message': 'Notification marked as read successfully',
//         };
//       } else {
//         return {
//           'success': false,
//           'message': 'Failed to mark as read: ${response.statusCode}',
//         };
//       }
//     } catch (e) {
//       return {
//         'success': false,
//         'message': 'Error marking notification as read: $e',
//       };
//     }
//   }

//   static Future<bool> favorite({required String taskId}) async {
//     try {
//       final token = await Storage.getToken();
//       final response = await http.put(
//         Uri.parse('${baseUrl}favourites/mark-fav/task/$taskId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         print('❌ Failed to mark favorite: ${response.statusCode}');
//         return false;
//       }
//     } catch (e) {
//       print('❌ Error in favorite(): $e');
//       return false;
//     }
//   }

//   static Future<bool> favoriteEvent({required String taskId}) async {
//     try {
//       final token = await Storage.getToken();
//       final response = await http.put(
//         Uri.parse('${baseUrl}favourites/mark-fav/task/$taskId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         print(response.body.toString());
//         return true;
//       } else {
//         print(Uri.parse.toString());
//         print('❌ Failed to mark favorite: ${response.statusCode}');
//         return false;
//       }
//     } catch (e) {
//       print('❌ Error in favorite(): $e');
//       return false;
//     }
//   }

//   static Future<bool> favoriteTestDrive({required String eventId}) async {
//     try {
//       final token = await Storage.getToken();
//       final response = await http.put(
//         Uri.parse('${baseUrl}favourites/mark-fav/event/$eventId'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         return true;
//       } else {
//         print('❌ Failed to mark favorite: ${response.statusCode}');
//         return false;
//       }
//     } catch (e) {
//       print('❌ Error in favorite(): $e');
//       return false;
//     }
//   }

//   static Future<Map<String, dynamic>> getAllVehicles() async {
//     try {
//       final token = await Storage.getToken();
//       final response = await http.get(
//         Uri.parse('${baseUrl}users/vehicles/all'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         return {'success': true, 'data': data['data']['rows'] ?? []};
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         return {
//           'success': false,
//           'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
//         };
//       }
//     } catch (e) {
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   // static Future<Map<String, dynamic>> vehicleSearch(String query) async {
//   //   try {
//   //     final token = await Storage.getToken();
//   //     final response = await http.get(
//   //       Uri.parse(
//   //         '${baseUrl}search/vehicles?vehicle=${Uri.encodeComponent(query)}',
//   //       ),
//   //       headers: {
//   //         'Authorization': 'Bearer $token',
//   //         'Content-Type': 'application/json',
//   //       },
//   //     );

//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> data = json.decode(response.body);
//   //       return {'success': true, 'data': data['data']['suggestions'] ?? []};
//   //     } else {
//   //       return {
//   //         'success': false,
//   //         'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
//   //       };
//   //     }
//   //   } catch (e) {
//   //     return {'success': false, 'error': e.toString()};
//   //   }
//   // }

//   static Future<Map<String, dynamic>> globalSearch(String query) async {
//     try {
//       final token = await Storage.getToken();

//       final response = await http.get(
//         Uri.parse('${baseUrl}search/global?query=$query'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         return {'success': true, 'data': data['data']['results'] ?? []};
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         return {
//           'success': false,
//           'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
//         };
//       }
//     } catch (e) {
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   static Future<Map<String, dynamic>> getVehicle(String query) async {
//     try {
//       final token = await Storage.getToken();

//       final response = await http.get(
//         Uri.parse('${baseUrl}search/global?query=$query'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         return {'success': true, 'data': data['data']['suggestions'] ?? []};
//       } else {
//         final Map<String, dynamic> errorData = json.decode(response.body);
//         final String errorMessage =
//             errorData['message'] ?? 'Failed to load dashboard data';
//         print("Failed to load data: $errorMessage");

//         // Check if unauthorized: status 401 or error message includes "unauthorized"
//         await handleUnauthorizedIfNeeded(response.statusCode, errorMessage);
//         ();
//         return {
//           'success': false,
//           'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
//         };
//       }
//     } catch (e) {
//       return {'success': false, 'error': e.toString()};
//     }
//   }

//   static Future<bool> getOtp({required String eventId}) async {
//     try {
//       final token = await Storage.getToken();
//       final url = Uri.parse(
//         'https://api.smartassistapps.in/api/events/$eventId/send-consent',
//       );

//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       print('📨 Sent OTP request for eventId: $eventId');
//       print('📥 Status Code: ${response.statusCode}');

//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ Error in getOtp(): $e');
//       return false;
//     }
//   }
// }

