import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'chat_pdf_viewer.dart';

class ChatDocsScreen extends StatefulWidget {
  final String chatId;

  const ChatDocsScreen({super.key, required this.chatId});

  @override
  State<ChatDocsScreen> createState() => _ChatDocsScreenState();
}

class _ChatDocsScreenState extends State<ChatDocsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _docs = [];

  int? get _peerUserId {
    if (!widget.chatId.startsWith('user_')) return null;
    return int.tryParse(widget.chatId.substring(5));
  }

  int? get _groupId {
    if (!widget.chatId.startsWith('group_')) return null;
    return int.tryParse(widget.chatId.substring(6));
  }

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final peerId = _peerUserId;
    final groupId = _groupId;
    if (peerId == null && groupId == null) {
      setState(() => _loading = false);
      return;
    }

    final rows = peerId != null
        ? await HomeApiService.fetchMessageThread(peerId, perPage: 200)
        : await HomeApiService.fetchGroupThread(groupId!, perPage: 200);

    final docs = rows
        .where((m) => (m['attachment_url'] ?? '').toString().isNotEmpty)
        .where((m) => (m['attachment_type'] ?? '') == 'document')
        .map((m) => {
              'name': (m['attachment_name'] ?? 'Document').toString(),
              'url': (m['attachment_url'] ?? '').toString(),
            })
        .toList();

    if (!mounted) return;
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.insert_drive_file_outlined, size: 56, color: Colors.black38),
                      SizedBox(height: 12),
                      Text('No documents shared yet', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = _docs[i];
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: Text(doc['name'] ?? 'Document'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPdfViewer(
                              title: doc['name'] ?? 'Document',
                              url: doc['url'] ?? '',
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
