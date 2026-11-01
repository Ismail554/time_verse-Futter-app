// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class SignupController extends ChangeNotifier {
  TextEditingController firstNameController = TextEditingController();
  TextEditingController surnameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirm_passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  String? signupError;
  String? selectedgender;
  String? selectedNationality;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void disposeControllers() {
    emailController.dispose();
    firstNameController.dispose();
    surnameController.dispose();
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

  bool validateSignupFields() {
    return areFieldsFilled([
      emailController,
      firstNameController,
      passwordController,
      confirm_passwordController,
    ]);
  }

  String? pickedImagePath;

  void pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      pickedImagePath = picked.path;
      notifyListeners();
    }
  }

  void updateGender(String? value) {
    selectedgender = value;
    notifyListeners();
  }

  void updateNationality(String? value) {
    selectedNationality = value;
    notifyListeners();
  }

  Future<bool> signupUser() async {
    try {
      final response = await _authService.signup(
        emailController.text.trim(),
        passwordController.text.trim(),
        firstNameController.text.trim(),
        surnameController.text.trim(),
        selectedgender ?? '',
        selectedNationality ?? '',
        profileImagePath: pickedImagePath,
      );

      debugPrint("Signup response: $response");

      if (response['success'] == true) {
        signupError = null;

        final token = response['data']?['access'];
        if (token != null) {
          debugPrint('Signup Access Token: $token');
        }

        return true;
      } else {
        final error = response['error'] ?? response['message'];
        signupError = (error != null ? error.toString() : 'Signup failed');
        debugPrint("Signup error: $signupError");
        return false;
      }
    } catch (e) {
      debugPrint("Signup exception: $e");
      signupError = 'Something went wrong. Please try again.';
      return false;
    }
  }

  /// Registers the account and automatically logs the user in, saving tokens and session.
  Future<bool> signupAndAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await signupUser();
      if (!success) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // Automatically sign in with the newly registered user
      final loginResponse = await _authService.login(email, password);
      if (loginResponse['success'] == true) {
        await AppPrefs.setLoggedIn(true);
        await AppPrefs.setFirstLaunch(false);
        await AppPrefs.setGoogleLogin(false);
        await GoogleServices().signOut();
      } else {
        debugPrint("Auto-login note: ${loginResponse['error']}");
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Signup & auto-login exception: $e");
      signupError = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
