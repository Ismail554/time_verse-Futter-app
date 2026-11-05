import 'package:flutter/material.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/core/utils/validators.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class LoginController extends ChangeNotifier {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  String? loginError;

  void disposeControllers() {
    emailController.dispose();
    passwordController.dispose();
  }

  bool rememberMe = false;

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  bool areFieldsFilled(List<TextEditingController> controllers) {
    for (var controller in controllers) {
      if (controller.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Returns a specific error message if email or password is invalid, or null if valid.
  String? validateLoginInput() {
    final emailError = Validators.validateEmail(emailController.text);
    if (emailError != null) return emailError;

    if (passwordController.text.trim().isEmpty) {
      return 'Please enter your password.';
    }
    return null;
  }

  bool validateLoginFields() {
    return validateLoginInput() == null;
  }

  Future<bool> loginUser() async {
    try {
      final response = await _authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (response['success'] == true) {
        loginError = null;

        await AppPrefs.setLoggedIn(true);
        await AppPrefs.setGoogleLogin(false);

        // Clear active Google session so silent requests don't trigger popups
        await GoogleServices().signOut();
        await AppPrefs.saveRememberMe(
          rememberMe,
          emailController.text.trim(),
        );

        return true;
      } else {
        loginError = response['error'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      debugPrint("Login error: $e");
      loginError = 'Something went wrong. Please try again.';
      return false;
    }
  }

  Future<void> loadRememberedUser() async {
    final data = await AppPrefs.getRememberedUser();

    if (data['remember'] == true) {
      emailController.text = data['email'] ?? '';
      rememberMe = true;
    }

    notifyListeners();
  }
}
