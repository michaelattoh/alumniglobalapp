import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/features/home/screens/chat_detail_screen.dart';
import 'package:flutter/material.dart';

class AppNavigator {
  AppNavigator._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Future<void> handlePushData(Map<String, dynamic> data) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = navigatorKey.currentState;
      final context = navigatorKey.currentContext;
      if (nav == null || context == null) return;

      final senderId = _asInt(data['sender_id']);
      final postId = _asInt(data['post_id']) ?? _asInt(data['postId']);
      final storyId = _asInt(data['story_id']) ?? _asInt(data['storyId']);
      final ticketId = _asInt(data['ticket_id']) ?? _asInt(data['ticketId']);
      final targetScreen = data['screen']?.toString();

      try {
        await HomeApiService.fetchNotificationsPage(page: 1, perPage: 30);
      } catch (_) {
        // Fresh notification sync should not block navigation.
      }

      if (targetScreen == 'mentorship') {
        nav.pushNamed('/home', arguments: {'tab': 2});
        return;
      }

      if (targetScreen == 'support' || ticketId != null) {
        nav.pushNamed('/support');
        return;
      }

      if (senderId != null) {
        final user = await HomeApiService.fetchUserProfile(senderId);
        final senderName =
            data['sender_name']?.toString().trim().isNotEmpty == true
            ? data['sender_name'].toString().trim()
            : (user?['name'] ?? 'Chat').toString();
        if (navigatorKey.currentContext == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: 'user_$senderId',
              chatName: senderName,
              isGroup: false,
            ),
          ),
        );
        return;
      }

      if (postId != null) {
        nav.pushNamed('/post-detail', arguments: postId);
        return;
      }

      nav.pushNamed(
        '/home',
        arguments: {'tab': 0, if (storyId != null) 'storyId': storyId},
      );
    });
  }
}
