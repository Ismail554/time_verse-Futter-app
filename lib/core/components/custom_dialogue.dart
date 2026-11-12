// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/colors.dart';

enum SnackBarType { error, success, info, warning }

/// Displays a sleek, modern floating SnackBar for API errors,
/// validation messages, and success notifications.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.error,
  String? title,
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onAction,
  String? actionLabel,
}) {
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  final IconData icon;
  final Color accentColor;
  final String defaultTitle;

  switch (type) {
    case SnackBarType.error:
      icon = Icons.error_outline_rounded;
      accentColor = const Color(0xFFEF4444);
      defaultTitle = 'Error';
      break;
    case SnackBarType.success:
      icon = Icons.check_circle_outline_rounded;
      accentColor = AppColors.fifth_color;
      defaultTitle = 'Success';
      break;
    case SnackBarType.warning:
      icon = Icons.warning_amber_rounded;
      accentColor = AppColors.fourth_color;
      defaultTitle = 'Notice';
      break;
    case SnackBarType.info:
      icon = Icons.info_outline_rounded;
      accentColor = const Color(0xFF38BDF8);
      defaultTitle = 'Info';
      break;
  }

  final displayTitle = title ?? defaultTitle;

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      duration: duration,
      content: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF0F172A)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: accentColor.withOpacity(0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Icon Pill
            Container(
              padding: EdgeInsets.all(7.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.15),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 20.sp,
              ),
            ),
            AppSpacing.w12,

            // Message text
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayTitle.isNotEmpty)
                    Text(
                      displayTitle,
                      style: GoogleFonts.outfit(
                        color: accentColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (displayTitle.isNotEmpty) AppSpacing.h2,
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // Action or Dismiss Button
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                child: Text(
                  actionLabel,
                  style: GoogleFonts.outfit(
                    color: AppColors.fourth_color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => messenger.hideCurrentSnackBar(),
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 16.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Convenience method to show an API error or validation error SnackBar.
void showErrorSnackBar(BuildContext context, String message, {String? title}) {
  showAppSnackBar(
    context,
    message,
    type: SnackBarType.error,
    title: title,
  );
}

/// Convenience method to show a success SnackBar.
void showSuccessSnackBar(BuildContext context, String message, {String? title}) {
  showAppSnackBar(
    context,
    message,
    type: SnackBarType.success,
    title: title,
  );
}

/// Convenience method to show a warning SnackBar.
void showWarningSnackBar(BuildContext context, String message, {String? title}) {
  showAppSnackBar(
    context,
    message,
    type: SnackBarType.warning,
    title: title,
  );
}

/// Convenience method to show an informational SnackBar.
void showInfoSnackBar(BuildContext context, String message, {String? title}) {
  showAppSnackBar(
    context,
    message,
    type: SnackBarType.info,
    title: title,
  );
}

/// Displays a high-fidelity animated interactive dialog with entrance scaling,
/// backdrop blur, continuous pulsing icon ripple, and tactile interactive buttons.
Future<T?> showInteractiveAnimatedDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
  Color? iconColor,
  String? primaryButtonText = 'OK',
  VoidCallback? onPrimaryPressed,
  Color? primaryButtonColor,
  String? secondaryButtonText,
  VoidCallback? onSecondaryPressed,
  bool barrierDismissible = true,
  Widget? customContent,
  bool isDestructive = false,
}) async {
  if (!context.mounted) return null;

  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return await showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'AnimatedDialog',
    barrierColor: Colors.black.withOpacity(isDarkMode ? 0.70 : 0.45),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curvedValue = Curves.easeOutBack.transform(anim1.value);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 5.0 * anim1.value,
          sigmaY: 5.0 * anim1.value,
        ),
        child: Transform.scale(
          scale: curvedValue.clamp(0.0, 1.05),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: _InteractiveAnimatedDialogWidget<T>(
              title: title,
              message: message,
              icon: icon,
              iconColor: iconColor,
              primaryButtonText: primaryButtonText,
              onPrimaryPressed: onPrimaryPressed,
              primaryButtonColor: primaryButtonColor,
              secondaryButtonText: secondaryButtonText,
              onSecondaryPressed: onSecondaryPressed,
              customContent: customContent,
              isDestructive: isDestructive,
            ),
          ),
        ),
      );
    },
  );
}

class _InteractiveAnimatedDialogWidget<T> extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? iconColor;
  final String? primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final Color? primaryButtonColor;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final Widget? customContent;
  final bool isDestructive;

  const _InteractiveAnimatedDialogWidget({
    required this.title,
    required this.message,
    required this.icon,
    this.iconColor,
    this.primaryButtonText,
    this.onPrimaryPressed,
    this.primaryButtonColor,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.customContent,
    this.isDestructive = false,
  });

  @override
  State<_InteractiveAnimatedDialogWidget<T>> createState() =>
      _InteractiveAnimatedDialogWidgetState<T>();
}

class _InteractiveAnimatedDialogWidgetState<T>
    extends State<_InteractiveAnimatedDialogWidget<T>>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final AnimationController _iconController;
  late final Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _iconScaleAnimation = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );

    _iconController.forward();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final accentColor = widget.iconColor ??
        (widget.isDestructive
            ? AppColors.color_danger
            : const Color(0xFFF5B301));

    final effectivePrimaryColor = widget.primaryButtonColor ??
        (widget.isDestructive
            ? AppColors.color_danger
            : const Color(0xFFF5B301));

    final bgColor = isDarkMode
        ? const Color(0xFF0F172A)
        : Colors.white;

    final titleColor = isDarkMode ? Colors.white : AppColors.l_text_clr;
    final messageColor =
        isDarkMode ? const Color(0xFF94A3B8) : AppColors.heading_color;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320.w,
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: accentColor.withOpacity(isDarkMode ? 0.35 : 0.25),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.65 : 0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              if (isDarkMode)
                BoxShadow(
                  color: accentColor.withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Pulsing Icon Header with Expanding Ripple Rings ---
              SizedBox(
                width: 84.w,
                height: 84.h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ripple 1
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, child) {
                        final progress = _rippleController.value;
                        final scale = 1.0 + (progress * 0.40);
                        final opacity = (1.0 - progress) * 0.40;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 58.r,
                            height: 58.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withOpacity(opacity),
                            ),
                          ),
                        );
                      },
                    ),
                    // Outer Ripple 2
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, child) {
                        final progress = (_rippleController.value + 0.5) % 1.0;
                        final scale = 1.0 + (progress * 0.28);
                        final opacity = (1.0 - progress) * 0.25;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 58.r,
                            height: 58.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withOpacity(opacity),
                            ),
                          ),
                        );
                      },
                    ),
                    // Central Badge Icon
                    ScaleTransition(
                      scale: _iconScaleAnimation,
                      child: Container(
                        width: 56.r,
                        height: 56.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withOpacity(0.18),
                          border: Border.all(
                            color: accentColor.withOpacity(0.55),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          color: accentColor,
                          size: 28.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,

              // --- Title ---
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: titleColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              AppSpacing.h8,

              // --- Message Content (Scroll-safe) ---
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 240.h),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: messageColor,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                    ),
                  ),
                ),
              ),

              if (widget.customContent != null) ...[
                AppSpacing.h12,
                widget.customContent!,
              ],

              AppSpacing.h24,

              // --- Interactive Tactile Action Buttons ---
              if (widget.secondaryButtonText != null)
                Row(
                  children: [
                    Expanded(
                      child: _InteractiveScaleButton(
                        text: widget.secondaryButtonText!,
                        onPressed: () {
                          if (widget.onSecondaryPressed != null) {
                            widget.onSecondaryPressed!();
                          } else {
                            Navigator.of(context, rootNavigator: true).pop(false);
                          }
                        },
                        backgroundColor: isDarkMode
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        textColor: isDarkMode ? Colors.white70 : Colors.black87,
                        border: Border.all(
                          color: isDarkMode ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
                        isOutlined: true,
                      ),
                    ),
                    AppSpacing.w12,
                    Expanded(
                      child: _InteractiveScaleButton(
                        text: widget.primaryButtonText ?? 'OK',
                        onPressed: () {
                          if (widget.onPrimaryPressed != null) {
                            widget.onPrimaryPressed!();
                          } else {
                            Navigator.of(context, rootNavigator: true).pop(true);
                          }
                        },
                        backgroundColor: effectivePrimaryColor,
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                )
              else
                _InteractiveScaleButton(
                  width: double.infinity,
                  text: widget.primaryButtonText ?? 'OK',
                  onPressed: () {
                    if (widget.onPrimaryPressed != null) {
                      widget.onPrimaryPressed!();
                    } else {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                  backgroundColor: effectivePrimaryColor,
                  textColor: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An interactive button widget that reacts dynamically to touch presses
/// with a fluid scale-down spring effect.
class _InteractiveScaleButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Border? border;
  final bool isOutlined;
  final double? width;

  const _InteractiveScaleButton({
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    this.border,
    this.isOutlined = false,
    this.width,
  });

  @override
  State<_InteractiveScaleButton> createState() =>
      _InteractiveScaleButtonState();
}

class _InteractiveScaleButtonState extends State<_InteractiveScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12.r),
            border: widget.border,
            boxShadow: widget.isOutlined
                ? null
                : [
                    BoxShadow(
                      color: widget.backgroundColor.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: GoogleFonts.outfit(
                color: widget.textColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays an animated confirmation dialog with interactive tactile buttons.
Future<bool?> showConfirmationDialog(
  BuildContext context,
  String message, {
  String title = 'Confirmation',
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  IconData? icon,
  Color? iconColor,
  Color? confirmColor,
  bool isDestructive = false,
  bool barrierDismissible = true,
}) async {
  if (!context.mounted) return false;

  final isDanger = isDestructive ||
      title.toLowerCase().contains('delete') ||
      confirmText.toLowerCase().contains('delete') ||
      confirmText.toLowerCase().contains('remove');

  final effectiveIcon = icon ??
      (isDanger
          ? Icons.delete_forever_rounded
          : Icons.help_outline_rounded);

  final effectiveIconColor = iconColor ??
      (isDanger ? AppColors.color_danger : const Color(0xFFF5B301));

  final effectiveConfirmColor = confirmColor ??
      (isDanger ? AppColors.color_danger : const Color(0xFFF5B301));

  final result = await showInteractiveAnimatedDialog<bool>(
    context: context,
    title: title,
    message: message,
    icon: effectiveIcon,
    iconColor: effectiveIconColor,
    isDestructive: isDanger,
    primaryButtonText: confirmText,
    primaryButtonColor: effectiveConfirmColor,
    onPrimaryPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
    secondaryButtonText: cancelText,
    onSecondaryPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
    barrierDismissible: barrierDismissible,
  );

  return result ?? false;
}

/// Backward compatibility & general message dialog: Displays error messages as
/// floating SnackBars by default, or shows an animated interactive dialog if [forceDialog] is true.
Future<void> showMessageDialog(
  BuildContext context,
  String message, {
  String title = 'Error',
  IconData icon = Icons.error_outline_rounded,
  Color iconColor = Colors.red,
  bool forceDialog = false,
  String buttonText = 'OK',
  VoidCallback? onButtonPressed,
}) async {
  if (!forceDialog) {
    if (title.toLowerCase().contains('error') || iconColor == Colors.red) {
      showErrorSnackBar(context, message, title: title);
      return;
    } else if (title.toLowerCase().contains('warn') || iconColor == Colors.orange) {
      showWarningSnackBar(context, message, title: title);
      return;
    }
  }

  if (!context.mounted) return;

  await showInteractiveAnimatedDialog<void>(
    context: context,
    title: title,
    message: message,
    icon: icon,
    iconColor: iconColor,
    primaryButtonText: buttonText,
    primaryButtonColor: iconColor,
    onPrimaryPressed: () {
      if (onButtonPressed != null) {
        onButtonPressed();
      } else {
        Navigator.of(context, rootNavigator: true).pop();
      }
    },
    barrierDismissible: true,
  );
}
