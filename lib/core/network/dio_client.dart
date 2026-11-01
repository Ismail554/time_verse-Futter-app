import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:time_verse/core/network/api_interceptor.dart';

/// Centralized Dio client management providing pre-configured Dio instances
/// with request/response/error logging via [ApiLoggingInterceptor].
class DioClient {
  DioClient._();

  static Dio? _instance;

  /// Singleton shared [Dio] instance with standard configuration and logging.
  static Dio get instance {
    _instance ??= createDio();
    return _instance!;
  }

  /// Creates a newly configured [Dio] instance with [ApiLoggingInterceptor]
  /// and custom or default [BaseOptions].
  static Dio createDio({
    BaseOptions? options,
    List<Interceptor>? additionalInterceptors,
    bool enableLogging = true,
  }) {
    final dio = Dio(options ?? defaultOptions);

    if (enableLogging) {
      dio.interceptors.add(ApiLoggingInterceptor());
    }

    if (additionalInterceptors != null && additionalInterceptors.isNotEmpty) {
      dio.interceptors.addAll(additionalInterceptors);
    }

    return dio;
  }

  /// Default [BaseOptions] configured with `.env` BASE_URL and 15s timeouts.
  static BaseOptions get defaultOptions => BaseOptions(
        baseUrl: dotenv.env['BASE_URL'] ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
}

/// Convenience global factory function to create a Dio instance with logging interceptor.
Dio createDio({
  BaseOptions? options,
  List<Interceptor>? additionalInterceptors,
  bool enableLogging = true,
}) =>
    DioClient.createDio(
      options: options,
      additionalInterceptors: additionalInterceptors,
      enableLogging: enableLogging,
    );

/// Extension on [Dio] to attach [ApiLoggingInterceptor] if not already present.
extension DioLoggingExtension on Dio {
  Dio addLoggingInterceptor() {
    if (!interceptors.any((interceptor) => interceptor is ApiLoggingInterceptor)) {
      interceptors.add(ApiLoggingInterceptor());
    }
    return this;
  }
}

