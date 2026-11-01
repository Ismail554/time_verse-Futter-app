import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/core/components/custom_bottomnav.dart';
import 'package:time_verse/core/components/custom_header.dart';
import 'package:time_verse/core/components/custom_settings_section.dart';
import 'package:time_verse/core/components/notification_card.dart';
import 'package:time_verse/core/components/user_profile_card.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/features/settings/log_out_modal.dart';
import 'package:time_verse/features/settings/settings_controller.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final userSession = UserSession();

    return Scaffold(
      extendBody: true,
      //backgroundColor: isDarkMode ? const Color(0xFF060E1E) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomHeaderBar(
                  title: 'Settings',
                  leftSpacing: 100.w,
                  rightSpacing: 79.w,
                ),
                AppSpacing.h24,

                UserProfileCard(
                  imageUrl: userSession.profileImageUrl ?? ImageAssets.profileImg,
                  userName: userSession.username ?? '',
                  isPremium: false,
                  subtitle: 'Manage your account and preferences',
                  onTap: () {
                    context.push('/profile');
                  },
                ),
                AppSpacing.h24,
                // 2. Alert Notification Action Card Component
                TappableNotificationCard(
                  title: 'Notifications',
                  subtitle: 'Manage alerts and reminders',
                  badgeCount: 1, // Dynamically input your real backend unread count here
                  onTap: () => context.push('/notification'),
                ),
                AppSpacing.h24,
                // Section 1: Security (Profile & Change Password)
                SettingsSection(
                  title: 'Security',
                  items: [
                    SettingsItem(
                      label: 'Change Password',
                      subtitle:'Update your security password', 
                      iconPath: IconAssets.lock,
                      onTap: () => context.push('/change_password'),
                    ),
                  ],
                ),
                // Section 2: Subscription
                SettingsSection(
                  title: 'Subscription',
                  items: [
                    SettingsItem(
                      label: 'Premium Plan',
                      subtitle: 'Unlimited AI quotes • Priority support',
                      statusText: 'Active until June 20, 2026',
                      iconPath: IconAssets.dollarIcon,
                      onTap: () => context.push('/subscription'),
                    ),
                  ],
                ),
                // Section 3: Support & Legal
                SettingsSection(
                  title: 'Support & legal',
                  items: [
                    SettingsItem(
                      label: 'Privacy Policy',
                      iconPath: IconAssets.shield1,
                      onTap: () => context.push('/privacy_policy'),
                    ),
                    SettingsItem(
                      label: 'Terms & Conditions',
                      iconPath: IconAssets.shield1,
                      onTap: () => context.push('/terms_and_condition'),
                    ),
                  ],
                ),

                // Section 4: Danger Zone
                SettingsSection(
                  title: 'Danger Zone',
                  isDangerZone:true, // Tells the widget to apply the red danger styling from the design
                  items: [
                    SettingsItem(
                      label: 'Delete Account',
                      iconPath: IconAssets.trash,
                      onTap: () => context.push('/delete_account'),
                    ),
                    SettingsItem(
                      label: 'Logout',
                      iconPath: IconAssets.logout,
                      onTap: () => showLogoutDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer<SettingsController>(
        builder: (context, controller, _) => const CustomBottomNavBar(),
      ),
    );
  }
}