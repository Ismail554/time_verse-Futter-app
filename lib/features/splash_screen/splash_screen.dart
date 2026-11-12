// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final isFirstLaunch = await AppPrefs.isFirstLaunch();
    if (isFirstLaunch) {
      await AppPrefs.setFirstLaunch(false);
      context.go('/landing');
      return;
    }

    final authService = AuthService();
    final hasValidSession = await authService.isLoggedIn();

    if (!mounted) return;

    if (hasValidSession) {
      await UserSession().initFromPrefs();
      if (!mounted) return;
      context.go('/home');
    } else {
      // Clear expired or invalid session state
      await authService.clearToken();
      await AppPrefs.clearAllUserData();
      UserSession().clear();

      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String logoAsset = isDarkMode ? ImageAssets.logo : ImageAssets.logoLight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Center(
          child: Image.asset(
            logoAsset,
            width: 268.w,
            height: 263.h,
          ),
        ),
      ),
    );
  }
}
