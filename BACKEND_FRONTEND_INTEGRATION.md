# Frontend + Backend Integration (Monorepo)

This project now runs as a monorepo:
- Flutter app at repo root (`ios/`, `android/`, `lib/`)
- Laravel backend in `backend/`

## 1) Start backend
```bash
cd backend
php artisan serve --host=0.0.0.0 --port=8000
```

## 2) Start Flutter
From repo root:
```bash
flutter run
```

## 3) API base URL behavior
Configured in `lib/core/config/api_config.dart`:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator / desktop / web local: `http://127.0.0.1:8000`

## 4) Auth token storage
Token is persisted via `SharedPreferences` using:
- `lib/core/services/auth_session.dart`

## 5) Connected auth screens
- `lib/features/auth/screens/register_screen.dart`
- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/role_details_screen.dart`

They now call backend endpoints directly and pass/store auth token.

## 6) CORS for web app
Backend CORS config added at:
- `backend/config/cors.php`
- API middleware includes `HandleCors` in `backend/bootstrap/app.php`

## 7) If using a physical phone
Set backend URL in `ApiConfig.baseUrl` to your machine LAN IP, e.g.:
```dart
return 'http://192.168.1.20:8000';
```
Device and laptop must be on same Wi-Fi.

## 8) Scheduled posts (cron)
The backend includes a scheduler job that publishes scheduled posts and sends notifications.

Add this cron entry on your server:
```bash
* * * * * cd /path/to/alumni_global_app/backend && php artisan schedule:run >> /dev/null 2>&1
```
