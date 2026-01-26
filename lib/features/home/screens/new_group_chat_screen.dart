import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

class NewGroupChatScreen extends StatefulWidget {
  const NewGroupChatScreen({super.key});

  @override
  State<NewGroupChatScreen> createState() => _NewGroupChatScreenState();
}

class _NewGroupChatScreenState extends State<NewGroupChatScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final Set<String> selectedUsers = {};

  final List<String> users = [
    'Daniel Owusu',
    'Amelia Richardson',
    'Kwame Boateng',
    'Sarah Mitchell',
    'Michael Johnson',
    'Product Team',
    'UX Designers Hub',
    'HR – Alpha Beta College',
  ];

  void _createGroup() {
    if (selectedUsers.isEmpty) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: 'group_${DateTime.now().millisecondsSinceEpoch}',
          chatName: 'New Group',
          isGroup: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = users
        .where((u) =>
            u.toLowerCase().contains(searchCtrl.text.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New group'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _createGroup,
            child: const Text(
              'Create',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search people',
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
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filteredUsers.length,
              itemBuilder: (_, i) {
                final user = filteredUsers[i];
                final selected = selectedUsers.contains(user);

                return ListTile(
                  leading: CircleAvatar(child: Text(user[0])),
                  title: Text(user),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: (_) {
                      setState(() {
                        if (selected) {
                          selectedUsers.remove(user);
                        } else {
                          selectedUsers.add(user);
                        }
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      if (selected) {
                        selectedUsers.remove(user);
                      } else {
                        selectedUsers.add(user);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}