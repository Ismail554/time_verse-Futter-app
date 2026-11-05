import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/alerm_notification_service.dart';
import 'package:time_verse/config/services/alerm_service.dart';
import 'package:time_verse/config/services/google_service.dart';
import 'package:time_verse/core/components/custom_dialogue.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';
import 'package:time_verse/features/calender/controller/calender_controller.dart';
import 'package:time_verse/features/home/controller/home_controller.dart';
import 'package:time_verse/features/settings/profile/controller/profile_controller.dart';

class DeleteAcController extends ChangeNotifier {
  Future<void> executeAccountDeletion({
    required BuildContext context,
    String? password,
    String? idToken,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _deleteAccountApiCall(
      password: password,
      idToken: idToken,
    );
    final bool success = result['success'] == true;

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (success) {
      await showMessageDialog(
        context,
        'Your account and associated data have been permanently deleted.',
        title: 'Success',
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
      );

      // Clean all user data and credentials
      await AlarmHelper.cancelAllAlarms();
      await NotificationService.cancelAllNotifications();
      await GoogleServices().signOut();
      await AppPrefs.setLoggedIn(false);
      await AppPrefs.setGoogleLogin(false);
      await AppPrefs.clearGoogleToken();
      await AuthService().clearToken();

      if (!context.mounted) return;
      context.read<HomeController>().resetSession();
      context.read<ProfileController>().clearProfile();
      context.read<CalendarController>().clearEvents();

      await Future.delayed(const Duration(milliseconds: 600));

      if (context.mounted) {
        Navigator.pop(context); // Close parent profile/settings interface context
        context.go('/login');
      }
    } else {
      await showMessageDialog(
        context,
        result['error'] ?? 'Failed to delete account. Please re-authenticate and try again.',
        title: 'Error',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  // Private helper to execute re-authenticated deletion call
  Future<Map<String, dynamic>> _deleteAccountApiCall({
    String? password,
    String? idToken,
  }) async {
    try {
      final token = await AuthService().getToken();
      final baseUrl = dotenv.env['BASE_URL'] ?? '';

      final payload = <String, dynamic>{
        if (password != null && password.isNotEmpty) "password": password,
        if (idToken != null && idToken.isNotEmpty) "id_token": idToken,
      };

      final response = await createDio().delete(
        '${baseUrl}api/v1/delete-account/',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      return {'success': response.statusCode == 200};
    } on DioException catch (e) {
      debugPrint("❌ Delete account error: $e");
      String errorMsg = 'Failed to delete account. Please verify credentials.';
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        errorMsg = data['detail']?.toString() ?? data['message']?.toString() ?? errorMsg;
      }
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
