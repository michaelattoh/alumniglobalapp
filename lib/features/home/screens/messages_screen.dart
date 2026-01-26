import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'new_message_screen.dart';
import 'new_group_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController searchCtrl = TextEditingController();
  String activeFilter = 'Focused';

  final List<String> filters = ['Focused', 'Jobs', 'Unread', 'Groups'];

  /// ✅ MORE CHATS ADDED
  final List<Map<String, String>> conversations = [
    {
      "name": "Daniel Owusu",
      "message": "Hey Michael, are you available?",
      "time": "Now",
      "type": "Focused",
      "unread": "true",
    },
    {
      "name": "Amelia Richardson",
      "message": "Your application has been reviewed.",
      "time": "1h",
      "type": "Jobs",
      "unread": "false",
    },
    {
      "name": "Product Team",
      "message": "Sprint planning starts tomorrow",
      "time": "2d",
      "type": "Groups",
      "unread": "true",
    },
    {
      "name": "Kwame Boateng",
      "message": "Let’s catch up this week",
      "time": "3h",
      "type": "Focused",
      "unread": "false",
    },
    {
      "name": "Sarah Mitchell",
      "message": "Please see the attached document",
      "time": "5h",
      "type": "Focused",
      "unread": "false",
    },
    {
      "name": "Recruitment – Verix",
      "message": "Interview scheduled for Friday",
      "time": "1d",
      "type": "Jobs",
      "unread": "true",
    },
    {
      "name": "Alumni Leaders",
      "message": "Next alumni meeting agenda",
      "time": "1d",
      "type": "Groups",
      "unread": "false",
    },
    {
      "name": "Michael Johnson",
      "message": "Thanks for the intro!",
      "time": "2d",
      "type": "Focused",
      "unread": "false",
    },
    {
      "name": "UX Designers Hub",
      "message": "New design resources shared",
      "time": "3d",
      "type": "Groups",
      "unread": "true",
    },
    {
      "name": "HR – Alpha Beta College",
      "message": "Application status update",
      "time": "4d",
      "type": "Jobs",
      "unread": "false",
    },
  ];

  void _openCreateMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Start new conversation'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NewMessageScreen(isGroup: false),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: const Text('Start group chat'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NewGroupChatScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = conversations.where((c) {
      final name = c['name'] ?? '';
      final type = c['type'] ?? '';
      final unread = c['unread'] == 'true';

      final matchesSearch =
          name.toLowerCase().contains(searchCtrl.text.toLowerCase());

      final matchesFilter = activeFilter == 'Focused'
          ? true
          : activeFilter == 'Unread'
              ? unread
              : type == activeFilter;

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// TOP BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search messages',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: _openCreateMenu,
                  ),
                ],
              ),
            ),

            /// FILTERS
            SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final f = filters[i];
                  final active = f == activeFilter;

                  return GestureDetector(
                    onTap: () {
                      setState(() => activeFilter = f);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            /// CHAT LIST
            Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: () async {
                    // TODO: fetch messages from API
                    await Future.delayed(const Duration(milliseconds: 900));
                    setState(() {});
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                    final c = filtered[i];
                    final name = c['name']!;
                    final message = c['message']!;
                    final time = c['time']!;
                    final unread = c['unread'] == 'true';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Stack(
                          children: [
                            CircleAvatar(child: Text(name[0])),
                            if (unread)
                              const Positioned(
                                right: 0,
                                top: 0,
                                child: CircleAvatar(
                                  radius: 5,
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          time,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                chatId: 'chat_${c['name'].hashCode}',
                                chatName: c['name'] ?? 'Unknown',
                                isGroup: c['type'] == 'Groups',
                              ),
                            ),
                          );
                        },
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