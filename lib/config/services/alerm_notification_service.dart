import 'dart:typed_data';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/app_route/app_route.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/core/utils/platform_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelVibrateId = 'event_reminder_vibrate_v3';
  static const String _channelSilentVibrationId = 'event_reminder_novibrate_v3';
  static const String _channelSilentSoundId = 'event_reminder_muted_v3';

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          _channelVibrateId,
          'Event Reminders (Sound & Vibration)',
          description: 'Event notifications with sound and vibration',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        ),
      );

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelSilentVibrationId,
          'Event Reminders (Sound Only)',
          description: 'Event notifications with sound and no vibration',
          importance: Importance.max,
          playSound: true,
          enableVibration: false,
        ),
      );

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelSilentSoundId,
          'Event Reminders (Silent)',
          description: 'Silent event notifications',
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        ),
      );
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';
    if (payload.isEmpty || AlarmHelper.isRingScreenPresented) return;

    final eventId = int.tryParse(payload);
    if (eventId != null && eventId > 0) {
      appRouter.push('/event_details', extra: eventId);
    }
  }

  /// Request system notification permission (Android 13+ POST_NOTIFICATIONS & iOS).
  static Future<bool> requestNotificationPermission() async {
    try {
      if (PlatformUtils.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          return result.isGranted;
        }
        return true;
      } else if (PlatformUtils.isIOS) {
        final plugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime alarmTime,
    required dynamic payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allowNotifs = prefs.getBool('notif_allow_notifications') ?? true;
      if (!allowNotifs) {
        debugPrint('⛔ Notifications disabled in settings. Skipping $title');
        return;
      }

      final shouldVibrate = prefs.getBool('notif_vibrate') ?? true;
      final notifVolume = prefs.getDouble('notif_volume') ?? 0.8;
      final playSound = notifVolume > 0.02;

      final String selectedChannelId;
      final String selectedChannelName;
      if (!playSound && !shouldVibrate) {
        selectedChannelId = _channelSilentSoundId;
        selectedChannelName = 'Event Reminders (Silent)';
      } else if (shouldVibrate) {
        selectedChannelId = _channelVibrateId;
        selectedChannelName = 'Event Reminders (Sound & Vibration)';
      } else {
        selectedChannelId = _channelSilentVibrationId;
        selectedChannelName = 'Event Reminders (Sound Only)';
      }

      final hasExactPermission = await _hasExactAlarmPermission();
      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(alarmTime, tz.local);

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint('⛔ Skipped past notification: $scheduledDate');
        return;
      }

      await _notifications.zonedSchedule(
        id,
        title.isNotEmpty ? title : 'Event Reminder',
        body.isNotEmpty ? body : 'Upcoming event reminder',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            selectedChannelId,
            selectedChannelName,
            channelDescription: 'Event reminder notifications',
            importance: Importance.max,
            priority: Priority.max,
            playSound: playSound,
            enableVibration: shouldVibrate,
            vibrationPattern: shouldVibrate
                ? Int64List.fromList([0, 400, 200, 400])
                : null,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            styleInformation: BigTextStyleInformation(
              body.isNotEmpty ? body : 'Upcoming event reminder',
              contentTitle: title.isNotEmpty ? title : 'Event Reminder',
              htmlFormatBigText: true,
              htmlFormatContentTitle: true,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: playSound,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: payload.toString(),
        androidScheduleMode: hasExactPermission
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );

      debugPrint('⏰ Notification scheduled (ID: $id) for $scheduledDate');
    } catch (e) {
      debugPrint('⚠️ Error scheduling notification: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('🛑 Notification cancelled for ID: $id');
    } catch (e) {
      debugPrint('⚠️ Error cancelling notification $id: $e');
    }
  }

  static Future<void> cancelNotificationsForEvent(int eventId) async {
    try {
      for (int i = 0; i < 50; i++) {
        await _notifications.cancel(AlarmHelper.computeAlarmId(eventId, i));
        await _notifications.cancel(AlarmHelper.computeNotificationId(eventId, i));
      }
      await _notifications.cancel(eventId);
      debugPrint('🛑 Cancelled all notifications for event ID: $eventId');
    } catch (e) {
      debugPrint('⚠️ Error cancelling notifications for event $eventId: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('🛑 All local notifications cancelled');
    } catch (e) {
      debugPrint('⚠️ Error cancelling all notifications: $e');
    }
  }

  static Future<bool> _hasExactAlarmPermission() async {
    if (!PlatformUtils.isAndroid) return true;

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  static Future<void> requestExactAlarmPermission() async {
    if (!PlatformUtils.isAndroid) return;

    final hasPermission = await _hasExactAlarmPermission();
    if (hasPermission) return;

    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }
}
