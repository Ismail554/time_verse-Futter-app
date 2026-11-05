import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/platform_utils.dart';
import 'package:time_verse/features/settings/notification/model/notification_model.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationSettingsController extends ChangeNotifier {
  final NotificationSettingsModel _settings = NotificationSettingsModel();

  static const MethodChannel _platform = MethodChannel('com.infiniquote.app/ringtone');

  static const String _prefAllowNotifications = 'notif_allow_notifications';
  static const String _prefAllowAlarms = 'notif_allow_alarms';
  static const String _prefVibrate = 'notif_vibrate';
  static const String _prefNotificationVolume = 'notif_volume';
  static const String _prefAlarmVolume = 'alarm_volume';
  static const String _prefRingtone = 'alarm_selected_ringtone';
  static const String _prefRingtoneTitle = 'alarm_selected_ringtone_title';
  static const String _prefRingtoneLocalPath = 'alarm_selected_ringtone_local_path';
  static const String _prefSnoozeMinutes = 'alarm_snooze_minutes';

  int _snoozeDurationMinutes = 5;
  String _selectedRingtoneTitle = 'Default Chime';
  bool _isPreviewPlaying = false;

  NotificationSettingsController() {
    loadSettingsFromPrefs();
  }

  // Getters
  bool get allowNotifications => _settings.allowNotifications;
  bool get allowAlarms => _settings.allowAlarms;
  bool get vibrate => _settings.vibrate;
  double get notificationVolume => _settings.notificationVolume;
  double get alarmVolume => _settings.alarmVolume;
  int get snoozeDurationMinutes => _snoozeDurationMinutes;
  String get selectedRingtoneTitle => _selectedRingtoneTitle;
  bool get isPreviewPlaying => _isPreviewPlaying;

  String get selectedRingtone =>
      _settings.selectedRingtone.isEmpty ? AudioAssets.alarm : _settings.selectedRingtone;

  Future<void> loadSettingsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings.allowNotifications = prefs.getBool(_prefAllowNotifications) ?? true;
      _settings.allowAlarms = prefs.getBool(_prefAllowAlarms) ?? true;
      _settings.vibrate = prefs.getBool(_prefVibrate) ?? true;
      _settings.notificationVolume = prefs.getDouble(_prefNotificationVolume) ?? 0.8;
      _settings.alarmVolume = prefs.getDouble(_prefAlarmVolume) ?? 1.0;
      _settings.selectedRingtone = prefs.getString(_prefRingtone) ?? AudioAssets.alarm;
      _selectedRingtoneTitle = prefs.getString(_prefRingtoneTitle) ?? 'Default Chime';
      _snoozeDurationMinutes = prefs.getInt(_prefSnoozeMinutes) ?? 5;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading notification settings: $e');
    }
  }

  // Setters / Actions
  Future<void> setAllowNotifications(bool val) async {
    _settings.allowNotifications = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAllowNotifications, val);

    if (!val) {
      await NotificationService.cancelAllNotifications();
    } else {
      await NotificationService.requestNotificationPermission();
    }
  }

  Future<void> setAllowAlarms(bool val) async {
    _settings.allowAlarms = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAllowAlarms, val);

    if (!val) {
      await AlarmHelper.cancelAllAlarms();
    } else {
      await checkAndRequestExactAlarmPermission();
    }
  }

  Future<void> setVibrate(bool val) async {
    _settings.vibrate = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefVibrate, val);

    if (val) {
      try {
        await _platform.invokeMethod('triggerVibration', {'durationMs': 120});
      } catch (_) {
        HapticFeedback.mediumImpact();
      }
    }
    await AlarmHelper.syncActiveAlarmsWithSettings();
  }

  Future<void> setNotificationVolume(double val) async {
    _settings.notificationVolume = val.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefNotificationVolume, _settings.notificationVolume);
  }

  Future<void> setAlarmVolume(double val) async {
    _settings.alarmVolume = val.clamp(0.05, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefAlarmVolume, _settings.alarmVolume);
  }

  Future<void> commitAlarmVolumeAndPreview(double val) async {
    await setAlarmVolume(val);
    await AlarmHelper.syncActiveAlarmsWithSettings();
    await previewAlarmSound(volumeOverride: _settings.alarmVolume, durationMs: 2200);
  }

  Future<void> setSelectedRingtone(
    String ringtone, {
    String? title,
    String? localPath,
  }) async {
    _settings.selectedRingtone = ringtone;
    if (title != null && title.isNotEmpty) {
      _selectedRingtoneTitle = title;
    } else if (!ringtone.startsWith('content://')) {
      _selectedRingtoneTitle = 'Default Chime';
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRingtone, ringtone);
    await prefs.setString(_prefRingtoneTitle, _selectedRingtoneTitle);
    if (localPath != null) {
      await prefs.setString(_prefRingtoneLocalPath, localPath);
    }
    await AlarmHelper.syncActiveAlarmsWithSettings();
  }

  Future<void> resetToDefaultRingtone() async {
    await stopPreviewSound();
    await setSelectedRingtone(
      AudioAssets.alarm,
      title: 'Default Chime',
      localPath: '',
    );
    await previewAlarmSound(durationMs: 2500);
  }

  Future<void> setSnoozeDuration(int minutes) async {
    _snoozeDurationMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSnoozeMinutes, minutes);
  }

  Future<void> previewAlarmSound({double? volumeOverride, int durationMs = 3000}) async {
    try {
      _isPreviewPlaying = true;
      notifyListeners();
      await _platform.invokeMethod('previewRingtone', {
        'uri': selectedRingtone,
        'volume': (volumeOverride ?? alarmVolume).clamp(0.05, 1.0),
        'durationMs': durationMs,
      });
      Future.delayed(Duration(milliseconds: durationMs), () {
        if (_isPreviewPlaying) {
          _isPreviewPlaying = false;
          notifyListeners();
        }
      });
    } catch (e) {
      _isPreviewPlaying = false;
      notifyListeners();
      debugPrint('⚠️ Failed to preview alarm sound: $e');
    }
  }

  Future<void> stopPreviewSound() async {
    try {
      await _platform.invokeMethod('stopRingtone');
    } catch (_) {}
    if (_isPreviewPlaying) {
      _isPreviewPlaying = false;
      notifyListeners();
    }
  }

  Future<void> fetchAndSyncSystemRingtone() async {
    if (PlatformUtils.isAndroid) {
      try {
        final String? systemRingtoneUri = await _platform.invokeMethod('getDefaultRingtoneUri');
        if (systemRingtoneUri != null && systemRingtoneUri.isNotEmpty) {
          final String? title = await _platform.invokeMethod('getRingtoneTitle', {
            'uri': systemRingtoneUri,
          });
          await setSelectedRingtone(systemRingtoneUri, title: title ?? 'System Alarm');
        }
      } catch (e) {
        debugPrint("Failed to fetch system ringtone URI: $e");
      }
    }
  }

  Future<void> checkAndRequestExactAlarmPermission() async {
    if (PlatformUtils.isAndroid) {
      try {
        final status = await Permission.scheduleExactAlarm.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          const intent = AndroidIntent(
            action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
          );
          await intent.launch();
        }
        final bool canFullScreen =
            await _platform.invokeMethod('canUseFullScreenIntent') ?? true;
        if (!canFullScreen) {
          await _platform.invokeMethod('requestFullScreenIntentPermission');
        }
      } catch (e) {
        debugPrint('⚠️ Exact alarm / full-screen intent check failed: $e');
      }
    }
  }

  Future<void> openDeviceSoundSettings() async {
    await stopPreviewSound();
    if (PlatformUtils.isAndroid) {
      try {
        final result = await _platform.invokeMethod('pickAlarmRingtone', {
          'currentUri': selectedRingtone,
        });
        if (result is Map) {
          final uri = result['uri']?.toString() ?? '';
          final title = result['title']?.toString() ?? 'System Alarm';
          final localPath = result['localPath']?.toString() ?? '';
          if (uri.isNotEmpty) {
            await setSelectedRingtone(uri, title: title, localPath: localPath);
          }
        }
        return;
      } catch (e) {
        debugPrint('⚠️ Native ringtone picker fallback to sound settings: $e');
      }
      const intent = AndroidIntent(action: 'android.settings.SOUND_SETTINGS');
      await intent.launch();
      Future.delayed(const Duration(seconds: 2), () => fetchAndSyncSystemRingtone());
    } else if (PlatformUtils.isIOS) {
      final Uri url = Uri.parse('App-Prefs:root=Sounds');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(Uri.parse('App-Prefs:'));
      }
    }
  }
}
