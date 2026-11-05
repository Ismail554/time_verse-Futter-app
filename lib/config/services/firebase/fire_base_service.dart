// ignore_for_file: avoid_print

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _token;

  /// Background/startup initialization.
  /// Sets up listeners WITHOUT popping up any permission dialog on splash or startup.
  static Future<void> initialize() async {
    // 1. Set up token refresh listener
    _messaging.onTokenRefresh.listen((newToken) async {
      _token = newToken;
      print('🔄 FCM Token refreshed: $newToken');
      await postTokenToBackend(newToken);
    });

    // 2. Set up foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? message.data['title'];
      final body = message.notification?.body ?? message.data['body'];

      await NotificationService.scheduleNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title ?? 'Notification',
        body: body ?? '',
        alarmTime: DateTime.now().add(const Duration(seconds: 1)),
        payload: message.messageId,
      );
    });

    // 3. Silent check: only if ALREADY authorized from a previous session, sync token silently
    unawaited(() async {
      try {
        final settings = await _messaging
            .getNotificationSettings()
            .timeout(const Duration(seconds: 2));
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          _token =
              await _messaging.getToken().timeout(const Duration(seconds: 2));
          if (_token != null) {
            await postTokenToBackend(_token!);
          }
        }
      } catch (e) {
        print('ℹ️ Silent FCM token check notice: $e');
      }
    }());
  }

  /// Request FCM notification permission and synchronize push token with backend.
  /// Called explicitly AFTER successful login (never during splash).
  static Future<void> requestPermissionAndSyncToken() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print('🔔 FCM Notification permission status: ${settings.authorizationStatus}');

      _token = await _messaging.getToken();
      print('🔑 FCM Token obtained: $_token');

      if (_token != null) {
        await postTokenToBackend(_token!);
      }
    } catch (e) {
      print('❌ Error requesting FCM permission / token: $e');
    }
  }

  static String? get token => _token;

  static Future<void> postTokenToBackend(String token) async {
    try {
      final authToken = await AuthService().getToken();
      if (authToken == null || authToken.isEmpty) {
        print('ℹ️ Skipping FCM token update: User not logged in yet.');
        return;
      }

      final dio = createDio();
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      final url = '${baseUrl}api/v1/update-fcm-token/';

      final response = await dio.post(
        url,
        data: {'fcm_token': token},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ FCM token sent to backend successfully');
      } else {
        print('❌ Failed to send FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error posting FCM token: $e');
    }
  }
}
