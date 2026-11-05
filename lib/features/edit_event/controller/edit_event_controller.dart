// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/features/calender/repository/event_detail_utils.dart';
import 'package:time_verse/features/edit_event/model/edit_event_model.dart';
import 'package:time_verse/features/edit_event/repository/edit_event_repo.dart';

class EditEventController extends ChangeNotifier {
  final EditEventRepository _repository = EditEventRepository();

  // Form Controllers
  final titleController = TextEditingController();
  final noteController = TextEditingController();
  final locationController = TextEditingController();
  final dateController = TextEditingController();
  final startTimeController = TextEditingController();
  final endTimeController = TextEditingController();

  // Selected State
  List<EditCategoryModel> categories = [];
  String? selectedCategory;
  String? selectedRepeat;
  String? selectedReminder;
  bool isLoading = true;

  // Options Lists
  final List<String> reminderOptions = [
    'None',
    '5 minutes before',
    '10 minutes before',
    '15 minutes before',
    '30 minutes before',
    '1 hour before',
    '1 day before',
    'Custom',
  ];

  final List<String> repeatOptions = [
    "Don't repeat",
    'Every 1 day',
    'Every 1 week',
    'Every 1 month',
    'Every 1 year',
  ];

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

  /// Maps UI repeat string to the backend expected enum/slug value
  String? _mapRepeatToApi(String? uiRepeat) {
    if (uiRepeat == null || uiRepeat == "Don't repeat") return null;
    switch (uiRepeat) {
      case 'Every 1 day':
        return 'daily';
      case 'Every 1 week':
        return 'weekly';
      case 'Every 1 month':
        return 'monthly';
      case 'Every 1 year':
        return 'yearly';
      default:
        return uiRepeat;
    }
  }

  Future<void> initEditPage(String eventId) async {
    isLoading = true;
    notifyListeners();

    try {
      categories = await _repository.getCategories();
      final eventDetails = await _repository.getEventDetails(eventId);

      if (eventDetails != null) {
        titleController.text = eventDetails.title ?? '';
        noteController.text = eventDetails.note ?? '';
        locationController.text = eventDetails.location ?? '';
        dateController.text = eventDetails.date != null
            ? DateFormat('MMMM d, yyyy').format(eventDetails.date!)
            : '';
        startTimeController.text = eventDetails.startTime ?? '';
        endTimeController.text = eventDetails.endTime ?? '';

        selectedCategory ??= eventDetails.category?.toString();

        selectedRepeat ??= repeatOptions.contains(eventDetails.repeat)
            ? eventDetails.repeat
            : repeatOptions.first;

        selectedReminder ??= reminderOptions.contains(eventDetails.reminder)
            ? eventDetails.reminder
            : reminderOptions.first;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(dynamic category) {
    selectedCategory = category?.toString();
    notifyListeners();
  }

  void selectRepeat(String repeat) {
    selectedRepeat = repeat;
    notifyListeners();
  }

  void setSelectedRepeat(String repeat) {
    selectRepeat(repeat);
  }

  void selectReminder(String reminder) {
    selectedReminder = reminder;
    notifyListeners();
  }

  String _cleanTimeStr(String raw) => EventDateTimeUtils.cleanTimeStr(raw);

  String _calculateAlarmOffset(String startTimeClean, String alarmClean) {
    if (alarmClean.isEmpty ||
        startTimeClean.isEmpty ||
        alarmClean.toLowerCase() == 'none') {
      return startTimeClean;
    }
    return EventDateTimeUtils.calculateAlarmOffset(startTimeClean, alarmClean);
  }

  String _formatAlarmISO(String date, String time) {
    return EventDateTimeUtils.formatAlarmISO(date, time);
  }

  Future<bool> updateEvent({
    required BuildContext context,
    required String eventId,
    String? rawStart,
    String? rawEnd,
    String? rawAlarm,
    VoidCallback? onSuccess,
  }) async {
    int? categoryId;
    try {
      final catObj = categories.firstWhere(
        (c) => c.name.toLowerCase() == selectedCategory?.toLowerCase(),
      );
      categoryId = int.tryParse(catObj.id.toString());
    } catch (_) {
      categoryId = int.tryParse(selectedCategory ?? '');
    }

    // 1. Get correct start, end, and alarm strings
    final effectiveStart = (rawStart != null && rawStart.isNotEmpty)
        ? rawStart
        : startTimeController.text.trim();
    final effectiveEnd = (rawEnd != null && rawEnd.isNotEmpty)
        ? rawEnd
        : endTimeController.text.trim();

    final activeReminder = (rawAlarm != null && rawAlarm.isNotEmpty)
        ? rawAlarm
        : (selectedReminder ?? '');

    // 2. Clean times and calculate ISO string matching AddEvent logic
    final start = _cleanTimeStr(effectiveStart);
    final end = _cleanTimeStr(effectiveEnd);
    final calculatedAlarmTime = _calculateAlarmOffset(
      start,
      activeReminder.trim(),
    );
    final formattedAlarmISO = _formatAlarmISO(
      dateController.text,
      calculatedAlarmTime,
    );

    DateTime? parsedDate;
    if (dateController.text.isNotEmpty) {
      for (final format in _dateFormats) {
        try {
          parsedDate = format.parse(dateController.text);
          break;
        } catch (_) {}
      }
      parsedDate ??= DateTime.tryParse(dateController.text);
    }

    final updatedData = EditEventModel(
      id: eventId,
      title: titleController.text.trim(),
      note: noteController.text.trim(),
      location: locationController.text.trim(),
      date: parsedDate,
      startTime: start,
      endTime: end,
      category: categoryId,
      repeat: _mapRepeatToApi(selectedRepeat),
      reminder: formattedAlarmISO,
    );

    final resultMap = await _repository.updateEvent(eventId, updatedData);

    if (resultMap != null) {
      final parsedEventId = int.tryParse(eventId) ?? 0;

      // 1. Cancel previous alarms and notifications for this event before rescheduling
      try {
        await AlarmHelper.stopAlarmForEvent(parsedEventId);
        await NotificationService.cancelNotificationsForEvent(parsedEventId);
      } catch (e) {
        debugPrint("⚠️ Error canceling previous alarms for event $eventId: $e");
      }

      // 2. Schedule updated alarm or fallback notification
      final prefs = await SharedPreferences.getInstance();
      final allowAlarms = prefs.getBool('notif_allow_alarms') ?? true;
      final allowNotifs = prefs.getBool('notif_allow_notifications') ?? true;

      try {
        final alarmTimeStr =
            resultMap['alarm_time']?.toString() ?? formattedAlarmISO;
        if (allowAlarms) {
          await AlarmHelper.scheduleEventAlarm(
            context,
            updatedData.toEventModel(overrideAlarmTime: alarmTimeStr),
          );
        } else if (allowNotifs) {
          final alarmDateTime =
              EventDateTimeUtils.parseAlarmIsoToLocal(alarmTimeStr);
          if (alarmDateTime != null) {
            final notifId = AlarmHelper.computeNotificationId(parsedEventId, 0);
            await NotificationService.scheduleNotification(
              id: notifId,
              title: updatedData.title ?? '',
              body: updatedData.note ?? '',
              alarmTime: alarmDateTime,
              payload: updatedData.id ?? '',
            );
          }
        }
      } catch (e) {
        debugPrint("⚠️ Alarm/Notification scheduling error: $e");
      }

      if (onSuccess != null) {
        onSuccess();
      }
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    locationController.dispose();
    dateController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    super.dispose();
  }
}
