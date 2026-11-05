// ignore_for_file: use_build_context_synchronously, duplicate_ignore, deprecated_member_use

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/custom_dialogue.dart';
import 'package:time_verse/core/components/custom_input_field.dart';
import 'package:time_verse/core/components/social_action_button.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/auth/login/controller/login_controller.dart';
import 'package:time_verse/features/settings/profile/controller/profile_controller.dart';
import 'package:time_verse/config/services/notification_permission_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final googleServices = GoogleServices();
    final loginController = Provider.of<LoginController>(context, listen: false);
    loginController.loadRememberedUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      googleServices.init();
    });
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String logoAsset = isDarkMode
      ? ImageAssets.logo 
      : ImageAssets.logoLight;
    final Color secondaryTextColor = isDarkMode 
      ? AppColors.fourth_color 
      : AppColors.heading_color;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body:Padding(
        padding: EdgeInsets.symmetric(horizontal: 24,vertical: 40),
        child: SingleChildScrollView(
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  logoAsset,
                  width:124.w,
                  height: 124.h,
                ),
              ),
              AppSpacing.h20,
              Center(
                child: Text(
                  'Welcome Back',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor    ,
                  ),
                ),
              ),
              AppSpacing.h20,
              Center(
                child: Text(
                  'Sign in to continue organizing amazing activities',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15.3.sp,
                    fontWeight: FontWeight.normal,
                    color: isDarkMode?AppColors.text_color: AppColors.heading_color    ,
                  ),
                ),
              ),
              AppSpacing.h20,
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF051123): AppColors.background_color,
                  borderRadius: BorderRadius.circular(12.r),
                  // ignore: deprecated_member_use
                  border: Border.all(color: AppColors.fourth_color.withOpacity(0.5), width: 1.w),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomInputField(
                      label: 'Email Address', // Removed the '*' to match image
                      hintText: 'Enter your email address..',
                      controller: loginController.emailController,
                      isPassword: false,
                      fontSize: 12,
                    ),
                    AppSpacing.h30,
                    CustomInputField(
                      label: 'Password', // Removed the '*' to match image
                      hintText: 'Enter your password',
                      controller: loginController.passwordController,
                      isPassword: true,
                      fontSize: 12,
                    ),
                    AppSpacing.h20,
                    Consumer<LoginController>(
                      builder: (context, controller, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left Group: Switch + Label text
                          Row(
                            children: [
                              SizedBox(
                                height: 24.h,
                                child: Switch(
                                  value: controller.rememberMe,
                                  onChanged: controller.toggleRememberMe,
                                  activeColor: Colors.white,
                                  activeTrackColor: Colors.orange, // Use AppColors.third_color if it's the orange tone
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: Colors.grey.shade700,
                                ),
                              ),
                              AppSpacing.w8,
                              Text(
                                'Remember Me',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.sp,
                                  color:Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.text_color
                                    : AppColors.heading_color,
                                ),
                              ),
                            ],
                          ),
                          // Right Group: Forgot Password button
                          TextButton(
                            onPressed: () {
                              context.push('/forgot_pass');
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                                color: Colors.red, // Use your orange color variable here
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h20,
              Center(
                child: CustomButton(
                  text: "Continue",
                  loadingText: "Signing in...",
                  autoLoading: true,
                  loadingColor: Colors.black,
                  onPressed: () async {
                    // Improved specific input validation
                    final validationError = loginController.validateLoginInput();
                    if (validationError != null) {
                      if (context.mounted) {
                        showErrorSnackBar(context, validationError);
                      }
                      return;
                    }

                    final success = await loginController.loginUser();
                    if (success) {
                      if (loginController.rememberMe) {
                        await AppPrefs.saveRememberMe(
                          true,
                          loginController.emailController.text.trim(),
                          loginController.passwordController.text.trim(),
                        );
                      } else {
                        await AppPrefs.saveRememberMe(false, '', '');
                      }
                      await AppPrefs.setLoggedIn(true);
                      await AppPrefs.setFirstLaunch(false);
                      await context.read<ProfileController>().loadUserProfile();
                      await NotificationPermissionService.ensurePermissionAfterLogin();
                      if (context.mounted) {
                        context.go('/home');
                      }
                    } else {
                      if (context.mounted) {
                        showErrorSnackBar(
                          context,
                          loginController.loginError ?? 'Invalid email or password. Please try again.',
                        );
                      }
                    }
                  },
                  gradient: AppGradientColors.button_gradient,
                  textColor: Colors.black,
                  fontFamily: 'SF Pro',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  height: 51.h,
                  width: double.infinity,
                ),
              ),
              AppSpacing.h20,
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: EdgeInsets.only(right: 12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.65),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  // Center Text
                  Text(
                    'Or continue with',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Right divider line
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: EdgeInsets.only(left: 12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.55),
                            Colors.white.withOpacity(0.0),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.h30,
              Center(
                child: SocialAuthButton(
                  text: 'Sign in with Google',
                  icon: SvgPicture.asset(
                    IconAssets.gmail,
                    fit: BoxFit.contain,
                  ),
                  onTap: () async {
                    final success = await googleServices.signIn();
                    if (success) {
                      await AppPrefs.setLoggedIn(true);
                      await AppPrefs.setFirstLaunch(false);

                      if (context.mounted) {
                        await context.read<ProfileController>().loadUserProfile();
                      }
                      await NotificationPermissionService.ensurePermissionAfterLogin();

                      if (context.mounted) {
                        context.go('/home');
                      }
                    } else {
                      if (context.mounted) {
                        showErrorSnackBar(
                          context,
                          "Google Sign-In failed. Please try again.",
                        );
                      }
                    }
                  },
                ),
              ),
              AppSpacing.h40,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.normal,
                        fontSize: 13.sp,
                        color: isDarkMode
                          ? AppColors.text_color
                          : AppColors.heading_color,
                        ),
                        children: [
                        const TextSpan(text: 'Don\'t have an account? '),
                        TextSpan(
                          text: 'Sign Up',
                          style: GoogleFonts.outfit(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.normal,
                            color: isDarkMode? AppColors.third_color: AppColors.heading_color,
                            ),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            context.push('/signup');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ) ,
    );
  }
}