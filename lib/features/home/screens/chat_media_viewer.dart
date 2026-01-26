import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ChatMediaViewer extends StatefulWidget {
  final List<Map<String, String>> media;
  final int initialIndex;

  const ChatMediaViewer({
    super.key,
    required this.media,
    required this.initialIndex,
  });

  @override
  State<ChatMediaViewer> createState() => _ChatMediaViewerState();
}

class _ChatMediaViewerState extends State<ChatMediaViewer> {
  late int index;
  VideoPlayerController? videoController;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    _loadMedia();
  }

  void _loadMedia() {
    videoController?.dispose();
    final item = widget.media[index];
    if (item['type'] == 'video') {
      videoController = VideoPlayerController.network(item['url']!)
        ..initialize().then((_) {
          setState(() {});
          videoController!.play();
        });
    }
  }

  void _next() {
    if (index < widget.media.length - 1) {
      setState(() {
        index++;
        _loadMedia();
      });
    }
  }

  void _prev() {
    if (index > 0) {
      setState(() {
        index--;
        _loadMedia();
      });
    }
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.media[index];

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: item['type'] == 'image'
                  ? Image.network(item['url']!, fit: BoxFit.contain)
                  : videoController != null &&
                          videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio:
                              videoController!.value.aspectRatio,
                          child: VideoPlayer(videoController!),
                        )
                      : const CircularProgressIndicator(),
            ),

            // Top controls
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white),
                        onPressed: _prev,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white),
                        onPressed: _next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}