import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Font & Typography Manager for InfiniQuote / TimeVerse.
/// Provides standardized styles and preloads all required typefaces
/// to eliminate font flicker / layout shift on initial application launch.
class FontManager {
  FontManager._();

  // -------------------------------------------------------------
  // FONT PRELOADER
  // -------------------------------------------------------------

  /// Asynchronously preloads all core application fonts and font-weights
  /// into memory before the first frame is rendered to prevent text flickering.
  static Future<void> preloadFonts() async {
    try {
      await GoogleFonts.pendingFonts([
        // Outfit - Primary application UI font (regular, medium, semi-bold, bold)
        GoogleFonts.outfit(fontWeight: FontWeight.w400),
        GoogleFonts.outfit(fontWeight: FontWeight.w500),
        GoogleFonts.outfit(fontWeight: FontWeight.w600),
        GoogleFonts.outfit(fontWeight: FontWeight.w700),
        GoogleFonts.outfit(fontWeight: FontWeight.bold),

        // Playfair Display - Premium headers and display titles
        GoogleFonts.playfairDisplay(fontWeight: FontWeight.w400),
        GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),

        // Inter - Secondary UI, alarms, bottom nav, dialogs
        GoogleFonts.inter(fontWeight: FontWeight.w400),
        GoogleFonts.inter(fontWeight: FontWeight.w500),
        GoogleFonts.inter(fontWeight: FontWeight.w600),
        GoogleFonts.inter(fontWeight: FontWeight.bold),

        // Poppins - Welcome screens, buttons, auth headers
        GoogleFonts.poppins(fontWeight: FontWeight.w400),
        GoogleFonts.poppins(fontWeight: FontWeight.w500),
        GoogleFonts.poppins(fontWeight: FontWeight.w600),
        GoogleFonts.poppins(fontWeight: FontWeight.w700),

        // Lora & Cormorant - Quotes, Reflections, Alarm subtitles
        GoogleFonts.lora(fontWeight: FontWeight.w400),
        GoogleFonts.lora(fontWeight: FontWeight.w500),
        GoogleFonts.lora(fontWeight: FontWeight.w600),
        GoogleFonts.cormorant(fontWeight: FontWeight.w400),
        GoogleFonts.cormorant(fontWeight: FontWeight.w600),
        GoogleFonts.cormorant(fontWeight: FontWeight.bold),

        // Manrope - Category items and details
        GoogleFonts.manrope(fontWeight: FontWeight.w400),
        GoogleFonts.manrope(fontWeight: FontWeight.w500),
        GoogleFonts.manrope(fontWeight: FontWeight.w600),

        // Supporting fonts used in buttons and components
        GoogleFonts.roboto(fontWeight: FontWeight.w400),
        GoogleFonts.roboto(fontWeight: FontWeight.w500),
        GoogleFonts.montserrat(fontWeight: FontWeight.w400),
        GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        GoogleFonts.lato(fontWeight: FontWeight.w400),
        GoogleFonts.nunito(fontWeight: FontWeight.w400),
      ]);
      debugPrint('✅ [FontManager] Primary fonts preloaded successfully');
    } catch (e) {
      debugPrint('⚠️ [FontManager] Font preloading warning: $e');
    }
  }

  // -------------------------------------------------------------
  // CENTRALIZED FONT GENERATORS
  // -------------------------------------------------------------

  static TextStyle outfit({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static TextStyle playfairDisplay({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static TextStyle lora({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.lora(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static TextStyle cormorant({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.cormorant(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  static TextStyle manrope({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
      );

  // -------------------------------------------------------------
  // TYPOGRAPHY PRESETS
  // -------------------------------------------------------------

  static TextStyle heading1({Color? color, double? fontSize}) =>
      playfairDisplay(
        fontSize: fontSize ?? 28.sp,
        fontWeight: FontWeight.bold,
        color: color,
      );

  static TextStyle heading2({Color? color, double? fontSize}) =>
      playfairDisplay(
        fontSize: fontSize ?? 22.sp,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle heading3({Color? color, double? fontSize}) =>
      outfit(
        fontSize: fontSize ?? 18.sp,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle bodyLarge({Color? color, double? fontSize}) =>
      outfit(
        fontSize: fontSize ?? 16.sp,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle bodyMedium({Color? color, double? fontSize}) =>
      outfit(
        fontSize: fontSize ?? 14.sp,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle bodySmall({Color? color, double? fontSize}) =>
      outfit(
        fontSize: fontSize ?? 12.sp,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle buttonText({Color? color, double? fontSize}) =>
      outfit(
        fontSize: fontSize ?? 16.sp,
        fontWeight: FontWeight.w600,
        color: color,
      );
}
