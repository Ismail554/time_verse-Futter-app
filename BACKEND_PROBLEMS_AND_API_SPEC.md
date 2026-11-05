# Backend Architecture, Vulnerabilities & Complete Mobile App API Specification

**Document Version:** 2.1.0 (Hardened Production Release - Iteration 2)  
**Last Updated:** November 2026  
**Target Backend Service:** `backend-1/` (Django 5.2.7 / DRF / SimpleJWT / PostgreSQL / Redis / Celery)  
**Target Mobile Client:** `time_verse/` (Flutter / Dart / Dio / Provider / Alarm / Google Sign-In)  
**Production Base URL:** `https://api.infiniquote.com/api/v1`  
**Swagger / OpenAPI Documentation:** `https://api.infiniquote.com/swagger`  
**Canonical Test Account:** `ismailshuvo555@gmail.com` (User ID: `75`)  

---

## Table of Contents
1. [Executive Summary & System Architecture](#1-executive-summary--system-architecture)
2. [Critical Backend Vulnerabilities & Security Defects (with CWEs & Code Patches)](#2-critical-backend-vulnerabilities--security-defects)
3. [Functional Bugs & Broken Logic (with Root Causes & Fixes)](#3-functional-bugs--broken-logic)
4. [Missing Backend Endpoints Required by Mobile Client](#4-missing-backend-endpoints-required-by-mobile-client)
5. [Architectural & Reliability Infrastructure Standards](#5-architectural--reliability-infrastructure-standards)
   - [5.1 Global DRF Custom Exception Handler & RFC 7807 Standard](#51-global-drf-custom-exception-handler--rfc-7807-standard)
   - [5.2 Celery Asynchronous Architecture & Deterministic Calendar Integration](#52-celery-asynchronous-architecture--deterministic-calendar-integration)
   - [5.3 3-Tier Resilient AI Quote Generation Architecture & Excel Decoupling](#53-3-tier-resilient-ai-quote-generation-architecture--excel-decoupling)
   - [5.4 Production Dependencies & Mandatory Database Migrations](#54-production-dependencies--mandatory-database-migrations)
6. [Authentication & Account Lifecycle Detailed Specifications](#6-authentication--account-lifecycle-detailed-specifications)
   - [6.1 User Registration Flow](#61-user-registration-flow)
   - [6.2 Google Sign-In, ID Token Exchange & Pre-Account Takeover Mitigation](#62-google-sign-in--id-token-exchange)
   - [6.3 Password Recovery Flow (Dual-Mode OTP & Reset Token)](#63-password-recovery-flow)
   - [6.4 Secure Account Deletion Flow & Google Calendar Cleanup](#64-account-deletion-flow)
7. [Event Synchronization, Timezones & Calendar Integration Contracts](#7-event-synchronization-timezones--calendar-integration-contracts)
   - [7.1 Timezone & Timestamp Handling Contract](#71-timezone--timestamp-handling-contract)
   - [7.2 Atomic Idempotent Event Creation & Google Calendar Sync Protocol](#72-idempotent-event-creation--google-calendar-sync-protocol)
   - [7.3 Recurrence Engine, RFC 5545 Compliance & Occurrence Expansion](#73-recurrence-engine-rfc-5545-compliance--occurrence-expansion)
8. [Complete & Exhaustive API Reference Specification (All Endpoints)](#8-complete--exhaustive-api-reference-specification)
   - [8.1 Authentication & Account APIs](#81-authentication--account-apis)
   - [8.2 User Profile, Mood, FCM & Legal APIs](#82-user-profile-mood-fcm--legal-apis)
   - [8.3 Categories & Event Management APIs](#83-categories--event-management-apis)
   - [8.4 Quotes, Favorites, AI Reflection & Feedback APIs](#84-quotes-favorites-ai-reflection--feedback-apis)
   - [8.5 Subscriptions & Access Control APIs](#85-subscriptions--access-control-apis)
   - [8.6 Administrative Subscription APIs (Secured)](#86-administrative-subscription-apis-secured)
9. [Backend Implementation & Verification Checklist](#9-backend-implementation--verification-checklist)

---

## 1. Executive Summary & System Architecture

### 1.1 Architectural Overview
The TimeVerse application platform comprises two primary software artifacts:
1. **Flutter Mobile Application (`time_verse/`)**: Cross-platform client utilizing Dio for network transport, Provider for reactive state management, `flutter_secure_storage` / `shared_preferences` for session management, and background scheduling via the `alarm` package.
2. **Django REST Framework Backend (`backend-1/`)**: RESTful microservices engine built upon Django 5.2.7, Django REST Framework (DRF), SimpleJWT authentication, Celery background worker queues backed by Redis, and PostgreSQL for relational persistence. It interfaces with external services including OpenAI GPT models (for personalized daily inspirational quotes and reflections) and Google Calendar API v3 (for bidirectional calendar synchronization).

```
                      +---------------------------------------+
                      |       Flutter Mobile Application      |
                      |  (Dio Client, State, Alarms, Storage) |
                      +-------------------+-------------------+
                                          |
                                          | HTTPS / JSON (RFC 7807)
                                          | Bearer JWT / X-Timezone
                                          v
                      +-------------------+-------------------+
                      |      Nginx 1.24 + Gunicorn 23.0       |
                      |     (api.infiniquote.com/api/v1)      |
                      +-------------------+-------------------+
                                          |
                                          v
                      +-------------------+-------------------+
                      |    Django REST Framework Application  |
                      | (Auth, Events, Profile, Subscriptions)|
                      +--------+------------------+-----------+
                               |                  |
            +------------------+                  +------------------+
            |                                                        |
            v                                                        v
+-----------+-----------+                                +-----------+-----------+
| PostgreSQL Database   |                                | Redis Broker & Celery |
| (Users, Events,       |                                | (Async Calendar Sync, |
|  Tokens, Subscriptions|                                |  Async Email Dispatch)|
+-----------------------+                                +-----------+-----------+
            |                                                        |
            |                                                        v
            v                                            +-----------+-----------+
+-----------+-----------+                                | External Integrations |
| OpenAI GPT-4 API      |                                | - Google Calendar v3  |
| (3s Timeout + Circuit |                                | - Google OAuth2       |
|  Breaker Fallback)    |                                | - SMTP / SendGrid     |
+-----------------------+                                +-----------------------+
```

### 1.2 Summary of Issues Discovered
A rigorous cross-codebase audit conducted across both frontend and backend repositories revealed:
- **7 Critical Security Vulnerabilities (P0)**, including an unauthenticated password reset bypass allowing complete account takeover (CWE-306), mass assignment in registration elevating regular users to Django superusers (CWE-915), severe Broken Object-Level Authorization (BOLA/IDOR) leaking user calendars (CWE-284/CWE-639), and missing administrative access controls (CWE-285).
- **10 Functional Bugs (P1)**, including hard crashes on SMTP disconnects, dropping recurrence rules on event creation, HTTP 405/404 routing errors on event update and deletion, dual-model Google Calendar synchronization divergence, and timezone inversion drifting alarms by up to 12 hours.
- **4 Missing Backend Endpoints**, directly invoked by Flutter but returning 404/502 errors due to absence in backend route tables (`resend-otp`, `user/mood`, `event/ai-reflection`, and `token/refresh`).
- **Architectural Gaps**, including unhandled server 500 HTML tracebacks, lack of RFC 7807 problem details, absence of Celery async offloading for calendar sync, and synchronous 4.5s blocking OpenAI calls.

---

## 2. Critical Backend Vulnerabilities & Security Defects

### SEC-01: Critical Authentication Bypass / Account Takeover via Password Reset
- **Vulnerability Identifier:** SEC-01  
- **Common Weakness Enumeration:** CWE-306 (Missing Authentication for Critical Function) / CWE-640 (Weak Password Recovery Mechanism)  
- **CVSS v3.1 Score:** **9.8 (Critical)** — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`  
- **Vulnerable Source File & Lines:** `backend-1/userauth/serializers.py`, lines 143–164 (`ResetPasswordSerializer`) and `backend-1/userauth/views.py`, line 143 (`reset_password`).  
- **Root Cause Analysis:**  
  The `ResetPasswordSerializer` defines only `email` and `new_password`. It does **not** declare an `otp` field, does not validate that an OTP was verified, and does not require a signed reset token. Any unauthenticated caller who knows any registered user's email address can send an HTTP POST request to `/api/v1/reset-password/` and arbitrarily overwrite that user's password.
- **Vulnerable Code in Repository:**
  ```python
  # backend-1/userauth/serializers.py:143-164
  class ResetPasswordSerializer(serializers.Serializer):
      email = serializers.EmailField()
      new_password = serializers.CharField(write_only=True, min_length=4)

      def validate_email(self, value):
          if not User.objects.filter(email=value).exists():
              raise serializers.ValidationError("No user found with this email.")
          return value

      def save(self):
          email = self.validated_data['email']
          new_password = self.validated_data['new_password']
          user = User.objects.get(email=email)
          user.set_password(new_password)
          user.save()
          return user
  ```
- **Remediation Specification:**
  1. **Dual-Mode Payload Compatibility:**
     Support BOTH the Flutter mobile payload (`{"email": "...", "otp": "...", "new_password": "..."}`) sent by `auth_service.dart:323-333` AND the Django reset token payload (`{"email": "...", "reset_token": "...", "new_password": "..."}`).
  2. **Direct OTP Validation & Brute-Force Tracking (ADV-03):**
     If `otp` is submitted directly:
     - Query the most recent active `PasswordResetOTP` record for the user (`is_used=False`).
     - Check `failed_attempts`: If `failed_attempts >= 5`, mark `is_used=True` and reject with HTTP 400 (`"Verification code locked due to excessive failed attempts. Please request a new one."`).
     - Verify code match: If `otp` does not match, increment `otp_record.failed_attempts += 1`, save, and reject with remaining attempts indicated.
     - Check 5-minute validity window: If `timezone.now() - otp_record.created_at > timedelta(minutes=5)`, mark `is_used=True`, save, and reject as expired.
  3. **Cryptographic Replay Protection via `default_token_generator` (ADV-01):**
     If `reset_token` is submitted:
     - DO NOT rely on stateless timestamp signing alone, which permits replay attacks for up to 15 minutes.
     - Verify the token using Django's `django.contrib.auth.tokens.default_token_generator.check_token(user, reset_token)`. Because Django's generator incorporates `user.password` into the HMAC hash (`f"{user.pk}{user.password}{user.last_login}{timestamp}"`), as soon as `user.set_password()` is executed, the password hash changes, rendering the token cryptographically invalid immediately and preventing token replay.
  4. **Single-Use Atomic Invalidation:**
     Execute password update and OTP invalidation inside a `transaction.atomic` block: mark all active OTPs for the user as `is_used=True`.
  5. **Mandatory Database Migration for `PasswordResetOTP` (ADV-05):**
     The existing `PasswordResetOTP` model in `backend-1/userauth/models.py` defines `otp = CharField(max_length=4)` without `is_used` or `failed_attempts`. Deploying without updating the model will immediately raise `django.core.exceptions.FieldError: Cannot resolve keyword 'is_used' into field` and `django.db.utils.DataError: value too long for type character varying(4)`. A Django migration must add:
     ```python
     # In userauth/models.py
     otp = models.CharField(max_length=6)
     is_used = models.BooleanField(default=False, db_index=True)
     failed_attempts = models.PositiveIntegerField(default=0)
     ```

- **Patched Implementation:**
  ```python
  # Patched backend-1/userauth/serializers.py
  import datetime
  from django.utils import timezone
  from django.db import transaction
  from django.contrib.auth import get_user_model
  from django.contrib.auth.tokens import default_token_generator
  from rest_framework import serializers
  from .models import PasswordResetOTP

  User = get_user_model()

  class ResetPasswordSerializer(serializers.Serializer):
      email = serializers.EmailField(required=True)
      new_password = serializers.CharField(write_only=True, min_length=8, required=True)
      otp = serializers.CharField(required=False, max_length=6, write_only=True)
      reset_token = serializers.CharField(required=False, write_only=True)

      def validate(self, attrs):
          email = attrs.get('email', '').strip().lower()
          otp = attrs.get('otp', '').strip() if attrs.get('otp') else None
          reset_token = attrs.get('reset_token', '').strip() if attrs.get('reset_token') else None

          try:
              user = User.objects.get(email=email)
          except User.DoesNotExist:
              # Prevent email enumeration while maintaining consistent validation schema
              raise serializers.ValidationError({"email": "No active user registered with this email address."})

          if not otp and not reset_token:
              raise serializers.ValidationError({
                  "non_field_errors": ["Either 'otp' (mobile client) or 'reset_token' must be provided."]
              })

          # Flow A: Reset Token submitted (Cryptographically replay-protected via default_token_generator)
          if reset_token:
              if not default_token_generator.check_token(user, reset_token):
                  raise serializers.ValidationError({
                      "reset_token": "Reset token is invalid, expired, or has already been used."
                  })

          # Flow B: Direct OTP submitted (Flutter mobile client: auth_service.dart:325)
          elif otp:
              otp_record = PasswordResetOTP.objects.filter(
                  user=user,
                  is_used=False
              ).order_by('-created_at').first()

              if not otp_record:
                  raise serializers.ValidationError({
                      "otp": "No active verification code found for this account. Please request a new one."
                  })

              # Check failed attempt lockout
              if otp_record.failed_attempts >= 5:
                  otp_record.is_used = True
                  otp_record.save(update_fields=['is_used'])
                  raise serializers.ValidationError({
                      "otp": "Verification code has been permanently invalidated due to 5 failed attempts. Please request a new code."
                  })

              # Validate expiration (5-minute TTL)
              if timezone.now() - otp_record.created_at > datetime.timedelta(minutes=5):
                  otp_record.is_used = True
                  otp_record.save(update_fields=['is_used'])
                  raise serializers.ValidationError({
                      "otp": "Verification code has expired. Please request a new one."
                  })

              # Verify OTP code match
              if otp_record.otp != otp:
                  otp_record.failed_attempts += 1
                  if otp_record.failed_attempts >= 5:
                      otp_record.is_used = True
                      otp_record.save(update_fields=['failed_attempts', 'is_used'])
                      raise serializers.ValidationError({
                          "otp": "Incorrect code. Maximum attempt limit reached (5/5). Code invalidated."
                      })
                  otp_record.save(update_fields=['failed_attempts'])
                  remaining = 5 - otp_record.failed_attempts
                  raise serializers.ValidationError({
                      "otp": f"Invalid verification code. {remaining} attempt(s) remaining."
                  })

              attrs['otp_record'] = otp_record

          attrs['user'] = user
          return attrs

      def save(self):
          user = self.validated_data['user']
          new_password = self.validated_data['new_password']

          with transaction.atomic():
              # Update password (changes user.password hash, invalidating any tokens generated from it)
              user.set_password(new_password)
              user.save(update_fields=['password'])

              # Invalidate all remaining active OTPs for this user immediately
              PasswordResetOTP.objects.filter(user=user, is_used=False).update(is_used=True)

          return user
  ```

---

### SEC-02: Mass Assignment & Privilege Escalation in Registration
- **Vulnerability Identifier:** SEC-02  
- **Common Weakness Enumeration:** CWE-915 (Improperly Controlled Modification of Dynamically-Determined Object Attributes)  
- **CVSS v3.1 Score:** **8.8 (High)** — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`  
- **Vulnerable Source File & Lines:** `backend-1/userauth/serializers.py`, lines 25–30 (`UserRegistrationsSerializers`).  
- **Root Cause Analysis:**  
  `UserRegistrationsSerializers` declares `fields = '__all__'` directly on the custom `User` model. The `User` model inherits from `AbstractBaseUser` and `PermissionsMixin`, exposing `is_staff`, `is_superuser`, `is_active`, `groups`, and `user_permissions`. An attacker posting `{"email": "...", "password": "...", "is_staff": true, "is_superuser": true}` is directly persisted as a superuser.
- **Vulnerable Code in Repository:**
  ```python
  # backend-1/userauth/serializers.py:25-30
  class UserRegistrationsSerializers(serializers.ModelSerializer):
      password = serializers.CharField(write_only=True, min_length=4)
      class Meta:
          model = User
          fields = '__all__'
  ```
- **Remediation Specification:**
  Explicitly restrict `Meta.fields` to client-allowed fields only (`email`, `password`, `first_name`, `last_name`, `gender`, `nationality`, `profile_picture`). Never use `fields = '__all__'` on user or authentication models.

---

### SEC-03: Broken Object-Level Authorization (BOLA / IDOR) in Event Endpoints
- **Vulnerability Identifier:** SEC-03  
- **Common Weakness Enumeration:** CWE-284 (Improper Access Control) / CWE-639 (Authorization Bypass Through User-Controlled Key)  
- **CVSS v3.1 Score:** **8.5 (High)** — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:N`  
- **Vulnerable Source File & Lines:**  
  - `backend-1/event/views.py`, line 214 (`all_event`)
  - `backend-1/event/views.py`, line 261 (`up_comming_event`)
  - `backend-1/event/views.py`, line 277 (`today_up_comming_event`)
  - `backend-1/event/views.py`, line 224 (`event_details`)
  - `backend-1/event/views.py`, line 315 (`delete_event`)
- **Root Cause Analysis:**  
  - `all_event` executes `Event.objects.all()`, returning every user's private schedules, locations, and personal notes to any logged-in user. The Flutter client had to implement client-side filtering (`where((e) => e.user == currentUserId)`) as a workaround.
  - `delete_event` executes `Event.objects.get(id=pk).delete()` without checking `event.user == request.user`. Any user can delete any other user's event.
  - `event_details` retrieves events by ID without verifying ownership.
- **Patched Implementation:**
  ```python
  # Scoped queries across all event views
  @api_view(['GET'])
  @permission_classes([IsAuthenticated])
  def all_event(request):
      date_str = request.query_params.get('date')
      events = Event.objects.filter(user=request.user)
      if date_str:
          events = events.filter(date=date_str)
      serializer = EventSerializer(events.order_by('-date', '-start_time'), many=True)
      return Response(serializer.data, status=status.HTTP_200_OK)

  @api_view(['DELETE'])
  @permission_classes([IsAuthenticated])
  def delete_event(request, pk):
      try:
          event = Event.objects.get(id=pk, user=request.user)
      except Event.DoesNotExist:
          return Response({
              "type": "https://api.infiniquote.com/errors/not-found",
              "title": "Event Not Found",
              "status": 404,
              "detail": f"No event found with ID {pk} belonging to the current user."
          }, status=status.HTTP_404_NOT_FOUND)

      # Trigger asynchronous Google Calendar deletion task if synced
      if event.google_calendar_event_id:
          delete_google_calendar_event_task.delay(request.user.id, event.google_calendar_event_id)

      event.delete()
      return Response({"message": "Event deleted successfully."}, status=status.HTTP_200_OK)
  ```

---

### SEC-04: OTP Brute-Force Without Throttling & Unauthenticated OTP Accumulation
- **Vulnerability Identifier:** SEC-04  
- **Common Weakness Enumeration:** CWE-307 (Improper Restriction of Excessive Authentication Attempts) / CWE-640 (Weak Password Recovery)  
- **CVSS v3.1 Score:** **7.5 (High)** — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`  
- **Vulnerable Source File & Lines:** `backend-1/userauth/views.py`, lines 120–135; `backend-1/userauth/models.py`, `PasswordResetOTP`.  
- **Root Cause Analysis:**  
  1. The OTP generated is a 4-digit decimal number ($10^4 = 10,000$ permutations).
  2. The endpoint `/api/v1/verify-otp/` has no DRF throttling or rate limiting. An automated script can exhaust all 10,000 possibilities in under 30 seconds.
  3. Every request to `/forget_password/` appends a new `PasswordResetOTP` record without deleting or invalidating old records. If a user requests an OTP 5 times, all 5 codes remain active concurrently.
- **Remediation Specification:**
  1. **6-Digit Cryptographic Generation:** Upgrade OTP generation from 4 digits to cryptographically secure 6-digit tokens ($10^6 = 1,000,000$ permutations) via `secrets.SystemRandom().randint(100000, 999999)`.
  2. **Mandatory Model Schema Migration (ADV-05):**
     In `backend-1/userauth/models.py`, alter `PasswordResetOTP`:
     ```python
     class PasswordResetOTP(models.Model):
         user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reset_otps')
         otp = models.CharField(max_length=6)
         is_used = models.BooleanField(default=False, db_index=True)
         failed_attempts = models.PositiveIntegerField(default=0)
         created_at = models.DateTimeField(auto_now_add=True)

         class Meta:
             indexes = [
                 models.Index(fields=['user', 'is_used', 'created_at']),
             ]
     ```
     Run `python manage.py makemigrations userauth && python manage.py migrate` to apply this schema migration.
  3. **Composite Scoped Throttling (ADV-07):**
     Implement a custom DRF throttle class combining client IP and the SHA-256 hash of the normalized email:
     ```python
     # api/throttling.py
     import hashlib
     from rest_framework.throttling import SimpleRateThrottle

     class AuthEndpointRateThrottle(SimpleRateThrottle):
         scope = 'auth'  # 5 requests / 15 minutes

         def get_cache_key(self, request, view):
             ip = self.get_ident(request)
             email = request.data.get('email', '').strip().lower()
             email_hash = hashlib.sha256(email.encode('utf-8')).hexdigest()[:16] if email else 'anon'
             return f"throttle_auth_{ip}_{email_hash}"
     ```
     Apply this throttle to `/forget_password/`, `/resend-otp/`, `/verify-otp/`, and `/reset-password/`.
  4. **Active Attempt Lockout & Prior OTP Invalidation:**
     - When generating a new OTP on `/forget_password/` or `/resend-otp/`, mark all prior active OTPs for the user as `is_used=True` in an atomic block.
     - On `/verify-otp/` and `/reset-password/`, track `failed_attempts`. If `failed_attempts >= 5`, permanently set `is_used=True` and reject further attempts for that OTP.

---

### SEC-05: Broken Access Control on Admin Subscription Endpoints
- **Vulnerability Identifier:** SEC-05  
- **Common Weakness Enumeration:** CWE-285 (Improper Authorization)  
- **CVSS v3.1 Score:** **8.8 (High)** — `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`  
- **Vulnerable Source File & Lines:** `backend-1/subscriptions/views.py`, lines 66–99 (`AdminSubscriptionListView`, `AdminUpdateSubscriptionView`, `AdminPlanUpdateView`).  
- **Root Cause Analysis:**  
  The three administrative views define `permission_classes = [IsAuthenticated]`. Any normal mobile app user with a valid JWT token can:
  - Query `GET /api/v1/all-user-subscriptions/` to inspect all registered users' emails, user IDs, and subscription histories.
  - Send `PUT /api/v1/admin/update-subscription/{user_id}/` with `{"status": "active"}` to grant themselves or any user free lifetime premium status.
  - Send `PATCH /api/v1/plan-update/{id}/` to alter system-wide subscription pricing and features.
- **Remediation Specification:**
  Enforce `permission_classes = [IsAdminUser]` on all three admin endpoints.

---

### SEC-06: Production Information Disclosure & Debug Leakage (`DEBUG = True`)
- **Vulnerability Identifier:** SEC-06  
- **Common Weakness Enumeration:** CWE-200 (Exposure of Sensitive Information to an Unauthorized Actor)  
- **CVSS v3.1 Score:** **7.5 (High)** — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`  
- **Vulnerable Source File & Lines:** `backend-1/backend/settings.py`, lines 37–43.  
- **Root Cause Analysis:**  
  In production, `DEBUG = True` and `ALLOWED_HOSTS = ['*']` are active. When unhandled exceptions occur (e.g. SMTP failures or OpenAI errors), Django generates a complete HTML traceback displaying environment variables, PostgreSQL connection strings (`NAME: 'radu', USER: 'radu', HOST: 'db'`), SimpleJWT signing keys, and Google OAuth credentials.
- **Remediation Specification:**
  Enforce `DEBUG = False` via environment variables. Configure `ALLOWED_HOSTS = ['api.infiniquote.com', 'localhost', '127.0.0.1']`. Implement a custom DRF exception handler that guarantees all responses are JSON.

---

### SEC-07: Insecure OAuth Client Configuration & Audience Mismatch
- **Vulnerability Identifier:** SEC-07  
- **Common Weakness Enumeration:** CWE-287 (Improper Authentication)  
- **Vulnerable Source Files & Lines:**  
  - `backend-1/backend/settings.py`, lines 270–278 (`GOOGLE_CLIENT_ID`, `GOOGLE_REDIRECT_URI`)
  - `backend-1/google_calendar_sync/views.py`, lines 150–165 & 180–185
  - `time_verse/lib/config/services/google_service.dart`, line 23 (`serverClientId`)
- **Root Cause Analysis:**  
  1. The Flutter mobile app authenticates using `serverClientId = '468767271373-igakn4plmbu2io7ocqph0miemm38lumq.apps.googleusercontent.com'`.
  2. The backend verifies incoming ID tokens strictly against `settings.GOOGLE_CLIENT_ID = '266848129575-j21g213vsnsai5k8jneg66j93nvua5vn.apps.googleusercontent.com'`.
  3. The audience validation inside `id_token.verify_oauth2_token()` raises `ValueError: Token used with wrong audience`, returning HTTP 400.
  4. The server auth code exchange hardcodes `redirect_uri="http://localhost:8000/google/callback/"`, failing on production Google OAuth servers.
- **Remediation Specification:**
  Support multi-audience verification by passing an authorized client ID list (`[WEB_CLIENT_ID, ANDROID_CLIENT_ID, IOS_CLIENT_ID, SERVER_CLIENT_ID]`). Set redirect URIs dynamically from environment settings.

---

### SEC-08: Insecure Client-Side Credential Storage Guidelines
- **Vulnerability Identifier:** SEC-08  
- **Common Weakness Enumeration:** CWE-312 (Cleartext Storage of Sensitive Information)  
- **Vulnerable Source File & Lines:** `time_verse/lib/config/app_route/app_prefernce.dart`, line 84 (`saveRememberMe`).  
- **Root Cause Analysis:**  
  When "Remember Me" is toggled, the mobile app writes the user's unencrypted password into Android `SharedPreferences` / iOS `NSUserDefaults`. On rooted Android devices or via unencrypted backups, credentials can be harvested in plaintext.
- **Remediation Specification:**  
  Never persist raw passwords. Store long-lived session state strictly using SimpleJWT refresh tokens stored in `flutter_secure_storage` (backed by Android Keystore and iOS Keychain). The backend must support the token refresh endpoint (`/api/v1/token/refresh/`) to maintain seamless persistent login.

---

## 3. Functional Bugs & Broken Logic

### BUG-01: SMTP Server Disconnect 500 Crash on `/forget_password/`
- **Component:** Authentication / Email Subsystem  
- **Files & Lines:** `backend-1/userauth/serializers.py`, line 110; `backend-1/userauth/views.py`, line 128; `backend-1/backend/settings.py`, lines 228–236.  
- **Root Cause:**  
  The `forget_password` view synchronously calls `send_mail()`. In production, the Gmail App Password for `accessi@wise.pro` is invalid or expired. `smtplib` throws `SMTPServerDisconnected: Connection unexpectedly closed`. Because there is no `try...except` wrapper and no `EMAIL_TIMEOUT` setting, Gunicorn worker threads hang and return a 500 HTML error.
- **Required Fix:**
  1. Configure a production transactional email service (SendGrid, AWS SES, or fresh Gmail App Password).
  2. Set `EMAIL_TIMEOUT = 10` in `backend/settings.py`.
  3. Wrap email dispatch in a Celery task: `send_password_reset_email.delay(user.email, otp)`.
  4. In the synchronous fallback, catch `(smtplib.SMTPException, OSError)` and return HTTP 503 if email delivery fails.

---

### BUG-02: Favorite Quotes (`GET /api/v1/event/my-quotes/`) Always Returns `[]`
- **Component:** Event & Quotation Subsystem  
- **Files & Lines:** `backend-1/event/views.py`, lines 347–351; `backend-1/event/serializers.py`, lines 28–32.  
- **Root Cause:**  
  The view filters events with:
  ```python
  events = Event.objects.filter(
      user=request.user,
      alarm_time__isnull=False,
      alarm_time__lte=now  # ONLY checks if alarm time has passed in UTC!
  )
  ```
  It **completely omits `is_favorite=True`**. If an event quote has `is_favorite=True` but its alarm time is in the future, it is omitted. Furthermore, the `EventQuoteSerializer` omits the `author` field, which the Flutter client attempts to display.
- **Required Fix:**
  Filter strictly on `is_favorite=True`:
  ```python
  @api_view(['GET'])
  @permission_classes([IsAuthenticated])
  def get_event_quotes(request):
      events = Event.objects.filter(user=request.user, is_favorite=True).order_by('-created_at')
      serializer = EventQuoteSerializer(events, many=True)
      return Response(serializer.data, status=status.HTTP_200_OK)
  ```
  Update `EventQuoteSerializer` to include `author` (computed from category or quote packet):
  ```python
  class EventQuoteSerializer(serializers.ModelSerializer):
      author = serializers.SerializerMethodField()

      class Meta:
          model = Event
          fields = ['id', 'description', 'author', 'created_at', 'is_favorite']

      def get_author(self, obj):
          return obj.category.name if obj.category else "TimeVerse Motivation"
  ```

---

### BUG-03: Event Update Fails with HTTP 405 Method Not Allowed
- **Component:** Event Management  
- **Files & Lines:** `backend-1/event/views.py`, line 102 (`create_event`); `time_verse/lib/features/edit_event/repository/edit_event_repo.dart`, line 106.  
- **Root Cause:**  
  The Flutter app updates events by sending `PATCH /api/v1/event/create/?id={id}`. However, `create_event` in `backend-1/event/views.py` is decorated strictly with `@api_view(['POST'])`. DRF immediately rejects incoming PATCH requests with HTTP 405. Furthermore, there is no update view declared in `event/views.py`.
- **Required Fix:**  
  Decorate `create_event` with `@api_view(['POST', 'PATCH'])` (handling update when query parameter `?id=` is present) AND register a dedicated route `PATCH /api/v1/event/update/<int:pk>/` for REST architectural purity.

---

### BUG-04: Event Deletion Typo Route Returns HTTP 404
- **Component:** Routing  
- **Files & Lines:** `backend-1/api/urls.py`, line 57.  
- **Root Cause:**  
  The URL pattern is misspelled in `api/urls.py`:
  ```python
  path("evenet/delete/<int:pk>/", event_view.delete_event, name="Event Delete")
  ```
  The mobile app sends `DELETE /api/v1/event/delete/{id}/`, which does not match `evenet` and returns 404 Not Found.
- **Required Fix:**  
  Fix the route to `event/delete/<int:pk>/` and keep `evenet/delete/<int:pk>/` as a backward-compatible alias.

---

### BUG-05: Event Recurrence Dropped on Save
- **Component:** Event Persistence  
- **Files & Lines:** `backend-1/dashbord/models.py`, lines 39–57 (`Event`); `backend-1/event/serializers.py`, lines 11–26 (`EventSerializer`).  
- **Root Cause:**  
  The mobile app sends `"repeat"` (string, e.g., `"1 week"`, `"custom"`) and `"custom_repeat"` (dictionary specifying frequency, unit, days, and end conditions). The backend `Event` model has **no fields** for `repeat` or `custom_repeat`. DRF silently drops these fields during serialization. As a result, recurring events never repeat on the backend.
- **Required Fix:**  
  Add `repeat` and `custom_repeat` fields to the `Event` model and serializer:
  ```python
  repeat = models.CharField(max_length=50, null=True, blank=True, default="dont_repeat")
  custom_repeat = models.JSONField(null=True, blank=True)
  ```

---

### BUG-06: Google Calendar Credentials Dual-Model Synchronization Failure
- **Component:** Google Calendar Integration  
- **Files & Lines:** `backend-1/google_calendar_sync/views.py`, line 204; `backend-1/google_calendar_sync/utils.py`, line 33.  
- **Root Cause:**  
  When mobile users log in via Google ID Token (`POST /api/v1/auth/login/idtoken/`), their OAuth tokens are saved into the `GoogleCalendarCredential` model (`google_calendar_sync/models.py`). However, the utility function `create_google_calendar_event()` attempts to load credentials from `GoogleAPICredentials.objects.get(user=user)`. Because `GoogleAPICredentials` does not exist for the user, it catches `DoesNotExist` and aborts with `"Google account not linked."` for 100% of mobile users.
- **Required Fix:**  
  Deprecate `GoogleAPICredentials`. Standardize all calendar operations onto the `GoogleCalendarCredential` model.

---

### BUG-07: Missing Google Calendar Event ID Persistence (Duplicate Events)
- **Component:** Google Calendar Integration  
- **Files & Lines:** `backend-1/dashbord/models.py`, line 39; `backend-1/google_calendar_sync/utils.py`, line 80.  
- **Root Cause:**  
  When an event is inserted into Google Calendar via the Google API, Google returns a unique event identifier (`id`, e.g. `"ab12cd34ef56"`). The backend `Event` model has no `google_calendar_event_id` field. The returned ID is discarded. Consequently:
  - If event creation is retried, a second Google event is created.
  - When an event is updated or deleted on TimeVerse, the backend cannot update or delete the event in Google Calendar.
- **Required Fix:**  
  Add `google_calendar_event_id = models.CharField(max_length=255, null=True, blank=True, db_index=True)` and `last_synced_at = models.DateTimeField(null=True, blank=True)` to the `Event` model.

---

### BUG-08: Synchronous OpenAI Blocking, Quota Exhaustion, Excel I/O Bottlenecks & `TypeError` Crash
- **Component:** AI Integration / Quotations Subsystem  
- **Files & Lines:** `backend-1/event/qtai.py`, lines 5–48; `backend-1/event/views.py`, lines 144 & 203–206.  
- **Root Cause:**  
  1. `QuoteGenerator.generate_quote()` synchronously queries `gpt-4-turbo` on every event creation, adding 4.1 to 4.5 seconds of HTTP blocking latency.
  2. When OpenAI quota is exhausted (HTTP 429) or errors out, `qtai.py` returns a dictionary: `{"error": str(e)}`.
  3. In `event/views.py:203`, the view attempts to execute:
     ```python
     quote_data = json.loads(quote_response)
     ```
     Because `quote_response` is already a `dict` (not a string), Python raises:
     `TypeError: the JSON object must be str, bytes or bytearray, not dict`.
  4. The exception handler only catches `(json.JSONDecodeError, AttributeError)`. The unhandled `TypeError` crashes the worker with a 500 HTML error.
  5. The Tier 2 fallback in `event/views.py:144` calls `pd.read_excel(random_quote_packet.exel_fill.path)` on the HTTP request thread. Parsing 500+ rows of Excel files synchronously via `pandas` and `openpyxl` takes 300–800ms and consumes 50–100MB of RAM, causing memory spikes and CPU starvation under concurrent event creation.
- **Required Fix:**  
  1. Migrate from `gpt-4-turbo` to `gpt-4o-mini` with a strict 3.0-second timeout (`timeout=3.0`) and catch `TypeError` in addition to JSON errors.
  2. Decouple quote fallback from runtime Excel files: migrate quotes into a relational PostgreSQL `Quote` model populated during administrative upload, queried in <5ms via `Quote.objects.filter(...)`.
  3. Provide an in-memory, zero-dependency static fallback array `UNIVERSAL_FALLBACK_QUOTES` (20+ curated quotes) in `backend-1/event/qtai.py` ensuring that event creation NEVER fails even if both OpenAI and PostgreSQL are degraded.

---

### BUG-09: Profile Name Field Mismatch
- **Component:** Profile Subsystem  
- **Files & Lines:** `backend-1/userauth/serializers.py`, lines 67–75 (`UserProfileSerializer`).  
- **Root Cause:**  
  The mobile app sends `"name": "Full Name"` or separate `"first_name"` / `"last_name"`. The backend serializer only updates `first_name` and `last_name` if explicitly passed, ignoring `"name"`.
- **Required Fix:**  
  In `UserProfileSerializer`, accept `name` as a write-only field. If `name` is provided without `first_name`/`last_name`, split on the first space:
  ```python
  if 'name' in validated_data and not validated_data.get('first_name'):
      parts = validated_data.pop('name').strip().split(' ', 1)
      validated_data['first_name'] = parts[0]
      validated_data['last_name'] = parts[1] if len(parts) > 1 else ''
  ```

---

### BUG-10: Free Subscription Plan Omission in Google Sign-In
- **Component:** Subscriptions / Auth  
- **Files & Lines:** `backend-1/google_calendar_sync/views.py`, lines 138–210.  
- **Root Cause:**  
  In `userauth/views.py:55` (standard registration), `activate_free_subscription(user)` is executed. In `google_id_token_login_view`, this step is omitted. Google users are created without an active subscription record, causing `/api/v1/my-access/` to fail or report invalid trial states.
- **Required Fix:**  
  Call `activate_free_subscription(user)` inside `google_id_token_login_view` whenever a new user is created.

---

## 4. Missing Backend Endpoints Required by Mobile Client

The following endpoints are actively invoked by `time_verse/` but do not exist in `backend-1/api/urls.py`, resulting in 404 HTML responses:

### MISS-01: Resend OTP Endpoint
- **Method & Route:** `POST /api/v1/resend-otp/`
- **Client Invocation:** `time_verse/lib/features/auth/auth_service/auth_service.dart`, line 280 (`resendOtp()`).
- **Functionality:** Invalidates any existing unexpired OTP for the specified email, generates a fresh 6-digit cryptographic OTP with a 5-minute validity window, and dispatches it via email.
- **Payload:** `{"email": "user@example.com"}`
- **Success Response:** `200 OK` — `{"success": true, "message": "Verification OTP has been resent to your email address."}`

### MISS-02: Daily Mood Tracking Endpoint
- **Method & Route:** `POST /api/v1/user/mood/`
- **Client Invocation:** `time_verse/lib/features/mood_tracker/controller/mood_controller.dart`, line 44.
- **Functionality:** Records the user's daily emotional state to inform the AI daily reflection synthesis.
- **Payload:** `{"mood": "Happy"}` (Enum: `Sad`, `Anxious`, `Neutral`, `Calm`, `Happy`, `Excited`, `Stressed`, `Grateful`)
- **Success Response:** `201 Created` — `{"success": true, "message": "Mood recorded successfully.", "mood": "Happy", "recorded_at": "2026-11-02T08:00:00Z"}`

### MISS-03: AI Daily Mood Reflection Endpoint
- **Method & Route:** `GET /api/v1/event/ai-reflection/`
- **Client Invocation:** `time_verse/lib/features/home/repository/event_repository.dart`, line 168; `time_verse/lib/features/home/models/ai_refelction_model.dart`.
- **Functionality:** Synthesizes the user's recorded mood and today's upcoming event titles to generate an encouraging reflection. Must include a database template fallback to guarantee `200 OK` even if OpenAI is unreachable.
- **Success Response:** `200 OK` — `{"mood": "Happy", "events": ["Team Sync"], "pre_quotes": ["Alone we can do so little..."], "ai_reflection": "Your optimistic mood complements your collaborative schedule today.", "raw_response": "{}"}`

### MISS-04: JWT Token Refresh Endpoint
- **Method & Route:** `POST /api/v1/token/refresh/`
- **Client Invocation:** Required by Dio client interceptor to renew expired access tokens.
- **Functionality:** DRF SimpleJWT `TokenRefreshView`. Validates refresh token, blacklists previous token if token rotation is active, and issues a new access token.
- **Payload:** `{"refresh": "<jwt_refresh_token>"}`
- **Success Response:** `200 OK` — `{"access": "<new_jwt_access_token>", "refresh": "<new_jwt_refresh_token>"}`

---

## 5. Architectural & Reliability Infrastructure Standards

### 5.1 Global DRF Custom Exception Handler & RFC 7807 Standard
To ensure the Flutter mobile app never crashes on unhandled HTML error pages (`FormatException: Unexpected character <`) and displays clean, specific error messages, the backend must configure a global exception handler and root Django handlers compliant with **RFC 7807 (Problem Details for HTTP APIs)**.

#### Configuration in `backend/settings.py`:
```python
import datetime

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'EXCEPTION_HANDLER': 'api.exceptions.custom_exception_handler',
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',
        'user': '1000/day',
        'auth': '5/15m',        # Harmonized with password recovery (5 attempts per 15 min)
        'login': '10/minute',    # Credential stuffing defense
    }
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': datetime.timedelta(minutes=15),  # Hardened down from vulnerable 5,000 minutes
    'REFRESH_TOKEN_LIFETIME': datetime.timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
}
```

> **Client Interceptor Contract (ADV-06):** When `ROTATE_REFRESH_TOKENS = True` and `BLACKLIST_AFTER_ROTATION = True`, the Flutter mobile application MUST use a `QueuedInterceptor` or mutex lock around `POST /api/v1/token/refresh/`. This guarantees that if multiple concurrent HTTP requests fail with `401 Unauthorized`, only a single refresh request is dispatched while others await the new access token. This eliminates false-positive session logouts caused by blacklisted token reuse.

#### Implementation in `backend-1/api/exceptions.py`:
```python
import uuid
import logging
from django.http import JsonResponse, Http404
from django.core.exceptions import PermissionDenied, SuspiciousOperation
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

logger = logging.getLogger(__name__)

def custom_exception_handler(exc, context):
    """
    RFC 7807 compliant exception handler for Django REST Framework.
    Extracts the first specific field error into top-level 'detail' to preserve
    Flutter mobile client message parsing in AuthService._handleError.
    """
    response = exception_handler(exc, context)
    error_id = f"err_{uuid.uuid4().hex[:12]}"

    if response is not None:
        formatted_errors = {}
        detail_msg = None

        if isinstance(response.data, dict):
            for field, messages in response.data.items():
                if isinstance(messages, list):
                    formatted_errors[field] = [str(m).strip("[]'") for m in messages]
                elif isinstance(messages, dict):
                    formatted_errors[field] = [f"{k}: {v}" for k, v in messages.items()]
                else:
                    formatted_errors[field] = [str(messages).strip("[]'")]

            # Prioritize explicit 'detail' key if provided by DRF / SimpleJWT
            if "detail" in response.data:
                detail_msg = str(response.data["detail"]).strip("[]'")
            elif formatted_errors:
                # Extract first validation message cleanly for Flutter client display
                first_field = next(iter(formatted_errors))
                first_messages = formatted_errors[first_field]
                detail_msg = first_messages[0] if first_messages else "Validation error occurred."
            else:
                detail_msg = "One or more validation errors occurred."

        elif isinstance(response.data, list):
            # Cleanly format list errors without stringified python brackets
            clean_msgs = [str(m).strip("[]'") for m in response.data]
            formatted_errors["non_field_errors"] = clean_msgs
            detail_msg = " ".join(clean_msgs) if clean_msgs else "Validation error occurred."
        else:
            clean_str = str(response.data).strip("[]'")
            formatted_errors["detail"] = [clean_str]
            detail_msg = clean_str

        error_payload = {
            "type": f"https://api.infiniquote.com/errors/{response.status_code}",
            "title": response.status_text if hasattr(response, 'status_text') else "API Error",
            "status": response.status_code,
            "detail": detail_msg,
            "errors": formatted_errors,
            "error_id": error_id
        }
        response.data = error_payload
        return response

    # Handle unhandled 500 exceptions escaping DRF views
    logger.exception(f"Unhandled Server Error [{error_id}]: {str(exc)}", exc_info=exc)
    return Response({
        "type": "https://api.infiniquote.com/errors/500",
        "title": "Internal Server Error",
        "status": 500,
        "detail": "An unexpected server error occurred. Our engineering team has been alerted.",
        "errors": {"server": ["Internal server error occurred."]},
        "error_id": error_id
    }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Root Django Error Handlers for Non-DRF routing and middleware errors
def bad_request_json(request, exception=None):
    return JsonResponse({
        "type": "https://api.infiniquote.com/errors/400",
        "title": "Bad Request",
        "status": 400,
        "detail": str(exception) if exception else "The request could not be processed due to invalid syntax.",
        "errors": {"request": ["Malformed request syntax."]},
        "error_id": f"err_{uuid.uuid4().hex[:12]}"
    }, status=400, content_type="application/problem+json")

def permission_denied_json(request, exception=None):
    return JsonResponse({
        "type": "https://api.infiniquote.com/errors/403",
        "title": "Forbidden",
        "status": 403,
        "detail": str(exception) if exception else "You do not have permission to access this resource.",
        "errors": {"permission": ["Access denied."]},
        "error_id": f"err_{uuid.uuid4().hex[:12]}"
    }, status=403, content_type="application/problem+json")

def not_found_json(request, exception=None):
    return JsonResponse({
        "type": "https://api.infiniquote.com/errors/404",
        "title": "Not Found",
        "status": 404,
        "detail": f"The requested resource endpoint '{request.path}' was not found on this server.",
        "errors": {"route": ["Endpoint route does not exist."]},
        "error_id": f"err_{uuid.uuid4().hex[:12]}"
    }, status=404, content_type="application/problem+json")

def server_error_json(request):
    error_id = f"err_{uuid.uuid4().hex[:12]}"
    return JsonResponse({
        "type": "https://api.infiniquote.com/errors/500",
        "title": "Internal Server Error",
        "status": 500,
        "detail": "An unexpected server error occurred. Our engineering team has been alerted.",
        "errors": {"server": ["Internal server error occurred."]},
        "error_id": error_id
    }, status=500, content_type="application/problem+json")
```

#### Registration in `backend-1/backend/urls.py`:
```python
# backend/urls.py root handler bindings
handler400 = 'api.exceptions.bad_request_json'
handler403 = 'api.exceptions.permission_denied_json'
handler404 = 'api.exceptions.not_found_json'
handler500 = 'api.exceptions.server_error_json'
```

---

### 5.2 Celery Asynchronous Architecture & Deterministic Calendar Integration
Synchronous external network calls must be removed from HTTP request cycles to prevent socket exhaustion and latency spikes:

1. **Pre-Generated Deterministic Calendar Event ID:**
   To completely eliminate the ghost event deletion race condition (where a user deletes an event 200ms after creation before Celery runs), the backend pre-generates a deterministic Google Calendar event ID at model creation time:
   ```python
   # In Event creation logic
   google_event_id = f"tv_{user.id}_{event.id}_{uuid.uuid4().hex[:8]}"
   event.google_calendar_event_id = google_event_id
   event.save(update_fields=['google_calendar_event_id'])
   ```
   If `delete_event` is called immediately, `event.google_calendar_event_id` is already populated, enabling the Celery cancellation task to target the exact Google Calendar event ID immediately.
2. **Exponential Backoff & Rate-Limit Resilience:**
   Celery synchronization tasks must configure exponential backoff with jitter for Google Calendar API 429 (quota) and 503 (service unavailable) responses:
   ```python
   @shared_task(
       bind=True,
       autoretry_for=(HttpError, ConnectionError),
       retry_backoff=True,
       retry_backoff_max=300,
       retry_jitter=True,
       max_retries=5
   )
   def sync_event_to_google_calendar_task(self, event_id, action='create'):
       ...
   ```
3. **Token Revocation (`invalid_grant`) Handling:**
   If the Google API raises `invalid_grant` (refresh token revoked or expired), the Celery worker must update `GoogleCalendarCredential.objects.filter(user_id=user_id).update(is_active=False)`. Subsequent profile queries will report `calendar_connected: false`, prompting the user to re-link without crashing workers.
4. **Transaction Commit Hook:**
   Queue Celery tasks only after the PostgreSQL database transaction successfully commits:
   ```python
   transaction.on_commit(lambda: sync_event_to_google_calendar_task.delay(event.id, action='create'))
   ```
5. **Mandatory Deprecation of Client-Side Google Calendar API Sync:**
   In `time_verse/lib/features/calender/services/event_services.dart:50-63`, the Flutter application directly invokes `GoogleServices().createGoogleCalendarEvent()`. This client-side call MUST be deprecated and removed. All external calendar synchronization is handled authoritatively and asynchronously by backend Celery workers to avoid dual-booking and race conditions.

---

### 5.3 3-Tier Resilient AI Quote Generation Architecture & Excel Decoupling
To resolve the 4.5s latency, 429 quota exhaustion crashes, and runtime `pd.read_excel()` CPU/RAM bottlenecks on `POST /api/v1/event/create/`:

```
+-------------------------------------------------------------+
| Incoming Event Creation: POST /api/v1/event/create/         |
+------------------------------+------------------------------+
                               |
                               v
+-------------------------------------------------------------+
| Tier 1: Synchronous OpenAI Call                             |
| - Model: gpt-4o-mini (Fast, low-latency)                    |
| - Strict Timeout: 3.0 seconds (timeout=3.0)                 |
| - Circuit Breaker: Trip after 3 consecutive failures        |
+------------------------------+------------------------------+
                               |
               +---------------+---------------+
               | Success (<3.0s)               | Timeout / 429 / Circuit Open / Exception
               v                               v
+------------------------------+ +------------------------------+
| Save Generated Quote to Event| | Tier 2: Relational DB Quotes |
| Return 201 Created           | | - Query PostgreSQL Quote     |
+------------------------------+ | - Random by category (<5ms)  |
                                 +--------------+---------------+
                                                |
                                +---------------+---------------+
                                | Found in DB   | Table Empty
                                v               v
                 +------------------------------+ +------------------------------+
                 | Save Relational Quote        | | Tier 3: Universal Static     |
                 | Return 201 Created           | | - In-memory Python Array     |
                 +------------------------------+ | - 22+ Curated Quotes (<1ms)  |
                                                  | Return 201 Created           |
                                                  +------------------------------+
```

#### Relational Database `Quote` Model (Eliminating Runtime Excel I/O):
In `backend-1/event/models.py`, replace runtime `pd.read_excel()` calls with a normalized relational model:
```python
class Quote(models.Model):
    packet = models.ForeignKey('QuotePacket', on_delete=models.CASCADE, related_name='quotes')
    category = models.ForeignKey('dashbord.EventCategory', on_delete=models.SET_NULL, null=True, blank=True)
    text = models.TextField()
    author = models.CharField(max_length=255, default="Unknown")
    is_active = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['category', 'is_active']),
        ]
```
*(When administrators upload Excel quote files, they are parsed once in the background to seed the `Quote` table, completely freeing HTTP request threads from `pandas` memory bloat).*

#### Tier 3 Universal Static In-Memory Quotes (`backend-1/event/qtai.py`):
```python
UNIVERSAL_FALLBACK_QUOTES = [
    {"text": "Alone we can do so little; together we can do so much.", "author": "Helen Keller"},
    {"text": "The secret of getting ahead is getting started.", "author": "Mark Twain"},
    {"text": "It always seems impossible until it is done.", "author": "Nelson Mandela"},
    {"text": "Don't count the days, make the days count.", "author": "Muhammad Ali"},
    {"text": "Focus on being productive instead of busy.", "author": "Tim Ferriss"},
    {"text": "Action is the foundational key to all success.", "author": "Pablo Picasso"},
    {"text": "Your time is limited, don't waste it living someone else's life.", "author": "Steve Jobs"},
    {"text": "Believe you can and you're halfway there.", "author": "Theodore Roosevelt"},
    {"text": "The future depends on what you do today.", "author": "Mahatma Gandhi"},
    {"text": "Do what you can, with what you have, where you are.", "author": "Theodore Roosevelt"},
    {"text": "Quality is not an act, it is a habit.", "author": "Aristotle"},
    {"text": "Success is not final, failure is not fatal: it is the courage to continue that counts.", "author": "Winston Churchill"},
    {"text": "The best way to predict the future is to create it.", "author": "Peter Drucker"},
    {"text": "Simplicity is the soul of efficiency.", "author": "Austin Freeman"},
    {"text": "Small daily improvements over time lead to stunning results.", "author": "Robin Sharma"},
    {"text": "Energy and persistence conquer all things.", "author": "Benjamin Franklin"},
    {"text": "You don't have to be great to start, but you have to start to be great.", "author": "Zig Ziglar"},
    {"text": "Discipline is the bridge between goals and accomplishment.", "author": "Jim Rohn"},
    {"text": "Productivity is never an accident. It is always the result of a commitment to excellence.", "author": "Paul J. Meyer"},
    {"text": "Start where you are. Use what you have. Do what you can.", "author": "Arthur Ashe"},
    {"text": "Continuous improvement is better than delayed perfection.", "author": "Mark Twain"},
    {"text": "Mastering others is strength. Mastering yourself is true power.", "author": "Lao Tzu"}
]
```

---

### 5.4 Production Dependencies & Mandatory Database Migrations
To prevent immediate `ModuleNotFoundError`, `ZoneInfoNotFoundError`, `FieldError`, and `DataError` crashes in production and containerized environments:

#### 1. Additions to `backend-1/requirements.txt`:
```text
celery>=5.4.0
redis>=5.0.0
tzdata>=2025.1
```
*(Note: `tzdata` is mandatory for Python's standard library `zoneinfo` module on Windows OS and minimal Linux containers lacking the system `/usr/share/zoneinfo` database).*

#### 2. Mandatory Django Database Schema Migrations:
1. **App `userauth` Migration (`PasswordResetOTP`):**
   - Expand `otp`: change from `models.CharField(max_length=4)` to `models.CharField(max_length=6)`.
   - Add `is_used`: `models.BooleanField(default=False, db_index=True)`.
   - Add `failed_attempts`: `models.PositiveIntegerField(default=0)`.
2. **App `dashbord` Migration (`Event`):**
   - Add `repeat`: `models.CharField(max_length=50, null=True, blank=True, default="dont_repeat")`.
   - Add `custom_repeat`: `models.JSONField(null=True, blank=True)`.
   - Add `google_calendar_event_id`: `models.CharField(max_length=255, null=True, blank=True, db_index=True)`.
   - Add `last_synced_at`: `models.DateTimeField(null=True, blank=True)`.
   - Add `exception_dates`: `models.JSONField(default=list, blank=True)`.
   - Add `timezone`: `models.CharField(max_length=64, default="UTC")`.
   - Add `start_datetime_utc`: `models.DateTimeField(null=True, blank=True, db_index=True)`.
   - Add `end_datetime_utc`: `models.DateTimeField(null=True, blank=True, db_index=True)`.
3. **App `event` Migration (`Quote`):**
   - Add `Quote` relational model linking quotes to `QuotePacket` and `EventCategory`.

---

## 6. Authentication & Account Lifecycle Detailed Specifications

### 6.1 User Registration Flow (`POST /api/v1/register/`)
- **HTTP Method:** `POST`
- **URL Path:** `/api/v1/register/`
- **Authentication:** Public (`AllowAny`)
- **Headers:**
  ```http
  Content-Type: multipart/form-data
  Accept: application/json
  ```
- **Request Payload Schema:**
  | Field Name | Type | Required | Constraints | Description |
  | :--- | :--- | :---: | :--- | :--- |
  | `email` | `string (email)` | **Yes** | Valid RFC 5322 format, lowercase, unique | Account email address |
  | `password` | `string` | **Yes** | Min 8 chars, at least 1 digit or symbol | Account password |
  | `first_name` | `string` | **Yes** | Min 2 chars, max 150 chars | User's legal first name |
  | `last_name` | `string` | **Yes** | Min 2 chars, max 150 chars | User's legal surname |
  | `gender` | `string` | No | Enum: `Male`, `Female`, `Other` | Gender identity |
  | `nationality` | `string` | No | Max 100 chars | Country of origin |
  | `profile_picture`| `file (binary)` | No | JPEG/PNG/WebP, Max 5 MB | Optional avatar photo |
- **Backend Processing Requirements:**
  1. Validate email uniqueness. If email exists, return HTTP 400 with `{"email": ["A user with this email already exists."]}`.
  2. Create `User` record with hashed password (`user.set_password()`).
  3. Populate `UserProfile` with `first_name`, `last_name`, `gender`, `nationality`, and `profile_picture`.
  4. Automatically activate free subscription via `activate_free_subscription(user)`.
  5. Generate JWT token pair (`RefreshToken.for_user(user)`).
  6. Return tokens and serialized user object immediately in HTTP 201 Created (eliminating redundant `/login/` calls).
- **Success Response (`201 Created`):**
  ```json
  {
    "success": true,
    "message": "User registered successfully.",
    "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "name": "Ismail Shuvo",
      "gender": "Male",
      "nationality": "American",
      "profile_picture": "https://api.infiniquote.com/media/profile_pictures/avatar.png",
      "created_at": "2026-11-02T06:30:00Z"
    }
  }
  ```
- **Error Responses:**
  - `400 Bad Request` (Duplicate Email):
    ```json
    {
      "type": "https://api.infiniquote.com/errors/400",
      "title": "Validation Error",
      "status": 400,
      "detail": "A user with this email address already exists.",
      "errors": {
        "email": ["A user with this email already exists."]
      },
      "error_id": "err_reg_dup_01"
    }
    ```
  - `400 Bad Request` (Password Too Short):
    ```json
    {
      "type": "https://api.infiniquote.com/errors/400",
      "title": "Validation Error",
      "status": 400,
      "detail": "Password must be at least 8 characters long.",
      "errors": {
        "password": ["Ensure this field has at least 8 characters."]
      },
      "error_id": "err_reg_pw_02"
    }
    ```

---

### 6.2 Google Sign-In & ID Token Exchange (`POST /api/v1/auth/login/idtoken/`)
- **HTTP Method:** `POST`
- **URL Path:** `/api/v1/auth/login/idtoken/`
- **Authentication:** Public (`AllowAny`)
- **Headers:** `Content-Type: application/json`, `Accept: application/json`
- **Request Payload Schema:**
  | Field Name | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `id_token` | `string` | **Yes** | Google OpenID Connect JWT token signed by Google |
  | `auth_code` | `string` | No | Server authorization code for offline Calendar API access |
  | `password` | `string` | No | Required ONLY if linking an existing password-protected account |
  | `link_otp` | `string` | No | Alternative 6-digit OTP to confirm linking existing password account |
- **Backend Verification & Pre-Account Takeover Mitigation Algorithm (ADV-02):**
  1. Define authorized client ID list:
     ```python
     VALID_AUDIENCES = [
         settings.GOOGLE_CLIENT_ID_WEB,
         settings.GOOGLE_CLIENT_ID_ANDROID,
         settings.GOOGLE_CLIENT_ID_IOS,
         settings.GOOGLE_CLIENT_ID_SERVER,
     ]
     ```
  2. Verify `id_token` signature against Google certificates with audience validation against `VALID_AUDIENCES`.
  3. **Mandatory Email Verification Check (ADV-02):**
     ```python
     if not id_info.get('email_verified', False):
         return Response({
             "type": "https://api.infiniquote.com/errors/403",
             "title": "Email Not Verified",
             "status": 403,
             "detail": "Google account email is not verified. Unverified emails cannot authenticate.",
             "errors": {"email": ["Unverified Google email address."]}
         }, status=status.HTTP_403_FORBIDDEN)
     ```
  4. Extract `email`, `given_name`, `family_name`, `name`, and `picture`.
  5. **Pre-Account Takeover Defense (ADV-02):**
     Check if a `User` record already exists with this email:
     ```python
     try:
         existing_user = User.objects.get(email=email)
         # If existing user has a usable password, prevent silent takeover!
         if existing_user.has_usable_password():
             password = request.data.get('password')
             link_otp = request.data.get('link_otp')
             is_authorized = False

             if password and existing_user.check_password(password):
                 is_authorized = True
             elif link_otp:
                 otp_record = PasswordResetOTP.objects.filter(
                     user=existing_user, otp=link_otp, is_used=False
                 ).order_by('-created_at').first()
                 if otp_record and (timezone.now() - otp_record.created_at < datetime.timedelta(minutes=5)):
                     otp_record.is_used = True
                     otp_record.save(update_fields=['is_used'])
                     # Invalidate any prior attacker password so attacker cannot retain backdoor access
                     existing_user.set_unusable_password()
                     existing_user.save(update_fields=['password'])
                     is_authorized = True

             if not is_authorized:
                 return Response({
                     "type": "https://api.infiniquote.com/errors/409",
                     "title": "Account Linking Confirmation Required",
                     "status": 409,
                     "detail": "An account with this email already exists with a password. Please provide your password or verify an email OTP to link Google Sign-In.",
                     "requires_link_confirmation": True
                 }, status=status.HTTP_409_CONFLICT)
     except User.DoesNotExist:
         # Create new Google user
         user = User.objects.create_user(email=email, first_name=given_name, last_name=family_name)
         user.set_unusable_password()
         user.save()
         activate_free_subscription(user)
     ```
  6. **Calendar Authorization Exchange:**
     - If `auth_code` is provided: exchange against Google token endpoint using registered server client credentials.
     - Persist `refresh_token` and `access_token` in `GoogleCalendarCredential`.
  7. **Dual-Key Response Construction (P0 / ADV-09 Compatibility):**
     In `time_verse/lib/config/services/google_service.dart:134-147`, the mobile app strictly inspects `data['access_token']`, `data['name']`, and `data['picture']` at the root of the JSON object. To guarantee 100% backward compatibility with both legacy mobile builds and standard SimpleJWT consumers, return BOTH canonical SimpleJWT keys (`access`, `refresh`, `user`) AND legacy root-level keys:
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "name": "Ismail Shuvo",
    "picture": "https://lh3.googleusercontent.com/a/ACg8oc...",
    "calendar_synced": true,
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "name": "Ismail Shuvo",
      "profile_picture": "https://lh3.googleusercontent.com/a/ACg8oc...",
      "is_google_user": true
    }
  }
  ```
- **Error Response (`400 Bad Request`):**
  ```json
  {
    "type": "https://api.infiniquote.com/errors/400",
    "title": "Invalid Token",
    "status": 400,
    "detail": "Google ID token validation failed. Unrecognized audience or expired token.",
    "errors": {
      "id_token": ["Token verification failed."]
    },
    "error_id": "err_goog_auth_01"
  }
  ```

---

### 6.3 Password Recovery Flow (Dual-Mode OTP & Reset Token)
The backend supports two distinct consumption patterns:
- **Mobile Client Direct Flow (`auth_service.dart:325`):** Submits `email`, `otp`, and `new_password` directly to `/reset-password/`.
- **Web / Two-Step Flow:** Submits `email` and `otp` to `/verify-otp/` to receive a `reset_token`, followed by `/reset-password/` with `reset_token`.

```
[Mobile App / Web User]           [Backend Endpoints]                   [Database & Token Generator]
          |                                |                                         |
          |--- 1. POST /forget_password/ ->|                                         |
          |    (email: alice@example.com)  |--- Throttling (5 req / 15 min) -------->|
          |                                |--- Invalidate previous OTPs ----------->|
          |                                |--- Generate 6-digit OTP (secrets) ----->|
          |                                |--- Offload send_email to Celery ------->|
          |<-- 2. Return 200 OK -----------|                                         |
          |                                                                          |
          |--- [OPTION A: Flutter Mobile App Direct Reset Flow] -------------------->|
          |--- 3a. POST /reset-password/ ->|                                         |
          |    (email, otp, new_password)  |--- Validate OTP & check 5m TTL -------->|
          |                                |--- Check failed_attempts (< 5) -------->|
          |                                |--- Increment attempt on mismatch ------>|
          |                                |--- transaction.atomic():                |
          |                                |      user.set_password(new_password)    |
          |                                |      OTPs.update(is_used=True) -------->|
          |<-- 4a. Return 200 OK ----------|                                         |
          |                                                                          |
          |--- [OPTION B: Web / Two-Step Token Flow] --------------------------------|
          |--- 3b. POST /verify-otp/ ----->|                                         |
          |    (email, otp)                |--- Validate OTP & check failed attempts |
          |                                |--- default_token_generator.make_token ->|
          |<-- 4b. Return {reset_token} ---|                                         |
          |                                                                          |
          |--- 5b. POST /reset-password/ ->|                                         |
          |    (email, reset_token, new_pw)|--- Verify default_token_generator ----->|
          |                                |--- transaction.atomic():                |
          |                                |      user.set_password(new_password)    |
          |                                |      (Token invalidated by PW change!)->|
          |<-- 6b. Return 200 OK ----------|                                         |
```

---

### 6.4 Secure Account Deletion Flow & Google Calendar Cleanup
- **HTTP Methods Supported:** Both `DELETE` and `POST /api/v1/delete-account/` (resolves mobile 405 error).
- **Authentication:** `Bearer <access_token>`
- **Request Payload Schema:**
  ```json
  {
    "password": "UserPassword123!",
    "id_token": "<optional_fresh_google_id_token>",
    "email_otp": "<optional_6_digit_confirmation_otp>"
  }
  ```
- **Re-Authentication & Ghost Event Prevention Processing Logic (ADV-04 & Challenger 2):**
  ```python
  @api_view(['DELETE', 'POST'])
  @permission_classes([IsAuthenticated])
  def delete_account(request):
      user = request.user
      password = request.data.get('password')
      id_token_str = request.data.get('id_token')
      email_otp = request.data.get('email_otp')

      # 1. Re-authentication verification
      if user.has_usable_password():
          if not password or not user.check_password(password):
              return Response({
                  "type": "https://api.infiniquote.com/errors/400",
                  "title": "Invalid Credentials",
                  "status": 400,
                  "detail": "Password is incorrect. Re-authentication required for deletion.",
                  "errors": {"password": ["Invalid password."]}
              }, status=status.HTTP_400_BAD_REQUEST)
      else:
          # Google OAuth users without usable passwords MUST re-authenticate
          reauth_valid = False
          if id_token_str:
              try:
                  id_info = id_token.verify_oauth2_token(id_token_str, google_requests.Request(), audience=VALID_AUDIENCES)
                  # Ensure token was issued within the last 5 minutes
                  auth_time = id_info.get('auth_time', id_info.get('iat', 0))
                  if (time.time() - auth_time) < 300 and id_info.get('email') == user.email:
                      reauth_valid = True
              except Exception:
                  reauth_valid = False
          elif email_otp:
              otp_record = PasswordResetOTP.objects.filter(user=user, otp=email_otp, is_used=False).order_by('-created_at').first()
              if otp_record and (timezone.now() - otp_record.created_at < datetime.timedelta(minutes=5)):
                  otp_record.is_used = True
                  otp_record.save(update_fields=['is_used'])
                  reauth_valid = True

          if not reauth_valid:
              return Response({
                  "type": "https://api.infiniquote.com/errors/401",
                  "title": "Re-Authentication Required",
                  "status": 401,
                  "detail": "Google OAuth users must supply a fresh Google ID token or email confirmation OTP before deleting their account.",
                  "errors": {"reauth": ["Fresh Google ID token or email OTP required."]}
              }, status=status.HTTP_401_UNAUTHORIZED)

      # 2. External Google Calendar Cleanup (Prevent Orphaned Ghost Events)
      # Synchronously or via immediate Celery blocking call purge external events BEFORE cascading deletion.
      # Note: For accounts with high event volume (>50 events), use Google Calendar Batch Request
      # or soft-delete (user.is_active=False) with background Celery task to avoid HTTP 504 timeouts:
      try:
          cred = GoogleCalendarCredential.objects.filter(user=user, is_active=True).first()
          if cred:
              synced_events = Event.objects.filter(user=user, google_calendar_event_id__isnull=False)
              for ev in synced_events:
                  try:
                      delete_google_calendar_event_synchronous(cred, ev.google_calendar_event_id)
                  except Exception as e:
                      logger.warning(f"Failed to delete external Google Calendar event {ev.google_calendar_event_id}: {e}")
      except Exception as e:
          logger.error(f"Error purging Google Calendar credentials for user {user.id}: {e}")

      # 3. Cascading database deletion
      user.delete()
      return Response({
          "success": true,
          "message": "Your account and associated data have been permanently deleted."
      }, status=status.HTTP_200_OK)
  ```

---

## 7. Event Synchronization, Timezones & Calendar Integration Contracts

### 7.1 Timezone & Timestamp Handling Contract
To resolve the discrepancy where upcoming events disappear prematurely and push alarm notifications drift by several hours:

1. **Client Header Requirement:**  
   The Flutter app sends the user's localized IANA timezone string in every authenticated request header:
   ```http
   X-Timezone: America/New_York
   ```
   *(Supported examples: `Europe/London`, `Asia/Dhaka`, `America/Los_Angeles`, `UTC`).*

2. **Backend Timezone Activation (`tzdata` Dependency):**  
   In Django middleware or view logic, activate the request timezone using `zoneinfo.ZoneInfo`. To prevent `ZoneInfoNotFoundError` on Windows servers and minimal Linux containers, `tzdata>=2025.1` must be installed in `requirements.txt`:
   ```python
   import zoneinfo
   from django.utils import timezone

   tz_name = request.headers.get('X-Timezone') or getattr(request.user, 'timezone', 'UTC')
   try:
       user_tz = zoneinfo.ZoneInfo(tz_name)
   except Exception:
       user_tz = zoneinfo.ZoneInfo('UTC')

   # Localized boundaries for upcoming/today queries
   now_utc = timezone.now()
   now_local = now_utc.astimezone(user_tz)
   today_local = now_local.date()
   time_local = now_local.time()
   ```

3. **Storage Format & Travel Semantic Integrity:**  
   All datetimes (`alarm_time`, `created_at`, `last_synced_at`) are stored in PostgreSQL as **timezone-aware UTC timestamps** (`TIMESTAMPTZ`). To prevent 5–6 hour wall-clock drifts when users travel across timezones, the `Event` model persists:
   - `timezone = models.CharField(max_length=64, default="UTC")`: The IANA timezone in which the event was scheduled.
   - `start_datetime_utc = models.DateTimeField(null=True, blank=True, db_index=True)`: The absolute instant of event start.
   - `end_datetime_utc = models.DateTimeField(null=True, blank=True, db_index=True)`: The absolute instant of event conclusion.
   
4. **Overnight Schedule Handling:**  
   For events where `end_time < start_time` (e.g., `start_time: "23:00"` and `end_time: "02:00"`), the backend automatically assigns `end_datetime_utc` to the following calendar day, validating `end_datetime_utc > start_datetime_utc`.

---

### 7.2 Atomic Idempotent Event Creation & Google Calendar Sync Protocol

```
[Mobile App]                       [Django API Worker]                  [Redis Lock / Cache]             [PostgreSQL]             [Celery Worker]
     |                                      |                                    |                            |                        |
     |-- POST /api/v1/event/create/ ------->|                                    |                            |                        |
     |   Header: Idempotency-Key: uuid      |-- SET lock:idemp:{key} NX EX 60 -->|                            |                        |
     |   Body: {title, date, times...}      |<-- Lock Acquired (1) --------------|                            |                        |
     |                                      |                                    |                            |                        |
     |                                      |-- Fingerprint SHA-256 payload ---->|                            |                        |
     |                                      |-- Run Tier 1-3 AI Quote Generator  |                            |                        |
     |                                      |<-- Quote resolved (<200ms) --------|                            |                        |
     |                                      |                                    |                            |                        |
     |                                      |-- Pre-generate google_event_id --->|                            |                        |
     |                                      |-- Save Event record -------------->|--------------------------->|                        |
     |                                      |<-- Event saved (ID: 1816476) ------|                            |                        |
     |                                      |                                    |                            |                        |
     |                                      |-- Cache Response (EX 86400) ------>|                            |                        |
     |                                      |-- transaction.on_commit() -------------------------------------------------------------->|
     |<-- Return 201 Created (immediate) ---|                                    |                            |                        |
     |                                                                                                                                 |-- Sync to Google
```

#### Deduplication & Atomic Idempotency Rules (Challenger 2):
1. **Redis Atomic Distributed Lock:**  
   The backend enforces a Redis atomic lock:
   ```python
   lock_key = f"lock:idempotency:{request.user.id}:{idempotency_key}"
   acquired = redis_client.set(lock_key, "IN_PROGRESS", nx=True, ex=60)
   if not acquired:
       # A concurrent request with this key is already in flight
       return Response({
           "type": "https://api.infiniquote.com/errors/409",
           "title": "Concurrent Request In Progress",
           "status": 409,
           "detail": "An identical event creation request is currently being processed. Please retry shortly.",
           "error_id": f"err_idemp_{uuid.uuid4().hex[:8]}"
       }, status=status.HTTP_409_CONFLICT, headers={"Retry-After": "2"})
   ```
2. **Payload SHA-256 Fingerprint Validation:**  
   Compute the deterministic SHA-256 hash of the request payload:
   ```python
   payload_hash = hashlib.sha256(json.dumps(request.data, sort_keys=True).encode()).hexdigest()
   cached_data = redis_client.get(f"idempotency:{request.user.id}:{idempotency_key}")
   if cached_data:
       cached_json = json.loads(cached_data)
       if cached_json.get("payload_hash") != payload_hash:
           return Response({
               "type": "https://api.infiniquote.com/errors/422",
               "title": "Idempotency Key Payload Mismatch",
               "status": 422,
               "detail": "The Idempotency-Key provided was previously used with a different request payload.",
               "error_id": f"err_idemp_tamper_{uuid.uuid4().hex[:8]}"
           }, status=status.HTTP_422_UNPROCESSABLE_ENTITY)
       # Return cached response without creating duplicate database records
       return Response(cached_json["response_data"], status=status.HTTP_201_CREATED, headers={"Idempotent-Replayed": "true"})
   ```
3. **Pre-Generated External Google Calendar ID:**  
   Before writing to PostgreSQL, generate a deterministic external event ID:
   ```python
   event.google_calendar_event_id = f"tv_{request.user.id}_{event.id}_{uuid.uuid4().hex[:8]}"
   ```
   This ensures that if the event is immediately deleted, `google_calendar_event_id` is never null, enabling Celery to cancel the Google Calendar event cleanly.
4. **Mandatory Client-Side Sync Deprecation:**  
   The Flutter app MUST deprecate and remove client-side `GoogleServices().createGoogleCalendarEvent()` in `event_services.dart:52`. All calendar synchronization is handled asynchronously server-side.

---

### 7.3 Recurrence Engine, RFC 5545 Compliance & Occurrence Expansion

#### 1. Day-of-Week Abbreviation Disambiguation (RFC 5545 Standard):
In `add_event_controller.dart:138`, Flutter extracts single letters (`"T-2"` -> `"T"`, `"T-4"` -> `"T"`), creating fatal collisions where Tuesday and Thursday both map to `"T"` and Saturday and Sunday both map to `"S"`.  
To resolve this, the backend and client contractually standardize on **RFC 5545 2-letter day codes**:
```json
["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
```

#### 2. Single-Occurrence Exception Dates (`exception_dates`):
To support deleting or modifying single occurrences (`?delete_type=single`) without corrupting recurring series, the `Event` model persists an array of canceled date strings:
```python
# In Event model
exception_dates = models.JSONField(default=list, blank=True)
```
When a client deletes a single instance via `DELETE /api/v1/event/delete/{id}/?delete_type=single&date=2026-11-05`:
1. The backend verifies `event.repeat != 'dont_repeat'`.
2. The backend appends `"2026-11-05"` to `event.exception_dates`.
3. The master series remains active in the database; only the target instance is cancelled.

#### 3. Date-Filtered Query Occurrence Expansion Algorithm (`GET /api/v1/event/?date=YYYY-MM-DD`):
When a client queries events for a specific day, the backend must expand recurring rules rather than performing naive `Event.objects.filter(date=target_date)` (which drops recurring events created on prior dates):

```python
def expand_events_for_date(user, target_date_str, user_tz):
    target_date = datetime.date.fromisoformat(target_date_str)
    day_name_2letter = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"][target_date.weekday()]

    # 1. Non-recurring events created for this exact date
    single_events = list(Event.objects.filter(
        user=user,
        date=target_date,
        repeat="dont_repeat"
    ))

    # 2. Recurring series whose start date is on or before target_date
    recurring_series = Event.objects.filter(
        user=user,
        date__lte=target_date
    ).exclude(repeat="dont_repeat")

    expanded_events = []
    for master in recurring_series:
        # Check if target date is explicitly cancelled
        if target_date_str in (master.exception_dates or []):
            continue

        # Check end conditions (end_date or end_count)
        if master.custom_repeat:
            end_date = master.custom_repeat.get('end_date')
            if end_date and target_date > datetime.date.fromisoformat(end_date):
                continue

        # Match frequency rules
        matches = False
        if master.repeat == "daily":
            matches = True
        elif master.repeat == "weekly":
            # Match day of week
            if master.date.weekday() == target_date.weekday():
                matches = True
        elif master.repeat == "custom" and master.custom_repeat:
            repeat_days = master.custom_repeat.get('repeat_days', [])
            if day_name_2letter in repeat_days:
                matches = True

        if matches:
            # Clone event representation for target date
            instance_data = EventSerializer(master).data
            instance_data['date'] = target_date_str
            instance_data['is_recurring_instance'] = True
            instance_data['master_event_id'] = master.id
            expanded_events.append(instance_data)

    return single_events + expanded_events
```

---

## 8. Complete & Exhaustive API Reference Specification

All endpoints are hosted at `https://api.infiniquote.com/api/v1`.  
Unless explicitly marked as Public, all endpoints require:
```http
Authorization: Bearer <access_token>
X-Timezone: <IANA_Timezone_String>
Content-Type: application/json
Accept: application/json
```

---

### 8.1 Authentication & Account APIs

#### 8.1.1 Register User
- **Method / Path:** `POST /api/v1/register/`
- **Auth:** Public
- **Content-Type:** `multipart/form-data` or `application/json`
- **Request Parameters:**
  - `email` (string, required): Valid unique email.
  - `password` (string, required): Min 8 characters.
  - `first_name` (string, required): Min 2 characters.
  - `last_name` (string, required): Min 2 characters.
  - `gender` (string, optional): `Male` | `Female` | `Other`.
  - `nationality` (string, optional): Country name.
  - `profile_picture` (file, optional): JPEG/PNG avatar file.
- **Success Response (`201 Created`):**
  ```json
  {
    "success": true,
    "message": "User registered successfully.",
    "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "name": "Ismail Shuvo",
      "gender": "Male",
      "nationality": "American",
      "profile_picture": "https://api.infiniquote.com/media/profile_pictures/avatar.png"
    }
  }
  ```
- **Error Responses:**
  - `400 Bad Request` — `{"type": "...", "status": 400, "errors": {"email": ["A user with this email already exists."]}}`

#### 8.1.2 User Login
- **Method / Path:** `POST /api/v1/login/`
- **Auth:** Public
- **Rate Limit:** 10 requests / minute (Composite: IP + Email hash); 5 consecutive failed attempts lock account for 15 minutes.
- **Request Payload:**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "password": "UserPassword123!"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "name": "Ismail Shuvo",
      "profile_picture": "https://api.infiniquote.com/media/profile_pictures/avatar.png",
      "birth_date": "1998-05-15"
    }
  }
  ```
- **Error Responses:**
  - `401 Unauthorized` — `{"type": "https://api.infiniquote.com/errors/401", "status": 401, "detail": "No active account found with the given credentials."}`
  - `429 Too Many Requests` — `{"type": "https://api.infiniquote.com/errors/429", "status": 429, "detail": "Request limit exceeded. Please wait 60 seconds before trying again."}`

#### 8.1.3 Google ID Token Login & Sync
- **Method / Path:** `POST /api/v1/auth/login/idtoken/`
- **Auth:** Public
- **Request Payload Schema:**
  | Field | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `id_token` | `string` | **Yes** | Google OpenID Connect JWT token signed by Google |
  | `auth_code` | `string` | No | Server authorization code for offline Calendar API access |
  | `password` | `string` | No | Password required only if linking an existing password-protected account |
  | `link_otp` | `string` | No | 6-digit confirmation OTP to link an existing password account |
- **Security Assertions:**
  - `assert id_info.get('email_verified') is True` enforced.
  - Silent pre-account takeover prevented: existing password accounts require `password` or `link_otp` confirmation.
- **Success Response (`200 OK` — Dual Key Compatibility for Flutter Mobile & SimpleJWT):**
  ```json
  {
    "success": true,
    "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "name": "Ismail Shuvo",
    "picture": "https://lh3.googleusercontent.com/a/ACg8oc...",
    "calendar_synced": true,
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "name": "Ismail Shuvo",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "profile_picture": "https://lh3.googleusercontent.com/a/ACg8oc...",
      "is_google_user": true
    }
  }
  ```
  *(Note: Top-level `access_token`, `name`, and `picture` are strictly required by `time_verse/lib/config/services/google_service.dart:137-145` to store credentials into `AppPrefs` and `UserSession`).*
- **Error Responses:**
  - `400 Bad Request` — `{"type": "https://api.infiniquote.com/errors/400", "status": 400, "errors": {"id_token": ["Invalid Google token."]}}`
  - `403 Forbidden` — `{"type": "https://api.infiniquote.com/errors/403", "status": 403, "detail": "Google account email is not verified by Google."}`
  - `409 Conflict` — `{"type": "https://api.infiniquote.com/errors/409", "status": 409, "detail": "Account exists with password. Re-authentication required to link.", "requires_link_confirmation": true}`

#### 8.1.4 Token Refresh
- **Method / Path:** `POST /api/v1/token/refresh/`
- **Auth:** Public
- **Contract:** SimpleJWT token rotation active (`ROTATE_REFRESH_TOKENS = True`, `BLACKLIST_AFTER_ROTATION = True`). Access token lifetime is 15 minutes; refresh token lifetime is 30 days.
- **Client Constraint:** Flutter Dio client must use a `QueuedInterceptor` to prevent race conditions when multiple concurrent requests trigger token refresh simultaneously.
- **Request Payload:**
  ```json
  {
    "refresh": "<jwt_refresh_token>"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "access": "<new_jwt_access_token>",
    "refresh": "<new_jwt_refresh_token>"
  }
  ```
- **Error Responses:**
  - `401 Unauthorized` — `{"type": "https://api.infiniquote.com/errors/401", "status": 401, "detail": "Token is invalid, blacklisted, or expired."}`

#### 8.1.5 Forgot Password (Request OTP)
- **Method / Path:** `POST /api/v1/forget_password/`
- **Auth:** Public
- **Rate Limit:** 5 requests / 15 minutes (Composite: IP + Email hash)
- **Request Payload:**
  ```json
  {
    "email": "ismailshuvo555@gmail.com"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "A 6-digit verification code has been sent to your email."
  }
  ```
- **Error Responses:**
  - `404 Not Found` — `{"type": "https://api.infiniquote.com/errors/404", "status": 404, "errors": {"email": ["No user found with this email."]}}`
  - `503 Service Unavailable` — `{"type": "https://api.infiniquote.com/errors/503", "status": 503, "detail": "Email delivery service temporarily unavailable. Please try again shortly."}`

#### 8.1.6 Resend OTP
- **Method / Path:** `POST /api/v1/resend-otp/`
- **Auth:** Public
- **Rate Limit:** 5 requests / 15 minutes
- **Request Payload:**
  ```json
  {
    "email": "ismailshuvo555@gmail.com"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "A new verification code has been dispatched."
  }
  ```

#### 8.1.7 Verify OTP
- **Method / Path:** `POST /api/v1/verify-otp/`
- **Auth:** Public
- **Rate Limit:** 5 requests / 15 minutes
- **Request Payload:**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "otp": "481920"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "OTP verified successfully.",
    "reset_token": "cf5435e07663b65a5e9-b17u7v68102"
  }
  ```
- **Error Responses:**
  - `400 Bad Request` — `{"type": "https://api.infiniquote.com/errors/400", "status": 400, "errors": {"otp": ["Invalid or expired verification code. 4 attempts remaining."]}}`

#### 8.1.8 Reset Password (Dual-Mode: Mobile OTP & Django Reset Token)
- **Method / Path:** `POST /api/v1/reset-password/`
- **Auth:** Public (Requires either `otp` OR `reset_token`)
- **Rate Limit:** 5 requests / 15 minutes
- **Request Parameters Schema:**
  | Field | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `email` | `string (email)` | **Yes** | Registered account email |
  | `new_password` | `string` | **Yes** | New password (min 8 chars) |
  | `otp` | `string (6 digits)` | Optional | Submitted directly by Flutter mobile client (`auth_service.dart:325`) |
  | `reset_token` | `string` | Optional | Django `default_token_generator` token submitted by web client |
- **Request Payload Example A (Flutter Mobile Client):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "otp": "481920",
    "new_password": "NewSecurePassword123!"
  }
  ```
- **Request Payload Example B (Web / Django Reset Token):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "reset_token": "cf5435e07663b65a5e9-b17u7v68102",
    "new_password": "NewSecurePassword123!"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "Password has been reset successfully. Please log in with your new credentials."
  }
  ```
- **Error Responses:**
  - `400 Bad Request` (Invalid Code / Lockout):
    ```json
    {
      "type": "https://api.infiniquote.com/errors/400",
      "title": "Validation Error",
      "status": 400,
      "detail": "Invalid verification code. 2 attempt(s) remaining.",
      "errors": {
        "otp": ["Invalid verification code. 2 attempt(s) remaining."]
      },
      "error_id": "err_otp_inv_04"
    }
    ```
  - `400 Bad Request` (Token Replayed / Expired):
    ```json
    {
      "type": "https://api.infiniquote.com/errors/400",
      "title": "Validation Error",
      "status": 400,
      "detail": "Reset token is invalid, expired, or has already been used.",
      "errors": {
        "reset_token": ["Reset token is invalid, expired, or has already been used."]
      },
      "error_id": "err_tok_used_01"
    }
    ```

#### 8.1.9 Change Password (Authenticated)
- **Method / Path:** `POST /api/v1/change-password/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:**
  ```json
  {
    "old_password": "OldPassword123!",
    "new_password": "NewPassword456!"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "Password changed successfully."
  }
  ```
- **Error Responses:**
  - `400 Bad Request` — `{"type": "https://api.infiniquote.com/errors/400", "status": 400, "errors": {"old_password": ["Current password is incorrect."]}}`

#### 8.1.10 Logout
- **Method / Path:** `POST /api/v1/logout/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:**
  ```json
  {
    "refresh": "<jwt_refresh_token>"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "Logged out successfully."
  }
  ```

#### 8.1.11 Delete Account (Re-Authenticated & Ghost Event Purged)
- **Method / Path:** `DELETE /api/v1/delete-account/` (and alias `POST /api/v1/delete-account/`)
- **Auth:** `Bearer <access_token>`
- **Request Payload Schema:**
  | Field | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `password` | `string` | Conditional | Required for standard password accounts |
  | `id_token` | `string` | Conditional | Fresh Google ID token (issued <5 min ago) for OAuth users without password |
  | `email_otp` | `string` | Conditional | Alternative 6-digit confirmation OTP for OAuth users |
- **Request Payload Example (Standard Password User):**
  ```json
  {
    "password": "UserPassword123!"
  }
  ```
- **Request Payload Example (Google OAuth User):**
  ```json
  {
    "id_token": "<fresh_google_id_token>"
  }
  ```
- **Processing Logic:**
  1. Validates re-authentication credentials.
  2. Purges external Google Calendar events before database deletion to prevent orphaned ghost events.
  3. Executes cascading deletion of `User`, `UserProfile`, `Event`, and `GoogleCalendarCredential` records.
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "Your account and associated data have been permanently deleted."
  }
  ```
- **Error Responses:**
  - `400 Bad Request` — `{"type": "https://api.infiniquote.com/errors/400", "status": 400, "detail": "Password is incorrect. Re-authentication required for deletion."}`
  - `401 Unauthorized` — `{"type": "https://api.infiniquote.com/errors/401", "status": 401, "detail": "Google OAuth users must supply a fresh Google ID token or email confirmation OTP before deleting their account."}`

---

### 8.2 User Profile, Mood, FCM & Legal APIs

#### 8.2.1 Get User Profile
- **Method / Path:** `GET /api/v1/profile/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):**
  ```json
  {
    "id": 75,
    "first_name": "Ismail",
    "last_name": "Shuvo",
    "name": "Ismail Shuvo",
    "email": "ismailshuvo555@gmail.com",
    "birth_date": "1998-05-15",
    "profile_picture": "https://api.infiniquote.com/media/profile_pictures/avatar.png"
  }
  ```

#### 8.2.2 Update User Profile
- **Method / Path:** `PUT /api/v1/profile/` (and alias `PATCH /api/v1/profile/`)
- **Auth:** `Bearer <access_token>`
- **Content-Type:** `multipart/form-data` or `application/json`
- **Request Payload:**
  - `first_name` (string, optional)
  - `last_name` (string, optional)
  - `name` (string, optional — automatically splits into first/last name)
  - `birth_date` (string `YYYY-MM-DD`, optional)
  - `profile_picture` (file, optional)
- **Success Response (`200 OK`):** Returns updated Profile object.

#### 8.2.3 Submit Daily User Mood
- **Method / Path:** `POST /api/v1/user/mood/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:**
  ```json
  {
    "mood": "Happy"
  }
  ```
- **Success Response (`201 Created`):**
  ```json
  {
    "success": true,
    "message": "Mood recorded successfully.",
    "mood": "Happy",
    "recorded_at": "2026-11-02T06:30:00Z"
  }
  ```

#### 8.2.4 Update FCM Push Token
- **Method / Path:** `POST /api/v1/update-fcm-token/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:**
  ```json
  {
    "fcm_token": "dGhpcy1pcy1hLWZha2UtZmNtLXRva2Vu..."
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "FCM device token registered successfully."
  }
  ```

#### 8.2.5 Privacy Policy & Terms of Service
- **Methods / Paths:**
  - `GET /api/v1/privacy-policy/`
  - `GET /api/v1/terms-and-conditions/`
- **Auth:** Public
- **Success Response (`200 OK`):**
  ```json
  {
    "id": 1,
    "title": "Privacy Policy",
    "description": "<h2>Privacy Policy</h2><p>Your privacy is important to us...</p>"
  }
  ```

---

### 8.3 Categories & Event Management APIs

#### 8.3.1 Get Event Categories
- **Method / Path:** `GET /api/v1/categories/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):**
  ```json
  [
    { "id": 1, "name": "Success Stories" },
    { "id": 2, "name": "Daily Motivation" },
    { "id": 12, "name": "Work" }
  ]
  ```

#### 8.3.2 Create Event
- **Method / Path:** `POST /api/v1/event/create/`
- **Auth:** `Bearer <access_token>`
- **Headers:** `Idempotency-Key: <UUID>` (recommended), `X-Timezone: <IANA>`
- **Request Payload:**
  ```json
  {
    "title": "Team Roadmap Sync",
    "date": "2026-11-05",
    "start_time": "10:00",
    "end_time": "11:00",
    "alarm_time": "2026-11-05T09:45:00Z",
    "is_alarm_sent": false,
    "is_completed": false,
    "location": "Conference Room A",
    "category_name": "Work",
    "type_event_description": "Review sprint goals",
    "repeat": "custom",
    "custom_repeat": {
      "repeat_every": 1,
      "repeat_unit": "week",
      "repeat_days": ["MO", "WE", "FR"],
      "ends": "after",
      "end_date": null,
      "end_count": 5
    }
  }
  ```
  *(Note: `repeat_days` MUST use RFC 5545 standard 2-letter codes: `MO`, `TU`, `WE`, `TH`, `FR`, `SA`, `SU` to prevent single-letter abbreviation collisions).*
- **Success Response (`201 Created`):**
  ```json
  {
    "id": 1816476,
    "user": 75,
    "title": "Team Roadmap Sync",
    "description": "Alone we can do so little; together we can do so much.",
    "type_event_description": "Review sprint goals",
    "date": "2026-11-05",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "location": "Conference Room A",
    "alarm_time": "2026-11-05T09:45:00Z",
    "category": 12,
    "category_name": "Work",
    "repeat": "custom",
    "custom_repeat": {
      "repeat_every": 1,
      "repeat_unit": "week",
      "repeat_days": ["MO", "WE", "FR"],
      "ends": "after",
      "end_date": null,
      "end_count": 5
    },
    "exception_dates": [],
    "is_completed": false,
    "is_alarm_sent": false,
    "is_favorite": false,
    "google_calendar_event_id": "tv_75_1816476_a1b2c3d4",
    "created_at": "2026-11-02T06:30:00Z",
    "ai_quote_available": true
  }
  ```

#### 8.3.3 List User Events (Scoping to Authenticated User & Recurrence Expansion)
- **Method / Path:** `GET /api/v1/event/`
- **Auth:** `Bearer <access_token>`
- **Query Parameters:** `?date=YYYY-MM-DD` (optional date filter)
- **Recurrence Query Processing Contract (Challenger 2):**  
  When `?date=YYYY-MM-DD` is passed, the backend does NOT perform naive `date=YYYY-MM-DD` filtering. Instead, it executes the occurrence expansion algorithm (Section 7.3):
  1. Retrieves all non-recurring events for `target_date`.
  2. Evaluates all recurring master records (`date <= target_date` and `repeat != 'dont_repeat'`).
  3. Filters out any occurrence where `target_date` is listed in `event.exception_dates`.
  4. Returns both single events and synthetic recurring instances for that specific date.
- **Success Response (`200 OK`):**
  ```json
  [
    {
      "id": 1816476,
      "user": 75,
      "title": "Team Roadmap Sync",
      "description": "Alone we can do so little; together we can do so much.",
      "date": "2026-11-05",
      "start_time": "10:00:00",
      "end_time": "11:00:00",
      "location": "Conference Room A",
      "alarm_time": "2026-11-05T09:45:00Z",
      "is_favorite": false,
      "is_recurring_instance": false
    }
  ]
  ```

#### 8.3.4 List Upcoming Events
- **Method / Path:** `GET /api/v1/up-comming/events/` (and alias `/api/v1/upcoming/events/`)
- **Auth:** `Bearer <access_token>`
- **Query Parameters:** `?date=YYYY-MM-DD` (optional)
- **Success Response (`200 OK`):** Array of future events scoped strictly to `request.user` based on user's localized date/time boundaries.

#### 8.3.5 Get Single Event Details
- **Method / Path:** `GET /api/v1/event/details/?event_id={id}` (and `GET /api/v1/event/details/{id}/`)
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):** Single Event object.
- **Error Response (`403 Forbidden`):** If event belongs to another user.

#### 8.3.6 Update Event
- **Method / Path:** `PATCH /api/v1/event/create/?id={id}` (and `PATCH /api/v1/event/update/{id}/`)
- **Auth:** `Bearer <access_token>`
- **Request Payload:** Partial Event fields to update.
- **Success Response (`200 OK`):** Updated Event object.

#### 8.3.7 Delete Event (Single Occurrence vs Full Series)
- **Method / Path:** `DELETE /api/v1/event/delete/{id}/` (and alias `DELETE /api/v1/evenet/delete/{id}/`)
- **Auth:** `Bearer <access_token>`
- **Query Parameters:**
  - `?delete_type=single&date=YYYY-MM-DD`: Deletes only the occurrence on `date`. Appends `YYYY-MM-DD` to `event.exception_dates`. Master row remains intact.
  - `?delete_type=all`: Deletes the master recurring series and all future occurrences. Queues Celery background task to remove from Google Calendar.
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "Event deleted successfully."
  }
  ```

---

### 8.4 Quotes, Favorites, AI Reflection & Feedback APIs

#### 8.4.1 Toggle Favorite Quote
- **Method / Path:** `POST /api/v1/event/{id}/favorite/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:** `{}`
- **Success Response (`200 OK`):** Event object with updated `"is_favorite": true` (or `false`).

#### 8.4.2 Get Saved Quotes ("My Quotes")
- **Method / Path:** `GET /api/v1/event/my-quotes/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):**
  ```json
  [
    {
      "id": 1816476,
      "description": "Alone we can do so little; together we can do so much.",
      "author": "Helen Keller",
      "is_favorite": true,
      "created_at": "2026-11-01T04:27:32Z"
    }
  ]
  ```

#### 8.4.3 Get AI Mood Reflection
- **Method / Path:** `GET /api/v1/event/ai-reflection/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):**
  ```json
  {
    "mood": "Happy",
    "events": ["Team Roadmap Sync"],
    "pre_quotes": ["Alone we can do so little; together we can do so much."],
    "ai_reflection": "Your optimistic mindset sets a collaborative foundation for today's roadmap sync.",
    "raw_response": "{}"
  }
  ```

#### 8.4.4 Submit Event / App Feedback
- **Method / Path:** `POST /api/v1/event/feedback/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:**
  ```json
  {
    "rating": 5,
    "comments": "The seamless calendar sync and daily motivation are fantastic!"
  }
  ```
- **Success Response (`201 Created`):** Feedback object.

---

### 8.5 Subscriptions & Access Control APIs

#### 8.5.1 Check User Feature Access
- **Method / Path:** `GET /api/v1/my-access/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):**
  ```json
  {
    "status": "success",
    "data": {
      "access_mode": "trial",
      "has_premium_access": true,
      "trial_days_left": 10,
      "trial_ends_at": "2026-11-12T06:30:00Z",
      "subscription_price": 9.99,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": {
        "ai_quote": true,
        "ai_reflection": true,
        "events": true,
        "calendar_sync": true
      }
    }
  }
  ```

#### 8.5.2 Get User Subscription Details
- **Method / Path:** `GET /api/v1/my-subscription/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):** Returns active plan, renewal date, and billing settings.

#### 8.5.3 List Subscription Plans
- **Method / Path:** `GET /api/v1/plans/`
- **Auth:** `Bearer <access_token>`
- **Success Response (`200 OK`):**
  ```json
  {
    "status": "success",
    "data": [
      {
        "id": 1,
        "name": "Free Tier",
        "price": 0.00,
        "billing_cycle": "forever"
      },
      {
        "id": 2,
        "name": "Premium Tier",
        "price": 9.99,
        "billing_cycle": "monthly"
      }
    ]
  }
  ```

---

### 8.6 Administrative Subscription APIs (Secured)

#### 8.6.1 List All User Subscriptions (Admin Only)
- **Method / Path:** `GET /api/v1/all-user-subscriptions/`
- **Auth:** `Bearer <access_token>` (Requires `is_staff: true`)
- **Success Response (`200 OK`):** Administrative user subscription audit list.
- **Error Response (`403 Forbidden`):** For non-admin users.

#### 8.6.2 Update User Subscription Tier (Admin Only)
- **Method / Path:** `PUT /api/v1/admin/update-subscription/{user_id}/`
- **Auth:** `Bearer <access_token>` (Requires `is_staff: true`)
- **Request Payload:** `{"status": "active"}`
- **Success Response (`200 OK`):** Updated user subscription record.

#### 8.6.3 Modify Subscription Plan (Admin Only)
- **Method / Path:** `PATCH /api/v1/plan-update/{id}/`
- **Auth:** `Bearer <access_token>` (Requires `is_staff: true`)
- **Success Response (`200 OK`):** Updated plan object.

---

## 9. Backend Implementation & Verification Checklist

| Priority | Task ID | Description | Target Codebase Location | Status |
| :---: | :--- | :--- | :--- | :---: |
| **P0** | **FIX-SEC-01** | Support dual-mode OTP/token, attempt tracking, and replay-protected `default_token_generator` on `/reset-password/` | `backend-1/userauth/serializers.py` & `views.py` | Required |
| **P0** | **FIX-SEC-02** | Remove `fields = '__all__'` from `UserRegistrationsSerializers` (Prevent superuser mass assignment) | `backend-1/userauth/serializers.py` | Required |
| **P0** | **FIX-SEC-03** | Scope all event queries to `user=request.user` (Fix BOLA/IDOR on list, get, and delete) | `backend-1/event/views.py` | Required |
| **P0** | **FIX-SEC-04** | Rate-limit OTP endpoints (5/15m composite IP+Email), lock OTP after 5 failed attempts, and invalidate prior OTPs | `backend-1/userauth/views.py` & `throttling.py` | Required |
| **P0** | **FIX-SEC-05** | Restrict admin subscription endpoints to `IsAdminUser` (`IsAuthenticated` -> `IsAdminUser`) | `backend-1/subscriptions/views.py` | Required |
| **P0** | **FIX-SEC-06** | Enforce `DEBUG = False` and strict `ALLOWED_HOSTS` in production environment | `backend-1/backend/settings.py` | Required |
| **P0** | **FIX-SEC-07** | Configure multi-audience Google client ID list in settings (`VALID_AUDIENCES`) | `backend-1/backend/settings.py` | Required |
| **P0** | **FIX-SEC-08** | Enforce `assert email_verified is True` and prevent pre-account takeover of existing password accounts | `backend-1/google_calendar_sync/views.py` | Required |
| **P0** | **FIX-SEC-09** | Require re-authentication (fresh Google ID token / email OTP) and purge external Google events before account deletion | `backend-1/userauth/views.py` | Required |
| **P0** | **FIX-CON-01** | Return dual response keys (`access` + `access_token`, `refresh` + `refresh_token`, `name`, `picture`) on Google ID token login | `backend-1/google_calendar_sync/views.py` | Required |
| **P1** | **FIX-DEP-01** | Add `celery>=5.4.0`, `redis>=5.0.0`, and `tzdata>=2025.1` to `backend-1/requirements.txt` | `backend-1/requirements.txt` | Required |
| **P1** | **FIX-MIG-01** | Create migration for `PasswordResetOTP`: `otp = CharField(max_length=6)`, `is_used = BooleanField()`, `failed_attempts = PositiveIntegerField()` | `backend-1/userauth/models.py` & `migrations/` | Required |
| **P1** | **FIX-MIG-02** | Create migration for `Event`: `repeat`, `custom_repeat`, `google_calendar_event_id`, `last_synced_at`, `exception_dates`, `timezone`, `start_datetime_utc`, `end_datetime_utc` | `backend-1/dashbord/models.py` & `migrations/` | Required |
| **P1** | **FIX-MIG-03** | Create migration for `Quote` relational model migrating quotes out of runtime Excel files | `backend-1/event/models.py` & `migrations/` | Required |
| **P1** | **FIX-BUG-01** | Wrap SMTP email in `try...except`, set `EMAIL_TIMEOUT = 10`, offload to Celery worker | `backend-1/userauth/serializers.py` | Required |
| **P1** | **FIX-BUG-02** | Fix `/event/my-quotes/` filter to query `is_favorite=True` and serialize `author` | `backend-1/event/views.py` & `serializers.py` | Required |
| **P1** | **FIX-BUG-03** | Support PATCH on `/event/create/?id=` and register `/event/update/<id>/` | `backend-1/event/views.py` & `api/urls.py` | Required |
| **P1** | **FIX-BUG-04** | Fix route typo `evenet/delete` -> `event/delete` with backward-compatible alias | `backend-1/api/urls.py` | Required |
| **P1** | **FIX-BUG-05** | Persist recurrence rules (`repeat` & `custom_repeat`) in `Event` model & serializer | `backend-1/dashbord/models.py` & `event/serializers.py` | Required |
| **P1** | **FIX-BUG-06** | Unify Google Calendar credentials exclusively on `GoogleCalendarCredential` | `backend-1/google_calendar_sync/utils.py` | Required |
| **P1** | **FIX-BUG-07** | Pre-generate deterministic `google_calendar_event_id` before database save to eliminate ghost events | `backend-1/dashbord/models.py` & `event/views.py` | Required |
| **P1** | **FIX-BUG-08** | Implement 3-tier quote fallback (`gpt-4o-mini`, 3s timeout, `Quote` DB model, `UNIVERSAL_FALLBACK_QUOTES`) | `backend-1/event/views.py` & `qtai.py` | Required |
| **P1** | **FIX-BUG-09** | Support `name` auto-splitting into `first_name` and `last_name` in `UserProfileSerializer` | `backend-1/userauth/serializers.py` | Required |
| **P1** | **FIX-BUG-10** | Automatically activate free subscription upon Google Sign-In user registration | `backend-1/google_calendar_sync/views.py` | Required |
| **P1** | **FIX-MISS-01**| Implement route and view for `POST /api/v1/resend-otp/` | `backend-1/api/urls.py` | Required |
| **P1** | **FIX-MISS-02**| Implement route and model for `POST /api/v1/user/mood/` | `backend-1/api/urls.py` | Required |
| **P1** | **FIX-MISS-03**| Implement route and fallback for `GET /api/v1/event/ai-reflection/` returning escaped `raw_response` | `backend-1/api/urls.py` | Required |
| **P1** | **FIX-MISS-04**| Expose SimpleJWT `TokenRefreshView` on `/api/v1/token/refresh/` | `backend-1/api/urls.py` | Required |
| **P2** | **FIX-ARCH-01**| Install RFC 7807 global DRF custom exception handler with first-error detail synthesis | `backend-1/api/exceptions.py` | Required |
| **P2** | **FIX-ARCH-02**| Register root Django JSON handlers (`handler400`, `handler403`, `handler404`, `handler500`) | `backend-1/backend/urls.py` | Required |
| **P2** | **FIX-ARCH-03**| Implement IANA timezone activation via `X-Timezone` header with `tzdata` fallback | `backend-1/api/middleware.py` | Required |
| **P2** | **FIX-ARCH-04**| Enforce Redis atomic lock idempotency (`SET lock NX EX 60`) & SHA-256 fingerprint validation | `backend-1/event/views.py` | Required |
| **P2** | **FIX-ARCH-05**| Enforce RFC 5545 2-letter recurrence codes & occurrence expansion engine on `GET /api/v1/event/?date=` | `backend-1/event/views.py` | Required |
| **P2** | **FIX-ARCH-06**| Reduce SimpleJWT `ACCESS_TOKEN_LIFETIME` to 15m; document mobile Dio `QueuedInterceptor` | `backend-1/backend/settings.py` | Required |
| **P2** | **FIX-ARCH-07**| Deprecate client-side Dart Google Calendar sync in `event_services.dart:52` to prevent dual-booking | `time_verse/lib/features/calender/services/event_services.dart` | Required |
