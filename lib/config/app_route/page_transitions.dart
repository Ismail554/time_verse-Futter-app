import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:time_verse/core/theme/theme_background_wrapper.dart';

/// Builds a high-performance 120 FPS page transition using a subtle slide
/// and smooth fade-through with [Curves.easeOutCubic].
///
/// Automatically wraps [child] in [ThemedBackgroundWrapper] so background
/// images remain visually stable without double-compositing or micro-stutters.
CustomTransitionPage<T> buildAppTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 260),
  Duration reverseDuration = const Duration(milliseconds: 220),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: ThemedBackgroundWrapper(child: child),
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      final forwardCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final exitCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0.0), // Sleek 4% horizontal shift
          end: Offset.zero,
        ).animate(forwardCurve),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(forwardCurve),
          child: FadeTransition(
            // Subtle fade for outgoing screen prevents text bleed-through
            opacity: Tween<double>(begin: 1.0, end: 0.94).animate(exitCurve),
            child: pageChild,
          ),
        ),
      );
    },
  );
}

/// Dedicated fade transition for splash, onboarding, and full-screen modals.
CustomTransitionPage<T> buildFadeTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: ThemedBackgroundWrapper(child: child),
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, pageChild) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(
        opacity: curve,
        child: pageChild,
      );
    },
  );
}

