/// Centralized input validation rules for authentication and forms across the app.
class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
  );

  /// Validates an email address format and non-emptiness.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed) || !trimmed.contains('.')) {
      return 'Please enter a valid email address (e.g. name@example.com).';
    }
    return null;
  }

  /// Validates a first name or surname.
  static String? validateName(String? value, {String fieldName = 'name'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName.';
    }
    if (value.trim().length < 2) {
      return '${fieldName[0].toUpperCase()}${fieldName.substring(1)} must be at least 2 characters long.';
    }
    return null;
  }

  /// Validates a password with minimum length (Backend requires min 8 characters).
  static String? validatePassword(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters long.';
    }
    return null;
  }

  /// Validates confirmation password against the original password.
  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match. Please verify your password.';
    }
    return null;
  }

  /// Validates acceptance of Terms & Conditions and Privacy Policy.
  static String? validateTerms(bool isAgreed) {
    if (!isAgreed) {
      return 'Please agree to the Terms & Conditions and Privacy Policy to proceed.';
    }
    return null;
  }
}
