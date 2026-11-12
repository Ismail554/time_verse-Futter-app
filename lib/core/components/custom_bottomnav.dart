// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/core/components/bottom_card_controller/bottom_card_controller.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';

class NavItem {
  final String label;
  final String iconPath;
  final String route;

  const NavItem({
    required this.label,
    required this.iconPath,
    required this.route,
  });
}

final List<NavItem> navItems = [
  const NavItem(label: 'Home', iconPath: IconAssets.home, route: '/home'),
  const NavItem(label: 'Calendar', iconPath: IconAssets.calender, route: '/calender'),
  const NavItem(label: 'Add', iconPath: IconAssets.addIcon, route: '/add'),
  const NavItem(label: 'Saved', iconPath: IconAssets.save, route: '/saved'),
  const NavItem(label: 'Settings', iconPath: IconAssets.setting, route: '/settings'),
];

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  int _resolveActiveIndex(BuildContext context, int fallback) {
    try {
      final path = GoRouterState.of(context).uri.path;
      if (path == '/home' || path.startsWith('/home')) return 0;
      if (path == '/calender' || path == '/calendar' || path.startsWith('/calender')) return 1;
      if (path == '/add' || path.startsWith('/add')) return 2;
      if (path == '/saved' || path.startsWith('/saved')) return 3;
      if (path == '/settings' || path.startsWith('/settings') || path.startsWith('/profile')) return 4;
    } catch (_) {}
    return fallback;
  }

  void _onTabTapped(BuildContext context, BottomNavController controller, int index, String route) {
    controller.navigateTo(index, context);
  }

  Widget _buildTabItem({
    required BuildContext context,
    required NavItem item,
    required int index,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor = AppColors.fourth_color;
    final inactiveColor = isDark ? Colors.white60 : const Color(0xFF7A8B9E);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              item.iconPath,
              width: 22.w,
              height: 22.h,
              colorFilter: ColorFilter.mode(
                isSelected ? activeColor : inactiveColor,
                BlendMode.srcIn,
              ),
            ),
            AppSpacing.h2,
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.5.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Consumer<BottomNavController>(
      builder: (context, controller, _) {
        final activeIndex = _resolveActiveIndex(context, controller.selectedIndex);
        final barHeight = 62.h + bottomPadding;
        final totalHeight = 78.h + bottomPadding;

        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // 1. Navigation Bar Base Container
              Container(
                height: barHeight,
                padding: EdgeInsets.only(
                  top: 6.h,
                  bottom: bottomPadding > 0 ? bottomPadding : 6.h,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.containers_bgd : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      width: 0.8,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Slot 0: Home
                    _buildTabItem(
                      context: context,
                      item: navItems[0],
                      index: 0,
                      isSelected: activeIndex == 0,
                      isDark: isDark,
                      onTap: () => _onTabTapped(context, controller, 0, navItems[0].route),
                    ),
                    // Slot 1: Calendar
                    _buildTabItem(
                      context: context,
                      item: navItems[1],
                      index: 1,
                      isSelected: activeIndex == 1,
                      isDark: isDark,
                      onTap: () => _onTabTapped(context, controller, 1, navItems[1].route),
                    ),
                    // Slot 2: Dedicated space reservation for Center Floating Action Button
                    const Expanded(
                      child: SizedBox(),
                    ),
                    // Slot 3: Saved
                    _buildTabItem(
                      context: context,
                      item: navItems[3],
                      index: 3,
                      isSelected: activeIndex == 3,
                      isDark: isDark,
                      onTap: () => _onTabTapped(context, controller, 3, navItems[3].route),
                    ),
                    // Slot 4: Settings
                    _buildTabItem(
                      context: context,
                      item: navItems[4],
                      index: 4,
                      isSelected: activeIndex == 4,
                      isDark: isDark,
                      onTap: () => _onTabTapped(context, controller, 4, navItems[4].route),
                    ),
                  ],
                ),
              ),

              // 2. Center Floating Action Button (Elevated perfectly over Slot 2)
              Positioned(
                bottom: bottomPadding + 14.h,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    debugPrint('Tapped floating action button: Navigating to /add');
                    context.push('/add');
                  },
                  child: Container(
                    width: 56.w,
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA500),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA500).withOpacity(0.4),
                          blurRadius: 12.r,
                          spreadRadius: 1.r,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6.r,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 30.w,
                        height: 30.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.w),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}