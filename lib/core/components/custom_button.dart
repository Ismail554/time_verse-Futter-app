// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/utils/app_spacing.dart';

/// An interactive, high-performance button optimized for API requests,
/// form submissions, and event triggers.
///
/// Features:
/// - Built-in [isLoading] spinner with optional [loadingText].
/// - Tap debouncing to eliminate duplicate API calls from double-tapping.
/// - Tactile micro-scale animation and light haptic feedback on press.
/// - Async [onPressed] support with automatic loading state if [autoLoading] is enabled.
/// - Full backward compatibility with all styling properties (gradients, borders, icons).
class CustomButton extends StatefulWidget {
  final String text;
  final FutureOr<void> Function()? onPressed;

  // Loading & State
  final bool isLoading;
  final String? loadingText;
  final Color? loadingColor;
  final bool isDisabled;
  final bool autoLoading;
  final bool enableDebounce;
  final Duration debounceDuration;
  final bool enableHaptics;
  final bool enableScaleAnimation;

  // Button Dimensions & Layout
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  // Typography & Colors
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? textColor;
  final Color? solidColor;
  final LinearGradient? gradient;
  final FontStyle? fontStyle;
  final String? fontFamily;
  final Color? borderColor;
  final LinearGradient? borderGradient;

  // Icons
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.loadingText,
    this.loadingColor,
    this.isDisabled = false,
    this.autoLoading = false,
    this.enableDebounce = true,
    this.debounceDuration = const Duration(milliseconds: 600),
    this.enableHaptics = true,
    this.enableScaleAnimation = true,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.fontSize,
    this.fontWeight,
    this.textColor,
    this.solidColor,
    this.gradient,
    this.padding,
    this.fontStyle,
    this.fontFamily,
    this.borderColor,
    this.borderGradient,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;
  bool _internalLoading = false;
  DateTime? _lastTapTime;

  bool get _effectiveLoading => widget.isLoading || _internalLoading;
  bool get _isClickable =>
      !widget.isDisabled && !_effectiveLoading && widget.onPressed != null;

  void _handleTapDown(TapDownDetails details) {
    if (!_isClickable) return;
    if (widget.enableScaleAnimation) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  Future<void> _handleTap() async {
    if (!_isClickable) return;

    // 1. Debounce rapid double-taps
    if (widget.enableDebounce) {
      final now = DateTime.now();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < widget.debounceDuration) {
        return;
      }
      _lastTapTime = now;
    }

    // 2. Light tactile haptic feedback
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }

    // 3. Execute action (with automatic loading if enabled)
    if (widget.autoLoading) {
      setState(() => _internalLoading = true);
      try {
        final result = widget.onPressed!();
        if (result is Future) {
          await result;
        }
      } finally {
        if (mounted) {
          setState(() => _internalLoading = false);
        }
      }
    } else {
      widget.onPressed!();
    }
  }

  TextStyle _buildTextStyle() {
    final baseStyle = TextStyle(
      fontSize: widget.fontSize ?? 14.sp,
      fontWeight: widget.fontWeight ?? FontWeight.w500,
      color: widget.textColor ?? Colors.white,
      fontStyle: widget.fontStyle ?? FontStyle.normal,
    );

    switch (widget.fontFamily?.toLowerCase()) {
      case 'poppins':
        return GoogleFonts.poppins(textStyle: baseStyle);
      case 'outfit':
        return GoogleFonts.outfit(textStyle: baseStyle);
      case 'lato':
        return GoogleFonts.lato(textStyle: baseStyle);
      case 'roboto':
        return GoogleFonts.roboto(textStyle: baseStyle);
      case 'montserrat':
        return GoogleFonts.montserrat(textStyle: baseStyle);
      case 'nunito':
        return GoogleFonts.nunito(textStyle: baseStyle);
      case 'inter':
      default:
        return GoogleFonts.inter(textStyle: baseStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGradient = widget.gradient != null;
    final loadingColor =
        widget.loadingColor ?? widget.textColor ?? Colors.white;

    final buttonCore = Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 48.h,
      padding: widget.padding ?? EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: hasGradient ? widget.gradient : null,
        color: hasGradient
            ? null
            : (widget.solidColor ?? Theme.of(context).primaryColor),
        border: widget.borderGradient == null && widget.borderColor != null
            ? Border.all(color: widget.borderColor!, width: 1)
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _effectiveLoading
            ? _buildLoadingContent(loadingColor)
            : _buildIdleContent(),
      ),
    );

    Widget content = widget.borderGradient != null
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: widget.borderGradient,
            ),
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: buttonCore,
            ),
          )
        : buttonCore;

    // Disabled styling dim
    if (widget.isDisabled) {
      content = Opacity(
        opacity: 0.55,
        child: content,
      );
    }

    // Micro-scale press interaction
    if (widget.enableScaleAnimation) {
      content = AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: content,
      );
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildLoadingContent(Color color) {
    final spinner = SizedBox(
      width: (widget.fontSize != null ? widget.fontSize! * 1.15 : 18.sp).clamp(14.0, 24.0),
      height: (widget.fontSize != null ? widget.fontSize! * 1.15 : 18.sp).clamp(14.0, 24.0),
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );

    if (widget.loadingText != null && widget.loadingText!.isNotEmpty) {
      return Row(
        key: const ValueKey('loading_with_text'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          spinner,
          AppSpacing.w10,
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.loadingText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _buildTextStyle(),
              ),
            ),
          ),
        ],
      );
    }

    return KeyedSubtree(
      key: const ValueKey('loading_spinner'),
      child: spinner,
    );
  }

  Widget _buildIdleContent() {
    return Row(
      key: const ValueKey('idle_content'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          widget.leadingIcon!,
          AppSpacing.w8,
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _buildTextStyle(),
            ),
          ),
        ),
        if (widget.trailingIcon != null) ...[
          AppSpacing.w8,
          widget.trailingIcon!,
        ],
      ],
    );
  }
}
