// ignore_for_file: deprecated_member_use

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

/// Displays an alert confirmation dialog with Cancel and Confirm buttons.
Future<bool?> showConfirmationDialog(
  BuildContext context,
  String message, {
  String title = 'Confirmation',
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
}) async {
  if (!context.mounted) return false;
  return await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

/// Backward compatibility: Displays error messages as floating SnackBars by default,
/// or shows an AlertDialog if [forceDialog] is true.
Future<void> showMessageDialog(
  BuildContext context,
  String message, {
  String title = 'Error',
  IconData icon = Icons.error_outline,
  Color iconColor = Colors.red,
  bool forceDialog = false,
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

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            AppSpacing.w8,
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: SingleChildScrollView(
            child: SelectableText(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
