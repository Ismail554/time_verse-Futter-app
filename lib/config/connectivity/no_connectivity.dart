import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:time_verse/core/utils/font_manager.dart';

/// Top bar that displays an animated, non-intrusive status banner when offline
/// or temporarily when internet connection is restored.
class NoInternetTopBar extends StatelessWidget {
  final bool hasConnection;
  final bool showBackOnline;

  const NoInternetTopBar({
    super.key,
    required this.hasConnection,
    this.showBackOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline = !hasConnection;
    final isVisible = isOffline || showBackOnline;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      child: isVisible
          ? Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: topPadding > 0 ? topPadding + 4.h : 8.h,
                  bottom: 8.h,
                  left: 16.w,
                  right: 16.w,
                ),
                decoration: BoxDecoration(
                  color: isOffline
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF2E7D32),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      isOffline ? 'No internet connection' : 'Back online',
                      style: FontManager.outfit(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Fallback compatibility alias for [NoInternetTopBar]
class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoInternetTopBar(hasConnection: false);
  }
}
