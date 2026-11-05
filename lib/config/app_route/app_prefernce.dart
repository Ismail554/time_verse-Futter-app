import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const _isLoggedInKey = 'is_logged_in';
  static const _isFirstLaunchKey = 'is_first_launch';
  static const _rememberMeKey = 'remember_me';
  static const _savedEmailKey = 'saved_email';
  static const _savedPasswordKey = 'saved_password';
  static const _isGoogleLoginKey = 'is_google_login';

  static const _googleUserNameKey = 'google_user_name';
  static const _googleUserEmailKey = 'google_user_email';
  static const _googleUserPhotoKey = 'google_user_photo';

  static const String _keyLastMoodTrackerDate = 'last_mood_tracker_date';

  /// Login persistence
  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Google login persistence
  static Future<void> setGoogleLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isGoogleLoginKey, value);
  }

  static Future<bool> isGoogleLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGoogleLoginKey) ?? false;
  }

  /// Save Google user info
  static Future<void> saveGoogleUser(String name, String email, {String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleUserNameKey, name);
    await prefs.setString(_googleUserEmailKey, email);
    if (photoUrl != null) {
      await prefs.setString(_googleUserPhotoKey, photoUrl);
    }
  }

  static Future<Map<String, String?>> getGoogleUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_googleUserNameKey),
      'email': prefs.getString(_googleUserEmailKey),
      'photoUrl': prefs.getString(_googleUserPhotoKey),
    };
  }

  static Future<String?> getGooglePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleUserPhotoKey);
  }

  /// Landing page shown only first time
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setFirstLaunch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, value);
  }

  /// Save Google OAuth server/access token
  static Future<void> saveGoogleToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_token', token);
  }

  static Future<String?> getGoogleToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_token');
  }

  static Future<void> clearGoogleToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_token');
  }

  /// Remember Me (SEC-08: Storing plaintext password removed; only persists saved email)
  static Future<void> saveRememberMe(bool remember, String email, [String? password]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);

    if (remember) {
      await prefs.setString(_savedEmailKey, email);
    } else {
      await prefs.remove(_savedEmailKey);
    }
    // Always purge any previously stored plaintext password for security
    await prefs.remove(_savedPasswordKey);
  }

  static Future<Map<String, dynamic>> getRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'remember': prefs.getBool(_rememberMeKey) ?? false,
      'email': prefs.getString(_savedEmailKey),
      'password': '',
    };
  }

  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<bool> shouldShowMoodTrackerToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownDate = prefs.getString(_keyLastMoodTrackerDate);
    final todayDate = _getTodayDateString();

    return lastShownDate != todayDate;
  }

  /// Saves today's date so the dialog won't pop up again today.
  static Future<void> markMoodTrackerShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastMoodTrackerDate, _getTodayDateString());
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
