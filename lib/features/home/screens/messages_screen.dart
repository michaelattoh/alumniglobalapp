import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_detail_screen.dart';
import 'new_group_chat_screen.dart';
import 'new_message_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  String activeFilter = 'Focused';
  bool _loading = true;

  final List<String> filters = ['Focused', 'Unread', 'Groups'];
  List<Map<String, dynamic>> conversations = [];

  @override
  void initState() {
    super.initState();
    if (HomeApiService.isInstitutionAccessRestricted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(HomeApiService.accessRestrictionMessage)),
        );
      });
      _loading = false;
      return;
    }
    _loadConversations();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _relativeTime(String? iso) {
    if (iso == null) return 'now';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _conversationInitials(String name, {required bool isGroup}) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return isGroup ? 'GR' : 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _previewLabel(Map<String, dynamic> conversation) {
    final message = (conversation['message'] ?? '').toString().trim();
    final isGroup =
        conversation['group_id'] != null ||
        (conversation['type'] ?? '').toString() == 'Groups';
    if (message.isEmpty) {
      return isGroup ? 'Group chat is ready' : 'Start a conversation';
    }
    return message;
  }

  Future<void> _loadConversations() async {
    final rows = await HomeApiService.fetchMessageConversations(maxUsers: 30);
    final groups = await HomeApiService.fetchGroupChats(perPage: 30);

    final groupRows = <Map<String, dynamic>>[];
    for (final g in groups) {
      final id = (g['id'] as num?)?.toInt();
      groupRows.add({
        'group_id': id,
        'name': (g['name'] ?? 'Group chat').toString(),
        'message': (g['last_message'] ?? 'Group chat').toString(),
        'time': _relativeTime(
          g['updated_at']?.toString() ?? g['created_at']?.toString(),
        ),
        'unread': false,
        'type': 'Groups',
      });
    }

    if (!mounted) return;
    setState(() {
      conversations = [...groupRows, ...rows];
      _loading = false;
    });
  }

  void _openCreateMenu() {
    if (HomeApiService.isInstitutionAccessRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HomeApiService.accessRestrictionMessage)),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF2563EB),
                ),
              ),
              title: const Text('Start new conversation'),
              subtitle: const Text('Message an alumni, school, or contact'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NewMessageScreen(isGroup: false),
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(Icons.groups_rounded, color: Color(0xFF7C3AED)),
              ),
              title: const Text('Start group chat'),
              subtitle: const Text('Create a shared space for a team or class'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewGroupChatScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final filtered = conversations.where((c) {
      final name = (c['name'] ?? '').toString();
      final type = (c['type'] ?? '').toString();
      final unread = c['unread'] == true;

      final matchesSearch = name.toLowerCase().contains(
        searchCtrl.text.toLowerCase(),
      );

      final matchesFilter = activeFilter == 'Focused'
          ? type != 'Groups'
          : activeFilter == 'Unread'
          ? unread
          : type == activeFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'Messages',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          onPressed: _openCreateMenu,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: const [
                          CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.forum_rounded,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stay close to your network',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Direct chats, groups, replies, reactions, and voice notes in one place.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search conversations',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final f = filters[i];
                    final active = f == activeFilter;
                    return GestureDetector(
                      onTap: () => setState(() => activeFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF0F172A)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF0F172A)
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: active ? Colors.white : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: _loadConversations,
                  child: _loading
                      ? ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: 6,
                          itemBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: _ConversationSkeleton(),
                          ),
                        )
                      : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                children: const [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Color(0xFFDBEAFE),
                                    child: Icon(
                                      Icons.mark_chat_unread_rounded,
                                      size: 32,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No conversations yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start a conversation or create a group to keep your alumni community moving.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            final name = (c['name'] ?? '').toString();
                            final unread = c['unread'] == true;
                            final peerId = (c['user_id'] as num?)?.toInt();
                            final groupId = (c['group_id'] as num?)?.toInt();
                            final isGroup =
                                (c['type'] ?? 'Focused') == 'Groups' ||
                                groupId != null;
                            final chatId = isGroup && groupId != null
                                ? 'group_$groupId'
                                : peerId != null
                                ? 'user_$peerId'
                                : 'chat_${name.hashCode}';
                            final preview = _previewLabel(c);
                            final time = (c['time'] ?? '').toString();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(24),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () async {
                                    if (HomeApiService
                                        .isInstitutionAccessRestricted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            HomeApiService
                                                .accessRestrictionMessage,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      filtered[i]['unread'] = false;
                                      final sourceIndex = conversations
                                          .indexWhere(
                                            (row) =>
                                                row['user_id'] ==
                                                    c['user_id'] &&
                                                row['group_id'] ==
                                                    c['group_id'],
                                          );
                                      if (sourceIndex >= 0) {
                                        conversations[sourceIndex] = {
                                          ...conversations[sourceIndex],
                                          'unread': false,
                                        };
                                      }
                                    });
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatDetailScreen(
                                          chatId: chatId,
                                          chatName: name,
                                          isGroup: isGroup,
                                        ),
                                      ),
                                    );
                                    if (!mounted) return;
                                    await _loadConversations();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 54,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isGroup
                                                  ? const [
                                                      Color(0xFF8B5CF6),
                                                      Color(0xFF4F46E5),
                                                    ]
                                                  : const [
                                                      Color(0xFF38BDF8),
                                                      Color(0xFF2563EB),
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _conversationInitials(
                                              name,
                                              isGroup: isGroup,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: unread
                                                            ? FontWeight.w800
                                                            : FontWeight.w700,
                                                        color: scheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  if (time.isNotEmpty)
                                                    Text(
                                                      time,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (isGroup)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            right: 8,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF312E81,
                                                              )
                                                            : const Color(
                                                                0xFFF3E8FF,
                                                              ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Group',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF7C3AED,
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: Text(
                                                      preview,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: unread
                                                            ? scheme.onSurface
                                                            : scheme
                                                                  .onSurfaceVariant,
                                                        fontWeight: unread
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        unread
                                            ? Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF2563EB),
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                            : Icon(
                                                Icons.chevron_right_rounded,
                                                color: scheme.onSurfaceVariant,
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
      ),
    );
  }
}

class _ConversationSkeleton extends StatelessWidget {
  const _ConversationSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
