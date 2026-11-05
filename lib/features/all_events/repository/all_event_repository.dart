import 'package:dio/dio.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class AllEventRepository {
  final Dio _dio = createDio();

  String formatEventDate(String rawDate) {
    final startDateTime = DateTime.tryParse(rawDate);
    if (startDateTime == null) return rawDate;
    return DateFormat('EEEE, MMM d, yyyy').format(startDateTime);
  }

  Future<List<EventModel>> fetchGoogleCalendarEvents() async {
    final accessToken = await GoogleServices().getValidAccessToken();
    if (accessToken == null || accessToken.isEmpty) return [];

    final gEventsData = await GoogleServices().getGoogleCalendarEvents(
      accessToken: accessToken,
      timeMin: DateTime.now().subtract(const Duration(days: 30)),
    );

    return gEventsData.map((json) {
      final rawStart = json['startTime'] ?? '';
      final rawEnd = json['endTime'] ?? '';
      final rawDate = json['date'] ?? '';

      return EventModel(
        id: json['id'].hashCode,
        userName: UserSession().username ?? 'Google Calendar',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        date: formatEventDate(rawDate.isNotEmpty ? rawDate : rawStart),
        startTime: rawStart,
        endTime: rawEnd,
        location: json['google_id'] ?? '',
        alarmTime: json['alarm_time'] ?? '',
        isCompleted: false,
        createdAt: rawDate.isNotEmpty ? rawDate : (rawStart.isNotEmpty ? rawStart : DateTime.now().toIso8601String()),
        user: int.tryParse(UserSession().userId ?? '0') ?? 0,
        category: 'Google Calendar',
        isFavorite: false,
        googleCalendarEventId: json['google_id'],
      );
    }).toList();
  }

  Future<List<EventModel>> fetchApiEvents() async {
    final authService = AuthService();
    final token = await authService.getToken();
    final baseUrl = dotenv.env['BASE_URL'] ?? '';

    final response = await _dio.get(
      '${baseUrl}api/v1/event/',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      final List data = response.data;
      final currentUserId = int.tryParse(UserSession().userId ?? '');

      return data.where((json) => json['user'] == currentUserId).map((json) {
        final rawDate = json['date']?.toString() ?? '';
        final formattedDate = formatEventDate(rawDate);
        return EventModel.fromMap({
          ...json,
          'date': formattedDate,
        });
      }).toList();
    }
    return [];
  }

  /// Deletes an event or single recurring occurrence per Section 7.3 & 8.3.7.
  /// If [deleteType] is 'single', target [dateStr] (format yyyy-MM-dd) is appended to exception_dates on the server.
  Future<bool> deleteEvent(
    EventModel event, {
    String deleteType = 'single',
    String? dateStr,
  }) async {
    if (event.category == 'Google Calendar') {
      final accessToken = await GoogleServices().getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ No access token available for Google Calendar delete');
        return false;
      }

      final googleEventId = event.googleCalendarEventId ??
          (event.location.isNotEmpty ? event.location : event.createdAt);
      if (googleEventId.isEmpty) return false;

      return await GoogleServices().deleteGoogleCalendarEvent(
        accessToken: accessToken,
        eventId: googleEventId,
      );
    }

    final token = await AuthService().getToken();
    final baseUrl = dotenv.env['BASE_URL'] ?? '';

    try {
      final effectiveId = event.masterEventId ?? event.id;

      String query = '?delete_type=$deleteType';
      if (deleteType == 'single') {
        final targetDate = dateStr ?? _extractIsoDate(event.date);
        if (targetDate.isNotEmpty) {
          query += '&date=$targetDate';
        }
      }

      final response = await _dio.delete(
        '${baseUrl}api/v1/event/delete/$effectiveId/$query',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('⚠️ Error deleting API event: $e');
      return false;
    }
  }

  String _extractIsoDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) return DateFormat('yyyy-MM-dd').format(parsed);
    try {
      final formatted = DateFormat('EEEE, MMM d, yyyy').parse(rawDate);
      return DateFormat('yyyy-MM-dd').format(formatted);
    } catch (_) {
      return rawDate;
    }
  }
}
