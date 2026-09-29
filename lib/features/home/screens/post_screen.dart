import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/features/home/widgets/mention_suggestion_box.dart';
import 'package:alumni_global_app/features/home/widgets/video_preview.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  static String? _draftText;
  static XFile? _draftMedia;
  static DateTime? _draftSchedule;
  static String? _draftVisibility;

  final TextEditingController _controller = TextEditingController(
    text: _draftText,
  );

  XFile? selectedMedia;
  DateTime? scheduledTime;
  String _visibility = 'public';
  bool _hasInstitution = false;
  int? _institutionId;
  List<Map<String, dynamic>> _mentionableUsers = [];
  List<Map<String, dynamic>> _mentionSuggestions = [];
  final Map<int, String> _mentionedUsers = {};

  String? topSuccessMessage;
  bool _posting = false;

  bool get hasContent =>
      _controller.text.trim().isNotEmpty ||
      selectedMedia != null ||
      scheduledTime != null;

  @override
  void initState() {
    super.initState();
    selectedMedia = _draftMedia;
    scheduledTime = _draftSchedule;
    _visibility = _draftVisibility ?? 'public';
    _controller.addListener(() {
      _handleComposerChanged();
      if (mounted) setState(() {});
    });
    _loadMe();
    _loadMentionableUsers();
  }

  Future<void> _loadMe() async {
    final me = await HomeApiService.fetchMe();
    if (!mounted) return;
    final memberships =
        (me?['memberships'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList() ??
        const <Map<String, dynamic>>[];
    int? approvedMembershipInstitutionId;
    for (final entry in memberships) {
      final institution = entry['institution'];
      if (institution is Map) {
        final nestedId = institution['id'];
        if (nestedId is num) {
          approvedMembershipInstitutionId = nestedId.toInt();
          break;
        }
        if (nestedId is String) {
          approvedMembershipInstitutionId = int.tryParse(nestedId);
          if (approvedMembershipInstitutionId != null) break;
        }
      }
      final raw = entry['institution_id'];
      if (raw is num) {
        approvedMembershipInstitutionId = raw.toInt();
        break;
      }
      if (raw is String) {
        approvedMembershipInstitutionId = int.tryParse(raw);
        if (approvedMembershipInstitutionId != null) break;
      }
    }
    final directInstitutionId =
        (me?['institution_id'] as num?)?.toInt() ??
        ((me?['institution'] as Map?)?['id'] as num?)?.toInt();
    final effectiveInstitutionId =
        directInstitutionId ?? approvedMembershipInstitutionId;
    setState(() {
      _institutionId = effectiveInstitutionId;
      _hasInstitution = effectiveInstitutionId != null;
      if (!_hasInstitution && _visibility == 'institution_only') {
        _visibility = 'public';
      }
    });
  }

  Future<void> _loadMentionableUsers() async {
    final users = await HomeApiService.fetchMentionableUsers();
    if (!mounted) return;
    setState(() {
      _mentionableUsers = users;
      _refreshMentionSuggestions();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showTopSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => selectedMedia = file);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => selectedMedia = file);
    }
  }

  Future<void> _pickSchedule() async {
    DateTime now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() => scheduledTime = scheduled);
  }

  Future<void> _exitPost() async {
    if (!hasContent) {
      Navigator.of(context).pop();
      return;
    }

    final save = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save draft?'),
        content: const Text('You have an unfinished post. Save it as a draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save == true) {
      _draftText = _controller.text;
      _draftMedia = selectedMedia;
      _draftSchedule = scheduledTime;
      _draftVisibility = _visibility;

      HapticFeedback.lightImpact();

      _showTopSuccess('Draft saved');
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).pop();
      });
    } else if (save == false) {
      _clearDraft();
      Navigator.of(context).pop();
    }
  }

  void _clearDraft() {
    _draftText = null;
    _draftMedia = null;
    _draftSchedule = null;
    _draftVisibility = null;
  }

  void _handleComposerChanged() {
    _mentionedUsers.removeWhere(
      (_, name) => !_controller.text.contains('@$name'),
    );
    _refreshMentionSuggestions();
  }

  void _refreshMentionSuggestions() {
    final selection = _controller.selection;
    final cursor = selection.baseOffset >= 0
        ? selection.baseOffset
        : _controller.text.length;
    final prefix = _controller.text.substring(0, cursor);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }
    final query = (match.group(1) ?? '').trim().toLowerCase();
    final suggestions = _mentionableUsers
        .where((user) {
          final name = (user['name'] ?? '').toString().trim();
          if (name.isEmpty) return false;
          if (_mentionedUsers.containsKey((user['id'] as num?)?.toInt())) {
            return false;
          }
          if (query.isEmpty) return true;
          final lowered = name.toLowerCase();
          return lowered.startsWith(query) || lowered.contains(query);
        })
        .take(6)
        .toList();
    setState(() => _mentionSuggestions = suggestions);
  }

  void _insertMention(Map<String, dynamic> user) {
    final userId = (user['id'] as num?)?.toInt();
    final name = (user['name'] ?? '').toString().trim();
    if (userId == null || name.isEmpty) return;
    final selection = _controller.selection;
    final cursor = selection.baseOffset >= 0
        ? selection.baseOffset
        : _controller.text.length;
    final prefix = _controller.text.substring(0, cursor);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) return;
    final mentionStart = match.start + (prefix[match.start] == ' ' ? 1 : 0);
    final replacement = '@$name ';
    final nextText =
        _controller.text.substring(0, mentionStart) +
        replacement +
        _controller.text.substring(cursor);
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: mentionStart + replacement.length,
      ),
    );
    _mentionedUsers[userId] = name;
    setState(() => _mentionSuggestions = []);
  }

  List<int> _selectedMentionIds() {
    final text = _controller.text;
    return _mentionedUsers.entries
        .where((entry) => text.contains('@${entry.value}'))
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> _postNow() async {
    final content = _controller.text.trim();
    if (content.isEmpty && selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text or media to post')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _posting = true);
    _clearDraft();
    HapticFeedback.mediumImpact();

    final mediaPayload = <Map<String, dynamic>>[];
    if (selectedMedia != null) {
      final upload = await HomeApiService.uploadMedia(
        filePath: selectedMedia!.path,
        fileName: selectedMedia!.name,
      );
      if (upload == null || upload['url'] == null) {
        if (mounted) setState(() => _posting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Media upload failed')));
        return;
      }
      final url = upload['url'].toString();
      final type =
          upload['type']?.toString() ?? _inferMediaType(selectedMedia!.path);
      mediaPayload.add({'type': type, 'url': url});
    }

    final createdPost = await HomeApiService.createPost(
      content: content.isEmpty ? 'Shared media' : content,
      media: mediaPayload,
      scheduledAt: scheduledTime?.toIso8601String(),
      visibility: _visibility,
      institutionId: _visibility == 'institution_only' ? _institutionId : null,
      mentions: _selectedMentionIds(),
    );
    if (mounted) setState(() => _posting = false);

    if (createdPost == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to publish post')));
      return;
    }

    final scheduledAt = scheduledTime;
    final isScheduled =
        scheduledAt != null && scheduledAt.isAfter(DateTime.now());
    if (!isScheduled) {
      HomeApiService.addPendingPost(createdPost);
      _showTopSuccess('Post published');
    } else {
      _showTopSuccess('Post scheduled');
    }
    Navigator.of(context).pop({
      'post': createdPost,
      'scheduled_at': scheduledTime?.toIso8601String(),
    });
  }

  String _inferMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi')) {
      return 'video';
    }
    return 'image';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              // -------- TOP BAR --------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _exitPost,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Create post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: hasContent && !_posting ? _postNow : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _posting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Share',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // -------- CONTENT --------
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Share with your network',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Visibility: Public',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Public'),
                            selected: _visibility == 'public',
                            onSelected: (_) =>
                                setState(() => _visibility = 'public'),
                          ),
                          ChoiceChip(
                            label: const Text('Institution'),
                            selected: _visibility == 'institution_only',
                            onSelected: _hasInstitution
                                ? (_) => setState(
                                    () => _visibility = 'institution_only',
                                  )
                                : null,
                          ),
                        ],
                      ),
                      if (!_hasInstitution)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Add your institution to post to your school.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'What do you want to share?',
                          border: InputBorder.none,
                        ),
                      ),
                      if (_mentionSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        MentionSuggestionBox(
                          users: _mentionSuggestions,
                          onSelected: _insertMention,
                        ),
                      ],
                      if (selectedMedia != null) ...[
                        const SizedBox(height: 12),
                        Stack(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey[200],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  _inferMediaType(selectedMedia!.path) ==
                                      'image'
                                  ? Image.file(
                                      File(selectedMedia!.path),
                                      fit: BoxFit.cover,
                                    )
                                  : VideoPreview.file(
                                      filePath: selectedMedia!.path,
                                      fit: BoxFit.contain,
                                      autoplay: false,
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => selectedMedia = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (scheduledTime != null) ...[
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(
                            'Scheduled: ${scheduledTime!.day}/${scheduledTime!.month}/${scheduledTime!.year} '
                            '${scheduledTime!.hour}:${scheduledTime!.minute.toString().padLeft(2, "0")}',
                          ),
                          onDeleted: () => setState(() => scheduledTime = null),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // -------- ACTIONS --------
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('Image'),
                    ),
                    TextButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_rounded),
                      label: const Text('Video'),
                    ),
                    TextButton.icon(
                      onPressed: _pickSchedule,
                      icon: const Icon(Icons.schedule_rounded),
                      label: const Text('Schedule'),
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
}
