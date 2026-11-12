// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/colors.dart';

/// Reusable image uploader component with empty & selected preview states.
/// Aliased as [ImagePickerBox] for complete backward compatibility.
class CustomImageUploader extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? imagePath;
  final File? imageFile;
  final String? imageUrl;
  final String? svgAsset;
  final String title;
  final String subtitle;
  final double width;
  final double? height;
  final bool isLoading;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool enabled;

  const CustomImageUploader({
    super.key,
    required this.onTap,
    this.onRemove,
    this.imagePath,
    this.imageFile,
    this.imageUrl,
    this.svgAsset,
    this.title = 'Add profile Photo',
    this.subtitle = 'Optional • JPG/PNG up to 5MB',
    this.width = double.infinity,
    this.height,
    this.isLoading = false,
    this.borderRadius,
    this.padding,
    this.enabled = true,
  });

  bool get _hasImage {
    if (imageFile != null) return true;
    if (imagePath != null && imagePath!.trim().isNotEmpty) return true;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return true;
    return false;
  }

  File? get _resolvedFile {
    if (imageFile != null) return imageFile;
    if (imagePath != null && imagePath!.trim().isNotEmpty) {
      return File(imagePath!.trim());
    }
    return null;
  }

  String _getFileName(File file) {
    try {
      final segments = file.uri.pathSegments;
      for (int i = segments.length - 1; i >= 0; i--) {
        if (segments[i].trim().isNotEmpty) return segments[i];
      }
      return file.path.split(RegExp(r'[\\/]')).last;
    } catch (_) {
      return 'Selected Photo';
    }
  }

  String _getFileSizeString(File file) {
    try {
      if (!file.existsSync()) return '';
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.third_color;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12.r);
    final double radiusValue = effectiveRadius.topLeft.x;

    return Semantics(
      button: true,
      label: _hasImage ? 'Selected image: $title. Tap to change.' : title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !isLoading ? onTap : null,
          borderRadius: effectiveRadius,
          child: _hasImage
              ? _buildPreviewCard(context, isDark, primaryColor, effectiveRadius)
              : _buildEmptyUploadBox(context, isDark, primaryColor, effectiveRadius, radiusValue),
        ),
      ),
    );
  }

  /// Selected image preview state with thumbnail, file details, and remove/change controls
  Widget _buildPreviewCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    BorderRadius effectiveRadius,
  ) {
    final file = _resolvedFile;
    final fileName = file != null ? _getFileName(file) : 'Selected Photo';
    final fileSize = file != null ? _getFileSizeString(file) : '';

    return Container(
      width: width,
      height: height?.h,
      padding: padding ?? EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.containers_bgd : Colors.white,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: primaryColor.withOpacity(isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              width: 56.w,
              height: 56.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C1B33) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file != null)
                    Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: primaryColor,
                          size: 22.sp,
                        ),
                      ),
                    )
                  else if (imageUrl != null)
                    Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: primaryColor,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  if (isLoading)
                    Container(
                      color: Colors.black45,
                      child: Center(
                        child: SizedBox(
                          width: 18.w,
                          height: 18.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AppSpacing.w12,
          // Image info & Change label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.l_text_clr,
                  ),
                ),
                AppSpacing.h4,
                Row(
                  children: [
                    if (fileSize.isNotEmpty) ...[
                      Text(
                        fileSize,
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '  •  ',
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          color: isDark
                              ? AppColors.secendary_text_color
                              : AppColors.l_text_clr2.withOpacity(0.6),
                        ),
                      ),
                    ],
                    Text(
                      'Tap to change',
                      style: GoogleFonts.outfit(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? AppColors.secendary_text_color
                            : AppColors.l_text_clr2.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove photo',
              splashRadius: 18.r,
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 20.sp,
              ),
              onPressed: onRemove,
            )
          else
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Icon(
                Icons.edit_outlined,
                color: primaryColor,
                size: 20.sp,
              ),
            ),
        ],
      ),
    );
  }

  /// Empty dashed-border upload prompt state
  Widget _buildEmptyUploadBox(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    BorderRadius effectiveRadius,
    double radiusValue,
  ) {
    return DottedBorder(
      options: CustomPathDottedBorderOptions(
        padding: EdgeInsets.zero,
        color: isDark
            ? primaryColor.withOpacity(0.6)
            : primaryColor.withOpacity(0.45),
        strokeWidth: 1.4,
        dashPattern: const [5, 4],
        customPath: (size) => Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, size.width, size.height),
              Radius.circular(radiusValue),
            ),
          ),
      ),
      child: Container(
        width: width,
        height: height?.h,
        padding: padding ?? EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.containers_bgd : Colors.white.withOpacity(0.85),
          borderRadius: effectiveRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 24.w,
                height: 24.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ] else if (svgAsset?.isNotEmpty == true) ...[
              SvgPicture.asset(
                svgAsset!,
                width: 24.w,
                height: 24.h,
                colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
              ),
            ] else ...[
              Icon(
                Icons.camera_alt_outlined,
                size: 24.sp,
                color: primaryColor,
              ),
            ],
            AppSpacing.h8,
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.l_text_clr,
              ),
            ),
            AppSpacing.h4,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? AppColors.secendary_text_color
                    : AppColors.l_text_clr2.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backward compatibility alias so callers using [ImagePickerBox] work out-of-the-box.
typedef ImagePickerBox = CustomImageUploader;
