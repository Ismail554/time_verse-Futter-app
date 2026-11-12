import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/custom_header.dart';
import 'package:time_verse/core/components/custom_input_field.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/settings/profile/controller/profile_controller.dart';
import 'package:time_verse/features/settings/profile/custom_widget/custom_datefield.dart';
import 'package:time_verse/features/settings/profile/custom_widget/custom_profileimg_container.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileController>().onInit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseurl = dotenv.env['BASE_URL'] ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Consumer<ProfileController>(
            builder: (context, controller, child) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  children: [
                    CustomHeaderBar(
                      title: 'Profile',
                      leftSpacing: 100.w,
                      rightSpacing: 83.w,
                    ),
                    AppSpacing.h20,
                    if (controller.isLoading)
                      Padding(
                        padding: EdgeInsets.only(top: 60.h),
                        child: const CircularProgressIndicator(),
                      )
                    else ...[
                      ProfileImagePicker(
                        assetPath: ImageAssets.profileImg,
                        pickedImage: controller.pickedImage,
                        imageUrl: controller.currentUser?.profilePicture != null
                            ? (controller.currentUser!.profilePicture!
                                    .startsWith('http')
                                ? controller.currentUser!.profilePicture
                                : '$baseurl${controller.currentUser!.profilePicture}')
                            : null,
                        onCameraTap: controller.pickImage,
                      ),
                      AppSpacing.h20,
                      Container(
                        padding: EdgeInsets.all(24.sp),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF051123)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12.sp),
                          border: Border.all(
                            color: AppColors.button_color,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            CustomInputField(
                              label: 'Name',
                              hintText: 'Enter your name',
                              controller: controller.nameController,
                              isPassword: false,
                              fontSize: 16.sp,
                              height: 44.h,
                              hintFontSize: 14.sp,
                            ),
                            AppSpacing.h20,
                            CustomInputField(
                              label: 'Email',
                              hintText: 'example@mail.com',
                              controller: controller.emailController,
                              isPassword: false,
                              fontSize: 16.sp,
                              height: 44.h,
                              hintFontSize: 14.sp,
                              isReadOnly: true,
                            ),
                            AppSpacing.h20,
                            CustomInputField(
                              label: 'Password',
                              hintText: '***********',
                              controller: controller.passwordController,
                              isPassword: false,
                              fontSize: 16.sp,
                              height: 44.h,
                              hintFontSize: 14.sp,
                              isReadOnly: true,
                            ),
                            AppSpacing.h20,
                            DateField(
                              label: 'Date of Birth',
                              selectedDate:
                                  controller.dateController.text.trim().isNotEmpty
                                      ? (DateTime.tryParse(
                                              controller.dateController.text
                                                  .trim()) ??
                                          DateTime(1995, 5, 23))
                                      : DateTime(1995, 5, 23),
                              onDateSelected: (newDate) {
                                controller.setBirthDate(newDate);
                              },
                            ),
                            AppSpacing.h20,
                            CustomButton(
                              text: "Update",
                              onPressed: () {
                                controller.updateProfile(context);
                              },
                              gradient: AppGradientColors.button_gradient,
                              textColor: Colors.black,
                              fontFamily: 'outfit',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              height: 50.h,
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
