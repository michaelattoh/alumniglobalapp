import 'package:flutter/material.dart';
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

  final List<String> users = [
    "Daniel Owusu",
    "Amelia Richardson",
    "Kwesi Mensah",
    "Sarah Johnson",
    "Bright Lamptey",
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = users
        .where((u) =>
            u.toLowerCase().contains(searchCtrl.text.toLowerCase()))
        .toList();

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
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixText: 'To: ',
                  hintText: 'Type a name',
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final name = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(name[0])),
                    title: Text(name),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: 'chat_${name.hashCode}',
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