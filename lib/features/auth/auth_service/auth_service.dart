// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:time_verse/features/auth/auth_model/auth_model.dart';

class AuthService {
  late final Dio _dio;
  final String _baseUrl = dotenv.env['BASE_URL'] ?? '';

  AuthService() {
    _dio = createDio(
      options: BaseOptions(
        baseUrl: _baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  // ---------------- TOKEN HANDLING ---------------- //
  static Completer<String?>? _refreshCompleter;
  static VoidCallback? onSessionExpired;

  Future<void> saveToken(String token, [String? refreshToken]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    debugPrint('✅ Tokens cleared from storage.');
  }

  /// Automatically refreshes the short-lived 15-minute JWT access token
  /// using the 30-day refresh token via POST /api/v1/token/refresh/.
  /// Uses a shared static Completer mutex to prevent concurrent refresh storms
  /// and token rotation collisions.
  Future<String?> refreshAccessToken({String? failedToken}) async {
    // 1. If another request already refreshed the token, return the new token immediately
    if (failedToken != null && failedToken.trim().isNotEmpty) {
      final currentStored = await getToken();
      if (currentStored != null && currentStored.trim().isNotEmpty && currentStored.trim() != failedToken.trim()) {
        debugPrint('🔄 Token was already refreshed by a concurrent request. Reusing new token.');
        return currentStored;
      }
    }

    // 2. If a refresh is already in flight, wait for its completion
    if (_refreshCompleter != null) {
      debugPrint('⏳ Refresh already in flight. Waiting for existing refresh to complete...');
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        debugPrint('⚠️ No refresh token available in storage.');
        _refreshCompleter?.complete(null);
        return null;
      }

      if (JwtDecoder.isExpired(refreshToken)) {
        debugPrint('⚠️ Stored refresh token is expired.');
        await clearToken();
        await AppPrefs.setLoggedIn(false);
        onSessionExpired?.call();
        _refreshCompleter?.complete(null);
        return null;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await refreshDio.post(
        'api/v1/token/refresh/',
        data: jsonEncode({'refresh': refreshToken}),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      if (response.statusCode == 200 && data != null) {
        final newAccess = data['access']?.toString();
        final newRefresh = data['refresh']?.toString();
        if (newAccess != null && newAccess.isNotEmpty) {
          await saveToken(newAccess, newRefresh);
          debugPrint('🔄 Access token successfully refreshed and rotated.');
          _refreshCompleter?.complete(newAccess);
          return newAccess;
        }
      }
      _refreshCompleter?.complete(null);
      return null;
    } catch (e) {
      debugPrint('❌ Error refreshing token: $e');
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        debugPrint('🚨 Refresh token invalidated/expired. Purging session.');
        await clearToken();
        await AppPrefs.setLoggedIn(false);
        onSessionExpired?.call();
      }
      _refreshCompleter?.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<int?> getUserIdFromToken() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return null;

    try {
      final decoded = JwtDecoder.decode(token);
      final rawId = decoded['user_id'] ?? decoded['user'] ?? decoded['id'];
      if (rawId is int) return rawId;
      if (rawId is String) return int.tryParse(rawId);
      return null;
    } catch (e) {
      debugPrint('⚠️ Error decoding user ID from token: $e');
      return null;
    }
  }

  // ---------------- USER INFO ---------------- //
  Future<int?> getUserId() async {
    return await getUserIdFromToken();
  }

  Future<Options> _authorizedHeader() async {
    final token = await getToken();
    return Options(
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return false;
    try {
      if (JwtDecoder.isExpired(token)) {
        debugPrint('⚠️ Stored access token is expired. Attempting token rotation...');
        final newAccess = await refreshAccessToken();
        if (newAccess != null) return true;

        // If refresh failed (e.g. device is offline), check if refresh token is still valid.
        // This prevents kicking the user out to login screen when opening app offline.
        final refreshToken = await getRefreshToken();
        if (refreshToken != null &&
            refreshToken.trim().isNotEmpty &&
            !JwtDecoder.isExpired(refreshToken)) {
          debugPrint('🌐 Offline session preserved: refresh token remains valid.');
          return true;
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Invalid JWT token format: $e');
      return false;
    }
  }

  // ---------------- AUTH REQUESTS ---------------- //

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        'api/v1/login/',
        data: jsonEncode({'email': email, 'password': password}),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final normalizedData = data['data'] != null
          ? data
          : {'data': {'access': data['access'], 'refresh': data['refresh'], 'user': data['user']}};

      if (response.statusCode == 200 && normalizedData['data']?['access'] != null) {
        final token = normalizedData['data']['access'];
        final refreshToken = normalizedData['data']['refresh'];
        debugPrint('🔑 Access Token received: $token');
        await saveToken(token, refreshToken is String ? refreshToken : null);
        await AppPrefs.setLoggedIn(true);

        final user = normalizedData['data']['user'] != null
            ? User.fromJson(normalizedData['data']['user'])
            : null;

        final rawUserId = user?.id ?? await getUserIdFromToken();
        final rawUserName = user?.name ?? '';
        final rawUserEmail = user?.email ?? email;
        final rawPhoto = user?.profilePicture;

        if (rawUserId != null) {
          await AppPrefs.saveUserSession(
            userId: rawUserId.toString(),
            userName: rawUserName,
            email: rawUserEmail,
            photoUrl: rawPhoto,
          );
          UserSession().userId = rawUserId.toString();
          UserSession().username = rawUserName;
          UserSession().profileImageUrl = rawPhoto;
        }

        return {
          'success': true,
          'data': {
            'token': token,
            'refresh': normalizedData['data']['refresh'],
            'user': user,
          },
        };
      }

      final errorMessage = normalizedData['detail'] ?? normalizedData['message'] ?? 'Login failed';
      return {
        'success': false,
        'error': errorMessage,
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String firstName,
    String lastName,
    String gender,
    String nationality, {
    String? profileImagePath,
  }) async {
    debugPrint("Image path: $profileImagePath");

    try {
      final hasImage =
          profileImagePath != null && profileImagePath.trim().isNotEmpty;
      final FormData formData = FormData.fromMap({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'gender': gender,
        'nationality': nationality,
        if (hasImage)
          'profile_picture': await MultipartFile.fromFile(
            profileImagePath.trim(),
            filename: profileImagePath.trim().split(RegExp(r'[\\/]')).last,
          ),
      });

      final response = await _dio.post(
        'api/v1/register/',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;

      final userData = data['user'] ?? data['data']?['user'];
      final user = userData != null ? User.fromJson(userData) : null;

      // Automatically store token if backend provides immediate login tokens
      final accessToken = data['access'] ?? data['access_token'] ?? data['data']?['access'];
      final refreshToken = data['refresh'] ?? data['refresh_token'] ?? data['data']?['refresh'];
      if (accessToken != null && accessToken is String) {
        await saveToken(accessToken, refreshToken is String ? refreshToken : null);
        await AppPrefs.setLoggedIn(true);
      }

      return {
        'success': true,
        'message': data['message'] ?? 'Signup successful',
        'data': {
          'access': accessToken,
          'refresh': refreshToken,
          'user': user,
        },
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': _handleError(e),
      };
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        'api/v1/forget_password/',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({'email': email}),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final userData = data['data']?['user'];
      final user = userData != null ? User.fromJson(userData) : null;

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Password reset initiated',
        'data': {'user': user},
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        'api/v1/verify-otp/',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final userData = data['data']?['user'];
      final user = userData != null ? User.fromJson(userData) : null;
      final resetToken = data['reset_token'] ?? data['data']?['reset_token'];

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'OTP verified',
        'reset_token': resetToken,
        'data': {'user': user},
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String newPassword, {
    String? resetToken,
  }) async {
    try {
      final payload = <String, dynamic>{
        'email': email,
        'new_password': newPassword,
        if (otp.isNotEmpty) 'otp': otp,
        if (resetToken != null && resetToken.isNotEmpty) 'reset_token': resetToken,
      };

      final response = await _dio.post(
        'api/v1/reset-password/',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode(payload),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final userData = data['data']?['user'];
      final user = userData != null ? User.fromJson(userData) : null;

      return {
        'success': response.statusCode == 200 ||
            data['message']?.toString().toLowerCase().contains('success') == true,
        'message': data['message'] ?? 'Password reset successful',
        'data': {'user': user},
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await _dio.post(
        '/api/v1/change-password/',
        options: await _authorizedHeader(),
        data: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final userData = data['data']?['user'];
      final user = userData != null ? User.fromJson(userData) : null;

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Password changed successfully',
        'data': {'user': user},
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _handleError(e)};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final response = await _dio.post(
        'api/v1/resend-otp/',
        data: jsonEncode({"email": email}),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'OTP resent successfully',
      };
    } on DioException catch (e) {
      return {'success': false, 'error': _handleError(e)};
    }
  }

  /// Calls the backend POST /api/v1/logout/ endpoint to blacklist the refresh token
  /// and clears stored tokens locally.
  Future<bool> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      final token = await getToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final logoutDio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        await logoutDio.post(
          'api/v1/logout/',
          data: jsonEncode({'refresh': refreshToken}),
        );
        debugPrint('✅ Logged out from server (refresh token blacklisted).');
      }
    } catch (e) {
      debugPrint('⚠️ Server logout notification error: $e');
    } finally {
      await clearToken();
      await AppPrefs.setLoggedIn(false);
    }
    return true;
  }

  // ---------------- ERROR HANDLER (RFC 7807 COMPLIANT) ---------------- //
  String _handleError(DioException e) {
    debugPrint("DioException response: ${e.response?.data}");

    if (e.response != null && e.response!.data != null) {
      final data = e.response!.data;

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        final errors = data['errors'];
        final message = data['message'];
        final error = data['error'];

        if (detail != null && detail.toString().trim().isNotEmpty) {
          return detail.toString();
        }

        if (errors is Map && errors.isNotEmpty) {
          final errorMessages = <String>[];
          errors.forEach((key, val) {
            if (val is List && val.isNotEmpty) {
              errorMessages.add('$key: ${val.first}');
            } else if (val != null) {
              errorMessages.add('$key: $val');
            }
          });
          if (errorMessages.isNotEmpty) {
            return errorMessages.join('\n');
          }
        }

        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
        if (error != null && error.toString().trim().isNotEmpty) {
          return error.toString();
        }

        for (var entry in data.entries) {
          if (['type', 'title', 'status', 'error_id'].contains(entry.key)) continue;
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          } else if (value is String) {
            return value;
          }
        }
        return 'Request failed';
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
            if (detail != null && detail.toString().trim().isNotEmpty) {
              return detail.toString();
            }
          }
        } catch (_) {
          return data;
        }
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Try again.';
    }
    if (e.type == DioExceptionType.badResponse && e.response?.statusCode == 401) {
      return 'Unauthorized. Please log in again.';
    }
    return e.message ?? 'Something went wrong. Please try later.';
  }
}
