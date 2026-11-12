import 'dart:ui' as ui;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:time_verse/core/utils/font_manager.dart';

/// Interactive, floating transparent glassmorphic snackbar for network connectivity.
/// Features tap-to-retry with rotating spinner, swipe-up to dismiss, and close button.
class NoInternetTopBar extends StatefulWidget {
  final bool hasConnection;
  final bool showBackOnline;

  const NoInternetTopBar({
    super.key,
    required this.hasConnection,
    this.showBackOnline = false,
  });

  @override
  State<NoInternetTopBar> createState() => _NoInternetTopBarState();
}

class _NoInternetTopBarState extends State<NoInternetTopBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _spinController;

  bool _isChecking = false;
  bool _isDismissedByUser = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(covariant NoInternetTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When connection status updates, bring the bar back if it was dismissed
    if (oldWidget.hasConnection != widget.hasConnection ||
        oldWidget.showBackOnline != widget.showBackOnline) {
      if (_isDismissedByUser) {
        setState(() {
          _isDismissedByUser = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;
    HapticFeedback.lightImpact();
    setState(() => _isChecking = true);
    _spinController.repeat();

    try {
      await Connectivity().checkConnectivity();
      // Allow user to visibly perceive the retry action
      await Future.delayed(const Duration(milliseconds: 650));
    } catch (_) {}

    if (mounted) {
      _spinController.stop();
      _spinController.reset();
      setState(() => _isChecking = false);
    }
  }

  void _dismissBar() {
    HapticFeedback.selectionClick();
    setState(() => _isDismissedByUser = true);
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !widget.hasConnection;
    final isVisible =
        (isOffline || widget.showBackOnline) && !_isDismissedByUser;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color accentColor = isOffline
        ? const Color(0xFFFF453A) // Clean iOS system red
        : const Color(0xFF30D158); // Clean iOS system green

    return IgnorePointer(
      ignoring: !isVisible,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: 'Outfit',
          ),
          child: AnimatedSlide(
            offset: isVisible ? Offset.zero : const Offset(0, -1.6),
            duration: const Duration(milliseconds: 380),
            curve: isVisible ? Curves.easeOutBack : Curves.easeInOutCubic,
            child: AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 280),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topPadding > 0 ? topPadding + 6.h : 16.h,
                    left: 14.w,
                    right: 14.w,
                  ),
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -80) {
                        _dismissBar();
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28.r),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 8.5.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.14),
                                Colors.white.withOpacity(0.03),
                              ],
                            ),
                            color: (isDarkMode
                                    ? const Color(0xFF090D1A)
                                    : const Color(0xFF1E293B))
                                .withOpacity(0.65),
                            borderRadius: BorderRadius.circular(28.r),
                            border: Border.all(
                              color: isOffline
                                  ? accentColor.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.22),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.32),
                                blurRadius: 22,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: accentColor.withOpacity(0.16),
                                blurRadius: 16,
                                spreadRadius: -2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Glowing animated icon badge
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) {
                                  return Container(
                                    width: 28.r,
                                    height: 28.r,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor.withOpacity(
                                        0.14 + (_pulseAnimation.value * 0.12),
                                      ),
                                      border: Border.all(
                                        color: accentColor.withOpacity(
                                          0.4 + (_pulseAnimation.value * 0.4),
                                        ),
                                        width: 1.1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withOpacity(
                                            _pulseAnimation.value * 0.35,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: isOffline
                                          ? Icon(
                                              Icons.wifi_off_rounded,
                                              color: Colors.white,
                                              size: 14.sp,
                                            )
                                          : Icon(
                                              Icons.wifi_rounded,
                                              color: Colors.white,
                                              size: 14.sp,
                                            ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(width: 10.w),

                              // 2. Status typography with zero underline
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isOffline
                                          ? (_isChecking
                                              ? 'Checking connection...'
                                              : "You're Offline")
                                          : 'Back Online',
                                      style: FontManager.outfit(
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.1,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    Text(
                                      isOffline
                                          ? 'Tap to retry • swipe up to hide'
                                          : 'Connection restored',
                                      style: FontManager.outfit(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.72),
                                        decoration: TextDecoration.none,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // 3. Interactive Retry Button (when offline)
                              if (isOffline) ...[
                                SizedBox(width: 10.w),
                                GestureDetector(
                                  onTap: _checkConnection,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 9.w,
                                      vertical: 4.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(14.r),
                                      border: Border.all(
                                        color: accentColor.withOpacity(0.42),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        RotationTransition(
                                          turns: _spinController,
                                          child: Icon(
                                            Icons.refresh_rounded,
                                            color: Colors.white,
                                            size: 12.sp,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          _isChecking ? 'Checking' : 'Retry',
                                          style: FontManager.outfit(
                                            fontSize: 10.5.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                // 4. Dismiss button
                                GestureDetector(
                                  onTap: _dismissBar,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: EdgeInsets.all(4.r),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white.withOpacity(0.75),
                                      size: 13.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
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

/// Fallback compatibility alias for [NoInternetTopBar]
class NoInternetWidget extends StatelessWidget {
  const NoInternetWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoInternetTopBar(hasConnection: false);
  }
}
