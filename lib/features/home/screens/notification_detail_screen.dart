import 'package:flutter/material.dart';
import 'notifications_screen.dart';

class NotificationDetailScreen extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailScreen({
    required this.notification,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Notification',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (notification.body != null)
              Text(
                notification.body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  notification.time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Open related content',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
