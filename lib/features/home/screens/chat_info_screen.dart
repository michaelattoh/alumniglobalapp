import 'package:alumni_global_app/features/home/screens/chat_docs_screen.dart';
import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'chat_media_screen.dart';
import 'edit_chat_title_sheet.dart';

class ChatInfoScreen extends StatelessWidget {
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
                  chatId: chatId,
                  chatName: chatName,
                  isGroup: isGroup,
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => EditChatTitleSheet(
                  initialTitle: chatName,
                ),
              );
            },
            child: const Text(
              'Edit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
                  chatName,
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
                  builder: (_) => ChatMediaScreen(chatId: chatId),
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
                  builder: (_) => ChatDocsScreen(chatId: chatId),
                ),
              );
            },
          ),
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