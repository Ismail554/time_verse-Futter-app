import 'package:flutter/material.dart';
import 'package:time_verse/core/utils/asset_manager.dart';

/// High-performance background wrapper that renders the themed wallpaper
/// isolated inside a [RepaintBoundary] with [gaplessPlayback] enabled.
/// This prevents CPU/GPU repainting of the full-screen image when page contents
/// animate, scroll, or update.
class ThemedBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const ThemedBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String backgroundAsset =
        isDarkMode ? ImageAssets.bgDark5 : ImageAssets.bgLight;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. Isolated Background Image (Paints once to GPU layer)
        Positioned.fill(
          child: RepaintBoundary(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),

        // 2. Isolated Content Layer
        Positioned.fill(
          child: RepaintBoundary(
            child: child,
          ),
        ),
      ],
    );
  }
}
