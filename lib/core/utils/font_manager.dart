import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class FontManager {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
      );

  static TextStyle heading1({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 28.sp,
    fontWeight: FontWeight.bold,
    color: color,
  );

  static TextStyle heading2({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 22.sp,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle heading3({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 18.sp,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle bodyLarge({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 16.sp,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle bodyMedium({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 14.sp,
    fontWeight: FontWeight.normal,
    color: color,
  );

  static TextStyle bodySmall({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 12.sp,
    fontWeight: FontWeight.normal,
    color: color,
  );

  static TextStyle buttonText({Color? color, double? fontSize}) => GoogleFonts.inter(
    fontSize: fontSize ?? 16.sp,
    fontWeight: FontWeight.w600,
    color: color,
  );
}
