// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:time_verse/core/components/bottom_card_controller/bottom_card_controller.dart';
import 'package:time_verse/core/components/custom_bottomnav.dart';
import 'package:time_verse/core/components/custom_header.dart';
import 'package:time_verse/core/utils/app_spacing.dart';
import 'package:time_verse/features/all_events/controller/all_events.dart';
import 'package:time_verse/features/all_events/custom_widget/custom_eventcard.dart';
import 'package:time_verse/features/all_events/custom_widget/event_remove_modal.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';

class AllEvents extends StatelessWidget {
  const AllEvents({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final controller = Provider.of<AllEventsController>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.events.isEmpty) {
        controller.fetchAllEvents();
      }
      context.read<BottomNavController>().updateIndexFromRoute(location);
    });

    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
        child: Column(
          children: [
            CustomHeaderBar(
              title: 'All Events',
              leftSpacing: 100,
              rightSpacing: 70,
            ),
            Consumer<AllEventsController>(
              builder: (context, controller, _) {
                final events = List<EventModel>.from(controller.events);
                // Sort chronologically by scheduled date/time
                events.sort((a, b) {
                  final dtA = a.scheduledDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final dtB = b.scheduledDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return dtA.compareTo(dtB);
                });

                if (events.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note, size: 56.sp, color: Colors.white24),
                          AppSpacing.h16,
                          Text(
                            'No events found',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AppSpacing.h8,
                          Text(
                            'Add events from Calendar or sync with Google',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final EventModel event = events[index];

                      return Dismissible(
                        key: ValueKey(event.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          final completer = Completer<bool>();
                          showRemoveEventDialog(
                            context,
                            onConfirm: () {
                              controller.runWithLoaderAndTimer<bool>(
                                context: context,
                                task: () => controller.removeEventFromList(
                                  event,
                                  deleteType: 'single',
                                ),
                              ).then((success) {
                                completer.complete(success == true);
                              });
                            },
                          );
                          return await completer.future.catchError((_) => false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: EventCard(
                            id: event.id,
                            title: event.title,
                            sub_title: event.description,
                            date: event.date,
                            time: event.startTime.isNotEmpty && event.endTime.isNotEmpty
                                ? '${event.startTime}-${event.endTime}'
                                : event.startTime,
                            location: event.category == 'Google Calendar' ? '' : event.location,
                            isDarkMode: isDarkMode,
                            onEdit: () {
                              context.push('/edit_event', extra: event);
                            },
                            onDelete: () {
                              showRemoveEventDialog(
                                context,
                                onConfirm: () {
                                  controller.runWithLoaderAndTimer<bool>(
                                    context: context,
                                    task: () => controller.removeEventFromList(
                                      event,
                                      deleteType: 'single',
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<AllEventsController>(
        builder: (context, controller, _) => const CustomBottomNavBar(),
      ),
    );
  }
}
