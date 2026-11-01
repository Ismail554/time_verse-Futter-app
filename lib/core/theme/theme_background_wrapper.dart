import 'package:flutter/material.dart';
import 'package:time_verse/core/utils/asset_manager.dart';

class ThemedBackgroundWrapper extends StatelessWidget {
  final Widget child;
  const ThemedBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    //!-------- Check current brightness -------------!
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String backgroundAsset = isDarkMode
        ? ImageAssets.bgDark5 
        : ImageAssets.bgLight;

    return Stack(
      children: <Widget>[
        //!-------- 1. Background Image ---------
        Positioned.fill(
          child: Image.asset(
            backgroundAsset,
            fit: BoxFit.cover, 
          ),
        ),

        //!-------- 2. FIXED: Bottom Solid Background Accent Layer ---------
        // Align(
        //   alignment: Alignment.bottomCenter,
        //   child: Container(
        //     color: isDarkMode ? const Color(0xFF060B13) : null,
        //     height: 100.h,
        //     width: double.infinity,
        //   ),
        // ),

        //!------------ 3. Scaffold Body Content Layer --------------!
        child,
      ],
    );
  }
}