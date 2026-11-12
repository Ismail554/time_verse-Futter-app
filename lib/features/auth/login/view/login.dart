// ignore_for_file: use_build_context_synchronously

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/config/services/notification_permission_service.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/custom_dialogue.dart';
import 'package:time_verse/core/components/custom_input_field.dart';
import 'package:time_verse/core/components/social_action_button.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/core/utils/font_manager.dart';
import 'package:time_verse/features/auth/login/controller/login_controller.dart';
import 'package:time_verse/features/settings/profile/controller/profile_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleServices _googleServices = GoogleServices();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LoginController>().loadRememberedUser();
      _googleServices.init();
    });
  }

  // ===========================================================================
  // AUTHENTICATION LOGIC
  // ===========================================================================

  Future<void> _handleEmailLogin(
    BuildContext context,
    LoginController controller,
  ) async {
    // Dismiss keyboard on submit
    FocusScope.of(context).unfocus();

    final validationError = controller.validateLoginInput();
    if (validationError != null) {
      if (context.mounted) {
        showErrorSnackBar(context, validationError);
      }
      return;
    }

    final success = await controller.loginUser();
    if (!context.mounted) return;

    if (success) {
      if (controller.rememberMe) {
        await AppPrefs.saveRememberMe(
          true,
          controller.emailController.text.trim(),
          controller.passwordController.text.trim(),
        );
      } else {
        await AppPrefs.saveRememberMe(false, '', '');
      }

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
      showErrorSnackBar(
        context,
        controller.loginError ??
            'Invalid email or password. Please try again.',
      );
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    FocusScope.of(context).unfocus();

    final success = await _googleServices.signIn();
    if (!context.mounted) return;

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
      showErrorSnackBar(
        context,
        "Google Sign-In failed. Please try again.",
      );
    }
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final loginController = context.read<LoginController>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final String logoAsset =
        isDarkMode ? ImageAssets.logo : ImageAssets.logoLight;
    final Color secondaryTextColor =
        isDarkMode ? AppColors.fourth_color : AppColors.heading_color;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Tapping anywhere outside text fields dismisses the soft keyboard
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            // Allows dragging down to smoothly dismiss the keyboard
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 16.h),
                  _buildHeader(logoAsset, secondaryTextColor, isDarkMode),
                  SizedBox(height: 24.h),
                  _buildCredentialsCard(
                    context,
                    loginController,
                    isDarkMode,
                  ),
                  SizedBox(height: 20.h),
                  _buildContinueButton(context, loginController),
                  SizedBox(height: 20.h),
                  _buildSocialDivider(),
                  SizedBox(height: 20.h),
                  _buildGoogleSignInButton(context),
                  SizedBox(height: 24.h),
                  _buildSignUpFooter(context, isDarkMode),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI SUB-COMPONENTS
  // ===========================================================================

  /// Header with App Logo, Welcome title, and Subtitle
  Widget _buildHeader(
    String logoAsset,
    Color secondaryTextColor,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Center(
          child: Image.asset(
            logoAsset,
            width: 124.w,
            height: 124.h,
          ),
        ),
        SizedBox(height: 16.h),
        Center(
          child: Text(
            'Welcome Back',
            style: GoogleFonts.playfairDisplay(
              fontSize: 34.sp,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Center(
          child: Text(
            'Sign in to continue organizing amazing activities',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.normal,
              color: isDarkMode
                  ? AppColors.text_color
                  : AppColors.heading_color,
            ),
          ),
        ),
      ],
    );
  }

  /// Credential Form Card with Email, Password, Remember Me, & Forgot Password
  Widget _buildCredentialsCard(
    BuildContext context,
    LoginController loginController,
    bool isDarkMode,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF051123) : AppColors.background_color,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          // ignore: deprecated_member_use
          color: AppColors.fourth_color.withOpacity(0.5),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomInputField(
            label: 'Email Address',
            hintText: 'Enter your email address..',
            controller: loginController.emailController,
            isPassword: false,
            fontSize: 12,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          AppSpacing.h24,
          CustomInputField(
            label: 'Password',
            hintText: 'Enter your password',
            controller: loginController.passwordController,
            isPassword: true,
            fontSize: 12,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                _handleEmailLogin(context, loginController),
          ),
          AppSpacing.h16,
          _buildRememberMeAndForgotPassword(context, isDarkMode),
        ],
      ),
    );
  }

  /// Row with "Remember Me" toggle switch and "Forgot Password?" link
  Widget _buildRememberMeAndForgotPassword(
    BuildContext context,
    bool isDarkMode,
  ) {
    return Consumer<LoginController>(
      builder: (context, controller, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Remember Me Switch & Label
            Row(
              children: [
                SizedBox(
                  height: 24.h,
                  child: Switch(
                    value: controller.rememberMe,
                    onChanged: controller.toggleRememberMe,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.fourth_color,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade700,
                  ),
                ),
                AppSpacing.w8,
                Text(
                  'Remember Me',
                  style: FontManager.outfit(
                    fontSize: 12.sp,
                    color: isDarkMode
                        ? AppColors.text_color
                        : AppColors.heading_color,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),

            // Forgot Password Link
            TextButton(
              onPressed: () => context.push('/forgot_pass'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: FontManager.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                  color: AppColors.third_color,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Main Continue / Sign In Action Button
  Widget _buildContinueButton(
    BuildContext context,
    LoginController loginController,
  ) {
    return Center(
      child: CustomButton(
        text: "Continue",
        loadingText: "Signing in...",
        autoLoading: true,
        loadingColor: Colors.black,
        onPressed: () => _handleEmailLogin(context, loginController),
        gradient: AppGradientColors.button_gradient,
        textColor: Colors.black,
        fontFamily: 'SF Pro',
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        height: 50.h,
        width: double.infinity,
      ),
    );
  }

  /// Elegant Gradient Line Divider with "Or continue with"
  Widget _buildSocialDivider() {
    return Row(
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
        Text(
          'Or continue with',
          style: FontManager.inter(
            color: const Color(0xFF9E9E9E),
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
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
    );
  }

  /// Google Sign-In Action Button
  Widget _buildGoogleSignInButton(BuildContext context) {
    return Center(
      child: SocialAuthButton(
        text: 'Sign in with Google',
        icon: SvgPicture.asset(
          IconAssets.gmail,
          fit: BoxFit.contain,
        ),
        onTap: () => _handleGoogleSignIn(context),
      ),
    );
  }

  /// Bottom Footer Link ("Don't have an account? Sign Up")
  Widget _buildSignUpFooter(BuildContext context, bool isDarkMode) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: FontManager.outfit(
            fontWeight: FontWeight.normal,
            fontSize: 13.sp,
            color: isDarkMode
                ? AppColors.text_color
                : AppColors.heading_color,
            decoration: TextDecoration.none,
          ),
          children: [
            const TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: 'Sign Up',
              style: FontManager.outfit(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppColors.third_color
                    : AppColors.heading_color,
                decoration: TextDecoration.none,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  context.push('/signup');
                },
            ),
          ],
        ),
      ),
    );
  }
}
