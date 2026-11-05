// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:time_verse/config/app_route/nav_config.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/all_events/repository/all_event_repository.dart';
import 'package:time_verse/features/calender/repository/event_detail_utils.dart';

class AllEventsController extends ChangeNotifier {
  final AllEventRepository _repository;

  int selectedIndex = 0;
  final List<EventModel> _events = [];
  List<EventModel> get events => List.unmodifiable(_events);

  AllEventsController({AllEventRepository? repository}) : _repository = repository ?? AllEventRepository() {
    fetchAllEvents();
  }

  void updateIndexFromRoute(String location) {
    final index = appRoutes.indexWhere((r) => location.startsWith(r));
    if (index != -1 && index != selectedIndex) {
      selectedIndex = index;
      notifyListeners();
    }
  }

  void navigateTo(int index, BuildContext context) {
    selectedIndex = index;
    notifyListeners();
    context.push(appRoutes[index]);
  }

  String formatEventDate(String rawDate) {
    return _repository.formatEventDate(rawDate);
  }

  Future<void> fetchAllEvents([BuildContext? context]) async {
    try {
      final apiEvents = await _repository.fetchApiEvents();
      final googleEvents = await _repository.fetchGoogleCalendarEvents();

      // Helper to normalize time string (e.g., "10:00:00" -> "10:00")
      String normalizeTime(String time) {
        if (time.isEmpty) return '';
        final parts = time.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
        return time;
      }

      // Filter out Google events that already exist in apiEvents
      final uniqueGoogleEvents = googleEvents.where((gEvent) {
        final isDuplicate = apiEvents.any((apiEvent) {
          final sameTitle = apiEvent.title.trim().toLowerCase() == gEvent.title.trim().toLowerCase();
          final sameDate = apiEvent.date == gEvent.date;
          final sameStartTime = normalizeTime(apiEvent.startTime) == normalizeTime(gEvent.startTime);
          return sameTitle && sameDate && sameStartTime;
        });
        return !isDuplicate;
      }).toList();

      _events
        ..clear()
        ..addAll(apiEvents)
        ..addAll(uniqueGoogleEvents);

      debugPrint('All event data loaded: ${_events.length} events');
      notifyListeners();

      final nowWithBuffer = DateTime.now().subtract(const Duration(minutes: 1));

      for (final event in _events) {
        if (event.alarmTime.isNotEmpty) {
          final parsedAlarm = EventDateTimeUtils.parseAlarmIsoToLocal(event.alarmTime);

          if (parsedAlarm != null && parsedAlarm.isAfter(nowWithBuffer)) {
            try {
              // AlarmHelper handles SharedPreferences checks and doesn't require context
              await AlarmHelper.scheduleEventAlarm(context, event);
              debugPrint("⏰ Verified/scheduled alarm for: ${event.title} at $parsedAlarm");
            } catch (alarmError) {
              debugPrint("❌ Failed to set alarm for ${event.title}: $alarmError");
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching events: $e');
    }
  }

  Future<bool> deleteEvent(EventModel event, {String deleteType = 'single'}) async {
    try {
      final success = await _repository.deleteEvent(event, deleteType: deleteType);
      if (success) {
        _events.removeWhere((e) => e.id == event.id);
        notifyListeners();
        // Fully cancel alarms and notifications for this event and all occurrences
        await AlarmHelper.stopAlarmForEvent(event.id);
        await NotificationService.cancelNotificationsForEvent(event.id);
      }
      return success;
    } catch (e) {
      debugPrint('⚠️ Error deleting event: $e');
      return false;
    }
  }

  Future<bool> removeEventFromList(EventModel event, {String deleteType = 'single'}) async {
    return await deleteEvent(event, deleteType: deleteType);
  }

  Future<T?> runWithLoaderAndTimer<T>({
    required BuildContext context,
    required Future<T> Function() task,
  }) async {
    final startTime = DateTime.now();
    Timer? periodicTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            periodicTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (dialogContext.mounted) {
                setState(() {});
              }
            });
            final elapsed = DateTime.now().difference(startTime);

            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    AppSpacing.h12,
                    Text(
                      "Deleting...\n${elapsed.inSeconds}s",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      final result = await task();
      return result;
    } finally {
      periodicTimer?.cancel();
      if (context.mounted) Navigator.pop(context);
    }
  }
}
