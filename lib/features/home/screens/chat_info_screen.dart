import 'package:alumni_global_app/features/home/screens/chat_docs_screen.dart';
import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'chat_media_screen.dart';
import 'edit_chat_title_sheet.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';

class ChatInfoScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isGroup,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  late String _title;
  bool _loadingMembers = false;
  List<Map<String, dynamic>> _members = [];
  int? _currentUserId;

  int? get _groupId {
    if (!widget.chatId.startsWith('group_')) return null;
    return int.tryParse(widget.chatId.substring(6));
  }

  @override
  void initState() {
    super.initState();
    _title = widget.chatName;
    _loadCurrentUser();
    _loadMembers();
  }

  Future<void> _loadCurrentUser() async {
    final id = await AuthSession.getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = id);
  }

  Future<void> _loadMembers() async {
    final groupId = _groupId;
    if (!widget.isGroup || groupId == null) return;
    setState(() => _loadingMembers = true);
    final rows = await HomeApiService.fetchGroupChatMembers(groupId);
    if (!mounted) return;
    setState(() {
      _members = rows;
      _loadingMembers = false;
    });
  }

  bool get _isAdmin {
    final meId = _currentUserId;
    if (meId == null) return false;
    final me = _members.firstWhere(
      (m) => (m['user']?['id'] as num?)?.toInt() == meId,
      orElse: () => {},
    );
    return (me['role'] ?? '') == 'admin';
  }

  Future<void> _removeMember(int userId) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final ok = await HomeApiService.removeGroupChatMember(
      groupId: groupId,
      userId: userId,
    );
    if (!mounted) return;
    if (ok) {
      await _loadMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove member')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Chat info'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  chatId: widget.chatId,
                  chatName: _title,
                  isGroup: widget.isGroup,
                ),
              ),
            );
          },
        ),
        actions: widget.isGroup && _groupId != null
            ? [
                TextButton(
                  onPressed: () async {
                    final nextTitle = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => EditChatTitleSheet(
                        initialTitle: _title,
                        groupId: _groupId!,
                      ),
                    );
                    if (nextTitle != null && nextTitle.trim().isNotEmpty && mounted) {
                      setState(() => _title = nextTitle.trim());
                    }
                  },
                  child: const Text(
                    'Edit',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ]
            : null,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 24),

          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(0xFFE5E7EB),
                  child: Icon(Icons.group_rounded, size: 42),
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _InfoTile(
            icon: Icons.photo_library_outlined,
            title: 'Media',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatMediaScreen(chatId: widget.chatId),
                ),
              );
            },
          ),

          _InfoTile(
            icon: Icons.insert_drive_file_outlined,
            title: 'Docs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDocsScreen(chatId: widget.chatId),
                ),
              );
            },
          ),

          if (widget.isGroup) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingMembers)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No members found'),
              )
            else
              ..._members.map((m) {
                final user = (m['user'] as Map<String, dynamic>?) ?? {};
                final name = (user['name'] ?? 'Member').toString();
                final role = (m['role'] ?? 'member').toString();
                final userId = (user['id'] as num?)?.toInt();
                final isMe = _currentUserId != null && userId == _currentUserId;
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE5E7EB),
                    child: Icon(Icons.person_rounded, color: Color(0xFF4B5563)),
                  ),
                  title: Text(name),
                  subtitle: Text(role == 'admin' ? 'Admin' : 'Member'),
                  trailing: userId != null && (isMe || _isAdmin)
                      ? TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(isMe ? 'Leave group?' : 'Remove member?'),
                                content: Text(isMe
                                    ? 'You will leave this group.'
                                    : 'Remove $name from the group?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text(isMe ? 'Leave' : 'Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && userId != null) {
                              await _removeMember(userId);
                              if (isMe && mounted) {
                                Navigator.of(context).pushReplacementNamed('/messages');
                              }
                            }
                          },
                          child: Text(isMe ? 'Leave' : 'Remove'),
                        )
                      : null,
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
