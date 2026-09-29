import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/features/home/screens/chat_detail_screen.dart';
import 'package:alumni_global_app/features/home/screens/events_screen.dart';
import 'package:alumni_global_app/features/home/screens/network_screen.dart';
import 'package:alumni_global_app/features/home/screens/support_screen.dart';
import 'package:flutter/material.dart';

enum NotificationType {
  post,
  job,
  mention,
  system,
  connection,
  message,
  event,
  support,
}

class NotificationsScreen extends StatefulWidget {
  final ValueChanged<int>? onUnreadCountChanged;
  final ValueChanged<int>? onOpenStory;

  const NotificationsScreen({
    super.key,
    this.onUnreadCountChanged,
    this.onOpenStory,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int selectedFilter = 0;
  final filters = ['All', 'Jobs', 'Posts', 'Mentions'];

  List<AppNotification> allNotifications = [];
  bool _markingAll = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _controller = ScrollController();
  bool _opening = false;

  int get _unreadCount => allNotifications.where((n) => n.unread).length;

  @override
  void initState() {
    super.initState();
    final cached = HomeApiService.getCachedNotifications();
    if (cached.isNotEmpty) {
      allNotifications = cached.map(_mapNotification).toList();
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnreadCountChanged?.call(_unreadCount);
      });
    }
    _loadNotifications(showLoader: cached.isEmpty);
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  AppNotification _mapNotification(Map<String, dynamic> row) {
    final typeStr = (row['type'] ?? '').toString();
    final data = (row['data'] as Map<String, dynamic>?) ?? {};
    final parsedType = typeStr.contains('job')
        ? NotificationType.job
        : typeStr.contains('connection')
        ? NotificationType.connection
        : typeStr.contains('support')
        ? NotificationType.support
        : typeStr.contains('event')
        ? NotificationType.event
        : typeStr.contains('mention')
        ? NotificationType.mention
        : typeStr.contains('message')
        ? NotificationType.message
        : typeStr.contains('system')
        ? NotificationType.system
        : NotificationType.post;
    final actorName =
        data['from_user_name']?.toString() ??
        data['sender_name']?.toString() ??
        data['name']?.toString();
    final defaultTitle = (row['title'] ?? 'Notification').toString();
    final defaultBody = row['body']?.toString();

    return AppNotification(
      id: (row['id'] as num?)?.toInt(),
      type: parsedType,
      rawType: typeStr,
      title: _friendlyTitle(typeStr, actorName, defaultTitle, data),
      body: _friendlyBody(typeStr, actorName, defaultBody, data),
      time: _timeAgo(row['created_at']?.toString()),
      unread: !(row['is_read'] == true),
      data: data,
    );
  }

  String _friendlyTitle(
    String rawType,
    String? actorName,
    String fallbackTitle,
    Map<String, dynamic> data,
  ) {
    final actor = (actorName ?? '').trim();
    final name = actor.isNotEmpty ? actor : 'Someone';
    final isMentorship =
        data['source']?.toString() == 'mentorship' ||
        data['screen']?.toString() == 'mentorship';
    switch (rawType) {
      case 'connection_request':
        return isMentorship
            ? '$name sent you a mentorship request'
            : '$name sent you a connection request';
      case 'connection_response':
        return isMentorship
            ? 'Your mentorship request was updated'
            : 'Your connection request was updated';
      case 'connection_accepted':
        return isMentorship
            ? 'Mentorship connection established'
            : 'Connection established';
      case 'post_mention':
        return '$name mentioned you in a post';
      case 'comment_mention':
        return '$name mentioned you in a comment';
      case 'post_comment':
        return '$name commented on your post';
      case 'post_reaction':
        return '$name reacted to your post';
      case 'post_repost':
        return '$name reposted your post';
      case 'post_share':
        return '$name shared your post';
      case 'story_reaction':
        return '$name reacted to your story';
      case 'story_reply':
        return '$name replied to your story';
      case 'story_repost':
        return '$name reposted your story';
      case 'story_share':
        return '$name shared your story';
      case 'support_reply':
        return 'Support replied to your ticket';
      case 'support_ticket':
        return 'New support ticket';
      default:
        return fallbackTitle;
    }
  }

  String? _friendlyBody(
    String rawType,
    String? actorName,
    String? fallbackBody,
    Map<String, dynamic> data,
  ) {
    final actor = (actorName ?? '').trim();
    final isMentorship =
        data['source']?.toString() == 'mentorship' ||
        data['screen']?.toString() == 'mentorship';
    switch (rawType) {
      case 'connection_request':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : isMentorship
            ? 'Tap to review this mentorship request.'
            : 'Tap to review this connection request.';
      case 'connection_response':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : isMentorship
            ? 'Tap to check the latest mentorship status.'
            : 'Tap to check the latest connection status.';
      case 'connection_accepted':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : isMentorship
            ? 'Tap to open your mentorship hub.'
            : 'Tap to open your network.';
      case 'post_mention':
        return actor.isNotEmpty
            ? 'Tap to view the post where $actor mentioned you.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to view the post mention.');
      case 'comment_mention':
        return actor.isNotEmpty
            ? 'Tap to view the comment where $actor mentioned you.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to view the comment mention.');
      case 'post_comment':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : actor.isNotEmpty
            ? 'Tap to view $actor\'s comment.'
            : 'Tap to view the comment.';
      case 'post_reaction':
        return actor.isNotEmpty
            ? '$actor interacted with your post.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to view the post.');
      case 'post_repost':
        return actor.isNotEmpty
            ? '$actor helped your post reach more people.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to view the repost.');
      case 'post_share':
        return actor.isNotEmpty
            ? '$actor shared your post with others.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to view the shared post.');
      case 'story_reaction':
        return actor.isNotEmpty
            ? '$actor reacted to your story.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to open the story.');
      case 'story_reply':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : actor.isNotEmpty
            ? 'Tap to view $actor\'s reply.'
            : 'Tap to view the reply.';
      case 'story_repost':
        return actor.isNotEmpty
            ? '$actor reposted your story.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to open the story.');
      case 'story_share':
        return actor.isNotEmpty
            ? '$actor shared your story.'
            : (fallbackBody?.isNotEmpty == true
                  ? fallbackBody
                  : 'Tap to open the story.');
      case 'support_reply':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : 'Tap to review the reply in Support.';
      case 'support_ticket':
        return fallbackBody?.isNotEmpty == true
            ? fallbackBody
            : 'Tap to review the ticket in Support.';
      default:
        return fallbackBody;
    }
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadNotifications({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _page = 1;
        _hasMore = true;
      });
    } else {
      _page = 1;
      _hasMore = true;
    }

    final res = await HomeApiService.fetchNotificationsPage(
      page: 1,
      perPage: 30,
    );
    final rows = (res['data'] as List<Map<String, dynamic>>?) ?? [];
    final meta = res['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
    if (!mounted) return;

    setState(() {
      allNotifications = rows.map(_mapNotification).toList();
      _loading = false;
      _page = 1;
      _hasMore = _page < lastPage;
    });
    widget.onUnreadCountChanged?.call(_unreadCount);
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final res = await HomeApiService.fetchNotificationsPage(
      page: nextPage,
      perPage: 30,
    );
    final rows = (res['data'] as List<Map<String, dynamic>>?) ?? [];
    final meta = res['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    if (!mounted) return;

    setState(() {
      allNotifications.addAll(rows.map(_mapNotification));
      _loadingMore = false;
      _page = nextPage;
      _hasMore = _page < lastPage;
    });
    widget.onUnreadCountChanged?.call(_unreadCount);
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    await HomeApiService.markAllNotificationsRead();
    for (final n in allNotifications) {
      n.unread = false;
    }
    await _loadNotifications(showLoader: false);
    if (mounted) {
      setState(() => _markingAll = false);
    }
    widget.onUnreadCountChanged?.call(0);
  }

  String _timeAgo(String? iso) {
    if (iso == null) return 'now';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
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

  Future<void> _openRelatedContent(AppNotification notification) async {
    if (_opening) return;
    _opening = true;
    try {
      if (notification.id != null && notification.unread) {
        await HomeApiService.markNotificationRead(notification.id!);
        if (!mounted) return;
        setState(() => notification.unread = false);
        widget.onUnreadCountChanged?.call(_unreadCount);
      }

      final data = notification.data ?? {};
      int? asInt(dynamic value) {
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      final senderId = asInt(data['sender_id']);
      final senderName = data['sender_name']?.toString();
      final eventId = asInt(data['event_id']);
      final fromUserId = asInt(data['from_user_id']);
      final targetScreen = data['screen']?.toString();
      final storyId =
          asInt(data['story_id']) ??
          asInt(data['storyId']) ??
          asInt((data['story'] as Map<String, dynamic>?)?['id']);
      final postId =
          asInt(data['post_id']) ??
          asInt(data['postId']) ??
          asInt((data['post'] as Map<String, dynamic>?)?['id']);
      final ticketId = asInt(data['ticket_id']) ?? asInt(data['ticketId']);

      if (targetScreen == 'mentorship') {
        Navigator.of(context).pushNamed('/home', arguments: {'tab': 2});
        return;
      }

      if (targetScreen == 'support' ||
          ticketId != null ||
          notification.type == NotificationType.support) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportScreen()),
        );
        return;
      }

      if (senderId != null) {
        final user = await HomeApiService.fetchUserProfile(senderId);
        if (!mounted) return;
        final resolvedChatName = senderName?.trim().isNotEmpty == true
            ? senderName!.trim()
            : (user?['name'] ?? 'Chat').toString();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: 'user_$senderId',
              chatName: resolvedChatName,
              isGroup: false,
            ),
          ),
        );
        return;
      }

      if (eventId != null) {
        final event = await HomeApiService.fetchEvent(eventId);
        if (!mounted) return;
        if (event != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
          );
          return;
        }
      }

      if (postId != null) {
        final cached = HomeApiService.getCachedPost(postId);
        final post = await HomeApiService.fetchPost(postId) ?? cached;
        if (!mounted) return;
        if (post != null) {
          Navigator.of(context).pushNamed(
            '/post-detail',
            arguments: {'postId': postId, 'post': post},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This post is not available yet.')),
          );
        }
        return;
      }

      if (storyId != null) {
        if (!mounted) return;
        widget.onOpenStory?.call(storyId);
        return;
      }

      if (fromUserId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NetworkScreen()),
        );
        return;
      }

      switch (notification.type) {
        case NotificationType.post:
          Navigator.of(context).pushNamed('/home');
          break;
        case NotificationType.job:
          Navigator.of(context).pushNamed('/jobs');
          break;
        case NotificationType.mention:
          Navigator.of(context).pushNamed('/home');
          break;
        case NotificationType.system:
          Navigator.of(context).pushNamed('/analytics');
          break;
        case NotificationType.connection:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NetworkScreen()),
          );
          break;
        case NotificationType.message:
          Navigator.of(context).pushNamed('/messages');
          break;
        case NotificationType.event:
          Navigator.of(context).pushNamed('/events');
          break;
        case NotificationType.support:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          );
          break;
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final filtered = filteredNotifications;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 34, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_unreadCount unread',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _markingAll ? null : _markAllRead,
                  child: Text(_markingAll ? 'Marking…' : 'Mark all read'),
                ),
              ),
            ),
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
                    onSelected: (_) => setState(() => selectedFilter = i),
                    selectedColor: const Color(0xFF065F46),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : scheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: theme.cardColor,
                    side: BorderSide(color: scheme.outlineVariant),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadNotifications,
                child: ListView.builder(
                  controller: _controller,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                  itemCount:
                      filtered.length +
                      (_loadingMore ? 1 : 0) +
                      (_loading && filtered.isEmpty ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (_loading && filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (index >= filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final n = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Material(
                        color: n.highlighted
                            ? const Color(0xFFEFF6FF)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openRelatedContent(n),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: n.unread
                                    ? const Color(0xFFBFDBFE)
                                    : scheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (n.unread)
                                  Container(
                                    margin: const EdgeInsets.only(top: 18),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 8),
                                const SizedBox(width: 8),
                                _NotificationAvatar(notification: n),
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
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      if (n.body != null &&
                                          n.body!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          n.body!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                height: 1.35,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  n.time,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? scheme.onSurfaceVariant
                                        : Colors.grey[600],
                                    fontWeight: n.unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class AppNotification {
  final int? id;
  final NotificationType type;
  final String rawType;
  final String title;
  final String? body;
  final String time;
  bool unread;
  final bool highlighted;
  final Map<String, dynamic>? data;

  AppNotification({
    this.id,
    required this.type,
    required this.rawType,
    required this.title,
    required this.time,
    this.body,
    this.unread = false,
    this.highlighted = false,
    this.data,
  });
}

class _NotificationAvatar extends StatelessWidget {
  final AppNotification notification;

  const _NotificationAvatar({required this.notification});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;

    switch (notification.rawType) {
      case 'post_comment':
        icon = Icons.mode_comment_rounded;
        color = const Color(0xFF2563EB);
        break;
      case 'post_reaction':
        icon = Icons.thumb_up_alt_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'post_repost':
        icon = Icons.repeat_rounded;
        color = const Color(0xFF7C3AED);
        break;
      case 'post_share':
        icon = Icons.share_rounded;
        color = const Color(0xFF059669);
        break;
      case 'story_reaction':
        icon = Icons.auto_awesome_rounded;
        color = const Color(0xFFDB2777);
        break;
      case 'story_reply':
        icon = Icons.reply_rounded;
        color = const Color(0xFF2563EB);
        break;
      case 'story_repost':
        icon = Icons.repeat_on_rounded;
        color = const Color(0xFFB45309);
        break;
      case 'story_share':
        icon = Icons.ios_share_rounded;
        color = const Color(0xFF0F766E);
        break;
      default:
        switch (notification.type) {
          case NotificationType.job:
            icon = Icons.work_rounded;
            color = Colors.green;
            break;
          case NotificationType.mention:
            icon = Icons.alternate_email_rounded;
            color = Colors.purple;
            break;
          case NotificationType.system:
            icon = Icons.campaign_rounded;
            color = Colors.blue;
            break;
          case NotificationType.connection:
            icon = Icons.person_add_alt_1_rounded;
            color = Colors.teal;
            break;
          case NotificationType.message:
            icon = Icons.chat_bubble_rounded;
            color = Colors.indigo;
            break;
          case NotificationType.event:
            icon = Icons.event_rounded;
            color = Colors.deepOrange;
            break;
          case NotificationType.support:
            icon = Icons.support_agent_rounded;
            color = Colors.cyan;
            break;
          case NotificationType.post:
            icon = Icons.article_rounded;
            color = Colors.grey;
            break;
        }
        break;
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
