import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/prograss_bar.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    context.push('/login').then((_) {
      if (mounted) {
        _isNavigating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String logoAsset =
        isDarkMode ? ImageAssets.logo : ImageAssets.logoLight;

    final Color primaryTextColor = AppColors.getDynamicTextColor(context);
    final Color secondaryTextColor =
        isDarkMode ? AppColors.text_color : AppColors.l_text_clr;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        // Catch upward pointer moves before any inner scroll physics consumes them
        onPointerMove: (event) {
          if (event.delta.dy < -14) {
            _navigateToLogin();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -80) {
              _navigateToLogin();
            }
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Column(
                children: [
                  Center(
                    child: Image.asset(
                      logoAsset,
                      width: 268.w,
                      height: 263.h,
                    ),
                  ),
                  AppSpacing.h20,
                  Text(
                    'Welcome to',
                    style: GoogleFonts.playfair(
                      fontSize: 27.sp,
                      fontWeight: FontWeight.normal,
                      color: primaryTextColor,
                    ),
                  ),
                  AppSpacing.h10,
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.playfair(
                        fontWeight: FontWeight.bold,
                        fontSize: 52.sp,
                      ),
                      children: [
                        TextSpan(
                          text: 'Infini',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                        const TextSpan(
                          text: 'Quote',
                          style: TextStyle(
                            color: Color(0xFFE19B00),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h10,
                  Text(
                    'Guiding your daily journey with calm, clarity, and intention.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.normal,
                      fontSize: 15.3.sp,
                      color: AppColors.text_color,
                    ),
                  ),
                  AppSpacing.h20,
                  CustomButton(
                    text: "Start Your Journey",
                    onPressed: () {
                      context.push('/signup');
                    },
                    gradient: AppGradientColors.button_gradient,
                    textColor: const Color(0xFF000000),
                    fontFamily: 'inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    height: 48.h,
                    width: 219.48.w,
                  ),
                  AppSpacing.h80,
                  SizedBox(
                    width: 142.w,
                    child: const ProgressIndicatorWidget(
                      barHeight: 4,
                      percentage: 100,
                      progressColor: AppColors.third_color,
                    ),
                  ),
                  AppSpacing.h20,

                  // Fully functional interactive "Swipe up to dismiss" section
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _navigateToLogin,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < 0) {
                        _navigateToLogin();
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _bounceAnimation.value),
                          child: child,
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              IconAssets.swipeUp,
                              width: 24.w,
                              height: 24.h,
                            ),
                            AppSpacing.h8,
                            Text(
                              'Swipe up to dismiss',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.normal,
                                color: AppColors.secendary_text_color,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
