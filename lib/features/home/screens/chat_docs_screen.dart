import 'package:flutter/material.dart';
import 'chat_pdf_viewer.dart';

class ChatDocsScreen extends StatelessWidget {
  final String chatId;

  const ChatDocsScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final docs = [
      {'name': 'Project_Proposal.pdf', 'url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'},
      {'name': 'Budget_2025.pdf', 'url': 'https://www.orimi.com/pdf-test.pdf'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final doc = docs[i];
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: Text(doc['name']!),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPdfViewer(
                    title: doc['name']!,
                    url: doc['url']!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}