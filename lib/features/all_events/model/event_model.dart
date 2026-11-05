// ignore_for_file: non_constant_identifier_names

import 'package:intl/intl.dart';

class EventModel {
  final int id;
  final String userName;
  final String title;
  final String description;
  final String date;
  final String startTime;
  final String endTime;
  final String location;
  final String alarmTime;
  final bool isCompleted;
  final bool isFavorite;
  final String createdAt;
  final int user;
  final String? category;
  final String? subtitle;
  final String? category_name;
  final String? repeat;
  final String? googleCalendarEventId;
  final bool isRecurringInstance;
  final int? masterEventId;
  final Map<String, dynamic>? customRepeat;
  final List<dynamic>? exceptionDates;

  EventModel({
    required this.id,
    required this.userName,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.alarmTime,
    required this.isCompleted,
    required this.isFavorite,
    required this.createdAt,
    required this.user,
    this.category,
    this.subtitle,
    this.category_name,
    this.repeat,
    this.googleCalendarEventId,
    this.isRecurringInstance = false,
    this.masterEventId,
    this.customRepeat,
    this.exceptionDates,
  });

  /// Computes the exact scheduled DateTime for chronological sorting and filtering
  DateTime? get scheduledDateTime {
    if (alarmTime.isNotEmpty) {
      final clean = alarmTime.trim().replaceAll(RegExp(r'Z$'), '');
      final dt = DateTime.tryParse(clean);
      if (dt != null) return dt;
    }

    if (date.isNotEmpty) {
      final direct = DateTime.tryParse(date);
      if (direct != null) {
        if (startTime.isNotEmpty) {
          final parts = startTime.split(':');
          if (parts.length >= 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            return DateTime(direct.year, direct.month, direct.day, h, m);
          }
        }
        return direct;
      }

      try {
        final parsed = DateFormat('EEEE, MMM d, yyyy').parse(date);
        if (startTime.isNotEmpty) {
          final parts = startTime.split(':');
          if (parts.length >= 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            return DateTime(parsed.year, parsed.month, parsed.day, h, m);
          }
        }
        return parsed;
      } catch (_) {}
    }

    if (createdAt.isNotEmpty) {
      return DateTime.tryParse(createdAt);
    }
    return null;
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] ?? 0,
      userName: map['user_name'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? map['type_event_description'] ?? '',
      date: map['date']?.toString() ?? '',
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      alarmTime: map['alarm_time']?.toString() ?? '',
      isCompleted: map['is_completed'] ?? false,
      isFavorite: map['is_favorite'] ?? false,
      createdAt: map['created_at']?.toString() ?? '',
      user: map['user'] ?? 0,
      category: map['category']?.toString(),
      subtitle: map['subtitle']?.toString(),
      category_name: map['category_name']?.toString(),
      repeat: map['repeat']?.toString(),
      googleCalendarEventId: map['google_calendar_event_id']?.toString(),
      isRecurringInstance: map['is_recurring_instance'] ?? false,
      masterEventId: map['master_event_id'] is int
          ? map['master_event_id']
          : int.tryParse(map['master_event_id']?.toString() ?? ''),
      customRepeat: map['custom_repeat'] is Map<String, dynamic>
          ? map['custom_repeat']
          : (map['custom_repeat'] is Map ? Map<String, dynamic>.from(map['custom_repeat']) : null),
      exceptionDates: map['exception_dates'] is List ? map['exception_dates'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_name': userName,
      'title': title,
      'description': description,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'alarm_time': alarmTime,
      'is_completed': isCompleted,
      'is_favorite': isFavorite,
      'created_at': createdAt,
      'user': user,
      'category': category,
      'subtitle': subtitle,
      'category_name': category_name,
      'repeat': repeat,
      'google_calendar_event_id': googleCalendarEventId,
      'is_recurring_instance': isRecurringInstance,
      'master_event_id': masterEventId,
      'custom_repeat': customRepeat,
      'exception_dates': exceptionDates,
    };
  }
}
