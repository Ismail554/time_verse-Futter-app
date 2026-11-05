import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    final prefs = await SharedPreferences.getInstance();
    final allowAlarms = prefs.getBool('notif_allow_alarms') ?? true;
    final allowNotifs = prefs.getBool('notif_allow_notifications') ?? true;

    // 1. Schedule full-screen ringing alarms when alarms are enabled
    if (allowAlarms) {
      await AlarmHelper.scheduleEventAlarm(null, event, occurrences);
    }

    // 2. When full-screen alarms are disabled (but notifications are enabled),
    // schedule standard reminder notifications using distinct notification IDs
    // so AlarmService and FlutterLocalNotifications never clash on the same second.
    if (!allowAlarms && allowNotifs) {
      try {
        for (int i = 0; i < occurrences.length; i++) {
          final alarmDt = occurrences[i];
          final notifId = AlarmHelper.computeNotificationId(event.id, i);
          await NotificationService.scheduleNotification(
            id: notifId,
            title: event.title,
            body: event.description,
            alarmTime: alarmDt,
            payload: event.id.toString(),
          );
        }
      } catch (e) {
        debugPrint("⚠️ Notification Error: $e");
      }
    }
  }

  Future<void> cancelReminders(int eventId) async {
    await AlarmHelper.stopAlarmForEvent(eventId);
    await NotificationService.cancelNotificationsForEvent(eventId);
  }
}
