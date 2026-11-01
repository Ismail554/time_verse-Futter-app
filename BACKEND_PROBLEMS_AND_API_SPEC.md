# Backend Problems & Complete Mobile App API Specification

**Base URL:** `https://api.infiniquote.com/api/v1`  
**Swagger URL:** `https://api.infiniquote.com/swagger`  
**Test Account:** `ismailshuvo555@gmail.com` (User ID: `75`)  
**Detected Backend Stack:** Django 5.1.7, Django REST Framework, SimpleJWT, `drf-yasg`, Gunicorn 23.0.0, Nginx 1.24.0, PostgreSQL (`db:5432`), Redis + Celery Beat

---

## Part 1: All Backend Problems & Required Fixes

### 🔴 P0 — Critical Blockers & Security Vulnerabilities

#### 1. `POST /api/v1/forget_password/` Crashes with `500 Internal Server Error` (`SMTPServerDisconnected`)
- **Current Behaviour:** Calling `POST /api/v1/forget_password/` with a valid registered email crashes with `500 Internal Server Error` and dumps a 20 KB plain-text Django traceback.
- **Traceback Root Cause:**
  - `/app/userauth/views.py`, line 128 (`forget_password` -> `serializer.save()`)
  - `/app/userauth/serializers.py`, line 144 (`create` -> `send_mail(...)`)
  - `/usr/local/lib/python3.12/smtplib.py`, line 739 (`self.connection.login(self.username, self.password)`)
  - Exception: `SMTPServerDisconnected: Connection unexpectedly closed`
- **Settings Causing Crash (`backend/settings.py`):**
  ```python
  EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
  EMAIL_HOST = 'smtp.gmail.com'
  EMAIL_PORT = 587
  EMAIL_USE_TLS = True
  EMAIL_HOST_USER = 'accessi@wise.pro'
  DEFAULT_FROM_EMAIL = 'TimeVarse <accessi@wise.pro>'
  ```
- **Required Fix:**
  1. Replace the invalid/revoked Gmail App Password for `accessi@wise.pro` (or configure an email relay such as SendGrid, Mailgun, or AWS SES).
  2. Set `EMAIL_TIMEOUT = 10` in `backend/settings.py`.
  3. Wrap `send_mail()` in `try...except` inside `/app/userauth/serializers.py` (or send asynchronously via Celery) so SMTP failures return a clean JSON error (`503 Service Unavailable`) instead of an unhandled 500 crash.

---

#### 2. `POST /api/v1/reset-password/` Changes Any User's Password Without OTP Verification (`200 OK`)
- **Current Behaviour:** The `ResetPassword` serializer (`#/definitions/ResetPassword` in Swagger) only requires `email` and `new_password`. It does **not** require or validate `otp`, nor does it check whether the user actually verified an OTP via `/api/v1/verify-otp/`.
- **Live Reproduction:**
  Sending `POST /api/v1/reset-password/` with `{"email": "ismailshuvo555@gmail.com", "new_password": "TestPassword123!"}` (with no Authorization header and no valid OTP) returns `200 OK: {"message": "Password Change Successfull"}`.
- **Security Impact:** Any unauthenticated attacker who knows a user's email address can immediately take over their account.
- **Required Fix:**
  Update `ResetPasswordSerializer` in `/app/userauth/serializers.py` to require `otp` (or a signed reset token issued by `/api/v1/verify-otp/`), verify that the OTP matches the user's unexpired OTP in the database, and delete/invalidate the OTP immediately after resetting the password.

---

#### 3. Missing `/api/v1/resend-otp/` Endpoint (`404 Not Found`)
- **Current Behaviour:** The mobile app calls `POST /api/v1/resend-otp/` with `{"email": "user@example.com"}` to resend the 4-digit verification code on the OTP screen. This route does not exist in `backend/urls.py` and returns a Django `404 Page not found` HTML error.
- **Required Fix:**
  Add `path('resend-otp/', ...)` (or alias it to the `forget_password` view logic) in `userauth/urls.py` so `POST /api/v1/resend-otp/` generates a fresh 4-digit OTP, emails it to the user, and returns `200 OK`.

---

#### 4. `GET /api/v1/event/ai-reflection/` Fails with `502 Bad Gateway` & Slows Down `POST /api/v1/event/create/`
- **Current Behaviour:**
  - `GET /api/v1/event/ai-reflection/` fails with `502 Bad Gateway`:
    ```json
    {
      "error": "Error code: 429 - {'error': {'message': 'You have no credits remaining. Add credits to continue using the API at https://platform.openai.com/settings/organization/billing/.', 'type': 'insufficient_quota', 'param': None, 'code': 'credit_balance_exhausted'}}"
    }
    ```
  - `POST /api/v1/event/create/` takes **4.1 to 4.5 seconds** per request because it synchronously calls OpenAI to generate an inspirational quote for the event's `description` field, hits the `429 insufficient_quota` error, and saves `"description": null`.
  - Because `"description"` is saved as `null`, `GET /api/v1/next-quite/` also returns `"description": null`.
- **Required Fix:**
  1. Top up the OpenAI organization billing balance at `https://platform.openai.com/settings/organization/billing/`.
  2. When OpenAI returns `429` or times out during `POST /api/v1/event/create/` or `GET /api/v1/event/ai-reflection/`, fallback gracefully to a pre-seeded quote from `QuotePacket` / category quotes in the database instead of returning `502` or leaving `description` as `null`.

---

#### 5. Broken Access Control on 3 Admin Subscription Endpoints (`200 OK` for Normal Users)
- **Current Behaviour:** A standard non-staff user (`is_staff: false`, `is_superuser: false`) can access and mutate the following admin endpoints:
  1. `GET /api/v1/all-user-subscriptions/` -> Returns `200 OK` with **every user's email address (`user_email`), user ID, and subscription history**.
  2. `PUT /api/v1/admin/update-subscription/{user_id}/` -> Returns `200 OK` and allows any normal user to set their own subscription `status` to `"active"`.
  3. `PATCH /api/v1/plan-update/{id}/` -> Returns `200 OK` and allows any normal user to modify global `SubscriptionPlan` records.
- **Required Fix:**
  Add `permission_classes = [IsAdminUser]` (or custom superadmin permission class matching `/api/v1/all-users/`) to those three views in `subscriptions/views.py`.

---

#### 6. `DEBUG = True` Enabled in Production (`backend/settings.py`)
- **Current Behaviour:** `DEBUG = True` and `ALLOWED_HOSTS = ['*']` are active on `https://api.infiniquote.com`. Any `404` or `500` error returns full Django debug pages exposing database credentials metadata (`NAME: 'radu', USER: 'radu', HOST: 'db'`), internal file paths, installed apps, and Google OAuth client IDs.
- **Required Fix:** Set `DEBUG = False` and configure `ALLOWED_HOSTS = ['api.infiniquote.com']` in production.

---

### 🟠 P1 — Functional Bugs & API Contract Mismatches

#### 7. `GET /api/v1/event/my-quotes/` Always Returns Empty List `[]`
- **Current Behaviour:**
  1. User creates an event (`POST /api/v1/event/create/`), e.g., ID `1816655`, even with non-null `"description": "Explicit quote description text"`.
  2. User marks the event as favorite (`POST /api/v1/event/1816655/favorite/`), which returns `200 OK` with `"is_favorite": true`.
  3. User calls `GET /api/v1/event/my-quotes/`, which returns `200 OK` with `[]` (empty array).
- **Required Fix:**
  Check the queryset filter in the `my-quotes` view (`event/views.py`). It should return all events/quotes belonging to `request.user` where `is_favorite=True` (ordered by `-created_at`), including `id`, `description` (falling back to `type_event_description` or a default quote if null), `author` / `category_name`, and `created_at`.

---

#### 8. `POST /api/v1/register/` Ignores `profile_picture` (`readOnly: true`) and Does Not Return JWT Tokens
- **Current Behaviour:**
  - In `UserRegistrationsSerializers`, `profile_picture` is marked `read_only=True`. Uploading a `profile_picture` file via `multipart/form-data` during registration is silently ignored and `profile_picture` is always returned as `null`.
  - Registration only returns `{"message": "User Registrations Successfully", "user": {...}}` without `access` and `refresh` tokens.
- **Required Fix:**
  Make `profile_picture` writable (`required=False, allow_null=True`) in `UserRegistrationsSerializers`, and optionally include `access` and `refresh` JWT tokens in the `201 Created` response.

---

#### 9. `PUT /api/v1/profile/` Name Field Mismatch (`name` vs `first_name` / `last_name`)
- **Current Behaviour:**
  - The backend `UserProfile` serializer expects `first_name` and `last_name`.
  - The mobile app displays a single "Full Name" input field and sends `"name": "Ismail Shuvo"` (or `first_name` / `last_name`). When `"name"` is sent in JSON/form-data, the backend ignores it and keeps the old `first_name`/`last_name`.
- **Required Fix:**
  In `UserProfileSerializer` (`userauth/serializers.py`), accept an optional write-only `name` field (in addition to `first_name` and `last_name`): if `name` is provided and `first_name` is not provided, split `name` on the first space into `first_name` and `last_name`. Also return a computed `name` field (`f"{obj.first_name} {obj.last_name}".strip()`) alongside `first_name` and `last_name`.

---

#### 10. `GET /api/v1/auth/login/` Uses `localhost` Redirect URI in Production
- **Current Behaviour:** `GOOGLE_REDIRECT_URI` in `backend/settings.py` is set to `'http://localhost:8000/api/v1/auth/google/callback/'`. Calling `GET /api/v1/auth/login/` redirects to Google's OAuth error page (`redirect_uri_mismatch`).
- **Required Fix:** Update `GOOGLE_REDIRECT_URI` to `'https://api.infiniquote.com/api/v1/auth/google/callback/'`.

---

#### 11. Duplicate & Misspelled Endpoints in `urls.py`
The following duplicate or misspelled routes exist in Swagger:
- `/api/v1/evenet/delete/{id}/` (misspelled duplicate of `/api/v1/event/delete/{id}/`)
- `/api/v1/next-quite/` (misspelled `quite` instead of `quote`)
- `/api/v1/up-comming/events/` (misspelled `up-comming` instead of `upcoming` — **keep existing route as alias so mobile app doesn't break**)
- `/api/v1/quote-packet/{id}/`, `/api/v1/quote-packet/details/{id}/`, `/api/v1/quote-packet-details/{id}/` (3 identical routes)
- `PATCH /api/v1/event/create/`, `PATCH /api/v1/event/create/{id}/`, `PATCH /api/v1/event/update/{id}/` (keep all 3 working for backward compatibility as mobile app currently uses `PATCH /api/v1/event/create/?id={id}`).

---

## Part 2: Complete Mobile App API Specification (Payloads & Expected Behaviour)

All endpoints below are prefixed with `/api/v1`.  
For authenticated endpoints, the mobile app sends:
```http
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
```

---

### 1. Authentication & Account APIs

#### 1.1 Register New Account
- **Endpoint:** `POST /api/v1/register/`
- **Auth:** Public (`AllowAny`)
- **Content-Type:** `multipart/form-data`
- **Request Payload (Form Fields):**
  | Field | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `email` | `string (email)` | Yes | User's email address (unique) |
  | `password` | `string` | Yes | Minimum 4 characters |
  | `first_name` | `string` | Yes | User's first name |
  | `last_name` | `string` | Yes | User's last name |
  | `gender` | `string` | No | e.g., `"Male"`, `"Female"`, `"Other"` |
  | `nationality` | `string` | No | e.g., `"American"`, `"British"`, `"Canadian"`, `"Other"` |
  | `profile_picture` | `file (image)` | No | Optional avatar image file (`jpg`/`png`) |
- **Expected Success Response (`201 Created`):**
  ```json
  {
    "success": true,
    "message": "User Registrations Successfully",
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "gender": "Male",
      "nationality": "American",
      "profile_picture": "https://api.infiniquote.com/media/profile_pictures/avatar.png"
    }
  }
  ```
- **Expected Error Response (`400 Bad Request`):**
  ```json
  {
    "email": ["User with this email already exists."]
  }
  ```

---

#### 1.2 User Login
- **Endpoint:** `POST /api/v1/login/`
- **Auth:** Public (`AllowAny`)
- **Request Payload (`application/json`):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "password": "TestPassword123!"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "access": "<jwt_access_token>",
    "refresh": "<jwt_refresh_token>",
    "user": {
      "id": 75,
      "email": "ismailshuvo555@gmail.com",
      "first_name": "Ismail",
      "last_name": "Shuvo",
      "profile_picture": "https://api.infiniquote.com/media/profile_pictures/avatar.png",
      "birth_date": "1998-05-15"
    }
  }
  ```
  *(Note: Also supports nested `{"data": {"access": "...", "refresh": "...", "user": {...}}}`).*
- **Expected Error Response (`400 Bad Request` or `401 Unauthorized`):**
  ```json
  {
    "detail": "Invalid credentials."
  }
  ```

---

#### 1.3 Google Sign-In (ID Token & Server Auth Code Exchange)
- **Endpoint:** `POST /api/v1/auth/login/idtoken/`
- **Auth:** Public (`AllowAny`)
- **Request Payload (`application/json`):**
  ```json
  {
    "id_token": "<google_id_token>",
    "auth_code": "<google_server_auth_code>"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "access_token": "<jwt_access_token>",
    "refresh_token": "<jwt_refresh_token>",
    "name": "Ismail Shuvo",
    "email": "ismailshuvo555@gmail.com",
    "picture": "https://lh3.googleusercontent.com/..."
  }
  ```
- **Expected Behaviour:** Verifies Google `id_token`, exchanges `auth_code` for Google Calendar refresh token if provided, creates/updates the user account, and returns the backend JWT `access_token`.

---

#### 1.4 Forgot Password (Send OTP)
- **Endpoint:** `POST /api/v1/forget_password/`
- **Auth:** Public (`AllowAny`)
- **Request Payload (`application/json`):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "OTP sent to your email successfully."
  }
  ```
- **Expected Error Response (`400 Bad Request`):**
  ```json
  {
    "email": ["No user found with this email."]
  }
  ```
- **Expected Behaviour:** Generates a 4-digit numeric OTP, stores it with an expiration timestamp (e.g., 3–5 minutes), and sends it to the user's email address via SMTP without crashing.

---

#### 1.5 Resend OTP
- **Endpoint:** `POST /api/v1/resend-otp/`
- **Auth:** Public (`AllowAny`)
- **Request Payload (`application/json`):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "OTP resent successfully."
  }
  ```

---

#### 1.6 Verify OTP
- **Endpoint:** `POST /api/v1/verify-otp/`
- **Auth:** Public (`AllowAny`)
- **Request Payload (`application/json`):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "otp": "1234"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "OTP verified successfully."
  }
  ```
- **Expected Error Response (`400 Bad Request`):**
  ```json
  {
    "non_field_errors": ["OTP Is Wrong"]
  }
  ```
- **Expected Behaviour:** Validates that the 4-digit `otp` matches the latest active OTP for `email` and has not expired. Marks the OTP as verified for the subsequent password reset call.

---

#### 1.7 Reset Password (Set New Password After OTP)
- **Endpoint:** `POST /api/v1/reset-password/`
- **Auth:** Public (`AllowAny` — **MUST validate `otp`**)
- **Request Payload (`application/json`):**
  ```json
  {
    "email": "ismailshuvo555@gmail.com",
    "otp": "1234",
    "new_password": "NewSecurePassword123!"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "message": "Password reset successful."
  }
  ```
- **Expected Error Response (`400 Bad Request`):**
  ```json
  {
    "otp": ["Invalid or expired OTP."]
  }
  ```
- **Expected Behaviour:** Verifies that `otp` is valid for `email` (and was verified within the allowed window), updates the user's password to `new_password`, and invalidates the OTP so it cannot be reused.

---

#### 1.8 Change Password (Authenticated)
- **Endpoint:** `POST /api/v1/change-password/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "old_password": "TestPassword123!",
    "new_password": "NewPassword456!"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "message": "Password changed successfully."
  }
  ```
- **Expected Error Response (`400 Bad Request`):**
  ```json
  {
    "old_password": ["Old password is not correct."]
  }
  ```

---

#### 1.9 Logout
- **Endpoint:** `POST /api/v1/logout/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "refresh": "<jwt_refresh_token>"
  }
  ```
- **Expected Success Response (`200 OK` or `205 Reset Content`):**
  ```json
  {
    "message": "Logged out successfully."
  }
  ```

---

#### 1.10 Delete Account
- **Endpoint:** `DELETE /api/v1/delete-account/` *(Recommend accepting both `DELETE` and `POST` on backend since current mobile build calls `POST`)*
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "password": "TestPassword123!"
  }
  ```
- **Expected Success Response (`200 OK` or `204 No Content`):**
  ```json
  {
    "message": "Account deleted successfully."
  }
  ```
- **Expected Error Response (`400 Bad Request`):**
  ```json
  {
    "password": ["Password is incorrect."]
  }
  ```

---

### 2. User Profile, Mood, FCM & Legal Content APIs

#### 2.1 Get User Profile
- **Endpoint:** `GET /api/v1/profile/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "id": 75,
    "first_name": "Ismail",
    "last_name": "Shuvo",
    "name": "Ismail Shuvo",
    "email": "ismailshuvo555@gmail.com",
    "birth_date": "1998-05-15",
    "profile_picture": "https://api.infiniquote.com/media/profile_pictures/favicon.png"
  }
  ```

---

#### 2.2 Update User Profile
- **Endpoint:** `PUT /api/v1/profile/`
- **Auth:** `Bearer <access_token>`
- **Content-Type:** Supports both `multipart/form-data` (when uploading `profile_picture`) and `application/json` (when updating text fields only)
- **Request Payload:**
  | Field | Type | Required | Description |
  | :--- | :--- | :---: | :--- |
  | `first_name` | `string` | No | First name |
  | `last_name` | `string` | No | Last name |
  | `name` | `string` | No | Full name (if sent by app without `first_name`/`last_name`, backend should split into `first_name` and `last_name`) |
  | `birth_date` | `string (YYYY-MM-DD)` | No | User's date of birth (nullable) |
  | `profile_picture` | `file (image)` | No | New profile image file (when `multipart/form-data`) |
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "id": 75,
    "first_name": "Ismail",
    "last_name": "Shuvo",
    "name": "Ismail Shuvo",
    "email": "ismailshuvo555@gmail.com",
    "birth_date": "1998-05-15",
    "profile_picture": "https://api.infiniquote.com/media/profile_pictures/favicon.png"
  }
  ```

---

#### 2.3 Submit Daily User Mood
- **Endpoint:** `POST /api/v1/user/mood/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "mood": "Happy"
  }
  ```
  *(Supported labels from app: `"Sad"`, `"Anxious"`, `"Neutral"`, `"Calm"`, `"Happy"`, `"Excited"`, `"Stressed"`, `"Grateful"`)*
- **Expected Success Response (`200 OK` or `201 Created`):**
  ```json
  {
    "message": "Mood updated successfully",
    "mood": "Happy"
  }
  ```

---

#### 2.4 Update FCM Push Notification Token
- **Endpoint:** `POST /api/v1/update-fcm-token/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "fcm_token": "<firebase_cloud_messaging_device_token>"
  }
  ```
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "message": "FCM token updated successfully."
  }
  ```

---

#### 2.5 Get Privacy Policy & Terms and Conditions
- **Endpoints:**
  - `GET /api/v1/privacy-policy/`
  - `GET /api/v1/terms-and-conditions/`
- **Auth:** `Bearer <access_token>` (or Public so users on the Signup screen can read Terms & Privacy Policy before registering!)
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "id": 1,
    "title": "Privacy Policy",
    "description": "<p>HTML or plain text content...</p>"
  }
  ```

---

### 3. Categories & Event Management APIs

#### 3.1 Get Event Categories
- **Endpoint:** `GET /api/v1/categories/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):**
  ```json
  [
    { "id": 1, "name": "Success Stories" },
    { "id": 2, "name": "Daily Motivation" },
    { "id": 12, "name": "Work" }
  ]
  ```

---

#### 3.2 Create Event
- **Endpoint:** `POST /api/v1/event/create/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "title": "Team Sync Meeting",
    "date": "2026-11-01",
    "start_time": "10:00",
    "end_time": "11:00",
    "alarm_time": "2026-11-01T09:45:00Z",
    "is_alarm_sent": true,
    "is_completed": false,
    "location": "Dhaka",
    "category_name": "Work",
    "type_event_description": "Discuss Q4 roadmap",
    "repeat": "custom",
    "custom_repeat": {
      "repeat_every": 1,
      "repeat_unit": "week",
      "repeat_days": ["M", "W", "F"],
      "ends": "after",
      "end_date": null,
      "end_count": 5
    }
  }
  ```
  - **Allowed `repeat` values:** `"dont_repeat"`, `"1 day"`, `"1 week"`, `"1 month"`, `"1 year"`, `"custom"`, or `null`.
- **Expected Success Response (`201 Created`):**
  ```json
  {
    "id": 1816476,
    "user": 75,
    "user_first_name": "Ismail",
    "user_last_name": "Shuvo",
    "category": 12,
    "category_name": "Work",
    "title": "Team Sync Meeting",
    "description": "Alone we can do so little; together we can do so much.",
    "type_event_description": "Discuss Q4 roadmap",
    "date": "2026-11-01",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "location": "Dhaka",
    "alarm_time": "2026-11-01T09:45:00Z",
    "repeat": "custom",
    "custom_repeat": {
      "repeat_every": 1,
      "repeat_unit": "week",
      "repeat_days": ["M", "W", "F"],
      "ends": "after",
      "end_date": null,
      "end_count": 5
    },
    "is_completed": false,
    "is_alarm_sent": true,
    "is_favorite": false,
    "created_at": "2026-11-01T04:27:32.284462Z",
    "ai_quote_available": true,
    "access_mode": "trial",
    "upgrade_required": false
  }
  ```
- **Expected Behaviour:** Saves the event and generates an inspirational quote in `"description"`. If OpenAI fails or is out of quota, it must immediately fallback to a quote from the category's `QuotePacket` rather than leaving `"description": null` or hanging for 4.5 seconds.

---

#### 3.3 List Events (All or Filtered by Date)
- **Endpoint:** `GET /api/v1/event/`
- **Query Parameters:** `?date=YYYY-MM-DD` (optional)
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):** Array of Event objects (`[...]`) belonging strictly to the authenticated user (`request.user`).

---

#### 3.4 List Upcoming / Ongoing Events
- **Endpoint:** `GET /api/v1/up-comming/events/`
- **Query Parameters:** `?date=YYYY-MM-DD` (optional)
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):** Array of future/repeating Event objects (`[...]`) for the authenticated user.

---

#### 3.5 Get Single Event Details
- **Endpoints:**
  - `GET /api/v1/event/details/?event_id={id}` *(used by mobile app)*
  - `GET /api/v1/event/details/{id}/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):** Single Event object (`{...}`).

---

#### 3.6 Update Event
- **Endpoints:**
  - `PATCH /api/v1/event/create/?id={id}` *(used by mobile app)*
  - `PATCH /api/v1/event/update/{id}/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):** Partial or full Event fields (`title`, `category`, `type_event_description`, `date`, `start_time`, `end_time`, `location`, `alarm_time`, `repeat`, `is_completed`, `is_favorite`).
- **Expected Success Response (`200 OK`):** Updated Event object (`{...}`).

---

#### 3.7 Delete Event
- **Endpoint:** `DELETE /api/v1/event/delete/{id}/?delete_type={single|all}`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK` or `204 No Content`):**
  ```json
  {
    "message": "Event deleted successfully"
  }
  ```

---

### 4. Quotes, Favorites, AI Reflection & Feedback APIs

#### 4.1 Toggle Favorite Quote / Event
- **Endpoint:** `POST /api/v1/event/{id}/favorite/`
- **Auth:** `Bearer <access_token>`
- **Request Payload:** `{}` (empty JSON body)
- **Expected Success Response (`200 OK`):** Updated Event object with `"is_favorite": true` (or `false` when untoggled).

---

#### 4.2 Get Saved Quotes ("My Quotes")
- **Endpoint:** `GET /api/v1/event/my-quotes/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):**
  ```json
  [
    {
      "id": 1816476,
      "created_at": "2026-11-01T04:27:32.284462Z",
      "description": "Alone we can do so little; together we can do so much.",
      "author": "Helen Keller"
    }
  ]
  ```
- **Expected Behaviour:** Must return all favorited quotes/events for the logged-in user (currently broken on backend—returns `[]`).

---

#### 4.3 Get AI Mood Reflection
- **Endpoint:** `GET /api/v1/event/ai-reflection/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "mood": "Happy",
    "events": ["Team Sync Meeting"],
    "pre_quotes": ["Alone we can do so little; together we can do so much."],
    "ai_reflection": "Today your schedule balances collaboration with focus...",
    "raw_response": "{}"
  }
  ```
- **Expected Behaviour:** Generates a daily AI reflection based on the user's mood and today's events. If OpenAI is unavailable, returns a graceful fallback reflection with HTTP `200 OK` instead of `502 Bad Gateway`.

---

#### 4.4 Submit Event / App Feedback
- **Endpoint:** `POST /api/v1/event/feedback/`
- **Auth:** `Bearer <access_token>`
- **Request Payload (`application/json`):**
  ```json
  {
    "rating": 5,
    "comments": "Great app!"
  }
  ```
- **Expected Success Response (`201 Created`):**
  ```json
  {
    "id": 13,
    "user": 75,
    "user_email": "ismailshuvo555@gmail.com",
    "user_first_name": "Ismail",
    "user_last_name": "Shuvo",
    "rating": 5,
    "comments": "Great app!",
    "created_at": "2026-11-01T04:28:04.841174Z"
  }
  ```

---

### 5. Subscriptions & Access Control APIs

#### 5.1 Check User Feature Access
- **Endpoint:** `GET /api/v1/my-access/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):**
  ```json
  {
    "status": "success",
    "data": {
      "access_mode": "trial",
      "has_premium_access": true,
      "trial_days_left": 10,
      "trial_ends_at": "2026-11-11T04:25:36.716915Z",
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

#### 5.2 Get User Subscription Details
- **Endpoint:** `GET /api/v1/my-subscription/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):** Returns `data` (user's `UserSubscription` + `plan`) and `settings` (`trial_days`, `price`, `currency`, `billing_cycle`, `is_trial_enabled`).

#### 5.3 List Subscription Plans
- **Endpoint:** `GET /api/v1/plans/`
- **Auth:** `Bearer <access_token>`
- **Expected Success Response (`200 OK`):** Returns array of `SubscriptionPlan` objects (`Free`, `Premium`).
