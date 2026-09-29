import 'package:flutter/material.dart';
import 'dart:async';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'chat_detail_screen.dart';

class NewMessageScreen extends StatefulWidget {
  final bool isGroup;

  const NewMessageScreen({
    super.key,
    required this.isGroup,
  });

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;

  List<Map<String, dynamic>> users = [];

  @override
  void dispose() {
    _debounce?.cancel();
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
    final results = await HomeApiService.searchDirectoryUsers(q, perPage: 30);
    if (!mounted) return;
    setState(() {
      users = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = users;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'New message',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchCtrl,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    _runSearch(value);
                  });
                },
                decoration: const InputDecoration(
                  prefixText: 'To: ',
                  hintText: 'Type a name',
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('Search people to start a chat'))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final row = filtered[i];
                            final id = (row['id'] as num?)?.toInt();
                            final name = (row['name'] ?? '').toString();
                            return ListTile(
                              leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '')),
                              title: Text(name),
                              subtitle: Text(
                                [
                                  (row['program'] ?? '').toString(),
                                  (row['location'] ?? '').toString(),
                                ].where((e) => e.isNotEmpty).join(' • '),
                              ),
                              onTap: id == null
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatDetailScreen(
                                            chatId: 'user_$id',
                                            chatName: name,
                                            isGroup: false,
                                          ),
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
