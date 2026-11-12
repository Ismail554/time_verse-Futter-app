import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:time_verse/features/auth/auth_model/auth_model.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class UserService {
  late final Dio _dio;
  final AuthService _authService = AuthService();
  final String _baseUrl = dotenv.env['BASE_URL'] ?? '';

  User? _currentUser;
  User? get currentUser => _currentUser;

  UserService() {
    _dio = createDio(
      options: BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  Future<User?> getUserProfile() async {
    try {
      final response = await _dio.get(
        'api/v1/profile/',
        options: await _authorizedHeader(),
      );

      final data =
          response.data is String ? jsonDecode(response.data) : response.data;

      if (response.statusCode == 200 && data != null) {
        final userJson = data['data'] ?? data;
        debugPrint('User data -> $userJson');
        _currentUser = User.fromJson(userJson);
        return _currentUser;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      return null;
    }
  }

  Future<User?> updateUserProfile(User user, {File? profileImage}) async {
    try {
      final isMultipart = profileImage != null;
      final dynamic payload;

      if (isMultipart) {
        final formMap = <String, dynamic>{
          'id': user.id,
          'name': user.name,
          if (user.birthDate != null && user.birthDate!.trim().isNotEmpty)
            'birth_date': user.birthDate!.trim(),
          if (user.password != null && user.password!.trim().isNotEmpty)
            'password': user.password!.trim(),
          'profile_picture': await MultipartFile.fromFile(
            profileImage.path,
            filename: profileImage.path.split(RegExp(r'[\\/]')).last,
          ),
        };
        payload = FormData.fromMap(formMap);
      } else {
        final jsonMap = <String, dynamic>{
          'id': user.id,
          'name': user.name,
          if (user.birthDate != null && user.birthDate!.trim().isNotEmpty)
            'birth_date': user.birthDate!.trim(),
          if (user.password != null && user.password!.trim().isNotEmpty)
            'password': user.password!.trim(),
        };
        payload = jsonEncode(jsonMap);
      }

      final response = await _dio.put(
        'api/v1/profile/',
        options: await _authorizedHeader(isMultipart: isMultipart),
        data: payload,
      );

      final data =
          response.data is String ? jsonDecode(response.data) : response.data;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data != null) {
        final userJson = data is Map<String, dynamic>
            ? (data['data'] ?? data['user'] ?? data)
            : data;
        final updatedUser = User.fromJson(userJson);
        _currentUser = updatedUser;
        debugPrint("✅ User updated successfully: ${updatedUser.name}");
        return updatedUser;
      } else {
        debugPrint(
          "❌ Failed to update user: ${data is Map ? (data['message'] ?? 'Unknown error') : data}",
        );
        return null;
      }
    } on DioException catch (e) {
      debugPrint(
        "❌ Dio error while updating user: ${e.response?.data ?? e.message}",
      );
      return null;
    } catch (e) {
      debugPrint("❌ Exception while updating user: $e");
      return null;
    }
  }

  Future<Options> _authorizedHeader({bool isMultipart = false}) async {
    final token = await _authService.getToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        if (!isMultipart) 'Content-Type': 'application/json',
      },
      sendTimeout: isMultipart ? const Duration(seconds: 30) : null,
      receiveTimeout: isMultipart ? const Duration(seconds: 30) : null,
    );
  }
}
