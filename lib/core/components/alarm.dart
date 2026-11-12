// ignore_for_file: use_build_context_synchronously, dead_null_aware_expression, deprecated_member_use

import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_verse/config/app_route/app_route.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/settings/notification/controller/notification_controller.dart';

class ExampleAlarmRingScreen extends StatefulWidget {
  const ExampleAlarmRingScreen({required this.alarmSettings, super.key});

  final AlarmSettings alarmSettings;

  @override
  State<ExampleAlarmRingScreen> createState() => _ExampleAlarmRingScreenState();
}

class _ExampleAlarmRingScreenState extends State<ExampleAlarmRingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AlarmSet>? _subscription;
  Timer? _clockTimer;
  Timer? _unattendedTimeoutTimer;
  late AnimationController _pulseController;
  late DateTime _currentTime;
  bool _isActionInProgress = false;

  // Native hardware channel for ringtone & volume button interception
  static const MethodChannel _ringtoneChannel = MethodChannel(
    'com.infiniquote.app/ringtone',
  );

  @override
  void initState() {
    super.initState();
    debugPrint('🔔 [AlarmRingScreen] Ringing: ${widget.alarmSettings.id}');
    AlarmHelper.isRingScreenPresented = true;
    _currentTime = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // 1. Immediately engage native hardware volume button interception (0ms delay)
    _ringtoneChannel.setMethodCallHandler(_handleNativeMethodCall);
    _engageNativeRingingMode();

    // 2. Keep clock display live every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // 3. Auto-snooze after 10 minutes of unattended ringing to protect battery & hardware
    _unattendedTimeoutTimer = Timer(const Duration(minutes: 10), () {
      if (mounted && !_isActionInProgress) {
        debugPrint('⏱️ [AlarmRingScreen] Unattended timeout reached -> Auto Snooze');
        _snooze();
      }
    });

    // 4. Auto-pop if alarm package reports this alarm was stopped externally (e.g. notification STOP button)
    _subscription = Alarm.ringing.listen((alarms) {
      if (alarms.containsId(widget.alarmSettings.id)) return;
      if (mounted && !_isActionInProgress) {
        _stopAudioAndPop();
      }
    });
  }

  Future<void> _engageNativeRingingMode() async {
    try {
      await _ringtoneChannel.invokeMethod('setAlarmRingingState', {
        'isRinging': true,
      });

      final prefs = await SharedPreferences.getInstance();
      final shouldVibrate = prefs.getBool('notif_vibrate') ?? true;
      if (!shouldVibrate) {
        await _ringtoneChannel.invokeMethod('cancelVibration');
      }

      // Only engage native MediaPlayer fallback if a content:// URI could not be copied locally
      if (await AlarmHelper.requiresNativeUriPlayerFallback()) {
        final uri = prefs.getString('alarm_selected_ringtone') ?? '';
        final volume = prefs.getDouble('alarm_volume') ?? 1.0;
        await _ringtoneChannel.invokeMethod('playRingtone', {
          'uri': uri,
          'volume': volume,
          'loop': true,
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error engaging native ringing mode: $e');
    }
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onVolumeButtonPressed') {
      debugPrint('🎚️ [AlarmRingScreen] Volume button pressed -> Auto Snooze');
      await _snooze();
    }
  }

  Future<void> _snooze() async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    int snoozeMinutes = 5;
    try {
      final notifController = context.read<NotificationSettingsController>();
      if (notifController.vibrate) {
        HapticFeedback.mediumImpact();
      }
      snoozeMinutes = notifController.snoozeDurationMinutes;
      await AlarmHelper.snoozeAlarm(widget.alarmSettings, snoozeMinutes);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alarm snoozed for $snoozeMinutes minutes',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFFFFB703),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error during snooze: $e');
    } finally {
      _closeScreen();
    }
  }

  Future<void> _stop() async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      final notifController = context.read<NotificationSettingsController>();
      if (notifController.vibrate) {
        HapticFeedback.heavyImpact();
      }
      await AlarmHelper.dismissAlarm(widget.alarmSettings.id);
    } catch (e) {
      debugPrint('⚠️ Error during stop: $e');
    } finally {
      _closeScreen();
    }
  }

  Future<void> _stopAudioAndPop() async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    try {
      await _ringtoneChannel.invokeMethod('setAlarmRingingState', {
        'isRinging': false,
      });
      await _ringtoneChannel.invokeMethod('stopRingtone');
      await _ringtoneChannel.invokeMethod('cancelVibration');
    } catch (_) {}
    _closeScreen();
  }

  void _closeScreen() {
    AlarmHelper.isRingScreenPresented = false;
    if (!mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      appRouter.go('/home');
    }
  }

  @override
  void dispose() {
    AlarmHelper.isRingScreenPresented = false;
    _clockTimer?.cancel();
    _unattendedTimeoutTimer?.cancel();
    _subscription?.cancel();
    _pulseController.dispose();
    _ringtoneChannel.setMethodCallHandler(null);
    _ringtoneChannel.invokeMethod('setAlarmRingingState', {'isRinging': false});
    _ringtoneChannel.invokeMethod('stopRingtone');
    _ringtoneChannel.invokeMethod('cancelVibration');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.alarmSettings.notificationSettings;
    final String formattedTime = DateFormat('HH:mm').format(_currentTime);
    final String formattedDateStr = DateFormat('EEE, d MMMM').format(_currentTime);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final snoozeMinutes = context.select<NotificationSettingsController, int>(
      (c) => c.snoozeDurationMinutes,
    );

    final primaryTextColor = isDarkMode ? Colors.white : AppColors.l_text_clr;
    final secondaryTextColor =
        isDarkMode ? Colors.grey.shade400 : AppColors.l_text_clr2;
    final cardBorderColor = isDarkMode
        ? const Color(0xFFFFB703).withOpacity(0.22)
        : const Color(0xFFFFB703).withOpacity(0.45);
    final cardBgColor = isDarkMode
        ? const Color(0xFF0A1628).withOpacity(0.75)
        : Colors.white.withOpacity(0.88);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _stop();
      },
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF050B16)
            : AppColors.background_color,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -250) {
              debugPrint('👆 Swiped UP on alarm screen -> Dismiss');
              _stop();
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? const [
                        Color(0xFF050B16),
                        Color(0xFF0A1628),
                        Color(0xFF050B16),
                      ]
                    : const [
                        Color(0xFFFFFBF5),
                        Color(0xFFFFF3DC),
                        Color(0xFFFFF7ED),
                      ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppSpacing.h12,
                      Text(
                        notification.title.isNotEmpty
                            ? notification.title
                            : 'Event Reminder',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          color: isDarkMode
                              ? AppColors.button_color
                              : AppColors.l_text_clr,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppSpacing.h12,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40.w,
                            height: 1.h,
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Icon(
                              Icons.star,
                              color: const Color(0xFFFFB703),
                              size: 12.sp,
                            ),
                          ),
                          Container(
                            width: 40.w,
                            height: 1.h,
                            color: isDarkMode ? Colors.white24 : Colors.black26,
                          ),
                        ],
                      ),
                      AppSpacing.h20,
                      Text(
                        formattedTime,
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFFF9F1C),
                          fontSize: 60.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      AppSpacing.h8,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📅 ', style: TextStyle(fontSize: 14.sp)),
                          Text(
                            'Today  •  $formattedDateStr',
                            style: GoogleFonts.inter(
                              color: secondaryTextColor,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h28,
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 22.h,
                        ),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '“',
                              style: GoogleFonts.cormorant(
                                color: const Color(0xFFFFB703),
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              notification.body.isNotEmpty
                                  ? notification.body
                                  : 'Every journey leads ahead, stepping into the potential trapped beneath your dreams.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cormorant(
                                color: primaryTextColor.withOpacity(0.92),
                                fontSize: 22.sp,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.h24,
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.08);
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 90.w,
                          height: 90.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFB703).withOpacity(0.12),
                            border: Border.all(
                              color: const Color(0xFFFFB703).withOpacity(0.25),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB703).withOpacity(0.25),
                                blurRadius: 35,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 70.w,
                              height: 70.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFB703).withOpacity(0.18),
                                border: Border.all(
                                  color: const Color(0xFFFFB703).withOpacity(0.38),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 54.w,
                                  height: 54.h,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFB703).withOpacity(0.32),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: const Color(0xFFFFB703),
                                    size: 28.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AppSpacing.h24,
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50.h,
                              child: OutlinedButton(
                                onPressed: _snooze,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDarkMode
                                        ? Colors.white30
                                        : const Color(0xFFD4902A),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '😴 ',
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                    Flexible(
                                      child: Text(
                                        'Snooze (${snoozeMinutes}m)',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: primaryTextColor,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          AppSpacing.w16,
                          Expanded(
                            child: SizedBox(
                              height: 50.h,
                              child: ElevatedButton(
                                onPressed: _stop,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE6A100),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.stop_rounded,
                                      color: Colors.black,
                                      size: 20.sp,
                                    ),
                                    AppSpacing.w6,
                                    Text(
                                      'Stop',
                                      style: GoogleFonts.inter(
                                        color: Colors.black,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h14,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: secondaryTextColor.withOpacity(0.75),
                            size: 20.sp,
                          ),
                          Text(
                            'Swipe Up to dismiss  •  Volume button to snooze',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: secondaryTextColor.withOpacity(0.75),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h8,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
