// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/custom_dialogue.dart';
import 'package:time_verse/core/components/custom_input_field.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/auth/reset_password/controller/reset_password_controller.dart';

class ResetPassword extends StatelessWidget {
  const ResetPassword({super.key});

  @override
  Widget build(BuildContext context) {
    final resetpasswordController = Provider.of<ResetPasswordController>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final routerState = GoRouterState.of(context);
    final email = Uri.decodeComponent(routerState.uri.queryParameters['email'] ?? '');
    final otp = Uri.decodeComponent(routerState.uri.queryParameters['otp'] ?? '');
    final resetToken = Uri.decodeComponent(routerState.uri.queryParameters['reset_token'] ?? '');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  ImageAssets.forgotPassword,
                  width: 233.w,
                  height: 184.h,
                ),
              ),
              AppSpacing.h5,
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'CREATE NEW PASSWORD',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26.sp, 
                        fontWeight: FontWeight.bold,
                        color: AppColors.fourth_color, 
                        letterSpacing: 0.5,
                      ),
                    ),
                    AppSpacing.h14,
                    Text(
                      'Create a new password (min. 8 characters)\nto secure your account and continue safely.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9EACBA), 
                        height: 1.4, 
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h20,
              Container(
                padding: EdgeInsets.all(24.sp),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.containers_bgd : AppColors.container,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isDarkMode ? AppColors.fourth_color.withValues(alpha: 0.5) : AppColors.new_clr,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    CustomInputField(
                      label: 'New Password *',
                      hintText: 'Enter new password (min 8 chars)...',
                      controller: resetpasswordController.passwordController,
                      isPassword: true,
                      fontSize: 13.sp,
                    ),
                    AppSpacing.h20,
                    CustomInputField(
                      label: 'Confirm Password *',
                      hintText: 'Re-enter your password...',
                      controller: resetpasswordController.confirm_passwordController,
                      isPassword: true,
                      fontSize: 13.sp,
                    ),
                    AppSpacing.h20,
                    Center(
                      child: CustomButton(
                        text: "Continue",
                        loadingText: "Updating Password...",
                        onPressed: () async {
                          final validationError = resetpasswordController.validatePasswordInputs();
                          if (validationError != null) {
                            showErrorSnackBar(context, validationError);
                            return;
                          }

                          final success = await resetpasswordController.resetPassword(
                            email,
                            otp,
                            resetToken: resetToken.isNotEmpty ? resetToken : null,
                          );

                          if (success) {
                            debugPrint("✅ Password reset success confirmed. Navigating to login...");
                            if (!context.mounted) return;
                            showSuccessSnackBar(context, "Password reset successfully. Please log in.");
                            await Future.delayed(const Duration(milliseconds: 800));
                            if (context.mounted) {
                              context.go('/login');
                            }
                          } else {
                            if (!context.mounted) return;
                            showErrorSnackBar(
                              context,
                              resetpasswordController.errorMessage ?? 'Password reset failed.',
                            );
                          }
                        },
                        gradient: AppGradientColors.button_gradient,
                        textColor: Colors.black,
                        fontFamily: 'outfit',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        height: 51.h,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
