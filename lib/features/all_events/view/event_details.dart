// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
import 'dart:math';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/core/components/custom_bottomnav.dart';
import 'package:time_verse/core/components/custom_button.dart';
import 'package:time_verse/core/components/custom_header.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';
import 'package:time_verse/features/all_events/controller/event_details_controller.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';


class EventDetails extends StatelessWidget {
  final int eventId;
  final EventModel? initialEvent;

  const EventDetails({
    super.key,
    required this.eventId,
    this.initialEvent,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final eventController = Provider.of<EventController>(context, listen: false);

    return Scaffold(
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: () async {
          await eventController.fetchEventDetailsById(
            eventId,
            forceRefresh: true,
            fallbackEvent: initialEvent,
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: FutureBuilder<EventModel?>(
            future: eventController.fetchEventDetailsById(
              eventId,
              fallbackEvent: initialEvent,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoading(context, isDarkMode);
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 80.0.h),
                  child: Center(
                    child: Text(
                      'Failed to load event details.',
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                );
              }

              final eventDetail = snapshot.data!;
              final String currentQuoteText = eventDetail.description.isNotEmpty ? eventDetail.description
              : 'Every journey towards family weaves new tales in the tapestry of our souls, binding us closer with each step.';

              // 2. Deterministic background selection using the quote hash
              final int randomSeed = currentQuoteText.hashCode;
              final int randomImageNum = (Random(randomSeed).nextInt(11)) + 1;
              final String prefix = isDarkMode ? 'db_' : 'wb_';
              final String currentBgPath = AiImageAssets.getImage(isDark: isDarkMode, index: randomImageNum);

              final displayDate = _formatDisplayDate(eventDetail.date);
              final displayTime = _formatTimeWithoutSeconds(eventDetail.startTime);

              final String dateTimeText;
              if (displayDate.isNotEmpty && displayTime.isNotEmpty) {
                dateTimeText = '$displayDate • $displayTime';
              } else if (displayDate.isNotEmpty) {
                dateTimeText = displayDate;
              } else if (displayTime.isNotEmpty) {
                dateTimeText = displayTime;
              } else {
                dateTimeText = '';
              }
              
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 40.0.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomHeaderBar(
                      title: "Share Quote",
                      leftSpacing: 80,
                      rightSpacing: 80,
                      onBackPressed: () => context.go('/home'),
                    ),
                    AppSpacing.h20,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        width: 327.w,
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF0A1128) : Colors.white,
                          gradient: isDarkMode ? const LinearGradient(
                            colors: [Color(0xFF0A1128), Color(0xFF1A1F3A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                          image: DecorationImage(
                            image: AssetImage(currentBgPath),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFB703).withOpacity(0.4),
                            width: 1.w,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppSpacing.h20,
                              Text(
                                eventDetail.title.isNotEmpty ? eventDetail.title : 'Event Details',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfair(
                                  fontSize: 27.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              if (dateTimeText.isNotEmpty) ...[
                                AppSpacing.h6,
                                Text(
                                  dateTimeText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? const Color(0xFF9CA3AF) : Colors.black,
                                  ),
                                ),
                              ],
                              AppSpacing.h14,
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1.h,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            const Color(0xFFFFB703).withOpacity(0.5)
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                                    child: SvgPicture.asset(
                                      IconAssets.sparkle,
                                      width: 12.w,
                                      height: 12.h,
                                      colorFilter: const ColorFilter.mode(
                                      Color(0xFFFFB703), BlendMode.srcIn),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1.h,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFFFB703).withOpacity(0.5),
                                            Colors.transparent
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.h24,
                              RepaintBoundary(
                                key: eventController.quoteShareKey,
                                child: Text(
                                  currentQuoteText.isNotEmpty ? '“ $currentQuoteText ”' : '',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cormorant(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? Colors.white: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              AppSpacing.h24,
                              Text(
                                'Inspired by InfiniQoute',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.h24,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomButton(
                          text: "Save",
                          onPressed: () async {
                            await eventController.shareQuoteAsImage(currentQuoteText, currentBgPath);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Quote saved as image!')),
                              );
                            }
                          },
                          borderGradient: AppGradientColors.button_gradient,
                          solidColor: isDarkMode ? AppColors.containers_bgd : AppColors.background_color,
                          textColor: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
                          fontFamily: 'outfit',
                          fontSize: 16.sp,
                          height: 48.h,
                          width: 159.w,
                          leadingIcon: SvgPicture.asset(
                            IconAssets.download,
                            width: 18.w,
                            height: 18.h,
                            colorFilter: ColorFilter.mode(
                              isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        AppSpacing.w10,
                        CustomButton(
                          text: "Share",
                          onPressed: () {
                            eventController.shareQuoteToSocialMedia(currentQuoteText, currentBgPath);
                          },
                          gradient: AppGradientColors.button_gradient,
                          textColor: AppColors.text_color,
                          fontFamily: 'outfit',
                          fontSize: 16.sp,
                          height: 48.h,
                          width: 159.w,
                          leadingIcon: SvgPicture.asset(
                            IconAssets.shareFilled,
                            width: 18.w,
                            height: 18.h,
                            colorFilter: const ColorFilter.mode(
                              AppColors.text_color,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h24,
                    TextButton(
                      onPressed: () => context.push('/all_events'),
                      child: Text(
                        'Explore more quotes  →',
                        style: GoogleFonts.outfit(
                          fontSize: 16.sp,
                          color: isDarkMode ? AppColors.background_color : AppColors.heading_color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  Widget _buildShimmerLoading(BuildContext context, bool isDarkMode) {
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 40.0.h),
      child: Column(
        children: [
          CustomHeaderBar(
            title: "Share Quote",
            leftSpacing: 80,
            rightSpacing: 80,
            onBackPressed: () => context.go('/home'),
          ),
          AppSpacing.h20,
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: 327.w,
              height: 420.h,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeWithoutSeconds(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';

    // Check for 12-hour formats e.g. "02:30:00 PM", "2:30:00 PM", "02:30 PM", "2:30 PM"
    for (final pattern in ['h:mm:ss a', 'hh:mm:ss a', 'h:mm a', 'hh:mm a']) {
      try {
        final dt = DateFormat(pattern).parse(clean);
        return DateFormat('h:mm a').format(dt);
      } catch (_) {}
    }

    // Check for 24-hour formats e.g. "14:30:00", "09:15:00", "14:30"
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1].split(' ')[0]);
      if (hour != null && minute != null) {
        final dt = DateTime(2000, 1, 1, hour, minute);
        return DateFormat('h:mm a').format(dt);
      }
    }

    return clean;
  }

  String _formatDisplayDate(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';

    final parsed = DateTime.tryParse(clean);
    if (parsed != null) {
      return DateFormat('MMM d, yyyy').format(parsed);
    }
    return clean;
  }
}