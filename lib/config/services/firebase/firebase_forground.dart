import 'package:alarm/alarm.dart';
import 'package:firebase_messaging/firebase_messaging.dart' hide NotificationSettings;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/alerm_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final String title = message.notification?.title ??
      message.data['title'] ??
      message.data['event_title'] ??
      '';
  final String body = message.notification?.body ??
      message.data['body'] ??
      message.data['message'] ??
      message.data['description'] ??
      '';

  if (title.isEmpty && body.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final allowNotifs = prefs.getBool('notif_allow_notifications') ?? true;
  final allowAlarms = prefs.getBool('notif_allow_alarms') ?? true;
  final shouldVibrate = prefs.getBool('notif_vibrate') ?? true;
  final alarmVolume = (prefs.getDouble('alarm_volume') ?? 1.0).clamp(0.05, 1.0);

  final rawEventId = message.data['eventId'] ?? message.data['id'];
  final int baseEventId = int.tryParse(rawEventId?.toString() ?? '') ??
      (DateTime.now().millisecondsSinceEpoch ~/ 1000);
  final int alarmId = AlarmHelper.computeAlarmId(baseEventId, 0);
  final int notifId = AlarmHelper.computeNotificationId(baseEventId, 0);

  final String payload = rawEventId?.toString() ?? '/home';
  final bool isExplicitAlarmPush =
      message.data['type']?.toString().toLowerCase() == 'alarm' ||
          message.data['is_alarm']?.toString().toLowerCase() == 'true';

  if (isExplicitAlarmPush && allowAlarms) {
    final audioPath = AlarmHelper.resolveAlarmAudioPath(prefs);
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId,
        dateTime: DateTime.now().add(const Duration(seconds: 1)),
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
          title: title.isNotEmpty ? title : 'Event Alarm',
          body: body.isNotEmpty ? body : 'Your scheduled event is starting now.',
          stopButton: 'STOP',
          icon: 'notification_icon',
        ),
        payload: payload,
      ),
    );
  } else if (allowNotifs && message.notification == null) {
    // Only schedule local notification for data-only messages (OS renders notification messages automatically)
    await NotificationService.scheduleNotification(
      id: notifId,
      title: title,
      body: body,
      alarmTime: DateTime.now().add(const Duration(seconds: 1)),
      payload: payload,
    );
  }
}
