import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'agn_high_importance',
    'Alumni Global Notifications',
    description: 'Important alerts, messages, and community updates.',
    importance: Importance.max,
  );
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _initialized = true;
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (!_initialized || kIsWeb) return;
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Alumni Global Network';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';
    if (title.isEmpty && body.isEmpty) return;

    await _plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
