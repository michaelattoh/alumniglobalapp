import 'package:flutter/material.dart';

enum NotificationType { post, job, mention, system }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int selectedFilter = 0;

  final filters = ['All', 'Jobs', 'My posts', 'Mentions'];

  final List<AppNotification> allNotifications = [
    AppNotification(
      type: NotificationType.post,
      title: 'Emmanuel Mbansi posted',
      body: '2026, here we come! 19 days to go 🚀',
      time: '3h',
      unread: true,
    ),
    AppNotification(
      type: NotificationType.system,
      title: 'You appeared in 5 searches this week',
      time: '1h',
    ),
    AppNotification(
      type: NotificationType.post,
      title: 'Edward Adjei reposted a post',
      body: 'Grateful for the opportunity to bring to light...',
      time: '43m',
      highlighted: true,
    ),
    AppNotification(
      type: NotificationType.mention,
      title: 'You were mentioned in a comment',
      body: 'Way to go Kwame 🎉🎉',
      time: '2h',
    ),
    AppNotification(
      type: NotificationType.job,
      title: 'New job matches your profile',
      body: 'Software Engineer • Accra',
      time: '4h',
    ),
    AppNotification(
      type: NotificationType.job,
      title: 'Application viewed',
      body: 'Rixrod Company Limited viewed your application',
      time: '1d',
    ),
  ];

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  List<AppNotification> get filteredNotifications {
    switch (selectedFilter) {
      case 1:
        return allNotifications
            .where((n) => n.type == NotificationType.job)
            .toList();
      case 2:
        return allNotifications
            .where((n) => n.type == NotificationType.post)
            .toList();
      case 3:
        return allNotifications
            .where((n) => n.type == NotificationType.mention)
            .toList();
      default:
        return allNotifications;
    }
  }

  void _openRelatedContent(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.post:
        // TODO: navigate to post detail screen
        Navigator.of(context).pushNamed('/post');
        break;

      case NotificationType.job:
        // TODO: navigate to job detail screen
        Navigator.of(context).pushNamed('/job');
        break;

      case NotificationType.mention:
        // TODO: navigate to comment thread
        Navigator.of(context).pushNamed('/post');
        break;

      case NotificationType.system:
        // Optional: analytics / insights
        Navigator.of(context).pushNamed('/analytics');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Notifications',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Filters
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = selectedFilter == i;
                  return ChoiceChip(
                    label: Text(filters[i]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => selectedFilter = i);
                    },
                    selectedColor: const Color(0xFF065F46),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[300]!),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                  itemCount: filteredNotifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final n = filteredNotifications[index];
                    return InkWell(
                      onTap: () => _openRelatedContent(n),
                      child: Container(
                        color: n.highlighted
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (n.unread)
                              Container(
                                margin:
                                    const EdgeInsets.only(top: 18),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              const SizedBox(width: 8),
                            const SizedBox(width: 8),
                            _NotificationAvatar(type: n.type),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (n.body != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body!,
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: theme
                                          .textTheme.bodySmall
                                          ?.copyWith(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              n.time,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== MODEL =====================

class AppNotification {
  final NotificationType type;
  final String title;
  final String? body;
  final String time;
  final bool unread;
  final bool highlighted;

  AppNotification({
    required this.type,
    required this.title,
    required this.time,
    this.body,
    this.unread = false,
    this.highlighted = false,
  });
}

// ===================== AVATAR =====================

class _NotificationAvatar extends StatelessWidget {
  final NotificationType type;

  const _NotificationAvatar({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.job:
        icon = Icons.work_rounded;
        color = Colors.green;
        break;
      case NotificationType.mention:
        icon = Icons.alternate_email_rounded;
        color = Colors.purple;
        break;
      case NotificationType.system:
        icon = Icons.trending_up;
        color = Colors.blue;
        break;
      default:
        icon = Icons.person_rounded;
        color = Colors.grey;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white,
      child: Icon(icon, color: color),
    );
  }
}
