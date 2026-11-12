// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/features/auth/auth_model/auth_model.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';
import 'package:time_verse/features/settings/profile/user_service/user_service.dart';

class ProfileController extends ChangeNotifier {
  final UserService _userService = UserService();

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController dateController = TextEditingController();

  final auth = AuthService();

  File? pickedImage;
  User? currentUser;
  bool isLoading = false;

  void onInit() {
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    try {
      isLoading = true;
      notifyListeners();

      final isGoogleLogin = await AppPrefs.isGoogleLogin();
      final user = await _userService.getUserProfile();

      if (user != null) {
        final resolvedName = (user.name.isNotEmpty && user.name != 'User')
            ? user.name
            : (UserSession().username ?? user.name);
        final resolvedPicture = (user.profilePicture != null &&
                user.profilePicture!.trim().isNotEmpty)
            ? user.profilePicture
            : (isGoogleLogin ? UserSession().profileImageUrl : null);

        final mergedUser = user.copyWith(
          name: resolvedName,
          profilePicture: resolvedPicture,
        );

        setUser(mergedUser);

        nameController.text = currentUser!.name;
        emailController.text = currentUser!.email ?? '';
        passwordController.text = currentUser!.password ?? '';
        dateController.text = currentUser!.birthDate ?? '';

        UserSession().userId = currentUser!.id.toString();
        UserSession().username = currentUser!.name;
        if (currentUser!.profilePicture != null &&
            currentUser!.profilePicture!.isNotEmpty) {
          UserSession().profileImageUrl = currentUser!.profilePicture;
        }

        // Persist session to local storage for offline cold start restoration
        await AppPrefs.saveUserSession(
          userId: currentUser!.id.toString(),
          userName: currentUser!.name,
          email: currentUser!.email ?? '',
          photoUrl: currentUser!.profilePicture,
        );

        debugPrint("✅ User data preloaded: ${UserSession().username}");
        debugPrint("✅ User Image: ${UserSession().profileImageUrl}");
      } else {
        debugPrint("⚠️ No user data found");
      }
    } catch (e) {
      debugPrint("❌ Error loading user data: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(BuildContext context) async {
    final isGoogleLogin = await AppPrefs.isGoogleLogin();
    if (isGoogleLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Google profile cannot be updated from here"),
        ),
      );
      return;
    }

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name cannot be empty")),
      );
      return;
    }

    debugPrint("🚀 Sending birthdate payload: '${dateController.text}'");

    final updatedUser = User(
      id: currentUser?.id ?? 0,
      name: nameController.text.trim(),
      birthDate: dateController.text.trim().isNotEmpty
          ? dateController.text.trim()
          : null,
      profilePicture: null,
      password: passwordController.text.trim().isNotEmpty
          ? passwordController.text.trim()
          : null,
    );

    isLoading = true;
    notifyListeners();

    try {
      final result = await _userService.updateUserProfile(
        updatedUser,
        profileImage: pickedImage,
      );

      if (result != null) {
        setUser(result);
        pickedImage = null;
        UserSession().username = currentUser?.name;
        if (currentUser?.profilePicture != null &&
            currentUser!.profilePicture!.isNotEmpty) {
          UserSession().profileImageUrl = currentUser!.profilePicture;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully")),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to update profile")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong. Please try again."),
          ),
        );
      }
    } finally {
      isLoading = false;

      await loadUserProfile();

      if (currentUser != null) {
        nameController.text = currentUser!.name;
        passwordController.text = currentUser!.password ?? '';
        dateController.text = currentUser!.birthDate ?? '';
      }

      debugPrint("✅ Updated birthday : ${dateController.text}");
      debugPrint("✅ Updated image path: ${UserSession().profileImageUrl}");

      notifyListeners();
    }
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        pickedImage = File(picked.path);
        debugPrint("✅ Image picked: ${pickedImage?.path}");
        notifyListeners();
      }
    } catch (e) {
      debugPrint("⚠️ Error picking profile image: $e");
    }
  }

  void setUser(User user) {
    final picture = user.profilePicture;
    user = user.copyWith(
      profilePicture: _resolveProfilePicture(picture),
    );

    currentUser = user;
    notifyListeners();
  }

  String? _resolveProfilePicture(String? picture) {
    final baseurl = dotenv.env['BASE_URL'] ?? '';
    if (picture == null || picture.isEmpty) return null;

    if (picture.startsWith('http')) {
      return picture;
    }

    final cleanBase =
        baseurl.endsWith('/') ? baseurl.substring(0, baseurl.length - 1) : baseurl;
    final cleanPic = picture.startsWith('/') ? picture : '/$picture';
    return '$cleanBase$cleanPic';
  }

  void setBirthDate(DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    dateController.text = formatted;
    debugPrint("🎯 Controller set text to: ${dateController.text}");
    notifyListeners();
  }

  void clearProfile() {
    currentUser = null;
    pickedImage = null;

    nameController.clear();
    emailController.clear();
    passwordController.clear();
    dateController.clear();

    UserSession().userId = null;
    UserSession().username = null;
    UserSession().profileImageUrl = null;

    notifyListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    dateController.dispose();
    super.dispose();
  }
}
