import 'package:flutter/foundation.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/firebase/fire_base_service.dart';

/// Centralized service to manage notification permissions.
///
/// Ensures permission dialogs are NEVER presented on splash or app launch,
/// and are ONLY requested after successful login (email, Google, or signup).
class NotificationPermissionService {
  /// Request system notification permissions (local + FCM) and synchronize
  /// push token with backend after successful login.
  static Future<void> ensurePermissionAfterLogin() async {
    try {
      debugPrint('🔔 [NotificationPermission] Requesting permissions after successful login...');

      // 1. Request local notification permission (Android 13+ POST_NOTIFICATIONS, iOS)
      final localGranted = await NotificationService.requestNotificationPermission();
      debugPrint('🔔 [NotificationPermission] Local notification granted: $localGranted');

      // 2. Request FCM notification permission & post push token to backend
      await FCMService.requestPermissionAndSyncToken();
      debugPrint('✅ [NotificationPermission] Notifications configured successfully.');
    } catch (e) {
      debugPrint('⚠️ [NotificationPermission] Error ensuring permissions: $e');
    }
  }
}

