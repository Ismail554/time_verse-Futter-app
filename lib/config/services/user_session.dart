// class UserSession {
//   static final UserSession _instance = UserSession._internal();

//   factory UserSession() {
//     return _instance;
//   }

//   UserSession._internal();

//   String? userId;
//   String? username;
//   String? profileImageUrl;

//   String get formattedUsername {
//     if (username == null || username!.trim().isEmpty) return '';

//     final parts = username!.trim().split(' ');

//     if (parts.length == 1) return username!;

//     final first = parts.first;
//     final rest = parts.sublist(1).join(' ');

//     return '$first\n$rest';
//   }
// }

import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();

  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  String? userId;
  String? username;
  String? profileImageUrl;

  /// Loads saved user details (Email or Google) into memory on cold start
  Future<void> initFromPrefs() async {
    final savedUserId = await AppPrefs.getUserId();
    if (savedUserId != null && savedUserId.isNotEmpty) {
      userId = savedUserId;
    }

    final savedName = await AppPrefs.getUserName();
    if (savedName != null && savedName.isNotEmpty) {
      username = savedName;
    }

    final savedPhoto = await AppPrefs.getUserPhoto();
    if (savedPhoto != null && savedPhoto.isNotEmpty) {
      profileImageUrl = savedPhoto;
    }

    final isGoogle = await AppPrefs.isGoogleLogin();
    if (isGoogle) {
      final googleUser = await AppPrefs.getGoogleUser();
      username = googleUser['name'] ?? username;
      profileImageUrl = googleUser['photoUrl'] ?? profileImageUrl;
    }

    // Fallback: If userId is not yet stored, extract user_id from JWT access token
    if (userId == null || userId!.isEmpty) {
      final jwtUserId = await AuthService().getUserIdFromToken();
      if (jwtUserId != null) {
        userId = jwtUserId.toString();
        await AppPrefs.saveUserId(userId!);
      }
    }
  }

  /// Clears in-memory session state on logout
  void clear() {
    userId = null;
    username = null;
    profileImageUrl = null;
  }

  String get formattedUsername {
    if (username == null || username!.trim().isEmpty) return '';
    final parts = username!.trim().split(' ');
    if (parts.length == 1) return username!;

    final first = parts.first;
    final rest = parts.sublist(1).join(' ');

    return '$first\n$rest';
  }
}