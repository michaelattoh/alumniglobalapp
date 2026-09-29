import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/features/home/widgets/video_preview.dart';

class StoryCreateScreen extends StatefulWidget {
  final StoryTemplateConfig? initialTemplate;

  const StoryCreateScreen({super.key, this.initialTemplate});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class StoryTemplateConfig {
  final String kind;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> meta;
  final LinearGradient background;
  final String? badgeImageUrl;
  final String badgeText;
  final Color accentColor;
  final String footerLine;
  final String highlightLabel;

  const StoryTemplateConfig({
    required this.kind,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.meta = const [],
    required this.background,
    this.badgeImageUrl,
    this.badgeText = '',
    this.accentColor = Colors.white,
    this.footerLine = '',
    this.highlightLabel = '',
  });

  factory StoryTemplateConfig.event({
    required String title,
    required String date,
    required String location,
    String host = 'Community event',
    String type = 'event',
    String? badgeImageUrl,
  }) {
    final lowerType = type.toLowerCase();
    final palette = lowerType.contains('webinar')
        ? (
            const Color(0xFF0F172A),
            const Color(0xFF7C3AED),
            const Color(0xFFC084FC),
            const Color(0xFFC084FC),
          )
        : lowerType.contains('network')
        ? (
            const Color(0xFF082F49),
            const Color(0xFF0EA5E9),
            const Color(0xFF67E8F9),
            const Color(0xFF67E8F9),
          )
        : lowerType.contains('career')
        ? (
            const Color(0xFF14532D),
            const Color(0xFF16A34A),
            const Color(0xFF86EFAC),
            const Color(0xFF86EFAC),
          )
        : (
            const Color(0xFF0F172A),
            const Color(0xFF1D4ED8),
            const Color(0xFF38BDF8),
            const Color(0xFFBAE6FD),
          );
    return StoryTemplateConfig(
      kind: 'event',
      eyebrow: 'Event highlight',
      title: title,
      subtitle: host,
      meta: [
        if (date.trim().isNotEmpty) date,
        if (location.trim().isNotEmpty) location,
      ],
      background: LinearGradient(
        colors: [palette.$1, palette.$2, palette.$3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      badgeImageUrl: badgeImageUrl,
      badgeText: lowerType.isEmpty ? 'EVENT' : lowerType.toUpperCase(),
      accentColor: palette.$4,
      footerLine: 'Tap in, attend, and bring someone with you',
      highlightLabel: 'Save the date',
    );
  }

  factory StoryTemplateConfig.achievement({
    required String title,
    required String subtitle,
    List<String> meta = const [],
    bool isSchool = false,
    String? badgeImageUrl,
    String badgeText = '',
  }) {
    return StoryTemplateConfig(
      kind: 'achievement',
      eyebrow: isSchool ? 'School achievement' : 'Alumni achievement',
      title: title,
      subtitle: subtitle,
      meta: meta,
      background: LinearGradient(
        colors: isSchool
            ? const [Color(0xFF14532D), Color(0xFF16A34A), Color(0xFF86EFAC)]
            : const [Color(0xFF581C87), Color(0xFF9333EA), Color(0xFFF472B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      badgeImageUrl: badgeImageUrl,
      badgeText: badgeText,
      accentColor: isSchool ? const Color(0xFFBBF7D0) : const Color(0xFFFBCFE8),
      footerLine: isSchool
          ? 'Institutional pride, leadership, and momentum'
          : 'Milestones worth sharing with your alumni network',
      highlightLabel: isSchool ? 'Institution Spotlight' : 'Recognition Moment',
    );
  }
}

class _StoryCreateScreenState extends State<StoryCreateScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  late final AnimationController _capturePulseController;
  XFile? _selected;
  String _type = 'image';
  bool _loading = false;
  String _visibility = 'public';
  String? _error;
  bool _toolRailExpanded = true;
  double _toolRailTopFactor = 0.54;
  final List<_StorySticker> _stickers = [];
  _StoryFilter _selectedFilter = _storyFilters.first;
  _StoryOverlay _selectedOverlay = _storyOverlays.first;
  StoryTemplateConfig? _template;

  bool get _hasStoryDraft =>
      _selected != null ||
      _template != null ||
      _captionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    _capturePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    if (_template != null) {
      _type = 'image';
    }
  }

  @override
  void dispose() {
    _capturePulseController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _selected = file;
      _type = 'image';
      _error = null;
      _template = null;
    });
  }

  Future<void> _pickVideo({required ImageSource source}) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;
    setState(() {
      _selected = file;
      _type = 'video';
      _error = null;
      _template = null;
    });
  }

  Future<void> _publish() async {
    if (!_hasStoryDraft) {
      setState(
        () => _error =
            'Choose a photo, video, template, or write a caption for your story first.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final composedPath = await _composedMediaPathIfNeeded();
    if (composedPath == null && _selected == null) {
      setState(() {
        _loading = false;
        _error = 'Unable to prepare this story card right now.';
      });
      return;
    }
    final upload = await HomeApiService.uploadMedia(
      filePath: composedPath ?? _selected!.path,
      fileName: composedPath == null
          ? _selected!.name
          : 'story-composed-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (upload == null) {
      setState(() {
        _loading = false;
        _error = 'Upload failed. Try again.';
      });
      return;
    }
    final url = upload['url']?.toString();
    if (url == null || url.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Upload failed. Try again.';
      });
      return;
    }

    final createdStory = await HomeApiService.createStory(
      visibility: _visibility,
      caption: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      media: [
        {'type': composedPath != null ? 'image' : _type, 'url': url},
      ],
    );
    if (!mounted) return;
    if (createdStory == null) {
      setState(() {
        _loading = false;
        _error = 'Unable to publish story.';
      });
      return;
    }

    HomeApiService.addPendingStory(createdStory);
    Navigator.pop(context, createdStory);
  }

  Future<String?> _composedMediaPathIfNeeded() async {
    if (_type != 'image') return null;
    final needsComposition =
        _template != null ||
        _stickers.isNotEmpty ||
        _selectedOverlay.id != 'none' ||
        _selectedFilter.id != 'none' ||
        _captionController.text.trim().isNotEmpty;
    if (!needsComposition) return null;
    try {
      final boundary =
          _previewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final bytes = Uint8List.view(data.buffer);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/story-composed-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openCaptionEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Story caption',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a quick thought to layer over your story.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _captionController,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _openVisibilityPicker() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _visibilityTile(
                  context,
                  value: 'public',
                  title: 'Public',
                  subtitle: 'Visible to your full community',
                  icon: Icons.public_rounded,
                ),
                const SizedBox(height: 10),
                _visibilityTile(
                  context,
                  value: 'institution_only',
                  title: 'Institution only',
                  subtitle: 'Keep this inside your school network',
                  icon: Icons.school_rounded,
                ),
              ],
            ),
          ),
        );
      },
    );
    if (value != null && mounted) {
      setState(() => _visibility = value);
    }
  }

  Future<void> _openStickerEditor() async {
    final controller = TextEditingController();
    Color selectedColor = Colors.white;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add text sticker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Drop a statement on the story and drag it wherever it feels right.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type sticker text',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _stickerPalette
                        .map(
                          (color) => GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == color
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.12),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          _stickers.add(
                            _StorySticker(
                              id: DateTime.now().microsecondsSinceEpoch
                                  .toString(),
                              text: text,
                              color: selectedColor,
                            ),
                          );
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111827),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Add sticker'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openFilterPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a filter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _storyFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final filter = _storyFilters[index];
                      final active = _selectedFilter.id == filter.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          width: 86,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.08),
                            ),
                            gradient: filter.previewGradient,
                          ),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              filter.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openOverlayPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick an overlay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _storyOverlays.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final overlay = _storyOverlays[index];
                      final active = _selectedOverlay.id == overlay.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedOverlay = overlay),
                        child: Container(
                          width: 88,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: overlay.previewGradient,
                            border: Border.all(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              overlay.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _visibilityTile(
    BuildContext context, {
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final active = _visibility == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).pop(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.white : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (active) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final caption = _captionController.text.trim();
    if (_selected == null && _template != null) {
      final isAchievement = _template!.kind == 'achievement';
      final isEvent = _template!.kind == 'event';
      final isSchoolHighlight =
          isAchievement && _template!.eyebrow.toLowerCase().contains('school');
      return RepaintBoundary(
        key: _previewKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: _template!.background),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.12),
                      Colors.transparent,
                      Colors.black.withOpacity(0.22),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 110),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEvent)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _templateBadgeAvatar(size: 56),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _template!.eyebrow,
                                        style: TextStyle(
                                          color: _template!.accentColor,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'You are invited',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              _templateBadgeAvatar(
                                size: isSchoolHighlight ? 60 : 52,
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _template!.eyebrow,
                                  style: TextStyle(
                                    color: isAchievement
                                        ? _template!.accentColor
                                        : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        if (isAchievement)
                          Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSchoolHighlight
                                          ? Icons.workspace_premium_rounded
                                          : Icons.emoji_events_rounded,
                                      color: _template!.accentColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _template!.highlightLabel,
                                      style: TextStyle(
                                        color: _template!.accentColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (!isSchoolHighlight)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 18),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        color: _template!.accentColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Featured',
                                        style: TextStyle(
                                          color: _template!.accentColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        Text(
                          _template!.title,
                          maxLines: isEvent ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isEvent ? 13 : 31,
                            fontWeight: FontWeight.w800,
                            height: isEvent ? 1.18 : 1.08,
                          ),
                        ),
                        if (_template!.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _template!.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _template!.meta
                              .map(
                                (item) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        if (isEvent) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Save the date',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: _template!.accentColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _template!.meta.isNotEmpty
                                            ? _template!.meta.first
                                            : 'Date coming soon',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _template!.meta.length > 1
                                            ? _template!.meta[1]
                                            : 'Online / in person',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    'RSVP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        if (_template!.footerLine.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _template!.footerLine,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 22,
              bottom: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Alumni Global',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            ..._buildStickerWidgets(),
          ],
        ),
      );
    }
    if (_selected == null) {
      if (caption.isNotEmpty) {
        return RepaintBoundary(
          key: _previewKey,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1D4ED8),
                  Color(0xFF38BDF8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.18),
                          Colors.transparent,
                          Colors.black.withOpacity(0.28),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 28,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Quick update',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Alumni Global',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF09090B), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    radius: 0.9,
                    center: const Alignment(0, -0.6),
                  ),
                ),
              ),
            ),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactPreview = constraints.maxWidth < 320;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: compactPreview ? 78 : 92,
                        height: compactPreview ? 78 : 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: compactPreview ? 36 : 42,
                        ),
                      ),
                      SizedBox(height: compactPreview ? 14 : 18),
                      Text(
                        'Capture a moment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compactPreview ? 20 : 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compactPreview ? 18 : 28,
                        ),
                        child: Text(
                          'Share a quick alumni update, event moment, or achievement highlight from camera or gallery.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.45),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (_type == 'image') {
      Widget image = Image.file(File(_selected!.path), fit: BoxFit.cover);
      if (_selectedFilter.id != 'none') {
        image = ColorFiltered(
          colorFilter: ColorFilter.matrix(_selectedFilter.matrix),
          child: image,
        );
      }
      return RepaintBoundary(
        key: _previewKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (_selectedOverlay.id != 'none')
              DecoratedBox(
                decoration: BoxDecoration(gradient: _selectedOverlay.gradient),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 124,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.34),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ..._buildStickerWidgets(),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: RepaintBoundary(
        key: _previewKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: VideoPreview.file(
                filePath: _selected!.path,
                fit: BoxFit.contain,
                autoplay: true,
                looping: true,
                showPlayOverlay: false,
              ),
            ),
            if (_selectedOverlay.id != 'none')
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _selectedOverlay.gradient,
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                      Colors.black.withOpacity(0.35),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 124,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.34),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ..._buildStickerWidgets(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStickerWidgets() {
    return _stickers
        .map(
          (sticker) => _DraggableSticker(
            key: ValueKey(sticker.id),
            sticker: sticker,
            onChanged: (updated) {
              setState(() {
                final index = _stickers.indexWhere(
                  (item) => item.id == updated.id,
                );
                if (index >= 0) _stickers[index] = updated;
              });
            },
            onRemove: () {
              setState(() {
                _stickers.removeWhere((item) => item.id == sticker.id);
              });
            },
          ),
        )
        .toList();
  }

  Widget _templateBadgeFallback() {
    return Container(
      color: Colors.white.withOpacity(0.12),
      child: Center(
        child: Text(
          _template!.badgeText.characters.take(2).toString(),
          style: TextStyle(
            color: _template!.accentColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _templateBadgeAvatar({double size = 52}) {
    if (_template?.badgeImageUrl != null &&
        _template!.badgeImageUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          _template!.badgeImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _templateBadgeFallback(),
        ),
      );
    }
    if (_template?.badgeText.isNotEmpty ?? false) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Center(
          child: Text(
            _template!.badgeText.characters.take(2).toString(),
            style: TextStyle(
              color: _template!.accentColor,
              fontWeight: FontWeight.w900,
              fontSize: size > 54 ? 18 : 16,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _railButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: _toolRailExpanded ? 14 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              if (_toolRailExpanded) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomTrayButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.18)
              : Colors.black.withOpacity(0.26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTray() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_selected != null)
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _type == 'image'
                  ? Image.file(File(_selected!.path), fit: BoxFit.cover)
                  : VideoPreview.file(
                      filePath: _selected!.path,
                      fit: BoxFit.cover,
                      autoplay: false,
                    ),
            ),
          _bottomTrayButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: () => _pickImage(source: ImageSource.gallery),
            active: _selected != null && _type == 'image',
          ),
          _bottomTrayButton(
            icon: Icons.movie_creation_outlined,
            label: 'Video',
            onTap: () => _pickVideo(source: ImageSource.gallery),
            active: _selected != null && _type == 'video',
          ),
          _bottomTrayButton(
            icon: Icons.camera_alt_outlined,
            label: 'Shoot',
            onTap: () => _pickImage(source: ImageSource.camera),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    final actionLabel = !_hasStoryDraft ? 'Pick media' : 'Post story';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _loading
              ? null
              : () {
                  if (!_hasStoryDraft) {
                    _pickImage(source: ImageSource.camera);
                  } else {
                    _publish();
                  }
                },
          child: AnimatedBuilder(
            animation: _capturePulseController,
            builder: (context, _) {
              final pulse = 1 + (_capturePulseController.value * 0.08);
              return Transform.scale(
                scale: _loading ? 1 : pulse,
                child: Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        color: Colors.white.withOpacity(
                          _selected == null ? 0.12 : 0.2,
                        ),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _loading
                          ? Colors.white.withOpacity(0.45)
                          : (_selected == null
                                ? Colors.white.withOpacity(0.92)
                                : Colors.white),
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.8,
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFF111827),
                              ),
                            ),
                          )
                        : Icon(
                            _selected == null
                                ? Icons.camera_alt_rounded
                                : Icons.arrow_upward_rounded,
                            color: const Color(0xFF111827),
                            size: 34,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          actionLabel,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = _captionController.text.trim();
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final isCompact = size.width < 380 || size.height < 760;
    final railTop = (screenHeight * _toolRailTopFactor).clamp(
      180.0,
      screenHeight - 280,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, isCompact ? 8 : 12, 16, 18),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _surfaceIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: isCompact ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Story update',
                            style: TextStyle(
                              fontSize: isCompact ? 18 : 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _template == null
                                ? 'Share a quick moment with your alumni community.'
                                : 'Turn this highlight into a story card.',
                            maxLines: isCompact ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusPill(
                      label: _visibility == 'public'
                          ? 'Community'
                          : 'Institution',
                      icon: _visibility == 'public'
                          ? Icons.public_rounded
                          : Icons.school_rounded,
                    ),
                    if (_hasStoryDraft) ...[
                      SizedBox(width: isCompact ? 8 : 10),
                      FilledButton(
                        onPressed: _loading ? null : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 12 : 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Post'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(isCompact ? 10 : 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _buildPreview(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: isCompact ? 18 : 26,
                        left: isCompact ? 18 : 26,
                        right: isCompact ? 18 : 26,
                        child: Row(
                          children: [
                            _softPreviewChip(
                              icon: Icons.auto_awesome_rounded,
                              label: _template == null
                                  ? 'Quick update'
                                  : 'Story card',
                            ),
                            const Spacer(),
                            _surfaceIconButton(
                              icon: Icons.text_fields_rounded,
                              onTap: _openCaptionEditor,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      Positioned(
                        left: isCompact ? 18 : 28,
                        top: railTop,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            final next =
                                (_toolRailTopFactor +
                                        (details.delta.dy /
                                            MediaQuery.of(context).size.height))
                                    .clamp(0.28, 0.72);
                            setState(() => _toolRailTopFactor = next);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _railButton(
                                icon: Icons.text_fields_rounded,
                                label: 'Sticker',
                                onTap: _openStickerEditor,
                              ),
                              _railButton(
                                icon: Icons.groups_rounded,
                                label: _visibility == 'public'
                                    ? 'Community'
                                    : 'Institution',
                                onTap: _openVisibilityPicker,
                              ),
                              _railButton(
                                icon: Icons.palette_outlined,
                                label: 'Overlay',
                                onTap: _openOverlayPicker,
                              ),
                              _railButton(
                                icon: Icons.tune_rounded,
                                label: 'Filter',
                                onTap: _openFilterPicker,
                              ),
                              _surfaceIconButton(
                                icon: _toolRailExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                                onTap: () => setState(() {
                                  _toolRailExpanded = !_toolRailExpanded;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null)
                        Positioned(
                          left: isCompact ? 18 : 28,
                          right: isCompact ? 18 : 28,
                          bottom: 112,
                          child: _errorBanner(_error!),
                        ),
                      if (caption.isNotEmpty)
                        Positioned(
                          left: isCompact ? 18 : 28,
                          right: isCompact ? 18 : 28,
                          bottom: 146,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              caption,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 10 : 14),
              Container(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    isCompact
                        ? Column(
                            children: [
                              _buildBottomTray(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildCaptureButton()),
                                  const SizedBox(width: 12),
                                  _surfaceIconButton(
                                    icon: Icons.cameraswitch_rounded,
                                    onTap: () {
                                      if (_type == 'video') {
                                        _pickVideo(source: ImageSource.camera);
                                      } else {
                                        _pickImage(source: ImageSource.camera);
                                      }
                                    },
                                    size: 48,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            runSpacing: 12,
                            spacing: 12,
                            children: [
                              _buildBottomTray(),
                              _buildCaptureButton(),
                              _surfaceIconButton(
                                icon: Icons.cameraswitch_rounded,
                                onTap: () {
                                  if (_type == 'video') {
                                    _pickVideo(source: ImageSource.camera);
                                  } else {
                                    _pickImage(source: ImageSource.camera);
                                  }
                                },
                                size: 54,
                              ),
                            ],
                          ),
                    SizedBox(height: isCompact ? 12 : 14),
                    Row(
                      children: [
                        Expanded(
                          child: _workspaceChip(
                            icon: Icons.edit_note_rounded,
                            text: 'Quick update',
                            active: _template == null,
                            onTap: () => setState(() => _template = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _workspaceChip(
                            icon: Icons.event_rounded,
                            text: 'Event card',
                            active: _template?.kind == 'event',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Use Share to story from an event to create an event card.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _workspaceChip(
                            icon: Icons.workspace_premium_rounded,
                            text: 'Highlight',
                            active: _template?.kind == 'achievement',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Use Share to story from a profile achievement or school highlight.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surfaceIconButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 46,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: const Color(0xFF0F172A), size: 24),
      ),
    );
  }

  Widget _statusPill({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softPreviewChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceChip({
    required IconData icon,
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB91C1C),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorySticker {
  final String id;
  final String text;
  final Color color;
  final Offset normalizedOffset;

  const _StorySticker({
    required this.id,
    required this.text,
    required this.color,
    this.normalizedOffset = const Offset(0.5, 0.38),
  });

  _StorySticker copyWith({
    String? id,
    String? text,
    Color? color,
    Offset? normalizedOffset,
  }) {
    return _StorySticker(
      id: id ?? this.id,
      text: text ?? this.text,
      color: color ?? this.color,
      normalizedOffset: normalizedOffset ?? this.normalizedOffset,
    );
  }
}

class _DraggableSticker extends StatelessWidget {
  final _StorySticker sticker;
  final ValueChanged<_StorySticker> onChanged;
  final VoidCallback onRemove;

  const _DraggableSticker({
    super.key,
    required this.sticker,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final left =
              (constraints.maxWidth - 160) * sticker.normalizedOffset.dx;
          final top =
              (constraints.maxHeight - 80) * sticker.normalizedOffset.dy;
          return Stack(
            children: [
              Positioned(
                left: left.clamp(0.0, constraints.maxWidth - 160),
                top: top.clamp(0.0, constraints.maxHeight - 90),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final next = Offset(
                      ((left + details.delta.dx) / (constraints.maxWidth - 160))
                          .clamp(0.0, 1.0),
                      ((top + details.delta.dy) / (constraints.maxHeight - 80))
                          .clamp(0.0, 1.0),
                    );
                    onChanged(sticker.copyWith(normalizedOffset: next));
                  },
                  onLongPress: onRemove,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      sticker.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sticker.color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        shadows: const [
                          Shadow(
                            blurRadius: 14,
                            color: Colors.black54,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryFilter {
  final String id;
  final String label;
  final List<double> matrix;
  final LinearGradient previewGradient;

  const _StoryFilter({
    required this.id,
    required this.label,
    required this.matrix,
    required this.previewGradient,
  });
}

class _StoryOverlay {
  final String id;
  final String label;
  final Gradient gradient;
  final LinearGradient previewGradient;

  const _StoryOverlay({
    required this.id,
    required this.label,
    required this.gradient,
    required this.previewGradient,
  });
}

const List<Color> _stickerPalette = [
  Colors.white,
  Color(0xFFFDE047),
  Color(0xFF60A5FA),
  Color(0xFFF472B6),
  Color(0xFF4ADE80),
  Color(0xFFF97316),
];

const List<double> _identityMatrix = [
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _monoMatrix = [
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _warmMatrix = [
  1.12,
  0,
  0,
  0,
  10,
  0,
  1.02,
  0,
  0,
  6,
  0,
  0,
  0.9,
  0,
  -4,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _coolMatrix = [
  0.92,
  0,
  0,
  0,
  -6,
  0,
  1.0,
  0,
  0,
  2,
  0,
  0,
  1.12,
  0,
  12,
  0,
  0,
  0,
  1,
  0,
];

const List<double> _vividMatrix = [
  1.18,
  0,
  0,
  0,
  0,
  0,
  1.12,
  0,
  0,
  0,
  0,
  0,
  1.18,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

final List<_StoryFilter> _storyFilters = [
  _StoryFilter(
    id: 'none',
    label: 'Clean',
    matrix: _identityMatrix,
    previewGradient: const LinearGradient(
      colors: [Color(0xFF1F2937), Color(0xFF374151)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryFilter(
    id: 'warm',
    label: 'Warm',
    matrix: _warmMatrix,
    previewGradient: const LinearGradient(
      colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryFilter(
    id: 'cool',
    label: 'Cool',
    matrix: _coolMatrix,
    previewGradient: const LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryFilter(
    id: 'mono',
    label: 'Mono',
    matrix: _monoMatrix,
    previewGradient: const LinearGradient(
      colors: [Color(0xFF111827), Color(0xFF6B7280)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryFilter(
    id: 'vivid',
    label: 'Vivid',
    matrix: _vividMatrix,
    previewGradient: const LinearGradient(
      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];

final List<_StoryOverlay> _storyOverlays = [
  _StoryOverlay(
    id: 'none',
    label: 'None',
    gradient: const LinearGradient(
      colors: [Colors.transparent, Colors.transparent],
    ),
    previewGradient: const LinearGradient(
      colors: [Color(0xFF1F2937), Color(0xFF475569)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryOverlay(
    id: 'sunset',
    label: 'Sunset',
    gradient: LinearGradient(
      colors: [
        const Color(0xFFF97316).withOpacity(0.24),
        const Color(0xFFEC4899).withOpacity(0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    previewGradient: const LinearGradient(
      colors: [Color(0xFFF97316), Color(0xFFEC4899)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryOverlay(
    id: 'ocean',
    label: 'Ocean',
    gradient: LinearGradient(
      colors: [
        const Color(0xFF0EA5E9).withOpacity(0.24),
        const Color(0xFF14B8A6).withOpacity(0.16),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    previewGradient: const LinearGradient(
      colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _StoryOverlay(
    id: 'midnight',
    label: 'Midnight',
    gradient: LinearGradient(
      colors: [
        const Color(0xFF111827).withOpacity(0.18),
        const Color(0xFF4F46E5).withOpacity(0.24),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    previewGradient: const LinearGradient(
      colors: [Color(0xFF111827), Color(0xFF4F46E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];
