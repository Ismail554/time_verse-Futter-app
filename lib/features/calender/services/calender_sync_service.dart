import 'package:dio/dio.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class CalendarSyncService {
  final Dio _dio = createDio();

  String normalizeTime(String rawTime) {
    if (rawTime.isEmpty) return '00:00';
    final parts = rawTime.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return rawTime;
  }

  bool isEventOccurringOnDate(EventModel event, DateTime targetDate, Map<String, dynamic>? rawJson) {
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    // Check if target date is in exception_dates
    final exceptions = event.exceptionDates ?? (rawJson?['exception_dates'] as List?);
    if (exceptions != null && exceptions.contains(targetDateStr)) {
      return false;
    }

    final rawDateStr = event.date.isNotEmpty ? event.date : event.createdAt;
    final startDate = DateTime.tryParse(rawDateStr);
    if (startDate == null) return false;

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (target.isBefore(start)) return false;

    // Direct day match
    if (start.year == target.year && start.month == target.month && start.day == target.day) {
      return true;
    }

    // Read custom repeat configuration if available
    final customRepeat = event.customRepeat ?? (rawJson?['custom_repeat'] as Map<String, dynamic>?);
    if (customRepeat != null) {
      final ends = customRepeat['ends']?.toString().toLowerCase();
      if (ends == 'on' && customRepeat['end_date'] != null) {
        final endDate = DateTime.tryParse(customRepeat['end_date'].toString());
        if (endDate != null && target.isAfter(endDate)) return false;
      }

      final unit = customRepeat['repeat_unit']?.toString().toLowerCase() ?? '';
      final interval = int.tryParse(customRepeat['repeat_every']?.toString() ?? '1') ?? 1;

      if (unit.contains('day')) {
        return target.difference(start).inDays % interval == 0;
      }

      if (unit.contains('week')) {
        final repeatDays = (customRepeat['repeat_days'] as List?)
                ?.map((d) => d.toString().toUpperCase())
                .toList() ??
            [];
        if (repeatDays.isNotEmpty) {
          const weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
          final currentCode = weekdayCodes[target.weekday - 1];
          if (!repeatDays.contains(currentCode)) return false;
        }
        return (target.difference(start).inDays ~/ 7) % interval == 0;
      }

      if (unit.contains('month')) {
        return target.day == start.day;
      }
      if (unit.contains('year')) {
        return target.month == start.month && target.day == start.day;
      }
    }

    String repeatRule = event.repeat?.toLowerCase().trim() ?? '';
    if (repeatRule.isEmpty || repeatRule == "don't repeat") return false;

    switch (repeatRule) {
      case '1 day':
      case 'every 1 day':
      case 'daily':
        return true;
      case '1 week':
      case 'every 1 week':
      case 'weekly':
        return target.difference(start).inDays % 7 == 0;
      case '1 month':
      case 'every 1 month':
      case 'monthly':
        return target.day == start.day;
      case '1 year':
      case 'every 1 year':
      case 'yearly':
        return target.month == start.month && target.day == start.day;
      default:
        return false;
    }
  }

  Future<List<EventModel>> fetchBackendEvents(DateTime targetDate) async {
    try {
      final token = await AuthService().getToken();
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      // Backend Section 7.3 occurrence expansion on date filter
      final response = await _dio.get(
        '${baseUrl}api/v1/event/',
        queryParameters: {'date': targetDateStr},
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200 && response.data is List) {
        final List data = response.data;
        final currentUserId = int.tryParse(UserSession().userId ?? '');
        final List<EventModel> list = [];

        for (var json in data) {
          if (json is! Map<String, dynamic>) continue;
          if (currentUserId != null && json['user'] != currentUserId) continue;

          final model = EventModel.fromMap(json);
          // Check if instance falls on target date
          if (model.isRecurringInstance || model.date == targetDateStr || isEventOccurringOnDate(model, targetDate, json)) {
            list.add(EventModel.fromMap({
              ...model.toMap(),
              'date': targetDateStr,
            }));
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching backend events: $e');
    }
    return [];
  }

  Future<List<EventModel>> fetchGoogleEvents(DateTime targetDate) async {
    final accessToken = await GoogleServices().getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) return [];

    final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
    final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

    final gEventsData = await GoogleServices().getGoogleCalendarEvents(
      accessToken: accessToken,
      timeMin: dayStart,
      timeMax: dayEnd,
    );

    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final List<EventModel> events = [];

    for (var json in gEventsData) {
      final rawStart = json['startTime'] ?? '';
      final rawEnd = json['endTime'] ?? '';
      final eventDate = json['date']?.isNotEmpty == true ? json['date'] : targetDateStr;

      if (eventDate != targetDateStr) continue;

      events.add(
        EventModel(
          id: json['id'],
          userName: UserSession().username ?? 'Google Calendar',
          title: json['title'] ?? '',
          description: json['description'] ?? '',
          date: targetDateStr,
          startTime: normalizeTime(rawStart),
          endTime: normalizeTime(rawEnd),
          location: json['google_id'] ?? json['location'] ?? '',
          alarmTime: json['alarm_time'] ?? '',
          isCompleted: false,
          createdAt: DateTime.now().toIso8601String(),
          user: int.tryParse(UserSession().userId ?? '0') ?? 0,
          category: 'Google Calendar',
          isFavorite: false,
          googleCalendarEventId: json['google_id'],
        ),
      );
    }

    return events;
  }

  Future<List<EventModel>> fetchCombinedEvents(DateTime targetDate) async {
    final results = await Future.wait([
      fetchBackendEvents(targetDate),
      fetchGoogleEvents(targetDate),
    ]);

    final List<EventModel> backendList = results[0];
    final List<EventModel> googleList = results[1];
    final Map<String, EventModel> uniqueEvents = {};

    for (var event in backendList) {
      final key = '${event.title.trim().toLowerCase()}_${event.date}_${normalizeTime(event.startTime)}';
      uniqueEvents[key] = event;
    }

    for (var event in googleList) {
      final isDup = backendList.any((bEvent) {
        final sameGoogleId = bEvent.googleCalendarEventId != null &&
            bEvent.googleCalendarEventId!.isNotEmpty &&
            bEvent.googleCalendarEventId == event.googleCalendarEventId;
        final sameTitle = bEvent.title.trim().toLowerCase() == event.title.trim().toLowerCase();
        final sameStart = normalizeTime(bEvent.startTime) == normalizeTime(event.startTime);
        return sameGoogleId || (sameTitle && sameStart);
      });

      if (!isDup) {
        final key = '${event.title.trim().toLowerCase()}_${event.date}_${normalizeTime(event.startTime)}';
        uniqueEvents.putIfAbsent(key, () => event);
      }
    }

    return uniqueEvents.values.toList();
  }
}
