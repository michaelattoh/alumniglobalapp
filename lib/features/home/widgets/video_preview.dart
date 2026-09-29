import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  final String? url;
  final String? filePath;
  final BoxFit fit;
  final bool autoplay;
  final bool looping;
  final bool muted;
  final bool showPlayOverlay;
  final bool tapToToggle;
  final VoidCallback? onTap;
  final Widget? fallback;

  const VideoPreview.network({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.autoplay = false,
    this.looping = false,
    this.muted = true,
    this.showPlayOverlay = true,
    this.tapToToggle = true,
    this.onTap,
    this.fallback,
  }) : filePath = null;

  const VideoPreview.file({
    super.key,
    required this.filePath,
    this.fit = BoxFit.cover,
    this.autoplay = false,
    this.looping = false,
    this.muted = true,
    this.showPlayOverlay = true,
    this.tapToToggle = true,
    this.onTap,
    this.fallback,
  }) : url = null;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  bool get _isPlaying => _controller?.value.isPlaying == true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.filePath != widget.filePath) {
      _disposeController();
      _init();
    }
  }

  Future<void> _init() async {
    final controller = widget.filePath != null
        ? VideoPlayerController.file(File(widget.filePath!))
        : (widget.url == null || widget.url!.isEmpty)
        ? null
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    if (controller == null) return;
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.looping);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (widget.autoplay) {
        await controller.play();
      } else {
        // Prime the first visible frame so feed/story previews do not sit on a
        // black box until the user opens the full viewer.
        await controller.play();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await controller.pause();
        await controller.seekTo(Duration.zero);
      }
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = false);
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _ready = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _controller == null || !_controller!.value.isInitialized) {
      return widget.fallback ??
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white70,
              size: 46,
            ),
          );
    }

    final size = _controller!.value.size;
    final width = size.width <= 0 ? 16.0 : size.width;
    final height = size.height <= 0 ? 9.0 : size.height;

    Future<void> togglePlayback() async {
      if (_controller == null) return;
      if (_isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      if (!mounted) return;
      setState(() {});
    }

    final VoidCallback? handleTap = widget.onTap != null
        ? widget.onTap
        : widget.tapToToggle
        ? () {
            togglePlayback();
          }
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          ),
          if (widget.showPlayOverlay && !_isPlaying)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
