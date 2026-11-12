import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/config/app_route/app_providers.dart';
import 'package:time_verse/config/app_route/init_app.dart';
import 'package:time_verse/config/app_route/app_route.dart';
import 'package:time_verse/config/connectivity/no_connectivity.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/core/theme/theme.dart';
import 'package:time_verse/core/theme/theme_provider.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/font_manager.dart';
import 'package:time_verse/features/calender/controller/calender_controller.dart';
import 'package:time_verse/features/home/controller/home_controller.dart';
import 'package:time_verse/features/settings/profile/controller/profile_controller.dart';

void main() async {
  await initApp();
  await FontManager.preloadFonts();
  AlarmSettings? ringingAlarm;
  try {
    final alarms = await Alarm.getAlarms();
    for (final alarm in alarms) {
      if (await Alarm.isRinging(alarm.id)) {
        ringingAlarm = alarm;
        break;
      }
    }
  } catch (_) {
    ringingAlarm = null;
  }

  runApp(MyApp(initialRingingAlarm: ringingAlarm));
}

class MyApp extends StatefulWidget {
  final AlarmSettings? initialRingingAlarm;

  const MyApp({super.key, this.initialRingingAlarm});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool hasConnection = true;
  bool showBackOnline = false;
  Timer? _backOnlineTimer;
  bool isAlarmActive = false;
  StreamSubscription<AlarmSet>? _activeRingSetSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(const AssetImage(ImageAssets.bgDark5), context);
      precacheImage(const AssetImage(ImageAssets.bgLight), context);
      precacheImage(const AssetImage(ImageAssets.logo), context);
      precacheImage(const AssetImage(ImageAssets.logoLight), context);
    });

    if (widget.initialRingingAlarm != null) {
      isAlarmActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _presentAlarmScreenIfNeeded(widget.initialRingingAlarm!);
      });
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      status,
    ) {
      if (!mounted) return;
      final isConnected = !status.contains(ConnectivityResult.none);
      _handleConnectivityChange(isConnected);
    });

    _activeRingSetSubscription = Alarm.ringing.listen((alarmSet) {
      if (!mounted) return;
      final ringingNow = alarmSet.alarms.isNotEmpty;
      if (isAlarmActive != ringingNow) {
        setState(() {
          isAlarmActive = ringingNow;
        });
      }
      if (ringingNow && !AlarmHelper.isRingScreenPresented) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _presentAlarmScreenIfNeeded(alarmSet.alarms.first);
        });
      }
    });
  }

  void _presentAlarmScreenIfNeeded(AlarmSettings alarmSettings) {
    final currentRoute =
        appRouter.routerDelegate.currentConfiguration.uri.toString();
    if (currentRoute != '/alarm' && !AlarmHelper.isRingScreenPresented) {
      AlarmHelper.isRingScreenPresented = true;
      appRouter.push('/alarm', extra: alarmSettings);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRingingAlarmsOnResume();
    }
  }

  Future<void> _checkRingingAlarmsOnResume() async {
    try {
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        if (await Alarm.isRinging(alarm.id)) {
          if (mounted) {
            setState(() {
              isAlarmActive = true;
            });
            _presentAlarmScreenIfNeeded(alarm);
          }
          break;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _activeRingSetSubscription?.cancel();
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final status = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final isConnected = !status.contains(ConnectivityResult.none);
    setState(() {
      hasConnection = isConnected;
    });
  }

  void _handleConnectivityChange(bool isConnected) {
    if (hasConnection == isConnected) return;

    if (isConnected && !hasConnection) {
      _backOnlineTimer?.cancel();
      setState(() {
        hasConnection = true;
        showBackOnline = true;
      });
      _backOnlineTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            showBackOnline = false;
          });
        }
      });
      _onReconnected();
    } else {
      _backOnlineTimer?.cancel();
      setState(() {
        hasConnection = isConnected;
        showBackOnline = false;
      });
    }
  }

  void _onReconnected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          final profile = navContext.read<ProfileController>();
          final home = navContext.read<HomeController>();
          final cal = navContext.read<CalendarController>();
          if (home.isInitialized) {
            home.loadHomeScreenData(profile, date: home.selectedDate);
          }
          cal.fetchUpcomingEvents();
        }
      } catch (e) {
        debugPrint('ℹ️ Reconnect auto-refresh notice: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      child: ScreenUtilInit(
        designSize: const Size(390, 846),
        minTextAdapt: true,
        builder: (context, child) {
          return Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final isDarkMode = themeProvider.themeMode == ThemeMode.dark ||
                  (themeProvider.themeMode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark);

              final overlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarBrightness:
                    isDarkMode ? Brightness.dark : Brightness.light,
                statusBarIconBrightness:
                    isDarkMode ? Brightness.light : Brightness.dark,
                systemStatusBarContrastEnforced: false,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    isDarkMode ? Brightness.light : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  title: 'InfiniQuote',
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: themeProvider.themeMode,
                  routerConfig: appRouter,
                  builder: (context, routerChild) {
                    return Stack(
                      children: [
                        routerChild ?? const SizedBox.shrink(),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: NoInternetTopBar(
                            hasConnection: hasConnection,
                            showBackOnline: showBackOnline,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
