import 'package:flutter/material.dart';
import 'chat_info_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isGroup,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'fromMe': false,
      'text': 'Hey, good to connect with you!',
      'time': '09:12',
    },
    {
      'fromMe': true,
      'text': 'Likewise! How’s everything going?',
      'time': '09:13',
    },
    {
      'fromMe': false,
      'text': 'All good. Let’s catch up soon.',
      'time': '09:14',
    },
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'fromMe': true,
        'text': text,
        'time': 'Now',
      });
      _messageController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _openChatInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          chatId: widget.chatId,
          chatName: widget.chatName,
          isGroup: widget.isGroup,
        ),
      ),
    );
  }

  void _openAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ListTile(
            leading: Icon(Icons.image),
            title: Text('Image'),
          ),
          ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text('Document'),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatId.isEmpty || widget.chatName.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('Invalid chat'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,

      /// TOP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: GestureDetector(
          onTap: _openChatInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chatName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              if (widget.isGroup)
                const Text(
                  'Group chat',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),

      /// BODY
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                final msg = _messages[index];
                final fromMe = msg['fromMe'] as bool;

                return Align(
                  alignment:
                      fromMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: fromMe
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'],
                          style: TextStyle(
                            color: fromMe ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'],
                          style: TextStyle(
                            fontSize: 10,
                            color: fromMe
                                ? Colors.white70
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /// INPUT BAR
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _openAttachMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_none_rounded),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}