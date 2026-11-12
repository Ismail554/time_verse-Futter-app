import 'package:flutter/material.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/calender/repository/add_event_repository.dart';

class EventAlarmService {
  final AddEventRepository _repository = AddEventRepository();

  Future<void> scheduleReminders({
    BuildContext? context,
    required EventModel event,
    required DateTime baseDateTime,
    required String? selectedRepeat,
    required int customRepeatCount,
    required String customRepeatUnit,
    required List<String> selectedDays,
    required String repeatEndType,
    required DateTime customEndDate,
    required int customOccurrences,
  }) async {
    final occurrences = _repository.generateAlarmOccurrences(
      startDateTime: baseDateTime,
      selectedRepeat: selectedRepeat,
      customRepeatCount: customRepeatCount,
      customRepeatUnit: customRepeatUnit,
      selectedDays: selectedDays,
      repeatEndType: repeatEndType,
      customEndDate: customEndDate,
      customOccurrences: customOccurrences,
    );

    await AlarmHelper.scheduleEventAlarm(context, event, occurrences);
  }

  Future<void> cancelReminders(int eventId) async {
    await AlarmHelper.stopAlarmForEvent(eventId);
    await NotificationService.cancelNotificationsForEvent(eventId);
  }
}
