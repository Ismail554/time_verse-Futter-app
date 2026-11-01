// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/core/utils/asset_manager.dart';
import 'package:time_verse/core/utils/colors.dart';

// class EventCard extends StatelessWidget {
//   final int id;
//   final String title;
//   final String sub_title;
//   final String date;
//   final String time;
//   final String location;
//   final VoidCallback onDelete;
//   final VoidCallback onEdit;
//   final bool isDarkMode;

//   const EventCard({
//     super.key,
//     required this.id,
//     required this.sub_title,
//     required this.title,
//     required this.date,
//     required this.time,
//     required this.location,
//     required this.onDelete,
//     required this.onEdit,
//     required this.isDarkMode,
//   });

//   @override
//   Widget build(BuildContext context) {
//     bool isValidLocation(String loc) {
//       final clean = loc.trim().toLowerCase();
//       if (clean.isEmpty || clean == 'unknown') return false;
//       if (clean.endsWith('@google.com')) return false;
//       return true;
//     }
//     return GestureDetector(
//       onTap: () {
//         context.push('/event_details', extra: id);
//       },
//       child: Container(
//         width: double.infinity,
//         decoration: BoxDecoration(
//           color: isDarkMode ? AppColors.containers_bgd : Colors.white,
//           borderRadius: BorderRadius.circular(12.r),
//           border: Border.all(color: AppColors.third_color),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             SvgPicture.asset(
//                               IconAssets.tittleIcon,
//                               height: 23.sp,
//                               width: 23.sp,
//                             ),
//                             Text(
//                               title,
//                               style: GoogleFonts.cormorant(
//                                 fontWeight: FontWeight.w700,
//                                 fontSize: 16.sp,
//                                 color: isDarkMode ? AppColors.text_color: const Color(0xFF353535),
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                               maxLines: 1,
//                             ),
//                           ],
//                         ),
//                         AppSpacing.h10,
//                         Text(
//                           sub_title,
//                           style: GoogleFonts.outfit(
//                             fontWeight: FontWeight.w500,
//                             fontSize: 12.sp,
//                             color: isDarkMode
//                             ? AppColors.text_color: const Color(0xFF353535),
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                           maxLines: 1,
//                         ),
//                       ],
//                     ),
//                   ),
//                   AppSpacing.w8,
//                   GestureDetector(
//                     onTap: onEdit,
//                     child: Icon(
//                       Icons.edit_outlined,
//                       size: 22.sp,
//                       color: isDarkMode ? AppColors.text_color : const Color(0xFF353535),
//                     ),
//                   ),
//                   AppSpacing.w10,
//                   GestureDetector(
//                     onTap: onDelete,
//                     child: SvgPicture.asset(
//                       IconAssets.deleteIcon,
//                       width: 30.w,
//                       height: 30.h,
//                     ),
//                   ),
//                 ],
//               ),
//               AppSpacing.h10,
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   SvgPicture.asset(
//                     IconAssets.today,
//                     width: 15.w,
//                     height: 15.h,
//                   ),
//                   AppSpacing.w10,
//                   Text(
//                     date,
//                     style: GoogleFonts.outfit(
//                       fontWeight: FontWeight.w500,
//                       fontSize: 12.sp,
//                       color: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
//                     ),
//                   ),
//                 ],
//               ),
//               AppSpacing.h15,
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   SvgPicture.asset(
//                     IconAssets.clockIcon,
//                     width: 15.w,
//                     height: 15.h,
//                   ),
//                   AppSpacing.w15,
//                   Text(
//                     time,
//                     style: GoogleFonts.outfit(
//                       fontWeight: FontWeight.w500,
//                       fontSize: 12.sp,
//                       color: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
//                     ),
//                   ),
//                 ],
//               ),
//               if (isValidLocation(location)) ...[
//                 AppSpacing.h15,
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   children: [
//                     SvgPicture.asset(
//                       IconAssets.pin,
//                       width: 20.w,
//                       height: 20.h,
//                     ),
//                     AppSpacing.w10,
//                     Expanded(
//                       child: Text(
//                         location,
//                         style: GoogleFonts.outfit(
//                           fontWeight: FontWeight.w500,
//                           fontSize: 12.sp,
//                           color: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//               AppSpacing.h10,
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

class EventCard extends StatelessWidget {
  final int id;
  final String title;
  final String sub_title;
  final String date;
  final String time;
  final String location;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final bool isDarkMode;

  const EventCard({
    super.key,
    required this.id,
    required this.sub_title,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.onDelete,
    required this.onEdit,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    bool isValidLocation(String loc) {
      final clean = loc.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'unknown') return false;
      if (clean.toLowerCase().endsWith('@google.com')) return false;

      // Checks if location is a single long alphanumeric string (Google ID format)
      final isGoogleId = !clean.contains(' ') &&
          clean.length >= 20 &&
          RegExp(r'^[a-zA-Z0-9]+$').hasMatch(clean);

      return !isGoogleId;
    }

    return GestureDetector(
      onTap: () {
        context.push('/event_details', extra: id);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.containers_bgd : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.third_color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              IconAssets.tittleIcon,
                              height: 23.sp,
                              width: 23.sp,
                            ),
                            Text(
                              title,
                              style: GoogleFonts.cormorant(
                                fontWeight: FontWeight.w700,
                                fontSize: 16.sp,
                                color: isDarkMode ? AppColors.text_color: const Color(0xFF353535),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                        AppSpacing.h10,
                        Text(
                          sub_title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: 12.sp,
                            color: isDarkMode
                            ? AppColors.text_color: const Color(0xFF353535),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.w8,
                  GestureDetector(
                    onTap: onEdit,
                    child: Icon(
                      Icons.edit_outlined,
                      size: 22.sp,
                      color: isDarkMode ? AppColors.text_color : const Color(0xFF353535),
                    ),
                  ),
                  AppSpacing.w10,
                  GestureDetector(
                    onTap: onDelete,
                    child: SvgPicture.asset(
                      IconAssets.deleteIcon,
                      width: 30.w,
                      height: 30.h,
                    ),
                  ),
                ],
              ),
              AppSpacing.h10,
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    IconAssets.today,
                    width: 15.w,
                    height: 15.h,
                  ),
                  AppSpacing.w10,
                  Text(
                    date,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: 12.sp,
                      color: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
                    ),
                  ),
                ],
              ),
              AppSpacing.h15,
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    IconAssets.clockIcon,
                    width: 15.w,
                    height: 15.h,
                  ),
                  AppSpacing.w15,
                  Text(
                    time,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: 12.sp,
                      color: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
                    ),
                  ),
                ],
              ),
              if (isValidLocation(location)) ...[
                AppSpacing.h15,
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      IconAssets.pin,
                      width: 20.w,
                      height: 20.h,
                    ),
                    AppSpacing.w10,
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w500,
                          fontSize: 12.sp,
                          color: isDarkMode ? AppColors.text_color : const Color(0xFF373F4B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              AppSpacing.h10,
            ],
          ),
        ),
      ),
    );
  }
}