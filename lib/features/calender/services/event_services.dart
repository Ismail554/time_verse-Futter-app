// lib/services/event_service.dart
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/calender/repository/add_event_repository.dart';
import 'package:time_verse/features/calender/repository/event_detail_utils.dart';

class EventService {
  final AddEventRepository _repository = AddEventRepository();

  Future<EventModel?> createAndSyncEvent({
    required String title,
    required String dateText,
    required String startTime,
    required String endTime,
    required String alarmISO,
    String? location,
    String? categoryName,
    String? note,
    String? apiRepeatValue,
    Map<String, dynamic>? customRepeatMap,
  }) async {
    final backendDate = EventDateTimeUtils.parseBackendDate(dateText.trim());

    final result = await _repository.createTask(
      title: title.trim(),
      date: backendDate,
      startTime: startTime,
      endTime: endTime,
      location: location?.trim().isEmpty == true ? null : location?.trim(),
      alarmTime: alarmISO,
      categoryName: categoryName?.isEmpty == true ? null : categoryName,
      note: note?.trim(),
      repeat: apiRepeatValue,
      customRepeat: customRepeatMap,
    );

    if (result != null) {
      final resultMap = Map<String, dynamic>.from(result);
      if (resultMap['alarm_time'] == null || resultMap['alarm_time'].toString().isEmpty) {
        resultMap['alarm_time'] = alarmISO;
      }
      resultMap['is_alarm_sent'] = true;

      final eventModel = EventModel.fromMap(resultMap);

      // Note: Client-side Google Calendar creation is deprecated per Section 5.2.5 (BUG-06, BUG-07, FIX-ARCH-07).
      // External Google Calendar sync is performed authoritatively and asynchronously by backend Celery workers
      // using the pre-generated deterministic google_calendar_event_id.

      return eventModel;
    }
    return null;
  }
}
