import 'package:flutter/material.dart';
import 'chat_media_viewer.dart';

class ChatMediaScreen extends StatelessWidget {
  final String chatId;

  const ChatMediaScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    // API-ready mock media
    final media = [
      {'type': 'image', 'url': 'https://picsum.photos/400/600?1'},
      {'type': 'image', 'url': 'https://picsum.photos/400/600?2'},
      {'type': 'video', 'url': 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4'},
      {'type': 'image', 'url': 'https://picsum.photos/400/600?3'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Media'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: media.length,
        itemBuilder: (_, index) {
          final item = media[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatMediaViewer(
                    media: media,
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
                      item['url']!,
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