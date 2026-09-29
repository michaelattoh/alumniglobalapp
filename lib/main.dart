import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/app/app.dart';
import 'core/services/app_navigator.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/push_token_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlumniGlobalApp());
  Future<void>(() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 6));
      }
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await LocalNotificationService.initialize();
      await PushTokenService.initialize(
        onNotificationTap: AppNavigator.handlePushData,
      );
    } catch (_) {
      // Native startup services must never block the first UI frame.
    }
  });
}
