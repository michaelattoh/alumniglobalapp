import 'package:flutter/material.dart';

class EditChatTitleSheet extends StatefulWidget {
  final String initialTitle;

  const EditChatTitleSheet({
    super.key,
    required this.initialTitle,
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
    setState(() => saving = true);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat title updated successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
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