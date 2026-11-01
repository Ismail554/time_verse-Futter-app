// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/colors.dart';

/// Shows a polished animated success dialog with entrance transitions,
/// pulsing badge ripples, and a call-to-action button.
Future<void> showAnimatedSuccessDialog({
  required BuildContext context,
  String title = 'Account Created!',
  String subtitle = 'Welcome to InfiniQuote!\nYour account has been created successfully.',
  String buttonText = 'Continue to Home',
  String? email,
  VoidCallback? onContinue,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'SuccessDialog',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, anim1, anim2) {
      return _AnimatedSuccessDialogWidget(
        title: title,
        subtitle: subtitle,
        buttonText: buttonText,
        email: email,
        onContinue: onContinue,
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curvedValue = Curves.easeOutBack.transform(anim1.value);
      return Transform.scale(
        scale: curvedValue,
        child: Opacity(
          opacity: anim1.value.clamp(0.0, 1.0),
          child: child,
        ),
      );
    },
  );
}

class _AnimatedSuccessDialogWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final String? email;
  final VoidCallback? onContinue;

  const _AnimatedSuccessDialogWidget({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    this.email,
    this.onContinue,
  });

  @override
  State<_AnimatedSuccessDialogWidget> createState() =>
      _AnimatedSuccessDialogWidgetState();
}

class _AnimatedSuccessDialogWidgetState
    extends State<_AnimatedSuccessDialogWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _checkController;
  late final Animation<double> _checkScaleAnimation;
  late final Animation<double> _checkRotateAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _checkScaleAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _checkRotateAnimation = Tween<double>(begin: -math.pi / 4, end: 0.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: Curves.easeOutBack,
      ),
    );

    _checkController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode
        ? AppColors.containers_bgd
        : AppColors.background_color;
    final borderColor = isDarkMode
        ? AppColors.fourth_color.withOpacity(0.4)
        : AppColors.third_color.withOpacity(0.3);
    final titleColor = isDarkMode
        ? AppColors.text_color
        : AppColors.l_text_clr;
    final subtitleColor = isDarkMode
        ? AppColors.secendary_text_color
        : AppColors.heading_color;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 330.w,
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.6 : 0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              if (isDarkMode)
                BoxShadow(
                  color: AppColors.fourth_color.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🌟 Animated Icon Header with Ripple Pulse
              SizedBox(
                width: 100.w,
                height: 100.h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ripple 1
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final progress = _pulseController.value;
                        final scale = 1.0 + (progress * 0.35);
                        final opacity = (1.0 - progress) * 0.45;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 76.w,
                            height: 76.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.fifth_color.withOpacity(opacity),
                            ),
                          ),
                        );
                      },
                    ),
                    // Outer Ripple 2
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final progress = (_pulseController.value + 0.5) % 1.0;
                        final scale = 1.0 + (progress * 0.25);
                        final opacity = (1.0 - progress) * 0.3;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 76.w,
                            height: 76.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.third_color.withOpacity(opacity),
                            ),
                          ),
                        );
                      },
                    ),
                    // Inner Success Circle
                    Container(
                      width: 76.w,
                      height: 76.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00C896),
                            Color(0xFF008F66),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C896).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _checkController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _checkRotateAnimation.value,
                            child: Transform.scale(
                              scale: _checkScaleAnimation.value,
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 42,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.h20,

              // 🏷️ Title Header
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: 0.3,
                ),
              ),

              AppSpacing.h10,

              // 📄 Subtitle Description
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.45,
                ),
              ),

              if (widget.email != null && widget.email!.isNotEmpty) ...[
                AppSpacing.h12,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14.sp,
                        color: AppColors.fourth_color,
                      ),
                      AppSpacing.w6,
                      Flexible(
                        child: Text(
                          widget.email!,
                          style: GoogleFonts.outfit(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: titleColor.withOpacity(0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              AppSpacing.h25,

              // 🚀 Action Button
              CustomButton(
                text: widget.buttonText,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.onContinue != null) {
                    widget.onContinue!();
                  }
                },
                gradient: AppGradientColors.button_gradient,
                textColor: Colors.black,
                fontFamily: 'outfit',
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                height: 48.h,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

