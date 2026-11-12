// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/core/utils/validators.dart';
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

  /// Validates all signup input fields and returns a specific, user-friendly error message
  /// if any field fails validation, or null if all fields are valid.
  String? validateSignupInput({required bool isTermsAgreed}) {
    final termsError = Validators.validateTerms(isTermsAgreed);
    if (termsError != null) return termsError;

    final firstNameError = Validators.validateName(
      firstNameController.text,
      fieldName: 'first name',
    );
    if (firstNameError != null) return firstNameError;

    final surnameError = Validators.validateName(
      surnameController.text,
      fieldName: 'surname',
    );
    if (surnameError != null) return surnameError;

    final emailError = Validators.validateEmail(emailController.text);
    if (emailError != null) return emailError;

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

  bool validateSignupFields() {
    return validateSignupInput(isTermsAgreed: true) == null;
  }

  String? pickedImagePath;

  Future<void> pickImage({int maxSizeInMB = 5}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        final file = File(picked.path);
        if (await file.exists()) {
          final bytes = await file.length();
          if (bytes > maxSizeInMB * 1024 * 1024) {
            signupError = 'Image exceeds ${maxSizeInMB}MB limit. Please choose a smaller photo.';
            notifyListeners();
            return;
          }
        }
        pickedImagePath = picked.path;
        signupError = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error picking image: $e');
    }
  }

  void clearImage() {
    pickedImagePath = null;
    notifyListeners();
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

      // If token wasn't already stored during signup, perform fallback login
      final hasToken = await _authService.getToken();
      if (hasToken == null || hasToken.isEmpty) {
        final email = emailController.text.trim();
        final password = passwordController.text.trim();
        final loginResponse = await _authService.login(email, password);
        if (loginResponse['success'] != true) {
          debugPrint("Auto-login fallback note: ${loginResponse['error']}");
        }
      }

      await AppPrefs.setLoggedIn(true);
      await AppPrefs.setFirstLaunch(false);
      await AppPrefs.setGoogleLogin(false);
      await GoogleServices().signOut();

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
