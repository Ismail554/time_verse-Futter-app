// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:time_verse/core/utils/validators.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class ResetPasswordController extends ChangeNotifier {
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirm_passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? errorMessage;

  void disposeControllers() {
    passwordController.dispose();
    confirm_passwordController.dispose();
  }

  bool areFieldsFilled(List<TextEditingController> controllers) {
    for (final controller in controllers) {
      if (controller.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  bool validateLoginFields() {
    return areFieldsFilled([passwordController, confirm_passwordController]);
  }

  String? validatePasswordInputs() {
    final passwordError = Validators.validatePassword(
      passwordController.text,
      minLength: 8,
    );
    if (passwordError != null) return passwordError;

    final confirmError = Validators.validateConfirmPassword(
      passwordController.text,
      confirm_passwordController.text,
    );
    if (confirmError != null) return confirmError;

    return null;
  }

  Future<bool> resetPassword(
    String email,
    String otp, {
    String? resetToken,
  }) async {
    try {
      final response = await _authService.resetPassword(
        email,
        otp,
        passwordController.text.trim(),
        resetToken: resetToken,
      );

      debugPrint("Reset password response: $response");

      if (response['success'] == true) {
        errorMessage = null;
        return true;
      } else {
        errorMessage = response['error'] ?? response['message'] ?? 'Reset failed';
        return false;
      }
    } catch (e) {
      debugPrint("Reset password exception: $e");
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    }
  }
}
