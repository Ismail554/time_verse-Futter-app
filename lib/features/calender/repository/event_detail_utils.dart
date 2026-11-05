import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class EventDateTimeUtils {
  static final List<DateFormat> _dateFormats = [
    DateFormat("yyyy-MM-dd"),
    DateFormat("dd/MM/yyyy"),
    DateFormat("dd-MM-yyyy"),
    DateFormat("MM/dd/yyyy"),
    DateFormat("MM-dd-yyyy"),
    DateFormat("EEEE, MMMM d, yyyy"),
    DateFormat("MMMM d, yyyy"),
    DateFormat("d MMMM yyyy"),
  ];

  /// Cleans raw time strings into HH:mm format
  static String cleanTimeStr(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return "00:00";

    if (clean.toLowerCase().contains('am') || clean.toLowerCase().contains('pm')) {
      for (final pattern in ["h:mm a", "hh:mm:ss a", "hh:mm a"]) {
        try {
          return DateFormat("HH:mm").format(DateFormat(pattern).parse(clean));
        } catch (_) {}
      }
    }

    final parts = clean.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return "$hour:$minute";
    }

    return clean;
  }

  /// Calculates alarm offset back from event start time
  static String calculateAlarmOffset(String startTimeClean, String alarmClean) {
    if (alarmClean.isEmpty || startTimeClean.isEmpty) return startTimeClean;
    try {
      final lowerAlarm = alarmClean.toLowerCase();
      if (lowerAlarm.contains(':') || lowerAlarm.contains('am') || lowerAlarm.contains('pm')) {
        return cleanTimeStr(lowerAlarm);
      }

      final parts = startTimeClean.split(':');
      final baseTime = DateTime(2026, 1, 1, int.parse(parts[0]), int.parse(parts[1]));

      int minutesBefore = 10;
      final match = RegExp(r'\d+').firstMatch(lowerAlarm);

      if (match != null) {
        final val = int.parse(match.group(0)!);
        if (lowerAlarm.contains('hr') || lowerAlarm.contains('hour')) {
          minutesBefore = val * 60;
        } else if (lowerAlarm.contains('day')) {
          minutesBefore = val * 1440;
        } else {
          minutesBefore = val;
        }
      }

      final calculated = baseTime.subtract(Duration(minutes: minutesBefore));
      return DateFormat("HH:mm:ss").format(calculated);
    } catch (e) {
      debugPrint("⚠️ Failed to parse offset: $e");
      return startTimeClean;
    }
  }

  /// Parses date string and time string into a local DateTime instance
  static DateTime parseDateTime(String rawDate, String rawTime) {
    final cleanDate = rawDate.trim();
    final cleanTime = cleanTimeStr(rawTime);

    DateTime? parsedDate;
    for (final format in _dateFormats) {
      try {
        parsedDate = format.parseStrict(cleanDate);
        break;
      } catch (_) {}
    }

    final timeParts = cleanTime.split(':');
    final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

    if (parsedDate != null) {
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
    }

    // Explicitly parse local fields to prevent UTC date shifting
    final fallback = DateTime.tryParse(cleanDate) ?? DateTime.now();
    return DateTime(fallback.year, fallback.month, fallback.day, hour, minute);
  }

  /// Formats date and time into UTC ISO standard string with 'Z' suffix
  /// as required by the backend API spec (Section 7.1 & 8.3.2).
  static String formatAlarmISO(String date, String time) {
    try {
      final dt = parseDateTime(date, time);
      return "${dt.toUtc().toIso8601String().split('.').first}Z";
    } catch (_) {
      return "${parseBackendDate(date)}T00:00:00Z";
    }
  }

  /// Safely parses an ISO-8601 alarm timestamp (either UTC with 'Z'/offset or naive local)
  /// into a local wall-clock DateTime without shifting the user's timezone.
  static DateTime? parseAlarmIsoToLocal(String rawIso) {
    final trimmed = rawIso.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// Converts multi-format date string into backend yyyy-MM-dd format
  static String parseBackendDate(String rawDateText) {
    for (final format in _dateFormats) {
      try {
        return DateFormat("yyyy-MM-dd").format(format.parseStrict(rawDateText));
      } catch (_) {}
    }
    try {
      final dt = DateTime.parse(rawDateText);
      return DateFormat("yyyy-MM-dd").format(DateTime(dt.year, dt.month, dt.day));
    } catch (_) {
      return rawDateText;
    }
  }

  /// Parses DioException or dynamic error into user readable text conforming to RFC 7807 Problem Details
  static String formatErrorMessage(dynamic e) {
    if (e is DioException && e.response?.data is Map) {
      final map = e.response!.data as Map;
      if (map['detail'] != null && map['detail'].toString().trim().isNotEmpty) {
        return map['detail'].toString();
      }
      if (map['errors'] is Map) {
        final errorsMap = map['errors'] as Map;
        final lines = <String>[];
        errorsMap.forEach((k, v) {
          if (v is List && v.isNotEmpty) {
            lines.add('$k: ${v.first}');
          } else if (v != null) {
            lines.add('$k: $v');
          }
        });
        if (lines.isNotEmpty) return lines.join('\n');
      }
      return map.entries
          .where((entry) => !['type', 'title', 'status', 'error_id'].contains(entry.key.toString()))
          .map((entry) => "${entry.key}: ${entry.value.toString().replaceAll('[', '').replaceAll(']', '')}")
          .join("\n");
    } else if (e is DioException) {
      return e.response?.data?.toString() ?? e.message ?? "Unknown server error";
    }
    return e.toString();
  }
}
