import 'package:alumni_global_app/core/services/auth_session.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/services/local_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

class PushTokenService {
  PushTokenService._();

  static const _tokenKey = 'push_token';
  static const _deviceIdKey = 'push_device_id';
  static const _generalTopic = 'general';
  static const _roleTopics = <String>['alumni', 'school_admin', 'super_admin'];
  static bool _initialized = false;

  static Future<void> initialize({
    void Function(RemoteMessage message)? onForegroundMessage,
    Future<void> Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _persistToken(token);
      final userId = await AuthSession.getUserId();
      if (userId == null) return;
      final deviceId = await _getOrCreateDeviceId();
      final platform = _platformName();
      final ok = await HomeApiService.registerPushToken(
        token: token,
        platform: platform,
        deviceId: deviceId,
      );
      if (ok) {
        await syncTopics();
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      LocalNotificationService.showFromRemoteMessage(message);
      onForegroundMessage?.call(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await onNotificationTap?.call(message.data);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await onNotificationTap?.call(initialMessage.data);
    }
  }

  static String _platformName() {
    return kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : 'unknown';
  }

  static Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'device-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static Future<String?> _getToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _persistToken(token);
      return token;
    }
    return null;
  }

  static Future<bool> register() async {
    final userId = await AuthSession.getUserId();
    if (userId == null) return false;

    final token = await _getToken();
    if (token == null) return false;
    final deviceId = await _getOrCreateDeviceId();
    final platform = _platformName();
    final ok = await HomeApiService.registerPushToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
    );
    if (ok) {
      await syncTopics();
    }
    return ok;
  }

  static Future<bool> unregister() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey) ?? await _getToken();
    await _unsubscribeFromAllTopics();
    if (token == null || token.isEmpty) return true;
    final ok = await HomeApiService.unregisterPushToken(token: token);
    if (ok) {
      await prefs.remove(_tokenKey);
      await FirebaseMessaging.instance.deleteToken();
    }
    return ok;
  }

  static Future<void> syncTopics() async {
    final role = await AuthSession.getRole();
    await _unsubscribeFromRoleTopics();
    await FirebaseMessaging.instance.subscribeToTopic(_generalTopic);
    final mappedRole = _mapRoleToTopic(role);
    if (mappedRole != null) {
      await FirebaseMessaging.instance.subscribeToTopic(mappedRole);
    }
  }

  static String? _mapRoleToTopic(String? role) {
    switch (role) {
      case 'alumni':
        return 'alumni';
      case 'institution_admin':
        return 'school_admin';
      case 'super_admin':
      case 'admin':
        return 'super_admin';
      default:
        return null;
    }
  }

  static Future<void> _unsubscribeFromRoleTopics() async {
    for (final topic in _roleTopics) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
  }

  static Future<void> _unsubscribeFromAllTopics() async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(_generalTopic);
    await _unsubscribeFromRoleTopics();
  }
}
