import 'package:alarm/model/alarm_settings.dart';
import 'package:go_router/go_router.dart';
import 'package:time_verse/config/app_route/page_transitions.dart';
import 'package:time_verse/core/components/alarm.dart';
import 'package:time_verse/features/all_events/model/event_model.dart';
import 'package:time_verse/features/all_events/view/all_events.dart';
import 'package:time_verse/features/all_events/view/event_details.dart';
import 'package:time_verse/features/auth/forgot_passowrd/view/forgot_password.dart';
import 'package:time_verse/features/auth/login/view/login.dart';
import 'package:time_verse/features/auth/otp/view/otp_view.dart';
import 'package:time_verse/features/auth/reset_password/view/reset_password.dart';
import 'package:time_verse/features/auth/signup/view/signup.dart';
import 'package:time_verse/features/calender/view/add_event.dart';
import 'package:time_verse/features/calender/view/calender_view.dart';
import 'package:time_verse/features/edit_event/view/edit_event_view.dart';
import 'package:time_verse/features/home/view/home_view.dart';
import 'package:time_verse/features/lending/view/lending.dart';
import 'package:time_verse/features/qoutation/saved_qoutation/view/saved_qoutatio.dart';
import 'package:time_verse/features/settings/change_password/view/change_password.dart';
import 'package:time_verse/features/settings/delete_account/view/delete_account.dart';
import 'package:time_verse/features/settings/notification/view/notification.dart';
import 'package:time_verse/features/settings/privacy/view/privacy.dart';
import 'package:time_verse/features/settings/profile/view/profile.dart';
import 'package:time_verse/features/settings/settings.dart';
import 'package:time_verse/features/settings/subscription/controller/subscription_controller.dart';
import 'package:time_verse/features/settings/subscription/view/subscription.dart';
import 'package:time_verse/features/settings/terms_condition/view/terms_&_condition.dart';
import 'package:time_verse/features/splash_screen/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => buildFadeTransitionPage(
        context: context,
        state: state,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: '/landing',
      pageBuilder: (context, state) => buildFadeTransitionPage(
        context: context,
        state: state,
        child: const LandingScreen(),
      ),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: Signup(),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: '/forgot_pass',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const ForgotPassword(),
      ),
    ),
    GoRoute(
      path: '/otp',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const OtpView(),
      ),
    ),
    GoRoute(
      path: '/reset_password',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const ResetPassword(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const Settings(),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const Profile(),
      ),
    ),
    GoRoute(
      path: '/change_password',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const ChangePassword(),
      ),
    ),
    GoRoute(
      path: '/privacy_policy',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const Privacy(),
      ),
    ),
    GoRoute(
      path: '/terms_and_condition',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const TermsAndCondition(),
      ),
    ),
    GoRoute(
      path: '/notification',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const NotificationsScreen(),
      ),
    ),
    GoRoute(
      path: '/delete_account',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const DeleteAccount(),
      ),
    ),
    GoRoute(
      path: '/subscription',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: Subscription(controller: SubscriptionController()),
      ),
    ),
    GoRoute(
      path: '/saved',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: SavedQoutation(),
      ),
    ),
    GoRoute(
      path: '/all_events',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const AllEvents(),
      ),
    ),
    GoRoute(
      path: '/event_details',
      pageBuilder: (context, state) {
        int eventId = 0;
        EventModel? event;
        if (state.extra is int) {
          eventId = state.extra as int;
        } else if (state.extra is EventModel) {
          event = state.extra as EventModel;
          eventId = event.id;
        } else if (state.extra is String) {
          eventId = int.tryParse(state.extra as String) ?? 0;
        }
        return buildAppTransitionPage(
          context: context,
          state: state,
          child: EventDetails(eventId: eventId, initialEvent: event),
        );
      },
    ),
    GoRoute(
      path: '/calender',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const CalenderView(),
      ),
    ),
    GoRoute(
      path: '/calendar',
      redirect: (_, __) => '/calender',
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: HomeView(),
      ),
    ),
    GoRoute(
      path: '/add',
      pageBuilder: (context, state) => buildAppTransitionPage(
        context: context,
        state: state,
        child: const AddEventPage(),
      ),
    ),
    GoRoute(
      path: '/edit_event',
      pageBuilder: (context, state) {
        final extra = state.extra;
        final String eventId = extra is EventModel
            ? extra.id.toString()
            : (extra?.toString() ?? '');

        return buildAppTransitionPage(
          context: context,
          state: state,
          child: EditEventPage(eventId: eventId),
        );
      },
    ),
    GoRoute(
      path: '/alarm',
      pageBuilder: (context, state) {
        final alarm = state.extra as AlarmSettings;
        return buildFadeTransitionPage(
          context: context,
          state: state,
          child: ExampleAlarmRingScreen(alarmSettings: alarm),
        );
      },
    ),
  ],
);
