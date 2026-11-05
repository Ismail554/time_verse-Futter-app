import 'package:dio/dio.dart';
import 'package:time_verse/core/network/network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:time_verse/config/app_route/app_prefernce.dart';
import 'package:time_verse/config/services/user_session.dart';
import 'package:time_verse/features/auth/auth_service/auth_service.dart';

class GoogleServices {
  static final GoogleServices _instance = GoogleServices._internal();
  factory GoogleServices() => _instance;
  GoogleServices._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _currentUser;
  final String serverClientId = '468767271373-igakn4plmbu2io7ocqph0miemm38lumq.apps.googleusercontent.com';
  String? _accessToken;
  String? get accessToken => _accessToken;

  final List<String> scopes = [
    'email',
    'profile',
    'openid',
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  void init() {
    _googleSignIn.initialize(
      serverClientId: serverClientId,
    );
  }

  Future<String?> getValidAccessToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken;
    }
    try {
      if (_currentUser != null) {
        final auth = await _currentUser!.authorizationClient.authorizeScopes(scopes);
        _accessToken = auth.accessToken;
        return _accessToken;
      }

      final savedGoogleToken = await AppPrefs.getGoogleToken();
      if (savedGoogleToken != null && savedGoogleToken.isNotEmpty) {
        _accessToken = savedGoogleToken;
        return _accessToken;
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error retrieving access token: $e");
      return null;
    }
  }

  /// Obtains a fresh Google ID token for re-authentication (e.g. required for account deletion per ADV-04)
  Future<String?> getFreshIdToken() async {
    try {
      final user = _currentUser ?? await _googleSignIn.authenticate();
      final auth = user.authentication;
      return auth.idToken;
    } catch (e) {
      debugPrint("⚠️ Error acquiring fresh Google ID token: $e");
      return null;
    }
  }

  Future<bool> signIn() async {
    try {
      await signOut();

      final user = await _googleSignIn.authenticate();
      _currentUser = user;

      final authentication = _currentUser!.authentication;
      final idToken = authentication.idToken;

      final auth = await _currentUser!.authorizationClient.authorizeScopes(scopes);
      _accessToken = auth.accessToken;

      final serverAuth = await _currentUser!.authorizationClient.authorizeServer(scopes);
      final String? serverAuthCode = serverAuth?.serverAuthCode;

      UserSession().username = _currentUser!.displayName;
      UserSession().profileImageUrl = _currentUser!.photoUrl;

      await AppPrefs.saveGoogleUser(
        _currentUser!.displayName ?? '',
        _currentUser!.email,
        photoUrl: _currentUser!.photoUrl,
      );

      if (idToken != null) {
        final apiSuccess = await sendTokensToApi(
          idToken: idToken,
          serverAuthCode: serverAuthCode,
        );
        if (!apiSuccess) {
          debugPrint("⚠️ Backend token exchange did not succeed.");
          await signOut();
          return false;
        }
      }

      debugPrint("✅ Google Sign-In Success for: ${_currentUser!.displayName}");
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled by user') || errorStr.contains('16:')) {
        debugPrint("ℹ️ Google Sign-In was canceled by the user.");
        await signOut();
        return false;
      }

      debugPrint("❌ Google Sign-In error: $e");
      await signOut();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _accessToken = null;
    } catch (e) {
      debugPrint("Error signing out Google: $e");
    }
  }

  Future<bool> sendTokensToApi({required String idToken, String? serverAuthCode}) async {
    try {
      final dio = createDio();
      final baseurl = dotenv.env['BASE_URL'];
      final String url = '${baseurl}api/v1/auth/login/idtoken/';

      final response = await dio.post(
        url,
        data: {
          'id_token': idToken,
          if (serverAuthCode != null && serverAuthCode.isNotEmpty)
            'auth_code': serverAuthCode,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Dual-key compatibility per Backend v2.1.0 (Section 6.2 & 8.1.3)
        final backendAccessToken = data['access'] ?? data['access_token'];
        final backendRefreshToken = data['refresh'] ?? data['refresh_token'];

        if (backendAccessToken != null) {
          await AuthService().saveToken(
            backendAccessToken.toString(),
            backendRefreshToken?.toString(),
          );
          await AppPrefs.setLoggedIn(true);
          await AppPrefs.setGoogleLogin(true);

          // Save Google OAuth token for client calendar read requests
          if (_accessToken != null && _accessToken!.isNotEmpty) {
            await AppPrefs.saveGoogleToken(_accessToken!);
          }

          final userData = data['user'];
          final name = userData?['name'] ?? data['name'] ?? _currentUser?.displayName;
          final picture = userData?['profile_picture'] ?? data['picture'] ?? _currentUser?.photoUrl;
          final userId = userData?['id']?.toString();

          if (userId != null) UserSession().userId = userId;
          if (name != null) UserSession().username = name.toString();
          if (picture != null) UserSession().profileImageUrl = picture.toString();

          debugPrint('✅ Google login successful and tokens stored.');
          return true;
        }
      } else {
        debugPrint('⚠️ Unexpected status code: ${response.statusCode}');
      }
      return false;
    } on DioException catch (e) {
      debugPrint('❌ Error sending tokens: ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Exception in sendTokensToApi: $e');
      return false;
    }
  }

  String? _buildGoogleRRule(String? repeat, Map<String, dynamic>? customRepeat) {
    if (repeat == null || repeat.isEmpty || repeat == "Don't repeat") return null;

    final rule = repeat.toLowerCase().trim();

    if (rule == 'every 1 day' || rule == '1 day') return 'RRULE:FREQ=DAILY;COUNT=7';
    if (rule == 'every 1 week' || rule == '1 week') return 'RRULE:FREQ=WEEKLY;COUNT=4';
    if (rule == 'every 1 month' || rule == '1 month') return 'RRULE:FREQ=MONTHLY;COUNT=12';
    if (rule == 'every 1 year' || rule == '1 year') return 'RRULE:FREQ=YEARLY;COUNT=5';

    if (rule == 'custom' && customRepeat != null) {
      final unit = customRepeat['repeat_unit']?.toString().toUpperCase() ?? 'WEEKLY';
      final interval = customRepeat['repeat_every'] ?? 1;
      String freq = 'WEEKLY';

      if (unit.contains('DAY')) {
        freq = 'DAILY';
      } else if (unit.contains('MONTH')) {
        freq = 'MONTHLY';
      } else if (unit.contains('YEAR')) {
        freq = 'YEARLY';
      }

      String rrule = 'RRULE:FREQ=$freq;INTERVAL=$interval';

      final days = customRepeat['repeat_days'] as List?;
      if (days != null && days.isNotEmpty) {
        final dayMap = {
          'S': 'SU', 'M': 'MO', 'T': 'TU', 'W': 'WE', 'TH': 'TH', 'F': 'FR', 'SAT': 'SA',
          '0': 'SU', '1': 'MO', '2': 'TU', '3': 'WE', '4': 'TH', '5': 'FR', '6': 'SA', '7': 'SU',
          'SU': 'SU', 'MO': 'MO', 'TU': 'TU', 'WE': 'WE', 'FR': 'FR', 'SA': 'SA',
        };
        final mappedDays = days.map((d) => dayMap[d.toString().trim().toUpperCase()] ?? 'MO').join(',');
        rrule += ';BYDAY=$mappedDays';
      }

      if (customRepeat['ends'] == 'on' && customRepeat['end_date'] != null) {
        final rawEndDateStr = customRepeat['end_date'].toString();
        final parsed = DateTime.tryParse(rawEndDateStr);
        if (parsed != null) {
          final endOfDayUtc = DateTime.utc(parsed.year, parsed.month, parsed.day, 23, 59, 59);
          final formattedEnd = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(endOfDayUtc);
          rrule += ';UNTIL=$formattedEnd';
        }
      } else if (customRepeat['ends'] == 'after' && customRepeat['end_count'] != null) {
        rrule += ';COUNT=${customRepeat['end_count']}';
      }

      return rrule;
    }

    return null;
  }

  Future<void> createGoogleCalendarEvent({
    required String accessToken,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    String? description,
    String? location,
    String? alarmTimeISO,
    String? repeat,
    Map<String, dynamic>? customRepeat,
  }) async {
    final cleanStart = startTime.split(':').length == 2 ? "$startTime:00" : startTime;
    var cleanEnd = endTime.split(':').length == 2 ? "$endTime:00" : endTime;

    String userTimeZone = 'UTC';
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      if (tz.identifier.contains('/')) {
        userTimeZone = tz.identifier;
      } else {
        userTimeZone = DateTime.now().timeZoneName;
      }
    } catch (e) {
      debugPrint("⚠️ Could not fetch IANA timezone: $e");
      userTimeZone = DateTime.now().timeZoneName;
    }

    final parts = date.split('-');
    final int year = parts.length == 3 ? int.parse(parts[0]) : DateTime.now().year;
    final int month = parts.length == 3 ? int.parse(parts[1]) : DateTime.now().month;
    final int day = parts.length == 3 ? int.parse(parts[2]) : DateTime.now().day;

    final startParts = cleanStart.split(':').map(int.parse).toList();
    final endParts = cleanEnd.split(':').map(int.parse).toList();

    final startDt = DateTime.utc(year, month, day, startParts[0], startParts[1]);
    var endDt = DateTime.utc(year, month, day, endParts[0], endParts[1]);

    if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
      endDt = startDt.add(const Duration(minutes: 30));
    }

    final String startIso = "${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(startDt)}Z";
    final String endIso = "${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(endDt)}Z";

    final rrule = _buildGoogleRRule(repeat, customRepeat);

    final body = {
      "summary": title,
      "description": description ?? "",
      "location": location ?? "",
      "start": {
        "dateTime": startIso,
        "timeZone": userTimeZone,
      },
      "end": {
        "dateTime": endIso,
        "timeZone": userTimeZone,
      },
      if (rrule != null) "recurrence": [rrule],
      "reminders": {
        "useDefault": false,
        "overrides": [
          {"method": "popup", "minutes": 15},
        ],
      },
    };

    try {
      final dio = createDio();
      final response = await dio.post(
        "https://www.googleapis.com/calendar/v3/calendars/primary/events",
        data: body,
        options: Options(
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ Google Calendar recurring event locked perfectly!");
      }
    } catch (e) {
      debugPrint("❌ Google Calendar Exception: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getGoogleCalendarEvents({
    required String accessToken,
    DateTime? timeMin,
    DateTime? timeMax,
  }) async {
    final dio = createDio();
    final startStr = (timeMin ?? DateTime.now()).toUtc().toIso8601String();

    Map<String, dynamic> queryParameters = {
      'timeMin': startStr,
      'singleEvents': true,
      'orderBy': 'startTime',
      'showDeleted': false,
    };

    if (timeMax != null) {
      queryParameters['timeMax'] = timeMax.toUtc().toIso8601String();
    }

    try {
      final response = await dio.get(
        "https://www.googleapis.com/calendar/v3/calendars/primary/events",
        queryParameters: queryParameters,
        options: Options(
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json",
          },
        ),
      );

      if (response.statusCode == 200) {
        final List items = response.data['items'] ?? [];
        final activeItems = items.where((event) => event['status'] != 'cancelled').toList();

        final Set<String> seenGoogleIds = {};
        final List<Map<String, dynamic>> parsedEvents = [];

        for (var event in activeItems) {
          final String googleId = event['id'] ?? '';
          if (googleId.isNotEmpty && seenGoogleIds.contains(googleId)) {
            continue;
          }
          seenGoogleIds.add(googleId);

          final startRaw = event['start']?['dateTime'] ?? event['start']?['date'] ?? '';
          final endRaw = event['end']?['dateTime'] ?? event['end']?['date'] ?? '';

          final DateTime? startDt = DateTime.tryParse(startRaw)?.toLocal();
          final DateTime? endDt = DateTime.tryParse(endRaw)?.toLocal();

          if (startDt == null) continue;

          final int eventId = googleId.hashCode.abs() % 1000000;

          parsedEvents.add({
            'id': eventId,
            'google_id': googleId,
            'title': event['summary'] ?? 'No Title',
            'description': event['description'] ?? '',
            'location': event['location'] ?? '',
            'startTime': DateFormat('HH:mm').format(startDt),
            'endTime': endDt != null ? DateFormat('HH:mm').format(endDt) : '',
            'date': DateFormat('yyyy-MM-dd').format(startDt),
            'alarm_time': startDt.subtract(const Duration(minutes: 15)).toIso8601String(),
          });
        }

        return parsedEvents;
      }
      return [];
    } catch (e) {
      debugPrint("❌ Google Calendar Fetch Exception: $e");
      return [];
    }
  }

  Future<bool> deleteGoogleCalendarEvent({
    required String accessToken,
    required String eventId,
  }) async {
    final dio = createDio();
    try {
      final response = await dio.delete(
        "https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId",
        options: Options(
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint("✅ Event deleted from Google Calendar");
        return true;
      } else {
        debugPrint("⚠️ Google Calendar delete error: ${response.data}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Google Calendar Delete Exception: $e");
      return false;
    }
  }
}
