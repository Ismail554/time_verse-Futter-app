// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/calender/repository/add_event_repository.dart';
import 'package:time_verse/features/calender/repository/event_detail_utils.dart';

class AlarmHelper {
  static final Set<int> _scheduledIds = {};
  static final Map<int, EventModel> _cachedEvents = {};
  static final Map<int, List<DateTime>> _cachedOccurrences = {};
  static const MethodChannel _ringtoneChannel = MethodChannel('com.infiniquote.app/ringtone');
  static bool isRingScreenPresented = false;

  /// Safe 32-bit positive integer hash for Alarm IDs (range: 1 .. 200,000,100)
  /// to prevent Android PendingIntent 32-bit overflow.
  static int computeAlarmId(int eventId, [int occurrenceIndex = 0]) {
    final base = (eventId.abs() % 2000000) * 100;
    return (base + (occurrenceIndex.abs() % 100)) + 1;
  }

  /// Distinct 32-bit positive integer hash for Local Notification IDs
  /// (offset by 500,000,000 so it never collides with AlarmService foreground notification IDs).
  static int computeNotificationId(int eventId, [int occurrenceIndex = 0]) {
    return computeAlarmId(eventId, occurrenceIndex) + 500000000;
  }

  /// Resolves the audio path for AlarmSettings.
  /// Uses a locally cached custom system ringtone file if available and valid,
  /// otherwise falls back to the bundled Flutter asset.
  static String resolveAlarmAudioPath(SharedPreferences prefs) {
    final localPath = prefs.getString('alarm_selected_ringtone_local_path') ?? '';
    final selectedUri = prefs.getString('alarm_selected_ringtone') ?? '';
    if (selectedUri.startsWith('content://') && localPath.isNotEmpty) {
      try {
        final file = File(localPath);
        if (file.existsSync() && file.lengthSync() > 0) {
          return localPath;
        }
      } catch (_) {}
    }
    return AudioAssets.alarm;
  }

  /// Returns true if the user selected a content:// ringtone that could not be copied to a local file
  /// and therefore requires the native Android MediaPlayer fallback during ringing.
  static Future<bool> requiresNativeUriPlayerFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedUri = prefs.getString('alarm_selected_ringtone') ?? '';
      if (!selectedUri.startsWith('content://')) return false;
      final localPath = prefs.getString('alarm_selected_ringtone_local_path') ?? '';
      if (localPath.isNotEmpty) {
        final file = File(localPath);
        if (file.existsSync() && file.lengthSync() > 0) {
          return false; // Alarm package is already playing the local copy!
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Schedules event alarms or fallback notifications without requiring a BuildContext,
  /// reading saved settings directly from SharedPreferences.
  static Future<void> scheduleEventAlarm([
    BuildContext? context,
    EventModel? event,
    List<DateTime>? occurrences,
  ]) async {
    if (event == null) return;

    final prefs = await SharedPreferences.getInstance();
    final allowAlarms = prefs.getBool('notif_allow_alarms') ?? true;
    final allowNotifs = prefs.getBool('notif_allow_notifications') ?? true;
    final shouldVibrate = prefs.getBool('notif_vibrate') ?? true;
    final alarmVolume = (prefs.getDouble('alarm_volume') ?? 1.0).clamp(0.05, 1.0);
    final audioPath = resolveAlarmAudioPath(prefs);

    final timesToSchedule = occurrences != null && occurrences.isNotEmpty
        ? List<DateTime>.from(occurrences)
        : <DateTime>[];

    // Generate occurrences for repeating events if none were provided
    if (timesToSchedule.isEmpty && event.alarmTime.isNotEmpty) {
      final parsed = EventDateTimeUtils.parseAlarmIsoToLocal(event.alarmTime);

      if (parsed != null) {
        final repeatRule = event.repeat?.toLowerCase().trim() ?? '';
        if (repeatRule.isNotEmpty && repeatRule != "don't repeat" && repeatRule != 'none') {
          final repo = AddEventRepository();
          final customDays = <String>[];
          int interval = 1;
          String unit = 'week';
          String endType = 'Never';
          DateTime endDate = DateTime.now().add(const Duration(days: 365));
          int maxOccurrences = 30;

          if (event.customRepeat != null) {
            interval = int.tryParse(
                  (event.customRepeat!['interval'] ?? event.customRepeat!['repeat_every'])
                          ?.toString() ??
                      '1',
                ) ??
                1;
            unit = (event.customRepeat!['unit'] ?? event.customRepeat!['repeat_unit'])
                    ?.toString() ??
                'week';
            endType = (event.customRepeat!['end_type'] ?? event.customRepeat!['ends'])
                    ?.toString() ??
                'Never';
            final rawDays =
                event.customRepeat!['days_of_week'] ?? event.customRepeat!['repeat_days'];
            if (rawDays is List) {
              customDays.addAll(rawDays.map((e) => e.toString()));
            }
            if (event.customRepeat!['end_date'] != null) {
              endDate = DateTime.tryParse(event.customRepeat!['end_date'].toString()) ?? endDate;
            }
            if (event.customRepeat!['occurrences'] != null) {
              maxOccurrences = int.tryParse(event.customRepeat!['occurrences'].toString()) ?? 30;
            }
          }

          timesToSchedule.addAll(
            repo.generateAlarmOccurrences(
              startDateTime: parsed,
              selectedRepeat: event.repeat,
              customRepeatCount: interval,
              customRepeatUnit: unit,
              selectedDays: customDays,
              repeatEndType: endType,
              customEndDate: endDate,
              customOccurrences: maxOccurrences,
            ),
          );
        } else {
          timesToSchedule.add(parsed);
        }
      }
    }

    if (timesToSchedule.isNotEmpty && event.id > 0) {
      _cachedEvents[event.id] = event;
      _cachedOccurrences[event.id] = List<DateTime>.from(timesToSchedule);
    }

    if (!allowAlarms) {
      if (allowNotifs) {
        final now = DateTime.now();
        for (int i = 0; i < timesToSchedule.length; i++) {
          final localTime = timesToSchedule[i];
          if (localTime.isBefore(now)) continue;
          final notifId = computeNotificationId(event.id, i);
          await NotificationService.scheduleNotification(
            id: notifId,
            title: event.title,
            body: event.description,
            alarmTime: localTime,
            payload: event.id.toString(),
          );
        }
        debugPrint('🔔 Alarms disabled -> Scheduled fallback notification(s) for ${event.title}');
      } else {
        debugPrint('⛔ Alarms & Notifications disabled in settings. Skipping ${event.title}');
      }
      return;
    }

    final now = DateTime.now();
    Set<int> existingAlarmIds = {};
    try {
      final existing = await Alarm.getAlarms();
      existingAlarmIds = existing.map((a) => a.id).toSet();
    } catch (_) {}

    for (int i = 0; i < timesToSchedule.length; i++) {
      final localTime = timesToSchedule[i];
      final alarmId = computeAlarmId(event.id, i);

      if (localTime.isBefore(now)) {
        debugPrint('⛔ Skipping past alarm for ${event.title}: $localTime');
        continue;
      }

      if (_scheduledIds.contains(alarmId) && existingAlarmIds.contains(alarmId)) {
        debugPrint('🔁 Alarm already scheduled with ID $alarmId for ${event.title}');
        continue;
      }

      try {
        await Alarm.set(
          alarmSettings: AlarmSettings(
            id: alarmId,
            dateTime: localTime,
            assetAudioPath: audioPath,
            loopAudio: true,
            vibrate: shouldVibrate,
            volumeSettings: VolumeSettings.fade(
              volume: alarmVolume,
              fadeDuration: const Duration(seconds: 2),
            ),
            androidFullScreenIntent: true,
            warningNotificationOnKill: false,
            notificationSettings: NotificationSettings(
              title: event.title.isNotEmpty ? event.title : 'Event Reminder',
              body: event.description.isNotEmpty
                  ? event.description
                  : 'Your scheduled event is starting now.',
              stopButton: 'STOP',
              icon: 'notification_icon',
            ),
            payload: event.id.toString(),
          ),
        );
        _scheduledIds.add(alarmId);
        debugPrint('⏰ Alarm scheduled for ${event.title} at $localTime (ID: $alarmId)');
      } catch (e) {
        debugPrint('⚠️ Failed to schedule alarm for ${event.title}: $e');
      }
    }
  }

  /// Synchronizes all currently scheduled future alarms & fallback notifications when the user updates
  /// Allow Alarms, Allow Notifications, Vibration, Volume, or Selected Ringtone in Notification Settings.
  static Future<void> syncActiveAlarmsWithSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allowAlarms = prefs.getBool('notif_allow_alarms') ?? true;
      final allowNotifs = prefs.getBool('notif_allow_notifications') ?? true;
      final shouldVibrate = prefs.getBool('notif_vibrate') ?? true;
      final alarmVolume = (prefs.getDouble('alarm_volume') ?? 1.0).clamp(0.05, 1.0);
      final audioPath = resolveAlarmAudioPath(prefs);
      final now = DateTime.now();

      if (!allowAlarms) {
        // Ensure full-screen alarms are stopped
        try {
          await Alarm.stopAll();
        } catch (_) {}
        _scheduledIds.clear();

        if (!allowNotifs) {
          await NotificationService.cancelAllNotifications();
          return;
        }

        // Re-schedule fallback notifications for cached events so updated vibration/volume takes effect
        await NotificationService.cancelAllNotifications();
        for (final entry in _cachedEvents.entries) {
          final event = entry.value;
          final occurrences = _cachedOccurrences[entry.key] ?? const <DateTime>[];
          for (int i = 0; i < occurrences.length; i++) {
            final dt = occurrences[i];
            if (dt.isAfter(now)) {
              await NotificationService.scheduleNotification(
                id: computeNotificationId(event.id, i),
                title: event.title,
                body: event.description,
                alarmTime: dt,
                payload: event.id.toString(),
              );
            }
          }
        }
        debugPrint('🔄 Synced ${_cachedEvents.length} events to fallback notifications.');
        return;
      }

      // allowAlarms == true: clear fallback notifications to prevent duplicate firing on the same second
      await NotificationService.cancelAllNotifications();

      final allAlarms = await Alarm.getAlarms();
      final activeIds = <int>{};

      for (final alarm in allAlarms) {
        if (alarm.dateTime.isAfter(now) && !(await Alarm.isRinging(alarm.id))) {
          await Alarm.set(
            alarmSettings: alarm.copyWith(
              assetAudioPath: audioPath,
              vibrate: shouldVibrate,
              volumeSettings: VolumeSettings.fade(
                volume: alarmVolume,
                fadeDuration: const Duration(seconds: 2),
              ),
            ),
          );
          activeIds.add(alarm.id);
          _scheduledIds.add(alarm.id);
        }
      }

      // Also restore any cached events that were previously cancelled when allowAlarms was toggled off
      for (final entry in _cachedEvents.entries) {
        final event = entry.value;
        final occurrences = _cachedOccurrences[entry.key] ?? const <DateTime>[];
        for (int i = 0; i < occurrences.length; i++) {
          final dt = occurrences[i];
          final alarmId = computeAlarmId(event.id, i);
          if (dt.isAfter(now) && !activeIds.contains(alarmId)) {
            await scheduleEventAlarm(null, event, occurrences);
            break;
          }
        }
      }

      debugPrint('🔄 Synchronized active alarms with updated settings.');
    } catch (e) {
      debugPrint('⚠️ Error syncing active alarms with settings: $e');
    }
  }

  /// Cancels base event ID and all possible occurrence IDs for an event
  static Future<void> stopAlarmForEvent(int eventId) async {
    _cachedEvents.remove(eventId);
    _cachedOccurrences.remove(eventId);
    await stopAlarm(eventId);

    for (int i = 0; i < 50; i++) {
      final alarmId = computeAlarmId(eventId, i);
      await stopAlarm(alarmId);
    }

    try {
      final allAlarms = await Alarm.getAlarms();
      for (final alarm in allAlarms) {
        if (alarm.payload == eventId.toString() || alarm.id == eventId) {
          await stopAlarm(alarm.id);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking active alarms for cancellation: $e');
    }
  }

  /// Stops all native audio + hardware vibration immediately across both Flutter & Native channels.
  static Future<void> _killAllActiveRingingHardware(int primaryAlarmId) async {
    try {
      await _ringtoneChannel.invokeMethod('setAlarmRingingState', {'isRinging': false});
    } catch (_) {}
    try {
      await _ringtoneChannel.invokeMethod('stopRingtone');
    } catch (_) {}
    try {
      await _ringtoneChannel.invokeMethod('cancelVibration');
    } catch (_) {}

    try {
      await Alarm.stop(primaryAlarmId);
      _scheduledIds.remove(primaryAlarmId);
    } catch (e) {
      debugPrint('⚠️ Error stopping primary alarm $primaryAlarmId: $e');
    }

    // Also stop any other concurrently ringing alarms so vibration can never stay stuck
    try {
      final allAlarms = await Alarm.getAlarms();
      for (final alarm in allAlarms) {
        if (alarm.id != primaryAlarmId && await Alarm.isRinging(alarm.id)) {
          await Alarm.stop(alarm.id);
          _scheduledIds.remove(alarm.id);
        }
      }
    } catch (_) {}

    try {
      await NotificationService.cancelNotification(primaryAlarmId);
    } catch (_) {}
  }

  /// Centralized Snooze: stops native audio + Alarm vibration, then schedules a future alarm.
  static Future<void> snoozeAlarm(AlarmSettings settings, int snoozeMinutes) async {
    final safeMinutes = snoozeMinutes.clamp(1, 120);
    await _killAllActiveRingingHardware(settings.id);

    try {
      final snoozeTime = DateTime.now().add(Duration(minutes: safeMinutes));
      final prefs = await SharedPreferences.getInstance();
      final shouldVibrate = prefs.getBool('notif_vibrate') ?? true;
      final alarmVolume = (prefs.getDouble('alarm_volume') ?? 1.0).clamp(0.05, 1.0);
      final audioPath = resolveAlarmAudioPath(prefs);

      await Alarm.set(
        alarmSettings: settings.copyWith(
          dateTime: snoozeTime,
          assetAudioPath: audioPath,
          vibrate: shouldVibrate,
          volumeSettings: VolumeSettings.fade(
            volume: alarmVolume,
            fadeDuration: const Duration(seconds: 2),
          ),
        ),
      );
      _scheduledIds.add(settings.id);
      debugPrint('😴 Alarm snoozed for $safeMinutes min to $snoozeTime (ID: ${settings.id})');
    } catch (e) {
      debugPrint('⚠️ Error setting snoozed alarm: $e');
    }
  }

  /// Centralized Stop: stops native audio and Alarm package vibration completely
  static Future<void> dismissAlarm(int id) async {
    await _killAllActiveRingingHardware(id);
    debugPrint('🛑 Alarm completely dismissed (ID: $id)');
  }

  static void listenToAlarmRingtone(BuildContext context) {
    Alarm.ringStream.stream.listen((alarmSettings) {
      if (context.mounted && !isRingScreenPresented) {
        isRingScreenPresented = true;
        context.push('/alarm', extra: alarmSettings);
      }
    });
  }

  static Future<void> stopAlarm(int id) async {
    try {
      await Alarm.stop(id);
    } catch (_) {}
    _scheduledIds.remove(id);
  }

  static Future<void> cancelAllAlarms() async {
    try {
      await _ringtoneChannel.invokeMethod('setAlarmRingingState', {'isRinging': false});
      await _ringtoneChannel.invokeMethod('stopRingtone');
      await _ringtoneChannel.invokeMethod('cancelVibration');
    } catch (_) {}
    try {
      await Alarm.stopAll();
    } catch (_) {}
    _scheduledIds.clear();
    debugPrint('🛑 All scheduled alarms cancelled');
  }

  static Future<void> scheduleAlarmsForEvents(BuildContext? context, List<EventModel> events) async {
    for (var event in events) {
      await scheduleEventAlarm(context, event);
    }
  }

  static void resetScheduledIds() {
    _scheduledIds.clear();
  }
}
