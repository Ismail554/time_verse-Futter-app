// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/custom_dialogue.dart';
import 'package:time_verse/core/components/custom_otp_field.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/auth/otp/controller/otp_controller.dart';

class OtpView extends StatelessWidget {
  const OtpView({super.key});

  @override
  Widget build(BuildContext context) {
    final otpController = Provider.of<OtpController>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      otpController.startTimer();
    });
    
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
                  width: 219.w,
                  height: 219.h,
                ),
              ),
              AppSpacing.h5,
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'VERIFICATION CODE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26.sp, 
                        fontWeight: FontWeight.bold,
                        color: AppColors.fourth_color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    AppSpacing.h12, 
                    Text(
                      'We have sent a 6-digit OTP code\nto your email address',
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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.containers_bgd
                      : AppColors.container,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isDarkMode
                        ? AppColors.fourth_color
                        : AppColors.new_clr,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    CircularOtpField(
                      numberOfFields: 6,
                      mainController: otpController.otpController,
                      onSubmit: (code) {
                        debugPrint('OTP entered: $code');
                      },
                    ),
                    AppSpacing.h24,
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? AppColors.text_color.withOpacity(0.3)
                                : AppColors.heading_color.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Consumer<OtpController>(
                            builder: (context, controller, _) {
                              return Text(
                                controller.formattedTime,
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.sp,
                                  color: const Color(0xFFF29F0D),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDarkMode
                                ? AppColors.text_color.withOpacity(0.3)
                                : AppColors.heading_color.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h24,
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF29F0D).withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CustomButton(
                          text: "Recover Account",
                          loadingText: "Verifying...",
                          autoLoading: true,
                          loadingColor: Colors.black,
                          onPressed: () async {
                            final email = Uri.decodeComponent(
                              GoRouterState.of(
                                context,
                              ).uri.queryParameters['email'] ??
                              '',
                            );
                            final controller = Provider.of<OtpController>(
                              context,
                              listen: false,
                            );
                            final otp = controller.otpController.text
                                .replaceAll(RegExp(r'\s+'), '');
                            debugPrint("Entered OTP: $otp");

                            if (otp.length != 6) {
                              if (context.mounted) {
                                showErrorSnackBar(
                                  context,
                                  'Please enter a valid 6-digit verification code.',
                                );
                              }
                              return;
                            }
                            final isVerified = await controller.verifyOtpUser(
                              email,
                              otp,
                            );
                            if (isVerified) {
                              final encodedEmail = Uri.encodeComponent(email);
                              final encodedOtp = Uri.encodeComponent(otp);
                              final encodedToken = Uri.encodeComponent(controller.resetToken ?? '');
                              if (context.mounted) {
                                showSuccessSnackBar(context, 'OTP verified successfully');
                                context.push(
                                  '/reset_password?email=$encodedEmail&otp=$encodedOtp&reset_token=$encodedToken',
                                );
                              }
                            } else {
                              if (context.mounted) {
                                showErrorSnackBar(
                                  context,
                                  controller.otpError ??
                                      'OTP verification failed. Please try again.',
                                );
                              }
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
                    ),
                  ],
                ),
              ),
              AppSpacing.h40,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w500,
                        fontSize: 16.sp,
                        color: isDarkMode
                          ? AppColors.text_color
                          : const Color(0xFFC2C2C2),
                      ),
                      children: [
                        const TextSpan(text: "Didn't receive OTP code? "),
                        TextSpan(
                          text: 'Resend',
                          style: GoogleFonts.outfit(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fourth_color,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.fourth_color,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = () async {
                            final email = Uri.decodeComponent(
                              GoRouterState.of(context).uri.queryParameters['email'] ?? '',
                            );
                            if (email.trim().isEmpty) {
                              showErrorSnackBar(context, 'Email not found. Please try again.');
                              return;
                            }
                            final success = await otpController.resendOtp(email.trim());
                            if (context.mounted) {
                              if (success) {
                                showSuccessSnackBar(context, 'A new verification code has been dispatched.');
                              } else {
                                showErrorSnackBar(
                                  context,
                                  otpController.otpError ?? 'Failed to resend code.',
                                );
                              }
                            }
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
      ),
    );
  }
}
