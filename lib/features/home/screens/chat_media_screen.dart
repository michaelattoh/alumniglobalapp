import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'chat_media_viewer.dart';

class ChatMediaScreen extends StatefulWidget {
  final String chatId;

  const ChatMediaScreen({super.key, required this.chatId});

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  bool _loading = true;
  List<Map<String, String>> _media = [];

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
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final peerId = _peerUserId;
    final groupId = _groupId;
    if (peerId == null && groupId == null) {
      setState(() => _loading = false);
      return;
    }

    final rows = peerId != null
        ? await HomeApiService.fetchMessageThread(peerId, perPage: 200)
        : await HomeApiService.fetchGroupThread(groupId!, perPage: 200);

    final media = rows
        .where((m) => (m['attachment_url'] ?? '').toString().isNotEmpty)
        .where((m) => (m['attachment_type'] ?? '') == 'image' || (m['attachment_type'] ?? '') == 'video')
        .map((m) => {
              'type': (m['attachment_type'] ?? 'image').toString(),
              'url': (m['attachment_url'] ?? '').toString(),
            })
        .toList();

    if (!mounted) return;
    setState(() {
      _media = media;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Media'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _media.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.photo_library_outlined, size: 56, color: Colors.black38),
                      SizedBox(height: 12),
                      Text('No media shared yet', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _media.length,
                  itemBuilder: (_, index) {
                    final item = _media[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatMediaViewer(
                              media: _media,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                item['url'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                            if (item['type'] == 'video')
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
