import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Centralized Dio interceptor that logs all outgoing HTTP requests,
/// incoming HTTP responses, and network errors in a clear, formatted layout.
class ApiLoggingInterceptor extends Interceptor {
  final bool logHeaders;
  final bool logRequestBody;
  final bool logResponseBody;
  final bool logErrors;
  final int maxBodyLength;

  ApiLoggingInterceptor({
    this.logHeaders = true,
    this.logRequestBody = true,
    this.logResponseBody = true,
    this.logErrors = true,
    this.maxBodyLength = 5000,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['request_start_time'] = DateTime.now().millisecondsSinceEpoch;

    try {
      final buffer = StringBuffer();
      buffer.writeln('\n┌──────────────────────── [API REQUEST] ────────────────────────');
      buffer.writeln('│ 🌐 Method : ${options.method.toUpperCase()}');
      buffer.writeln('│ 🔗 URL    : ${options.uri}');

      if (options.queryParameters.isNotEmpty) {
        buffer.writeln('│ 🔍 Query  : ${_formatObject(options.queryParameters)}');
      }

      if (logHeaders && options.headers.isNotEmpty) {
        buffer.writeln('│ 📋 Headers:');
        options.headers.forEach((key, value) {
          buffer.writeln('│    $key: $value');
        });
      }

      if (logRequestBody && options.data != null) {
        buffer.writeln('│ 📦 Body   :');
        buffer.writeln(_indentString(_formatBody(options.data)));
      }

      buffer.write('└───────────────────────────────────────────────────────────────');
      _log(buffer.toString());
    } catch (e) {
      _log('⚠️ ApiLoggingInterceptor error on request: $e');
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final startTime = response.requestOptions.extra['request_start_time'] as int?;
      final duration = startTime != null ? DateTime.now().millisecondsSinceEpoch - startTime : null;
      final durationStr = duration != null ? ' [${duration}ms]' : '';
      final statusCode = response.statusCode ?? 0;
      final statusMessage = response.statusMessage ?? '';
      final isSuccess = statusCode >= 200 && statusCode < 300;
      final statusIcon = isSuccess ? '✅' : '⚠️';

      final buffer = StringBuffer();
      buffer.writeln('\n┌──────────────────────── [API RESPONSE] ───────────────────────');
      buffer.writeln('│ $statusIcon Status : $statusCode $statusMessage$durationStr');
      buffer.writeln('│ 🌐 Method : ${response.requestOptions.method.toUpperCase()}');
      buffer.writeln('│ 🔗 URL    : ${response.requestOptions.uri}');

      if (logResponseBody && response.data != null) {
        buffer.writeln('│ 📥 Data   :');
        buffer.writeln(_indentString(_formatBody(response.data)));
      }

      buffer.write('└───────────────────────────────────────────────────────────────');
      _log(buffer.toString());
    } catch (e) {
      _log('⚠️ ApiLoggingInterceptor error on response: $e');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (logErrors) {
      try {
        final startTime = err.requestOptions.extra['request_start_time'] as int?;
        final duration = startTime != null ? DateTime.now().millisecondsSinceEpoch - startTime : null;
        final durationStr = duration != null ? ' [${duration}ms]' : '';
        final statusCode = err.response?.statusCode;
        final statusMessage = err.response?.statusMessage ?? '';

        final buffer = StringBuffer();
        buffer.writeln('\n┌──────────────────────── [API ERROR] ──────────────────────────');
        buffer.writeln('│ ❌ URL    : ${err.requestOptions.uri}');
        buffer.writeln('│ 🌐 Method : ${err.requestOptions.method.toUpperCase()}');
        if (statusCode != null) {
          buffer.writeln('│ 🔢 Status : $statusCode $statusMessage$durationStr');
        } else if (durationStr.isNotEmpty) {
          buffer.writeln('│ ⏱️ Duration: $durationStr');
        }
        buffer.writeln('│ 🚨 Type   : ${err.type}');
        buffer.writeln('│ 💬 Message: ${err.message}');

        if (err.response?.data != null) {
          buffer.writeln('│ 📥 Error Data:');
          buffer.writeln(_indentString(_formatBody(err.response?.data)));
        }

        buffer.write('└───────────────────────────────────────────────────────────────');
        _log(buffer.toString());
      } catch (e) {
        _log('⚠️ ApiLoggingInterceptor error on error log: $e');
      }
    }

    handler.next(err);
  }

  String _formatBody(dynamic data) {
    if (data == null) return 'null';

    try {
      if (data is FormData) {
        final fields = data.fields.map((f) => '${f.key}: ${f.value}').toList();
        final files = data.files.map((f) => '${f.key}: ${f.value.filename} (${f.value.length} B)').toList();
        return 'FormData(\n  fields: $fields,\n  files: $files\n)';
      }

      if (data is Map || data is List) {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
        return _truncateIfNeeded(jsonStr);
      }

      if (data is String) {
        try {
          final decoded = jsonDecode(data);
          final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
          return _truncateIfNeeded(formatted);
        } catch (_) {
          return _truncateIfNeeded(data);
        }
      }

      return _truncateIfNeeded(data.toString());
    } catch (_) {
      return data.toString();
    }
  }

  String _formatObject(dynamic obj) {
    try {
      if (obj is Map || obj is List) {
        return const JsonEncoder.withIndent('  ').convert(obj);
      }
      return obj.toString();
    } catch (_) {
      return obj.toString();
    }
  }

  String _truncateIfNeeded(String str) {
    if (maxBodyLength > 0 && str.length > maxBodyLength) {
      return '${str.substring(0, maxBodyLength)}\n... [Truncated ${str.length - maxBodyLength} characters]';
    }
    return str;
  }

  String _indentString(String str) {
    return str.split('\n').map((line) => '│   $line').join('\n');
  }

  void _log(String message) {
    debugPrint(message);
  }
}

