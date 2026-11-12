import 'package:time_verse/features/all_events/model/event_model.dart';

class EditEventModel {
  final String? id;
  final String? title;
  final String? note;
  final String? location;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final dynamic category; // Can hold int ID or String name
  final String? reminder;
  final String? repeat;

  EditEventModel({
    this.id,
    this.title,
    this.note,
    this.location,
    this.date,
    this.startTime,
    this.endTime,
    this.category,
    this.reminder,
    this.repeat,
  });

  Map<String, dynamic> toJson() {
    // 1. Format date -> YYYY-MM-DD
    final dateString = date != null
        ? "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}"
        : null;

    // 2. Ensure times have seconds (HH:mm:ss)
    String? formatTime(String? time) {
      if (time == null || time.isEmpty) return null;
      final parts = time.split(':');
      if (parts.length == 2) return "$time:00";
      return time;
    }

    // 3. Preserve calculated reminder ISO timestamp if provided, otherwise fall back to startTime
    String? formattedAlarm = (reminder != null && reminder!.isNotEmpty) ? reminder : null;
    if (formattedAlarm == null && dateString != null && startTime != null && startTime!.isNotEmpty) {
      try {
        final parsedStart = formatTime(startTime)!;
        final dt = DateTime.parse("${dateString}T$parsedStart");
        formattedAlarm = dt.toUtc().toIso8601String();
      } catch (_) {
        formattedAlarm = reminder;
      }
    }

    final mappedRepeat = selectedRepeatToApi(repeat);

    return {
      "category": category is int ? category : int.tryParse(category?.toString() ?? '') ?? category,
      "title": title,
      "type_event_description": note ?? "",
      "date": dateString,
      "start_time": formatTime(startTime),
      "end_time": formatTime(endTime),
      "location": (location == null || location!.isEmpty) ? "unknown" : location,
      "alarm_time": formattedAlarm,
      if (mappedRepeat != null) "repeat": mappedRepeat,
      "is_completed": false,
      "is_alarm_sent": true,
      "is_favorite": false,
    };
  }

  static String? selectedRepeatToApi(String? value) {
    if (value == null || value.isEmpty) return null;
    final val = value.toLowerCase().trim();
    if (val == "don't repeat" || val == 'none') return null;
    if (val.contains("day") || val == 'daily') return "1 day";
    if (val.contains("week") || val == 'weekly') return "1 week";
    if (val.contains("month") || val == 'monthly') return "1 month";
    if (val.contains("year") || val == 'yearly') return "1 year";
    return value;
  }
}

// Extension to map EditEventModel -> EventModel cleanly
extension EditEventModelMapper on EditEventModel {
  EventModel toEventModel({String? overrideAlarmTime}) {
    final dateString = date != null
        ? "${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}"
        : '';

    return EventModel(
      id: int.tryParse(id ?? '') ?? 0,
      userName: '',
      title: title ?? '',
      description: note ?? '',
      date: dateString,
      startTime: startTime ?? '',
      endTime: endTime ?? '',
      location: (location == null || location!.isEmpty) ? "unknown" : location!,
      alarmTime: overrideAlarmTime ?? reminder ?? '',
      isCompleted: false,
      isFavorite: false,
      createdAt: '',
      user: 0,
      category: category?.toString(),
      category_name: category?.toString(),
      repeat: repeat,
    );
  }
}

  /// Helper to convert UI display string to API repeat value
class EditCategoryModel {
  final String id;
  final String name;

  EditCategoryModel({required this.id, required this.name});

  factory EditCategoryModel.fromJson(Map<String, dynamic> json) {
    return EditCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}