import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:time_verse/core/utils/app_spacing.dart';

class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.red, size: 80.sp),
            AppSpacing.h24,
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            AppSpacing.h8,
            Text(
              'Please check your network settings.',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
