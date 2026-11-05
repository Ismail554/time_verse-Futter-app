import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

/// Interceptor that automatically injects the stored JWT Bearer token
/// and local IANA timezone headers into every outgoing request.
/// Uses QueuedInterceptor to safely coordinate concurrent token refresh on 401s.
class AuthAndHeadersInterceptor extends QueuedInterceptor {
  static String clientTimezone = 'UTC';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // 1. Inject Authorization header if not already supplied
      final currentAuth = options.headers['Authorization'];
      if (currentAuth == null || currentAuth.toString().trim().isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null && token.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${token.trim()}';
        }
      }

      // 2. Inject client IANA timezone metadata for server date/time conversions
      final now = DateTime.now();
      options.headers['X-Timezone'] = clientTimezone;
      options.headers['X-Timezone-Offset'] = now.timeZoneOffset.inMinutes.toString();
    } catch (e) {
      debugPrint('⚠️ AuthAndHeadersInterceptor error on request: $e');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final isAuthEndpoint = path.contains('/login') ||
        path.contains('/register') ||
        path.contains('/token/refresh') ||
        path.contains('/forget_password') ||
        path.contains('/reset-password') ||
        path.contains('/verify-otp');

    if (err.response?.statusCode == 401 && !isAuthEndpoint) {
      debugPrint('🚨 [Auth] 401 Unauthorized received for: ${err.requestOptions.uri.path}. Initiating token refresh...');
      try {
        final authService = AuthService();
        final newAccessToken = await authService.refreshAccessToken();

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          debugPrint('🔄 Retrying original request with rotated access token...');
          final requestOptions = err.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          // Use a clean Dio instance to replay the request
          final retryDio = Dio(
            BaseOptions(
              baseUrl: requestOptions.baseUrl,
              connectTimeout: requestOptions.connectTimeout,
              receiveTimeout: requestOptions.receiveTimeout,
              sendTimeout: requestOptions.sendTimeout,
              responseType: requestOptions.responseType,
              contentType: requestOptions.contentType,
              validateStatus: requestOptions.validateStatus,
            ),
          );

          final response = await retryDio.request<dynamic>(
            requestOptions.path,
            data: requestOptions.data,
            queryParameters: requestOptions.queryParameters,
            options: Options(
              method: requestOptions.method,
              headers: requestOptions.headers,
            ),
          );

          return handler.resolve(response);
        } else {
          debugPrint('⚠️ Token refresh failed.');
          final refreshToken = await authService.getRefreshToken();
          if (refreshToken == null || JwtDecoder.isExpired(refreshToken)) {
            debugPrint('🚨 Refresh token is expired or absent. Clearing session.');
            await authService.clearToken();
            await AppPrefs.setLoggedIn(false);
          }
        }
      } catch (e) {
        debugPrint('❌ Token refresh error in interceptor: $e');
      }
    }

    handler.next(err);
  }
}
