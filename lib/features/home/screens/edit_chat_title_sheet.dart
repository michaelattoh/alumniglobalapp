import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class EditChatTitleSheet extends StatefulWidget {
  final String initialTitle;
  final int groupId;

  const EditChatTitleSheet({
    super.key,
    required this.initialTitle,
    required this.groupId,
  });

  @override
  State<EditChatTitleSheet> createState() => _EditChatTitleSheetState();
}

class _EditChatTitleSheetState extends State<EditChatTitleSheet> {
  late TextEditingController controller;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialTitle);
  }

  Future<void> _save() async {
    final nextTitle = controller.text.trim();
    if (nextTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    setState(() => saving = true);
    final updated = await HomeApiService.updateGroupChat(
      groupId: widget.groupId,
      name: nextTitle,
    );

    if (!mounted) return;

    setState(() => saving = false);

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update chat title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat title updated successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, nextTitle);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Chat title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
