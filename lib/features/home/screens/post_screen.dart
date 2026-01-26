import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  static String? _draftText;
  static XFile? _draftMedia;
  static DateTime? _draftSchedule;

  final TextEditingController _controller =
      TextEditingController(text: _draftText);

  XFile? selectedMedia;
  DateTime? scheduledTime;

  String? topSuccessMessage;

  bool get hasContent =>
      _controller.text.trim().isNotEmpty ||
      selectedMedia != null ||
      scheduledTime != null;

  @override
  void initState() {
    super.initState();
    selectedMedia = _draftMedia;
    scheduledTime = _draftSchedule;
  }

  void _showTopSuccess(String message) {
    setState(() => topSuccessMessage = message);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => topSuccessMessage = null);
    });
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
        content: const Text(
          'You have an unfinished post. Save it as a draft?',
        ),
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
  }

  Future<void> _postNow() async {
    _clearDraft();
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Posting…',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    Navigator.of(context).pop(); // Close loader

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 12),
            Text(
              'Posted!',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));

    Navigator.of(context).pop();
    Navigator.of(context).pop();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (topSuccessMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.green.withOpacity(0.1),
                child: Text(
                  topSuccessMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // -------- TOP BAR --------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _exitPost,
                  ),
                  TextButton(
                    onPressed: hasContent ? _postNow : null,
                    child: const Text(
                      'Post',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
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
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'What do you want to share?',
                        border: InputBorder.none,
                      ),
                    ),

                    if (selectedMedia != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[200],
                        ),
                        child: Center(
                          child: Text(
                            selectedMedia!.path.split('/').last,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
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
    );
  }
}
