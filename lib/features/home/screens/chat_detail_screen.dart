import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';
import 'chat_info_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'chat_pdf_viewer.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _loading = true;
  bool _sendingAttachment = false;
  int? _currentUserId;
  bool _peerTyping = false;
  List<int> _groupTypingUsers = [];
  Timer? _typingDebounce;
  Timer? _typingPoller;
  Timer? _typingHeartbeat;
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  bool _recordCancelled = false;
  double _dragDx = 0;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String _connectionStatus = 'unknown';
  bool _connecting = false;
  Map<String, dynamic>? _replyingTo;
  String _wallpaper = 'default';
  final Map<int, GlobalKey> _messageKeys = {};

  final List<Map<String, dynamic>> _messages = [];

  int? get _peerUserId {
    if (!widget.chatId.startsWith('user_')) return null;
    final raw = widget.chatId.substring(5);
    return int.tryParse(raw);
  }

  int? get _groupId {
    if (!widget.chatId.startsWith('group_')) return null;
    final raw = widget.chatId.substring(6);
    return int.tryParse(raw);
  }

  @override
  void initState() {
    super.initState();
    _bootstrapChat();
    _loadConnectionStatus();
    _loadWallpaper();
    _startTypingPoller();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingPoller?.cancel();
    _typingHeartbeat?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapChat() async {
    await _loadCurrentUser();
    await _loadThread();
  }

  Future<void> _loadCurrentUser() async {
    final id = await AuthSession.getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = id);
  }

  Future<void> _loadConnectionStatus() async {
    final peerId = _peerUserId;
    if (peerId == null) return;
    try {
      final data = await HomeApiService.fetchConnections(perPage: 40);
      final sent = (data['sent'] as List<Map<String, dynamic>>?) ?? [];
      final received = (data['received'] as List<Map<String, dynamic>>?) ?? [];
      String status = 'none';
      for (final row in sent) {
        final to = (row['to_user'] as Map<String, dynamic>?) ?? {};
        final id = (to['id'] as num?)?.toInt();
        if (id == peerId) {
          status = row['status']?.toString() ?? 'pending';
          break;
        }
      }
      if (status == 'none') {
        for (final row in received) {
          final from = (row['from_user'] as Map<String, dynamic>?) ?? {};
          final id = (from['id'] as num?)?.toInt();
          if (id == peerId) {
            status = row['status']?.toString() ?? 'pending';
            if (status == 'pending') {
              status = 'incoming';
            }
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() => _connectionStatus = status);
    } catch (_) {
      if (!mounted) return;
      setState(() => _connectionStatus = 'unknown');
    }
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('chat_wallpaper_${widget.chatId}');
    final remote = await HomeApiService.fetchChatWallpaper(
      chatKey: widget.chatId,
    );
    if (!mounted) return;
    setState(() {
      _wallpaper = remote ?? cached ?? 'default';
    });
    if (remote != null) {
      await prefs.setString('chat_wallpaper_${widget.chatId}', remote);
    }
  }

  Future<void> _sendConnectionRequest() async {
    if (HomeApiService.isInstitutionAccessRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HomeApiService.accessRestrictionMessage)),
      );
      return;
    }
    if (_connecting || _peerUserId == null) return;
    setState(() => _connecting = true);
    final ok = await HomeApiService.sendConnection(_peerUserId!);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      if (ok) _connectionStatus = 'pending';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Connection request sent' : 'Unable to send request',
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    final dt = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Now';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _statusLine() {
    if (widget.isGroup) {
      if (_groupTypingUsers.isNotEmpty) {
        return _groupTypingUsers.length == 1
            ? 'Someone is typing...'
            : '${_groupTypingUsers.length} people typing...';
      }
      return 'Group chat';
    }
    if (_peerTyping) {
      return 'Typing...';
    }
    switch (_connectionStatus) {
      case 'connected':
        return 'Connected';
      case 'pending':
        return 'Connection pending';
      case 'incoming':
        return 'Wants to connect';
      default:
        return 'Direct chat';
    }
  }

  Map<String, dynamic> _mapThreadMessage(Map<String, dynamic> m) {
    final sender = (m['sender'] as Map<String, dynamic>?) ?? {};
    final senderId = (sender['id'] as num?)?.toInt();
    final fromMe = _currentUserId != null
        ? senderId == _currentUserId
        : senderId == null
        ? false
        : widget.chatId != 'user_$senderId';
    final reactions =
        (m['reactions'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];
    final replyTo = m['reply_to'] is Map
        ? Map<String, dynamic>.from(m['reply_to'] as Map)
        : null;
    return {
      'id': (m['id'] as num?)?.toInt(),
      'fromMe': fromMe,
      'text': (m['body'] ?? '').toString(),
      'isEncrypted': m['is_encrypted'] == true,
      'encryptedPayload': m['encrypted_payload']?.toString(),
      'time': _formatTime(m['created_at']?.toString()),
      'senderName': (sender['name'] ?? '').toString(),
      'attachmentUrl': HomeApiService.normalizeMediaUrl(
        m['attachment_url']?.toString(),
      ),
      'attachmentType': m['attachment_type'],
      'attachmentName': m['attachment_name'],
      'attachmentSize': m['attachment_size'],
      'readAt': m['read_at'],
      'readCount': m['read_by_count'],
      'replyTo': replyTo,
      'replyToMessageId': m['reply_to_message_id'],
      'reactions': reactions,
      'status': 'sent',
    };
  }

  Future<void> _loadThread() async {
    final peerId = _peerUserId;
    final groupId = _groupId;
    if (peerId == null && groupId == null) {
      setState(() => _loading = false);
      return;
    }

    final rows = peerId != null
        ? await HomeApiService.fetchMessageThread(peerId, perPage: 80)
        : await HomeApiService.fetchGroupThread(groupId!, perPage: 80);
    if (!mounted) return;

    rows.sort((a, b) {
      final aTime =
          DateTime.tryParse((a['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          DateTime.tryParse((b['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    setState(() {
      _messages
        ..clear()
        ..addAll(rows.map(_mapThreadMessage));
      _loading = false;
    });

    Future.delayed(const Duration(milliseconds: 60), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    if (HomeApiService.isInstitutionAccessRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HomeApiService.accessRestrictionMessage)),
      );
      return;
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final peerId = _peerUserId;
    final groupId = _groupId;
    if (peerId == null && groupId == null) return;

    final tempIndex = _messages.length;
    setState(() {
      _messages.add({
        'id': null,
        'fromMe': true,
        'text': text,
        'time': 'Now',
        'senderName': '',
        'replyTo': _replyingTo,
        'replyToMessageId': _replyingTo?['id'],
        'reactions': const <Map<String, dynamic>>[],
        'status': 'sending',
      });
      _messageController.clear();
      _replyingTo = null;
    });

    final result = peerId != null
        ? await HomeApiService.sendMessage(
            userId: peerId,
            body: text,
            replyToMessageId: _messages[tempIndex]['replyToMessageId'] as int?,
          )
        : {
            'ok': await HomeApiService.sendGroupMessage(
              groupId: groupId!,
              body: text,
              replyToMessageId:
                  _messages[tempIndex]['replyToMessageId'] as int?,
            ),
          };
    final ok = result['ok'] == true;
    if (mounted) {
      setState(() {
        if (ok && result['data'] is Map<String, dynamic>) {
          _messages[tempIndex] = _mapThreadMessage(
            Map<String, dynamic>.from(result['data'] as Map<String, dynamic>),
          );
        } else {
          _messages[tempIndex]['status'] = 'failed';
        }
      });
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] != null
                ? result['message'].toString()
                : 'Failed to send message',
          ),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _startTypingPoller() {
    final peerId = _peerUserId;
    final groupId = _groupId;
    if (peerId == null && groupId == null) return;

    _typingPoller = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        if (peerId != null) {
          final typing = await HomeApiService.fetchTypingStatus(userId: peerId);
          if (mounted) setState(() => _peerTyping = typing);
        } else if (groupId != null) {
          final typingUsers = await HomeApiService.fetchGroupTypingStatus(
            groupId: groupId,
          );
          if (mounted) setState(() => _groupTypingUsers = typingUsers);
        }
      } catch (_) {
        // Ignore typing polling errors.
      }
    });
  }

  void _handleTypingChanged(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      _typingHeartbeat?.cancel();
      _typingHeartbeat = null;
      return;
    }

    Future<void> pingTyping() async {
      final peerId = _peerUserId;
      final groupId = _groupId;
      try {
        if (peerId != null) {
          await HomeApiService.sendTypingStatus(userId: peerId);
        } else if (groupId != null) {
          await HomeApiService.sendGroupTypingStatus(groupId: groupId);
        }
      } catch (_) {
        // Ignore typing send errors.
      }
    }

    _typingHeartbeat ??= Timer.periodic(const Duration(seconds: 12), (_) {
      if (_messageController.text.trim().isEmpty) {
        _typingHeartbeat?.cancel();
        _typingHeartbeat = null;
        return;
      }
      pingTyping();
    });

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 2500), () async {
      await pingTyping();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isLastOutgoing(int index) {
    for (var i = index + 1; i < _messages.length; i++) {
      if (_messages[i]['fromMe'] == true) return false;
    }
    return true;
  }

  Future<void> _sendAttachment({
    required String filePath,
    required String type,
    String? fileName,
  }) async {
    if (HomeApiService.isInstitutionAccessRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HomeApiService.accessRestrictionMessage)),
      );
      return;
    }
    if (_sendingAttachment) return;
    final peerId = _peerUserId;
    final groupId = _groupId;
    if (peerId == null && groupId == null) return;

    setState(() => _sendingAttachment = true);
    final upload = await HomeApiService.uploadMedia(
      filePath: filePath,
      fileName: fileName,
    );
    if (upload == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload failed')));
      }
      setState(() => _sendingAttachment = false);
      return;
    }

    final url = upload['url']?.toString();
    if (url == null || url.isEmpty) {
      setState(() => _sendingAttachment = false);
      return;
    }

    final tempIndex = _messages.length;
    setState(() {
      _messages.add({
        'id': null,
        'fromMe': true,
        'text': '',
        'time': 'Now',
        'senderName': '',
        'attachmentUrl': url,
        'attachmentType': type,
        'attachmentName': fileName ?? upload['name'],
        'attachmentSize': upload['size'],
        'replyTo': _replyingTo,
        'replyToMessageId': _replyingTo?['id'],
        'reactions': const <Map<String, dynamic>>[],
        'status': 'sending',
      });
      _replyingTo = null;
    });

    final result = peerId != null
        ? await HomeApiService.sendMessage(
            userId: peerId,
            body: '',
            replyToMessageId: _messages[tempIndex]['replyToMessageId'] as int?,
            attachmentUrl: url,
            attachmentType: type,
            attachmentName: fileName ?? upload['name']?.toString(),
            attachmentSize: upload['size'] is int
                ? upload['size'] as int
                : null,
          )
        : {
            'ok': await HomeApiService.sendGroupMessage(
              groupId: groupId!,
              body: '',
              replyToMessageId:
                  _messages[tempIndex]['replyToMessageId'] as int?,
              attachmentUrl: url,
              attachmentType: type,
              attachmentName: fileName ?? upload['name']?.toString(),
              attachmentSize: upload['size'] is int
                  ? upload['size'] as int
                  : null,
            ),
          };

    final ok = result['ok'] == true;
    if (mounted) {
      setState(() {
        _messages[tempIndex]['status'] = ok ? 'sent' : 'failed';
      });
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] != null
                ? result['message'].toString()
                : 'Failed to send attachment',
          ),
        ),
      );
    }

    setState(() => _sendingAttachment = false);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _saveWallpaper(String wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_wallpaper_${widget.chatId}', wallpaper);
    await HomeApiService.updateChatWallpaper(
      chatKey: widget.chatId,
      wallpaper: wallpaper,
    );
    if (!mounted) return;
    setState(() => _wallpaper = wallpaper);
  }

  GlobalKey _messageKeyFor(int? messageId) {
    if (messageId == null) {
      return GlobalKey();
    }
    return _messageKeys.putIfAbsent(messageId, GlobalKey.new);
  }

  Future<void> _scrollToMessage(int? messageId) async {
    if (messageId == null) return;
    final key = _messageKeys[messageId];
    final context = key?.currentContext;
    if (context == null) {
      _showError('Original message is not visible in this thread yet.');
      return;
    }
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  void _openWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in const [
            ('default', 'Default'),
            ('sky', 'Sky'),
            ('mint', 'Mint'),
            ('sunset', 'Sunset'),
            ('midnight', 'Midnight'),
          ])
            ListTile(
              title: Text(option.$2),
              trailing: _wallpaper == option.$1
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () async {
                Navigator.of(context).pop();
                await _saveWallpaper(option.$1);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  BoxDecoration _wallpaperDecoration() {
    switch (_wallpaper) {
      case 'sky':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2FE), Color(0xFFBFDBFE)],
          ),
        );
      case 'mint':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          ),
        );
      case 'sunset':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEDD5), Color(0xFFFECDD3)],
          ),
        );
      case 'midnight':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        );
      default:
        return const BoxDecoration(color: Colors.white);
    }
  }

  void _setReplyingTo(Map<String, dynamic> message) {
    setState(() => _replyingTo = message);
  }

  String _replySnippet(Map<String, dynamic>? message) {
    if (message == null) return '';
    final body = (message['text'] ?? '').toString().trim();
    if (body.isNotEmpty) return body;
    final attachmentType = message['attachmentType']?.toString();
    if (attachmentType == 'image') return 'Photo';
    if (attachmentType == 'video') return 'Video';
    if (attachmentType == 'audio') return 'Voice note';
    if (attachmentType != null && attachmentType.isNotEmpty) {
      return 'Attachment';
    }
    return 'Message';
  }

  List<Map<String, dynamic>> _groupedReactions(
    List<Map<String, dynamic>> reactions,
  ) {
    final currentUserId = _currentUserId;
    final grouped = <String, Map<String, dynamic>>{};
    for (final reaction in reactions) {
      final emoji = reaction['emoji']?.toString() ?? '';
      if (emoji.isEmpty) continue;
      final entry = grouped.putIfAbsent(
        emoji,
        () => {'emoji': emoji, 'count': 0, 'mine': false},
      );
      entry['count'] = ((entry['count'] as int?) ?? 0) + 1;
      if (reaction['user_id'] == currentUserId) {
        entry['mine'] = true;
      }
    }
    return grouped.values.toList();
  }

  Future<void> _reactToMessage(
    Map<String, dynamic> message,
    String emoji,
  ) async {
    final messageId = message['id'] as int?;
    if (messageId == null) return;
    final ok = widget.isGroup
        ? await HomeApiService.reactToGroupMessage(
            messageId: messageId,
            emoji: emoji,
          )
        : await HomeApiService.reactToDirectMessage(
            messageId: messageId,
            emoji: emoji,
          );
    if (!mounted) return;
    if (!ok) {
      _showError('Unable to react right now.');
      return;
    }
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    final updated =
        ((message['reactions'] as List?) ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) => entry['user_id'] != currentUserId)
            .toList()
          ..add({
            'id': null,
            'emoji': emoji,
            'user_id': currentUserId,
            'user_name': 'You',
          });
    setState(() => message['reactions'] = updated);
  }

  void _openReactionPicker(Map<String, dynamic> message) {
    final messageText = (message['text'] ?? '').toString().trim();
    final copyValue = messageText.isNotEmpty
        ? messageText
        : _replySnippet(message);
    final canCopy = copyValue.isNotEmpty && copyValue != 'Message';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '🔥', '👏', '😮'].map((emoji) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _reactToMessage(message, emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
              if (canCopy) ...[
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: const Text('Copy message'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: copyValue));
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final picker = ImagePicker();
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (file != null) {
                  await _sendAttachment(
                    filePath: file.path,
                    fileName: file.name,
                    type: 'image',
                  );
                }
              } catch (_) {
                _showError('Unable to attach image right now.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_rounded),
            title: const Text('Video'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final picker = ImagePicker();
                final file = await picker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (file != null) {
                  await _sendAttachment(
                    filePath: file.path,
                    fileName: file.name,
                    type: 'video',
                  );
                }
              } catch (_) {
                _showError('Unable to attach video right now.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: const Text('Document'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final result = await FilePicker.platform.pickFiles();
                final file = result?.files.single;
                if (file != null && file.path != null) {
                  await _sendAttachment(
                    filePath: file.path!,
                    fileName: file.name,
                    type: 'document',
                  );
                }
              } catch (_) {
                _showError('Unable to attach document right now.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.audiotrack_rounded),
            title: const Text('Audio'),
            onTap: () async {
              Navigator.pop(context);
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                  allowMultiple: false,
                );
                final file = result?.files.single;
                if (file != null && file.path != null) {
                  await _sendAttachment(
                    filePath: file.path!,
                    fileName: file.name,
                    type: 'audio',
                  );
                }
              } catch (_) {
                _showError('Unable to attach audio right now.');
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _beginRecording() async {
    if (_recording) return;
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showError('Microphone permission is required for voice notes.');
      return;
    }
    setState(() {
      _recording = true;
      _recordCancelled = false;
      _dragDx = 0;
      _recordSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _recording) {
        setState(() => _recordSeconds += 1);
      }
    });
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );
    } catch (_) {
      _recordTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordCancelled = false;
        _dragDx = 0;
        _recordSeconds = 0;
      });
      _showError('Unable to start recording right now.');
    }
  }

  Future<void> _startRecording(LongPressStartDetails details) async {
    await _beginRecording();
  }

  void _updateRecording(LongPressMoveUpdateDetails details) {
    if (!_recording) return;
    setState(() {
      _dragDx = details.offsetFromOrigin.dx;
      _recordCancelled = _dragDx < -80;
    });
  }

  Future<void> _stopRecording(LongPressEndDetails details) async {
    if (!_recording) return;
    final path = await _recorder.stop();
    final cancelled = _recordCancelled;
    _recordTimer?.cancel();
    setState(() {
      _recording = false;
      _recordCancelled = false;
      _dragDx = 0;
    });
    if (cancelled || path == null) {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      return;
    }
    await _sendAttachment(
      filePath: path,
      fileName: 'voice_note.m4a',
      type: 'audio',
    );
  }

  Future<void> _cancelRecording() async {
    if (!_recording) return;
    final path = await _recorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _recording = false;
      _recordCancelled = false;
      _dragDx = 0;
      _recordSeconds = 0;
    });
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _finishRecordingAndSend() async {
    if (!_recording) return;
    final path = await _recorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _recording = false;
      _recordCancelled = false;
      _dragDx = 0;
    });
    if (path == null) return;
    await _sendAttachment(
      filePath: path,
      fileName: 'voice_note.m4a',
      type: 'audio',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatId.isEmpty || widget.chatName.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Invalid chat')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      /// TOP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: GestureDetector(
          onTap: _openChatInfo,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isGroup
                        ? const [Color(0xFF8B5CF6), Color(0xFF4F46E5)]
                        : const [Color(0xFF38BDF8), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.chatName.isNotEmpty
                      ? widget.chatName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      _statusLine(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!widget.isGroup && _peerUserId != null) ...[
            if (_connectionStatus == 'none')
              TextButton(
                onPressed: _connecting ? null : _sendConnectionRequest,
                child: Text(_connecting ? 'Connecting...' : 'Connect'),
              )
            else if (_connectionStatus == 'pending')
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip(label: Text('Pending')),
              )
            else if (_connectionStatus == 'incoming')
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip(label: Text('Incoming')),
              ),
          ],
          IconButton(
            icon: const Icon(Icons.wallpaper_rounded, color: Colors.black),
            onPressed: _openWallpaperPicker,
          ),
        ],
      ),

      /// BODY
      body: Container(
        decoration: _wallpaperDecoration(),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadThread,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (_, index) {
                          final msg = _messages[index];
                          final fromMe = msg['fromMe'] as bool;
                          final attachmentUrl = msg['attachmentUrl']
                              ?.toString();
                          final attachmentType = msg['attachmentType']
                              ?.toString();
                          final attachmentName = msg['attachmentName']
                              ?.toString();
                          final isEncrypted = msg['isEncrypted'] == true;
                          final readAt = msg['readAt']?.toString();
                          final readCount = msg['readCount'];
                          final status = msg['status']?.toString();
                          final showRead =
                              fromMe &&
                              !widget.isGroup &&
                              _isLastOutgoing(index);
                          final showGroupRead =
                              fromMe &&
                              widget.isGroup &&
                              _isLastOutgoing(index);
                          final replyTo =
                              msg['replyTo'] as Map<String, dynamic>?;
                          final reactions =
                              ((msg['reactions'] as List?) ?? const [])
                                  .whereType<Map>()
                                  .map(
                                    (entry) => Map<String, dynamic>.from(entry),
                                  )
                                  .toList();
                          final groupedReactions = _groupedReactions(reactions);

                          return GestureDetector(
                            onLongPress: () => _openReactionPicker(msg),
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if ((!fromMe && velocity > 120) ||
                                  (fromMe && velocity < -120)) {
                                _setReplyingTo(msg);
                              }
                            },
                            child: Align(
                              key: _messageKeyFor(msg['id'] as int?),
                              alignment: fromMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                decoration: BoxDecoration(
                                  color: fromMe
                                      ? const Color(0xFF2563EB)
                                      : Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    if (!fromMe)
                                      const BoxShadow(
                                        color: Color(0x0F0F172A),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.isGroup &&
                                        !fromMe &&
                                        (msg['senderName'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          (msg['senderName'] ?? '').toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: fromMe
                                                ? Colors.white70
                                                : Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    if (replyTo != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: fromMe
                                              ? Colors.white12
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: fromMe
                                                  ? Colors.white70
                                                  : const Color(0xFF2563EB),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () => _scrollToMessage(
                                            (replyTo['id'] as num?)?.toInt(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ((replyTo['sender']
                                                            as Map?)?['name'] ??
                                                        'Reply')
                                                    .toString(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: fromMe
                                                      ? Colors.white70
                                                      : const Color(0xFF2563EB),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _replySnippet({
                                                  'text': replyTo['body'],
                                                  'attachmentType':
                                                      replyTo['attachment_type'],
                                                }),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: fromMe
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (attachmentUrl != null &&
                                        attachmentUrl.isNotEmpty)
                                      _AttachmentBubble(
                                        url: attachmentUrl,
                                        type: attachmentType ?? 'document',
                                        name: attachmentName,
                                        fromMe: fromMe,
                                      )
                                    else if (isEncrypted)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_rounded,
                                            size: 14,
                                            color: fromMe
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Encrypted message',
                                            style: TextStyle(
                                              color: fromMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        msg['text'],
                                        style: TextStyle(
                                          color: fromMe
                                              ? Colors.white
                                              : Colors.black87,
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
                                    if (status == 'failed')
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Failed',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      )
                                    else if (showRead)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.done_all_rounded,
                                              size: 14,
                                              color:
                                                  readAt != null &&
                                                      readAt.isNotEmpty
                                                  ? const Color(0xFF60A5FA)
                                                  : (fromMe
                                                        ? Colors.white70
                                                        : Colors.grey[600]),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              readAt != null &&
                                                      readAt.isNotEmpty
                                                  ? 'Seen ${_formatTime(readAt)}'
                                                  : 'Sent',
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
                                    if (showGroupRead && status != 'failed')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          (readCount is int && readCount > 0)
                                              ? 'Seen by $readCount'
                                              : 'Sent',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: fromMe
                                                ? Colors.white70
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    if (groupedReactions.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: groupedReactions.map((
                                            reaction,
                                          ) {
                                            final mine =
                                                reaction['mine'] == true;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: mine
                                                    ? (fromMe
                                                          ? Colors.white24
                                                          : const Color(
                                                              0xFFDBEAFE,
                                                            ))
                                                    : (fromMe
                                                          ? Colors.white12
                                                          : Colors.black
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                )),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${reaction['emoji'] ?? ''} ${reaction['count'] ?? 1}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            /// INPUT BAR
            if (_recording)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.black87,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _cancelRecording,
                      tooltip: 'Cancel',
                    ),
                    const SizedBox(width: 8),
                    _WaveformBars(seed: _recordSeconds),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording ${_recordSeconds}s',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _finishRecordingAndSend,
                      tooltip: 'Send voice note',
                    ),
                  ],
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Replying to message',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _replySnippet(_replyingTo),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () =>
                                  setState(() => _replyingTo = null),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            onPressed: _openAttachMenu,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onChanged: _handleTypingChanged,
                              decoration: InputDecoration(
                                hintText: 'Message',
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.92),
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
                          GestureDetector(
                            onTap: () async {
                              if (_recording) {
                                await _finishRecordingAndSend();
                              } else {
                                await _beginRecording();
                              }
                            },
                            onLongPressStart: _startRecording,
                            onLongPressMoveUpdate: _updateRecording,
                            onLongPressEnd: _stopRecording,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _recording
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _recording ? Icons.mic : Icons.mic_none_rounded,
                                color: _recording
                                    ? Colors.redAccent
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded),
                            onPressed: _sendingAttachment ? null : _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentBubble extends StatelessWidget {
  final String url;
  final String type;
  final String? name;
  final bool fromMe;

  const _AttachmentBubble({
    required this.url,
    required this.type,
    required this.fromMe,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'audio') {
      return _AudioAttachmentBubble(url: url, name: name, fromMe: fromMe);
    }

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 180,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 180,
            height: 140,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (url.toLowerCase().endsWith('.pdf')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatPdfViewer(title: name ?? 'Document', url: url),
            ),
          );
          return;
        }
        final uri = Uri.tryParse(url);
        if (uri == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid attachment URL')),
          );
          return;
        }
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open this attachment')),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: fromMe ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name ?? 'Attachment',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fromMe ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioAttachmentBubble extends StatefulWidget {
  final String url;
  final String? name;
  final bool fromMe;

  const _AudioAttachmentBubble({
    required this.url,
    required this.fromMe,
    this.name,
  });

  @override
  State<_AudioAttachmentBubble> createState() => _AudioAttachmentBubbleState();
}

class _AudioAttachmentBubbleState extends State<_AudioAttachmentBubble> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
        }
      });
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted && _controller.value.isPlaying) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller.value.isPlaying;
    final duration = _ready ? _controller.value.duration : null;
    final label = widget.name ?? 'Voice note';
    final position = _ready ? _controller.value.position : Duration.zero;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: widget.fromMe ? Colors.white : Colors.black87,
          ),
          onPressed: !_ready
              ? null
              : () {
                  if (isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                  setState(() {});
                },
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.fromMe ? Colors.white : Colors.black87,
                ),
              ),
              if (duration != null)
                _PlaybackWaveform(
                  progress: duration.inMilliseconds == 0
                      ? 0
                      : (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0, 1),
                  activeColor: widget.fromMe ? Colors.white : Colors.black87,
                  inactiveColor: widget.fromMe
                      ? Colors.white38
                      : Colors.black26,
                ),
              if (duration != null)
                Text(
                  '${duration.inSeconds}s',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.fromMe ? Colors.white70 : Colors.black54,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackWaveform extends StatelessWidget {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _PlaybackWaveform({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    const bars = 16;
    final activeBars = (bars * progress).round();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: List.generate(bars, (index) {
          final height = 6 + (index % 5) * 3;
          return Container(
            margin: const EdgeInsets.only(right: 2),
            width: 3,
            height: height.toDouble(),
            decoration: BoxDecoration(
              color: index <= activeBars ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _WaveformBars extends StatelessWidget {
  final int seed;

  const _WaveformBars({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(8, (index) {
        final base = 6 + (index * 3 + seed) % 10;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 3,
          height: base.toDouble(),
          decoration: BoxDecoration(
            color: Colors.white70,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
