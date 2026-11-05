import 'package:dio/dio.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';
import 'package:time_verse/features/calender/model/event_category_model.dart';

class AddEventRepository {
  final Dio _dio = createDio();
  final AuthService _authService = AuthService();

  Future<Options> _authorizedHeader({String? idempotencyKey}) async {
    final token = await _authService.getToken();

    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'Idempotency-Key': idempotencyKey,
      },
    );
  }

  /// Fetches event categories from backend
  Future<List<EventCategory>> fetchCategories() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? '';
    final response = await _dio.get(
      '${baseUrl}api/v1/categories/',
      options: await _authorizedHeader(),
    );

    if (response.statusCode == 200 && response.data is List) {
      debugPrint('!--------- Category ${response.data.toString()}---------!');
      return (response.data as List).map((json) => EventCategory.fromJson(json)).toList();
    }
    return [];
  }

  /// Creates a task on the server with idempotency protection (Section 7.2)
  Future<Map<String, dynamic>?> createTask({
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    String? location,
    required String alarmTime,
    String? categoryName,
    bool isCompleted = false,
    String? note,
    String? repeat,
    Map<String, dynamic>? customRepeat,
    String? idempotencyKey,
  }) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? '';
    final url = "${baseUrl}api/v1/event/create/";
    final bool isCustom = repeat?.toLowerCase() == 'custom';

    final effectiveIdempotencyKey = idempotencyKey ??
        'tv_app_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';

    final Map<String, dynamic> body = {
      "title": title,
      "date": date,
      "start_time": startTime,
      "end_time": endTime,
      "alarm_time": alarmTime,
      "is_alarm_sent": true,
      if (repeat != null && repeat.isNotEmpty)
        "repeat": isCustom ? "custom" : repeat,
      if (isCustom && customRepeat != null) "custom_repeat": customRepeat,
      "is_completed": isCompleted,
      if (location?.trim().isNotEmpty ?? false) "location": location!.trim(),
      if (categoryName?.trim().isNotEmpty ?? false)
        "category_name": categoryName!.trim(),
      if (note?.trim().isNotEmpty ?? false)
        "type_event_description": note!.trim(),
    };

    final response = await _dio.post(
      url,
      data: body,
      options: await _authorizedHeader(idempotencyKey: effectiveIdempotencyKey),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data;
    }

    return null;
  }

  List<DateTime> generateAlarmOccurrences({
    required DateTime startDateTime,
    required String? selectedRepeat,
    required int customRepeatCount,
    required String customRepeatUnit,
    required List<String> selectedDays,
    required String repeatEndType,
    required DateTime customEndDate,
    required int customOccurrences,
    int maxLimit = 30,
  }) {
    List<DateTime> occurrences = [];

    int intervalCount = 1;
    String intervalUnit = 'none';
    final normalizedRepeat = selectedRepeat?.trim().toLowerCase() ?? '';

    if (normalizedRepeat == 'custom') {
      intervalCount = customRepeatCount > 0 ? customRepeatCount : 1;
      final rawUnit = customRepeatUnit.trim().toLowerCase();
      if (rawUnit.startsWith('day')) {
        intervalUnit = 'day';
      } else if (rawUnit.startsWith('week')) {
        intervalUnit = 'week';
      } else if (rawUnit.startsWith('month')) {
        intervalUnit = 'month';
      } else if (rawUnit.startsWith('year')) {
        intervalUnit = 'year';
      }
    } else if (normalizedRepeat.isNotEmpty &&
        normalizedRepeat != "don't repeat" &&
        normalizedRepeat != 'none') {
      if (normalizedRepeat == 'every 1 day' || normalizedRepeat == 'daily' || normalizedRepeat == 'day') {
        intervalUnit = 'day';
      } else if (normalizedRepeat == 'every 1 week' || normalizedRepeat == 'weekly' || normalizedRepeat == 'week') {
        intervalUnit = 'week';
      } else if (normalizedRepeat == 'every 1 month' || normalizedRepeat == 'monthly' || normalizedRepeat == 'month') {
        intervalUnit = 'month';
      } else if (normalizedRepeat == 'every 1 year' || normalizedRepeat == 'yearly' || normalizedRepeat == 'year') {
        intervalUnit = 'year';
      }
    }

    if (intervalUnit == 'none') {
      occurrences.add(startDateTime);
      return occurrences;
    }

    DateTime current = startDateTime;
    int count = 0;
    int safetyIterations = 0;

    const rfcDayToIndex = <String, int>{
      'SU': 0,
      'MO': 1,
      'TU': 2,
      'WE': 3,
      'TH': 4,
      'FR': 5,
      'SA': 6,
    };

    final selectedDayIndices = selectedDays
        .map((d) {
          final upper = d.trim().toUpperCase();
          if (rfcDayToIndex.containsKey(upper)) {
            return rfcDayToIndex[upper]!;
          }
          final parts = d.split('-');
          return parts.length > 1 ? int.tryParse(parts[1]) ?? -1 : -1;
        })
        .where((idx) => idx >= 0 && idx <= 6)
        .toSet()
        .toList();

    final normalizedEndType = repeatEndType.trim().toLowerCase();

    while (count < maxLimit && safetyIterations < 1500) {
      safetyIterations++;
      if ((normalizedEndType == 'on' || normalizedEndType == 'on_date') &&
          current.isAfter(customEndDate)) {
        break;
      }
      if ((normalizedEndType == 'after' || normalizedEndType == 'after_occurrences') &&
          count >= customOccurrences) {
        break;
      }

      if (intervalUnit == 'week' && selectedDayIndices.isNotEmpty) {
        final currentDayIndex = current.weekday == 7 ? 0 : current.weekday;
        if (selectedDayIndices.contains(currentDayIndex)) {
          occurrences.add(current);
          count++;
        }
        if (current.weekday == DateTime.sunday && intervalCount > 1) {
          current = current.add(Duration(days: 1 + 7 * (intervalCount - 1)));
        } else {
          current = current.add(const Duration(days: 1));
        }
      } else {
        occurrences.add(current);
        count++;

        if (intervalUnit == 'day') {
          current = current.add(Duration(days: intervalCount));
        } else if (intervalUnit == 'week') {
          current = current.add(Duration(days: 7 * intervalCount));
        } else if (intervalUnit == 'month') {
          int newYear = current.year;
          int newMonth = current.month + intervalCount;

          while (newMonth > 12) {
            newYear++;
            newMonth -= 12;
          }

          int lastDayOfTargetMonth = DateTime(newYear, newMonth + 1, 0).day;
          int newDay = current.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : current.day;

          current = DateTime(
            newYear,
            newMonth,
            newDay,
            current.hour,
            current.minute,
          );
        } else if (intervalUnit == 'year') {
          current = DateTime(
            current.year + intervalCount,
            current.month,
            current.day,
            current.hour,
            current.minute,
          );
        }
      }
    }

    return occurrences;
  }

  Future<Map<String, dynamic>?> createTaskRaw(Map<String, dynamic> body) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? '';
    final url = "${baseUrl}api/v1/event/create/";
    final idempotencyKey = body['idempotency_key']?.toString();

    final response = await _dio.post(
      url,
      data: body,
      options: await _authorizedHeader(idempotencyKey: idempotencyKey),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data;
    }
    return null;
  }
}
