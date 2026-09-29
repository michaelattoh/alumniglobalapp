import 'package:flutter/material.dart';
import 'dart:async';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'chat_detail_screen.dart';

class NewGroupChatScreen extends StatefulWidget {
  const NewGroupChatScreen({super.key});

  @override
  State<NewGroupChatScreen> createState() => _NewGroupChatScreenState();
}

class _NewGroupChatScreenState extends State<NewGroupChatScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  final Set<int> selectedUserIds = {};
  final Set<String> selectedUserNames = {};
  Timer? _debounce;
  bool _loading = false;
  bool _creating = false;

  List<Map<String, dynamic>> users = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _groupNameController.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        users = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final results = await HomeApiService.searchDirectoryUsers(q, perPage: 40);
    if (!mounted) return;
    setState(() {
      users = results;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    if (selectedUserIds.isEmpty || _creating) return;
    setState(() => _creating = true);

    final name = _groupNameController.text.trim();
    final group = await HomeApiService.createGroupChat(
      name: name.isEmpty ? 'New Group' : name,
      memberIds: selectedUserIds.toList(),
    );

    if (!mounted) return;
    setState(() => _creating = false);

    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create group')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: 'group_${group['id']}',
          chatName: (group['name'] ?? 'New Group').toString(),
          isGroup: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = users;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New group'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: selectedUserIds.isEmpty || _creating ? null : _createGroup,
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Group name',
                prefixIcon: const Icon(Icons.groups_rounded),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: TextField(
              controller: searchCtrl,
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _runSearch(value);
                });
              },
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
          if (selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected: ${selectedUserIds.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedUserIds.clear();
                            selectedUserNames.clear();
                          });
                        },
                        child: const Text(
                          'Clear all',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: selectedUserNames.map((name) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            label: Text(name),
                            onDeleted: () {
                              final index = users.indexWhere((u) => (u['name'] ?? '').toString() == name);
                              if (index == -1) {
                                setState(() {
                                  selectedUserNames.remove(name);
                                });
                                return;
                              }
                              final id = (users[index]['id'] as num?)?.toInt();
                              setState(() {
                                selectedUserNames.remove(name);
                                if (id != null) selectedUserIds.remove(id);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? const Center(child: Text('Search people to add'))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredUsers.length,
                        itemBuilder: (_, i) {
                          final row = filteredUsers[i];
                          final id = (row['id'] as num?)?.toInt();
                          final name = (row['name'] ?? '').toString();
                          final selected = id != null && selectedUserIds.contains(id);

                          return ListTile(
                            leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '')),
                            title: Text(name),
                            subtitle: Text(
                              [
                                (row['program'] ?? '').toString(),
                                (row['location'] ?? '').toString(),
                              ].where((e) => e.isNotEmpty).join(' • '),
                            ),
                            trailing: Checkbox(
                              value: selected,
                              onChanged: id == null
                                  ? null
                                  : (_) {
                                      setState(() {
                                        if (selected) {
                                          selectedUserIds.remove(id);
                                          selectedUserNames.remove(name);
                                        } else {
                                          selectedUserIds.add(id);
                                          selectedUserNames.add(name);
                                        }
                                      });
                                    },
                            ),
                            onTap: id == null
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        selectedUserIds.remove(id);
                                        selectedUserNames.remove(name);
                                      } else {
                                        selectedUserIds.add(id);
                                        selectedUserNames.add(name);
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
