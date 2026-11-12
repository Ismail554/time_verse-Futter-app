// ignore_for_file: use_build_context_synchronously, invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/core/components/custom_bottomnav.dart';
import 'package:time_verse/core/components/custom_dialogue.dart';
import 'package:time_verse/core/theme/theme_provider.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/home/controller/home_controller.dart';
import 'package:time_verse/features/home/widget/feebpback_popup.dart';
import 'package:time_verse/features/settings/profile/controller/profile_controller.dart';


class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final GlobalKey _shareKey = GlobalKey();
  late final ScrollController _dateScrollController;
  bool _isPastEventsExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final double itemWidth = 66.w;
    final int todayIndex = now.day - 1;
    final double initialOffset = (todayIndex - 2).clamp(0, daysInMonth) * itemWidth;
    _dateScrollController = ScrollController(initialScrollOffset: initialOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final homeController = context.read<HomeController>();
      final profileController = context.read<ProfileController>();
      if (!homeController.isInitialized) {
        final currentRouteUri = GoRouterState.of(context).uri.toString();
        homeController.initOnce(profileController, context);
        homeController.updateIndexFromRoute(currentRouteUri);
      }
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final homeController = context.read<HomeController>();
    final profileController = context.read<ProfileController>();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await homeController.loadHomeScreenData(
            profileController,
            date: homeController.selectedDate,
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Consumer<ProfileController>(
                      builder: (context, profileController, _) {
                        final username = profileController.currentUser?.name ?? UserSession().formattedUsername;
                        final firstLetter = (username.isNotEmpty ? username[0] : 'a').toLowerCase();
                        return Transform.translate(
                          offset: Offset(-65.w, 0),
                          child: Image.asset(
                            AlphabetAssets.getLetterPng(firstLetter),
                            width: 150.w,
                            height: 100.h,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              AlphabetAssets.getLetterPng('a'),
                              width: 150.w,
                              height: 100.h,
                            ),
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            themeProvider.toggleTheme();
                          },
                          icon: SvgPicture.asset(
                            isDarkMode ? IconAssets.themeDark : IconAssets.lightTheme,
                            width: 37.w,
                            height: 37.h,
                          ),
                        ),
                        AppSpacing.w8,
                        GestureDetector(
                          onTap: () {
                            context.push('/profile');
                          },
                          child: SizedBox(
                            width: 40.w,
                            height: 40.w,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDarkMode ? AppColors.text_color : AppColors.heading_color,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: Selector<ProfileController, String?>(
                                  selector: (_, controller) => controller.currentUser?.profilePicture,
                                  builder: (_, profilePicture, __) {
                                    final String? activePhoto = (UserSession().profileImageUrl != null &&
                                            UserSession().profileImageUrl!.isNotEmpty)
                                        ? UserSession().profileImageUrl
                                        : profilePicture;

                                    final imageProvider = (activePhoto != null && activePhoto.isNotEmpty)
                                        ? NetworkImage(activePhoto) as ImageProvider<Object>
                                        : const AssetImage(ImageAssets.profileImg) as ImageProvider<Object>;
                                    return Image(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  'Welcome',
                  style: GoogleFonts.cormorant(
                    fontWeight: FontWeight.w700,
                    fontSize: 34.sp,
                    color: isDarkMode ? AppColors.fourth_color : const Color(0xFF403D3B),
                  ),
                ),
                Consumer<ProfileController>(
                  builder: (context, controller, _) {
                    final username = controller.currentUser?.name ?? UserSession().formattedUsername;
                    return Text(
                      username,
                      style: GoogleFonts.cormorant(
                        fontWeight: FontWeight.w700,
                        fontSize: 34.sp,
                        color: AppColors.fourth_color,
                      ),
                    );
                  },
                ),
                Text(
                  'Have a mindful and blessed day',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.normal,
                    fontSize: 14.sp,
                    color: isDarkMode ? Colors.white : const Color(0xFF414141),
                  ),
                ),
                AppSpacing.h30,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 1.h,
                          width: double.infinity,
                          color: isDarkMode ? const Color(0xFF3B3B3B) : const Color(0xFFF1A80A).withOpacity(0.6),
                        ),
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF060B13) : Colors.white,
                              borderRadius: BorderRadius.circular(30.r),
                              border: Border.all(
                                color: isDarkMode ? const Color(0xFF3B3B3B) : const Color(0xFFF1A80A).withOpacity(0.7),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF1A80A).withOpacity(isDarkMode ? 0.05 : 0.08),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  IconAssets.calender1,
                                  width: 16.w,
                                  height: 16.h,
                                ),
                                AppSpacing.w8,
                                Text(
                                  DateFormat('EEEE, MMMM d').format(homeController.selectedDate),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18.sp,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h25,
                    SizedBox(
                      height: 80.h,
                      child: Consumer<HomeController>(
                        builder: (context, controller, _) {
                          final now = DateTime.now();
                          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

                          return ListView.builder(
                            controller: _dateScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: daysInMonth,
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            itemBuilder: (context, index) {
                              final date = DateTime(now.year, now.month, index + 1);
                              final isSelected = date.day == controller.selectedDate.day &&
                                  date.month == controller.selectedDate.month &&
                                  date.year == controller.selectedDate.year;

                              return GestureDetector(
                                onTap: () {
                                  controller.selectDate(date, profileController);
                                },
                                onDoubleTap: () {
                                  controller.selectDate(date, profileController);
                                  final todayStart = DateTime(now.year, now.month, now.day);
                                  final targetDateStart = DateTime(date.year, date.month, date.day);
                                  if (!targetDateStart.isBefore(todayStart)) {
                                    final String formattedParamDate = DateFormat('MMMM d, yyyy').format(date);
                                    context.push('/add?selectedDate=$formattedParamDate');
                                  }
                                },
                                child: Container(
                                  width: 54.w,
                                  margin: EdgeInsets.symmetric(horizontal: 6.w),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFF1A80A)
                                        : (isDarkMode ? const Color(0xFF070F1A) : Colors.white),
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: !isSelected
                                          ? (isDarkMode ? Colors.white : Colors.grey.shade300)
                                          : Colors.transparent,
                                      width: 0.2.sp,
                                    ),
                                    boxShadow: [
                                      if (!isSelected) ...[
                                        BoxShadow(
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.3)
                                              : Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                        ),
                                      ] else ...[
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _getDayName(date.weekday),
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w400,
                                          color: isSelected
                                              ? const Color(0xFF060B13)
                                              : (isDarkMode ? const Color(0xFF7A8B9E) : Colors.grey.shade600),
                                        ),
                                      ),
                                      AppSpacing.h6,
                                      Text(
                                        date.day.toString(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF060B13)
                                              : (isDarkMode ? Colors.white : Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                AppSpacing.h30,
                Consumer<HomeController>(
                  builder: (context, homeController, _) {
                    final now = DateTime.now();
                    final isSelectedDateToday = homeController.selectedDate.year == now.year &&
                        homeController.selectedDate.month == now.month &&
                        homeController.selectedDate.day == now.day;
                    if (!isSelectedDateToday) {
                      return const SizedBox.shrink();
                    }
                    final aiReflectionText = homeController.currentReflection?.aiReflection.isNotEmpty == true
                        ? homeController.currentReflection!.aiReflection
                        : 'Today feels centered around connection, gratitude and emotionally meaningful movement.';
                    final activeBgImage = homeController.currentBgIndex != null
                        ? (isDarkMode
                            ? AiImageAssets.getDbImage(homeController.currentBgIndex!)
                            : AiImageAssets.getWbImage(homeController.currentBgIndex!))
                        : (isDarkMode
                            ? ImageAssets.containerBgImg
                            : ImageAssets.containerBgImgLight);
                    return Container(
                      width: 360.w,
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF070E1A) : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFC5A880).withOpacity(0.25),
                          width: 1,
                        ),
                        image: DecorationImage(
                          image: AssetImage(activeBgImage),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: 16.w,
                                right: 16.w,
                                top: 16.h,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.black.withOpacity(0.3) : const Color(0xFFFFF7E5),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: const Color(0xFFC5A880).withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.wb_sunny_rounded,
                                          color: const Color(0xFFFFA500),
                                          size: 14.sp,
                                        ),
                                        AppSpacing.w6,
                                        Text(
                                          'AI Reflections',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFFFA500),
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.h10,
                            RepaintBoundary(
                              key: _shareKey,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 20.h,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      IconAssets.quoteMark,
                                      width: 19.w,
                                      height: 20.h,
                                    ),
                                    AppSpacing.h10,
                                    Container(
                                      color: isDarkMode
                                          ? const Color(0xFF051123).withOpacity(0.2)
                                          : Colors.transparent,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 12.h,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        aiReflectionText,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cormorant(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 20.sp,
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AppSpacing.h10,
                            Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.35)
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(12.r),
                                  bottomRight: Radius.circular(12.r),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (homeController.currentReflection != null) {
                                          homeController.isReflectionFavorite = !homeController.isReflectionFavorite;
                                          homeController.notifyListeners();
                                        }
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            homeController.isReflectionFavorite
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: homeController.isReflectionFavorite
                                                ? Colors.red
                                                : (isDarkMode ? Colors.white : AppColors.fourth_color),
                                            size: 22.sp,
                                          ),
                                          AppSpacing.h4,
                                          Text(
                                            'Favorite',
                                            style: GoogleFonts.outfit(
                                              color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 24.h,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final success = await homeController.saveQuoteImageToGallery(
                                          _shareKey,
                                          bgAssetPath: activeBgImage,
                                        );
                                        if (success) {
                                          if (context.mounted) {
                                            await showMessageDialog(
                                              context,
                                              "Reflection saved to gallery successfully!",
                                              title: "Success",
                                              icon: Icons.check_circle_outline,
                                              iconColor: Colors.green,
                                            );
                                          }
                                        } else {
                                          if (context.mounted) {
                                            await showMessageDialog(
                                              context,
                                              "Failed to save image.",
                                              title: "Error",
                                              icon: Icons.error_outline,
                                              iconColor: Colors.red,
                                            );
                                          }
                                        }
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bookmark_border_rounded,
                                            color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                            size: 22.sp,
                                          ),
                                          AppSpacing.h4,
                                          Text(
                                            'Save',
                                            style: GoogleFonts.outfit(
                                              color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 24.h,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => homeController.shareQuoteAsImage(
                                        context,
                                        _shareKey,
                                        bgAssetPath: activeBgImage,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.share_outlined,
                                            color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                            size: 22.sp,
                                          ),
                                          AppSpacing.h4,
                                          Text(
                                            'Share',
                                            style: GoogleFonts.outfit(
                                              color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                AppSpacing.h30,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Schedule',
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.w600,
                        fontSize: 20.sp,
                        color: isDarkMode ? AppColors.l_schedule_clr3 : AppColors.heading_color,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFFF6AD14).withOpacity(0.65) : Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: InkWell(
                        onTap: () {
                          context.push('/all_events');
                        },
                        borderRadius: BorderRadius.circular(12.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See all',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFFA500),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              AppSpacing.w6,
                              Icon(
                                Icons.arrow_right_alt_rounded,
                                color: const Color(0xFFFFA500),
                                size: 20.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h16,
                Consumer<HomeController>(
                  builder: (context, controller, _) {
                    final rawEvents = controller.todaysEvents;
                    if (rawEvents.isEmpty) {
                      return Text(
                        'No Event yet',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w400,
                          fontSize: 14.sp,
                          color: isDarkMode ? AppColors.fourth_color : AppColors.heading_color,
                        ),
                      );
                    }

                    // Sort chronologically and validate past vs present/future
                    final allItems = _parseAndSortScheduleItems(rawEvents, controller.selectedDate);
                    final activeItems = allItems.where((i) => !i.isPast).toList();
                    final pastItems = allItems.where((i) => i.isPast).toList();

                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF051123) : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFC5A880).withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Present and Future Events (Active, chronologically sorted with period headers)
                          if (activeItems.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(activeItems.length, (index) {
                                final item = activeItems[index];
                                final isLastItem = index == activeItems.length - 1 && pastItems.isEmpty;

                                bool showHeaderLabel = false;
                                if (index == 0) {
                                  showHeaderLabel = true;
                                } else {
                                  final priorItem = activeItems[index - 1];
                                  if (item.period != priorItem.period) {
                                    showHeaderLabel = true;
                                  }
                                }

                                return Column(
                                  key: ValueKey('active_${item.event.id}_$index'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showHeaderLabel)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: 16.h,
                                          top: index > 0 ? 16.h : 0,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              item.period,
                                              style: GoogleFonts.playfairDisplay(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20.sp,
                                                color: const Color(0xFFFFA500),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            if (item.isPresent) ...[
                                              AppSpacing.w8,
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFA500).withOpacity(0.18),
                                                  borderRadius: BorderRadius.circular(10.r),
                                                  border: Border.all(
                                                    color: const Color(0xFFFFA500).withOpacity(0.6),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6.w,
                                                      height: 6.h,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFFFFA500),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    AppSpacing.w4,
                                                    Text(
                                                      'HAPPENING NOW',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 10.sp,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFFFFA500),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    _buildScheduleEvent(
                                      context,
                                      item.event.id,
                                      item.event.title,
                                      item.displayTime,
                                      item.event.category_name ?? '',
                                      item.event.location,
                                      item.event.description,
                                      item.isPresent ? const Color(0xFFFFA500) : Colors.grey,
                                      isDarkMode,
                                      lightModeBackgroundColor: AppColors.l_schedule_clr1,
                                      isLastItem: isLastItem,
                                      isPresent: item.isPresent,
                                      isPast: false,
                                    ),
                                  ],
                                );
                              }),
                            ),

                          // If all scheduled events for today have concluded
                          if (activeItems.isEmpty && pastItems.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                              margin: EdgeInsets.only(bottom: 14.h),
                              decoration: BoxDecoration(
                                color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: const Color(0xFFC5A880).withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(7.r),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFA500).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: const Color(0xFFFFA500),
                                      size: 18.sp,
                                    ),
                                  ),
                                  AppSpacing.w10,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'All Caught Up!',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.sp,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'All scheduled events for today have concluded.',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12.sp,
                                            color: isDarkMode ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 2. Old Passed Events Section (Apple Notification Stack Collapse)
                          if (pastItems.isNotEmpty) ...[
                            if (activeItems.isNotEmpty) SizedBox(height: 8.h),
                            _buildApplePastEventsStack(
                              context: context,
                              pastItems: pastItems,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                AppSpacing.h30,
                Consumer<HomeController>(
                  builder: (context, homeController, child) {
                    final now = DateTime.now();
                    final isSelectedDateToday = homeController.selectedDate.year == now.year &&
                        homeController.selectedDate.month == now.month &&
                        homeController.selectedDate.day == now.day;
                    final currentIdx = homeController.currentQuoteIndex;
                    final currentQuote = homeController.inspirationalQuotes.isNotEmpty
                        ? homeController.inspirationalQuotes[currentIdx % homeController.inspirationalQuotes.length]
                        : null;

                    if (!isSelectedDateToday || currentQuote == null || currentQuote.quote.trim().isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final String quoteKeyStr = 'quote_capture_${currentIdx % homeController.inspirationalQuotes.length}';
                    final GlobalKey inspirationQuoteKey = GlobalObjectKey(quoteKeyStr);
                    final int randomImageNum = (Random(currentIdx).nextInt(11)) + 1;
                    final String prefix = isDarkMode ? 'db_' : 'wb_';
                    final String currentBgPath = AiImageAssets.getImage(isDark: isDarkMode, index: randomImageNum);

                    return Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        image: DecorationImage(
                          image: AssetImage(currentBgPath),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Inspirational Quote',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cormorant(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20.sp,
                                    color: AppColors.fourth_color,
                                  ),
                                ),
                              ),
                              AppSpacing.w8,
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.black26 : const Color(0xFFFFFAEE),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFFFB800).withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: const Color(0xFFFFB800),
                                      size: 12.sp,
                                    ),
                                    AppSpacing.w4,
                                    Text(
                                      currentQuote.name.isNotEmpty ? currentQuote.name : 'Motivation',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFE5A100),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.h18,
                          GestureDetector(
                            child: Container(
                              constraints: BoxConstraints(maxHeight: 180.h),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: const Color(0xFFFFB800),
                                    width: 3.5.w,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.only(left: 14.w),
                              child: DefaultTextStyle(
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                                child: homeController.inspirationalQuotes.isEmpty
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFFFA500),
                                        ),
                                      )
                                    : PageView.builder(
                                        key: ValueKey(homeController.inspirationalQuotes.length),
                                        controller: homeController.pageController,
                                        itemCount: homeController.inspirationalQuotes.length,
                                        onPageChanged: (index) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (context.mounted) {
                                              homeController.updateQuoteIndex(index);
                                            }
                                          });
                                        },
                                        itemBuilder: (context, index) {
                                          if (index >= homeController.inspirationalQuotes.length) {
                                            return const SizedBox.shrink();
                                          }
                                          final quote = homeController.inspirationalQuotes[index];
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: RepaintBoundary(
                                                  key: inspirationQuoteKey,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                                                    decoration: const BoxDecoration(),
                                                    child: Text(
                                                      quote.quote,
                                                      textAlign: TextAlign.start,
                                                      style: GoogleFonts.cormorant(
                                                        fontWeight: FontWeight.w400,
                                                        fontSize: 18.sp,
                                                        color: isDarkMode
                                                            ? AppColors.l_schedule_clr3
                                                            : Colors.black87.withOpacity(0.6),
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              AppSpacing.h10,
                                              Text(
                                                "— ${quote.reference}",
                                                style: GoogleFonts.playfair(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 16.sp,
                                                  color: isDarkMode ? Colors.white60 : Colors.black54,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ),
                          AppSpacing.h20,
                          Container(
                            padding: EdgeInsets.only(top: 14.h),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      homeController.toggleFavorite();
                                      final success = await homeController.saveQuoteToFavorite(eventId: 0);
                                      if (success) {
                                        await showMessageDialog(
                                          context,
                                          "Quote saved to favorites successfully!",
                                          title: "Success",
                                          icon: Icons.check_circle_outline,
                                          iconColor: Colors.green,
                                        );
                                      }
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          homeController.isFavorite
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: homeController.isFavorite
                                              ? Colors.red
                                              : (isDarkMode ? Colors.white : AppColors.fourth_color),
                                          size: 22.sp,
                                        ),
                                        AppSpacing.h4,
                                        Text(
                                          'Favorite',
                                          style: GoogleFonts.outfit(
                                            color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 24.h,
                                  width: 1,
                                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.12),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final success = await homeController.saveQuoteImageToGallery(
                                        inspirationQuoteKey,
                                        bgAssetPath: currentBgPath,
                                      );
                                      if (success) {
                                        await showMessageDialog(
                                          context,
                                          "Quote image saved to gallery!",
                                          title: "Success",
                                          icon: Icons.check_circle_outline,
                                          iconColor: Colors.green,
                                        );
                                      } else {
                                        await showMessageDialog(
                                          context,
                                          "Failed to save image.",
                                          title: "Error",
                                          icon: Icons.error_outline,
                                          iconColor: Colors.red,
                                        );
                                      }
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bookmark_border_rounded,
                                          color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                          size: 22.sp,
                                        ),
                                        AppSpacing.h4,
                                        Text(
                                          'Save',
                                          style: GoogleFonts.outfit(
                                            color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 24.h,
                                  width: 1,
                                  color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.12),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => homeController.shareQuoteAsImage(
                                      context,
                                      inspirationQuoteKey,
                                      bgAssetPath: currentBgPath,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.share_outlined,
                                          color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                          size: 22.sp,
                                        ),
                                        AppSpacing.h4,
                                        Text(
                                          'Share',
                                          style: GoogleFonts.outfit(
                                            color: isDarkMode ? Colors.white : AppColors.fourth_color,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                AppSpacing.h30,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Leave us a feedback',
                      style: GoogleFonts.playfair(
                        fontWeight: FontWeight.w600,
                        fontSize: 22.sp,
                        color: isDarkMode ? AppColors.l_schedule_clr3 : Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => showFeedbackDialog(
                        context,
                        isDarkMode,
                        homeController,
                      ),
                      child: Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.1) : AppColors.button_color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: AppColors.fourth_color.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(Icons.add, color: Colors.white, size: 20.sp),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h30,
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF051123) : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDarkMode ? const Color(0xFFC5A880).withOpacity(0.35) : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Unlock More Blessings',
                        style: GoogleFonts.cormorant(
                          fontWeight: FontWeight.bold,
                          fontSize: 22.sp,
                          color: const Color(0xFFFFA500),
                        ),
                      ),
                      AppSpacing.h16,
                      SvgPicture.asset(
                        IconAssets.premiumIcon,
                        width: 72.w,
                        height: 72.h,
                      ),
                      AppSpacing.h20,
                      GestureDetector(
                        onTap: () {
                          context.push('/subscription');
                        },
                        child: Container(
                          width: 160.w,
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B301),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: Text(
                              'Go Premium',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.h120,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer<HomeController>(
        builder: (context, controller, _) => CustomBottomNavBar(),
      ),
    );
  }

  // ===========================================================================
  // SCHEDULE DATA MODELS & PARSING HELPERS
  // ===========================================================================

  List<_HomeScheduleItem> _parseAndSortScheduleItems(
    List<EventModel> rawEvents,
    DateTime targetDate,
  ) {
    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final isPastDay = DateTime(targetDate.year, targetDate.month, targetDate.day)
        .isBefore(DateTime(now.year, now.month, now.day));
    final isFutureDay = DateTime(targetDate.year, targetDate.month, targetDate.day)
        .isAfter(DateTime(now.year, now.month, now.day));

    final List<_HomeScheduleItem> items = [];

    for (final event in rawEvents) {
      final start = _parseScheduleTime(targetDate, event.startTime, fallback: event.scheduledDateTime);
      DateTime end = _parseScheduleTime(targetDate, event.endTime, fallback: start.add(const Duration(hours: 1)));
      if (end.isBefore(start)) {
        end = start.add(const Duration(hours: 1));
      }

      bool isPast = false;
      bool isPresent = false;
      bool isFuture = false;

      if (isPastDay) {
        isPast = true;
      } else if (isFutureDay) {
        isFuture = true;
      } else if (isToday) {
        if (end.isBefore(now)) {
          isPast = true;
        } else if (start.isBefore(now) && end.isAfter(now)) {
          isPresent = true;
        } else {
          isFuture = true;
        }
      }

      final period = _getSchedulePeriod(start);
      final displayTime = _formatScheduleDisplayTime(start, end, event.startTime, event.endTime);

      items.add(
        _HomeScheduleItem(
          event: event,
          startDateTime: start,
          endDateTime: end,
          isPast: isPast,
          isPresent: isPresent,
          isFuture: isFuture,
          period: period,
          displayTime: displayTime,
        ),
      );
    }

    // Sort chronologically ascending
    items.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return items;
  }

  DateTime _parseScheduleTime(DateTime baseDate, String? timeStr, {DateTime? fallback}) {
    if (timeStr == null || timeStr.trim().isEmpty) {
      return fallback ?? baseDate;
    }
    final clean = timeStr.trim();

    // 12-hour AM/PM: e.g. "02:30 PM", "2:30 PM", "9:00 AM"
    final amPmMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM|am|pm)$', caseSensitive: false).firstMatch(clean);
    if (amPmMatch != null) {
      int hour = int.tryParse(amPmMatch.group(1)!) ?? 0;
      final int minute = int.tryParse(amPmMatch.group(2)!) ?? 0;
      final String period = amPmMatch.group(3)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    }

    // 24-hour military: e.g. "14:30", "09:00", "14:30:00"
    final militaryMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clean);
    if (militaryMatch != null) {
      final int hour = int.tryParse(militaryMatch.group(1)!) ?? 0;
      final int minute = int.tryParse(militaryMatch.group(2)!) ?? 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    }

    // Direct ISO
    final direct = DateTime.tryParse(clean);
    if (direct != null) {
      return DateTime(baseDate.year, baseDate.month, baseDate.day, direct.hour, direct.minute);
    }

    return fallback ?? baseDate;
  }

  String _formatScheduleDisplayTime(DateTime start, DateTime end, String rawStart, String rawEnd) {
    try {
      final startFmt = DateFormat('h:mm a').format(start);
      if (rawEnd.trim().isNotEmpty && end.isAfter(start)) {
        final endFmt = DateFormat('h:mm a').format(end);
        return '$startFmt - $endFmt';
      }
      return startFmt;
    } catch (_) {
      if (rawStart.isNotEmpty && rawEnd.isNotEmpty) {
        return '$rawStart - $rawEnd';
      }
      return rawStart.isNotEmpty ? rawStart : 'Scheduled';
    }
  }

  String _getSchedulePeriod(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) {
      return 'Morning';
    } else if (hour == 12) {
      return 'Noon';
    } else if (hour > 12 && hour < 17) {
      return 'Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Evening';
    } else {
      return 'Night';
    }
  }

  // ===========================================================================
  // APPLE NOTIFICATION COLLAPSED STACK
  // ===========================================================================

  Widget _buildApplePastEventsStack({
    required BuildContext context,
    required List<_HomeScheduleItem> pastItems,
    required bool isDarkMode,
  }) {
    if (pastItems.isEmpty) return const SizedBox.shrink();

    final int count = pastItems.length;
    final topEvent = pastItems.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apple-style collapse / expand toggle bar
        InkWell(
          onTap: () {
            setState(() {
              _isPastEventsExpanded = !_isPastEventsExpanded;
            });
          },
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 2.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 14.sp,
                        color: isDarkMode ? AppColors.fourth_color : AppColors.heading_color,
                      ),
                      AppSpacing.w6,
                      Text(
                        'Earlier Today ($count)',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.fourth_color : AppColors.heading_color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _isPastEventsExpanded ? 'Collapse' : 'Show stack',
                  style: GoogleFonts.outfit(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFFA500),
                  ),
                ),
                AppSpacing.w4,
                Icon(
                  _isPastEventsExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18.sp,
                  color: const Color(0xFFFFA500),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),

        // Apple Notification Collapse Deck
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeInCubic,
          crossFadeState: _isPastEventsExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: GestureDetector(
            onTap: () {
              setState(() {
                _isPastEventsExpanded = true;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Layer 3 (deepest card peek if 3+ items)
                if (count >= 3)
                  Positioned(
                    bottom: -16.h,
                    left: 20.w,
                    right: 20.w,
                    height: 40.h,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF03070E) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFC5A880).withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4.r,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Layer 2 (middle card peek if 2+ items)
                if (count >= 2)
                  Positioned(
                    bottom: -8.h,
                    left: 10.w,
                    right: 10.w,
                    height: 40.h,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF050B15) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFC5A880).withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4.r,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Topmost Front Card: the latest finished event
                _buildScheduleEvent(
                  context,
                  topEvent.event.id,
                  topEvent.event.title,
                  topEvent.displayTime,
                  topEvent.event.category_name ?? '',
                  topEvent.event.location,
                  topEvent.event.description,
                  Colors.grey,
                  isDarkMode,
                  lightModeBackgroundColor: AppColors.l_schedule_clr1,
                  isLastItem: true,
                  isPast: true,
                  badgeLabel: count > 1 ? '+${count - 1} earlier' : 'Passed',
                ),
              ],
            ),
          ),
          secondChild: Column(
            children: List.generate(pastItems.length, (index) {
              final item = pastItems[index];
              final isLast = index == pastItems.length - 1;
              return _buildScheduleEvent(
                context,
                item.event.id,
                item.event.title,
                item.displayTime,
                item.event.category_name ?? '',
                item.event.location,
                item.event.description,
                Colors.grey,
                isDarkMode,
                lightModeBackgroundColor: AppColors.l_schedule_clr1,
                isLastItem: isLast,
                isPast: true,
                badgeLabel: 'Passed',
              );
            }),
          ),
        ),
        SizedBox(height: _isPastEventsExpanded ? 0 : 20.h),
      ],
    );
  }

  // ===========================================================================
  // EVENT TILE BUILDER
  // ===========================================================================

  Widget _buildScheduleEvent(
    BuildContext context,
    int id,
    String title,
    String time,
    String category,
    String location,
    String subtitle,
    Color indicatorColor,
    bool isDarkMode, {
    Color? lightModeBackgroundColor,
    bool isLastItem = false,
    bool isPast = false,
    bool isPresent = false,
    String? badgeLabel,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24.w,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLastItem)
                  Positioned(
                    top: 6.h,
                    bottom: 0,
                    child: Container(
                      width: 1.5.w,
                      color: isPast
                          ? (isDarkMode ? Colors.white12 : Colors.black12)
                          : const Color(0xFFC5A880).withOpacity(0.35),
                    ),
                  ),
                Positioned(
                  top: 6.h,
                  left: 6.w,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: isPresent
                              ? const Color(0xFFFFA500)
                              : isPast
                                  ? Colors.grey.shade600
                                  : const Color(0xFFFFA500),
                          shape: BoxShape.circle,
                          boxShadow: isPast
                              ? null
                              : [
                                  BoxShadow(
                                    color: isPresent
                                        ? const Color(0xFFFFA500).withOpacity(0.6)
                                        : const Color(0xFFFFA500).withOpacity(0.4),
                                    blurRadius: isPresent ? 8.r : 6.r,
                                    spreadRadius: isPresent ? 2.r : 1.r,
                                  ),
                                ],
                        ),
                      ),
                      Container(
                        width: 6.w,
                        height: 1.5.h,
                        color: isPast
                            ? (isDarkMode ? Colors.white12 : Colors.black12)
                            : const Color(0xFFC5A880).withOpacity(0.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    context.push('/event_details', extra: id);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: isPresent
                          ? (isDarkMode ? const Color(0xFF0C192E) : const Color(0xFFFFFBF2))
                          : isPast
                              ? (isDarkMode ? const Color(0xFF060D18) : Colors.grey.withOpacity(0.04))
                              : (isDarkMode ? const Color(0xFF09121F) : Colors.grey.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isPresent
                            ? const Color(0xFFFFA500).withOpacity(0.55)
                            : isPast
                                ? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06))
                                : const Color(0xFFC5A880).withOpacity(0.2),
                        width: isPresent ? 1.2 : 1,
                      ),
                      image: isPast
                          ? null
                          : DecorationImage(
                              image: AssetImage(
                                isDarkMode ? ImageAssets.containerBgm : ImageAssets.containerBgmLight,
                              ),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.15),
                                      ),
                                    ),
                                    child: Text(
                                      category.isEmpty ? 'General' : category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: isPast ? const Color(0xFF5A6B7E) : const Color(0xFF7A8B9E),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isPresent) ...[
                                    AppSpacing.w6,
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFA500).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10.r),
                                        border: Border.all(
                                          color: const Color(0xFFFFA500).withOpacity(0.6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 5.w,
                                            height: 5.h,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFFA500),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          AppSpacing.w4,
                                          Text(
                                            'NOW',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFFFA500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (isPast && badgeLabel != null) ...[
                                    AppSpacing.w6,
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Text(
                                        badgeLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode ? Colors.white60 : Colors.black45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            AppSpacing.w8,
                            Text(
                              time,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5.sp,
                                color: isPresent
                                    ? const Color(0xFFFFA500)
                                    : isPast
                                        ? (isDarkMode ? Colors.white54 : Colors.black45)
                                        : const Color(0xFFFFA500),
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.h12,
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: isPast
                                ? (isDarkMode ? Colors.white60 : Colors.black54)
                                : (isDarkMode ? Colors.white : Colors.black),
                          ),
                        ),
                        if (location.isNotEmpty && location.toLowerCase() != 'unknown') ...[
                          AppSpacing.h8,
                          Row(
                            children: [
                              Text('📍', style: TextStyle(fontSize: 14.sp)),
                              AppSpacing.w6,
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14.sp,
                                    color: isPast
                                        ? (isDarkMode ? Colors.white54 : Colors.black54)
                                        : (isDarkMode ? Colors.white70 : Colors.black),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (subtitle.isNotEmpty) ...[
                          AppSpacing.h4,
                          Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: isPast ? const Color(0xFF5A6B7E) : const Color(0xFF7A8B9E),
                                size: 14.sp,
                              ),
                              AppSpacing.w6,
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14.sp,
                                    color: isPast
                                        ? (isDarkMode ? Colors.white38 : Colors.black38)
                                        : (isDarkMode ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                isLastItem ? AppSpacing.empty : AppSpacing.h16,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}

/// Helper model for parsed, validated, and chronologically sorted schedule items
class _HomeScheduleItem {
  final EventModel event;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isPast;
  final bool isPresent;
  final bool isFuture;
  final String period;
  final String displayTime;

  const _HomeScheduleItem({
    required this.event,
    required this.startDateTime,
    required this.endDateTime,
    required this.isPast,
    required this.isPresent,
    required this.isFuture,
    required this.period,
    required this.displayTime,
  });
}
