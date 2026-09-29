import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_global_app/core/config/api_config.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/features/home/widgets/mention_suggestion_box.dart';
import 'package:alumni_global_app/features/home/widgets/video_preview.dart';
import 'chat_media_viewer.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final Map<String, dynamic>? initialPost;

  const PostDetailScreen({super.key, required this.postId, this.initialPost});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _sending = false;
  bool _saving = false;
  bool _isSaved = false;
  int _reactionCount = 0;
  int _commentCount = 0;
  bool _reporting = false;
  bool _muting = false;
  bool _hiding = false;
  Map<String, dynamic>? _replyingToComment;
  final TextEditingController _commentCtrl = TextEditingController();
  int? _resolvedPostId;
  bool _loadErrorShown = false;
  bool _refreshing = false;
  List<Map<String, dynamic>> _mentionableUsers = [];
  List<Map<String, dynamic>> _commentMentionSuggestions = [];
  final Map<int, String> _mentionedCommentUsers = {};
  _DetailReaction _selectedReaction = _DetailReaction.none;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
    }
    final initialId = widget.postId > 0
        ? widget.postId
        : _asInt(widget.initialPost?['id']);
    _resolvedPostId = initialId;
    final cached = initialId != null
        ? HomeApiService.getCachedPost(initialId)
        : null;
    if (cached != null) {
      _post = cached;
      final counts = Map<String, dynamic>.from(
        (cached['counts'] as Map?) ?? const {},
      );
      _reactionCount = _asInt(counts['reactions']) ?? 0;
      _commentCount = _asInt(counts['comments']) ?? 0;
      _isSaved = cached['is_saved'] == true;
      _selectedReaction = _reactionFromState(
        cached['user_reaction']?.toString(),
        cached['is_liked'] == true,
      );
      _loading = false;
    }
    _commentCtrl.addListener(_handleCommentChanged);
    _loadMentionableUsers();
    _loadPost();
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_handleCommentChanged);
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMentionableUsers() async {
    final users = await HomeApiService.fetchMentionableUsers();
    if (!mounted) return;
    setState(() {
      _mentionableUsers = users;
      _refreshCommentMentionSuggestions();
    });
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _loadPost() async {
    final postId = _resolvedPostId;
    if (postId == null || postId <= 0) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    if (_post != null) {
      setState(() => _refreshing = true);
    } else {
      setState(() => _loading = true);
    }
    try {
      Future<T> safe<T>(Future<T> future, T fallback) async {
        try {
          return await future;
        } catch (_) {
          return fallback;
        }
      }

      final post = await safe<Map<String, dynamic>?>(
        HomeApiService.fetchPost(postId),
        _post,
      );
      final comments = await safe(
        HomeApiService.fetchPostComments(postId, perPage: 50),
        _comments,
      );
      if (!mounted) return;
      setState(() {
        _post = post ?? _post;
        _comments = comments;
        _isSaved = post?['is_saved'] == true;
        _selectedReaction = _reactionFromState(
          post?['user_reaction']?.toString(),
          post?['is_liked'] == true,
        );
        final counts = Map<String, dynamic>.from(
          (post?['counts'] as Map?) ?? const {},
        );
        _reactionCount = _asInt(counts['reactions']) ?? _reactionCount;
        _commentCount = _asInt(counts['comments']) ?? _commentCount;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      if (!_loadErrorShown) {
        _loadErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t refresh post — showing cached content.'),
          ),
        );
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty || _sending) return;
    final postId = _resolvedPostId;
    if (postId == null) return;
    final replyTarget = _replyingToComment;
    setState(() => _sending = true);
    final ok = await HomeApiService.addPostComment(
      postId,
      content,
      parentId: _asInt(replyTarget?['id']),
      mentions: _selectedCommentMentionIds(),
    );
    if (!mounted) return;
    if (ok) {
      _commentCtrl.clear();
      _commentCount += 1;
      _replyingToComment = null;
      _mentionedCommentUsers.clear();
      _commentMentionSuggestions = [];
      HomeApiService.updateCachedPostState(postId, commentCount: _commentCount);
      await _loadPost();
    }
    setState(() => _sending = false);
  }

  void _handleCommentChanged() {
    _mentionedCommentUsers.removeWhere(
      (_, name) => !_commentCtrl.text.contains('@$name'),
    );
    _refreshCommentMentionSuggestions();
  }

  void _refreshCommentMentionSuggestions() {
    final selection = _commentCtrl.selection;
    final cursor = selection.baseOffset >= 0
        ? selection.baseOffset
        : _commentCtrl.text.length;
    final prefix = _commentCtrl.text.substring(0, cursor);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) {
      if (_commentMentionSuggestions.isNotEmpty) {
        setState(() => _commentMentionSuggestions = []);
      }
      return;
    }
    final query = (match.group(1) ?? '').trim().toLowerCase();
    final suggestions = _mentionableUsers
        .where((user) {
          final name = (user['name'] ?? '').toString().trim();
          if (name.isEmpty) return false;
          final userId = _asInt(user['id']);
          if (userId != null && _mentionedCommentUsers.containsKey(userId)) {
            return false;
          }
          if (query.isEmpty) return true;
          final lowered = name.toLowerCase();
          return lowered.startsWith(query) || lowered.contains(query);
        })
        .take(6)
        .toList();
    setState(() => _commentMentionSuggestions = suggestions);
  }

  void _insertCommentMention(Map<String, dynamic> user) {
    final userId = _asInt(user['id']);
    final name = (user['name'] ?? '').toString().trim();
    if (userId == null || name.isEmpty) return;
    final selection = _commentCtrl.selection;
    final cursor = selection.baseOffset >= 0
        ? selection.baseOffset
        : _commentCtrl.text.length;
    final prefix = _commentCtrl.text.substring(0, cursor);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(prefix);
    if (match == null) return;
    final mentionStart = match.start + (prefix[match.start] == ' ' ? 1 : 0);
    final replacement = '@$name ';
    final nextText =
        _commentCtrl.text.substring(0, mentionStart) +
        replacement +
        _commentCtrl.text.substring(cursor);
    _commentCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: mentionStart + replacement.length,
      ),
    );
    _mentionedCommentUsers[userId] = name;
    setState(() => _commentMentionSuggestions = []);
  }

  List<int> _selectedCommentMentionIds() {
    final text = _commentCtrl.text;
    return _mentionedCommentUsers.entries
        .where((entry) => text.contains('@${entry.value}'))
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    final postId = _resolvedPostId;
    if (postId == null) return;
    setState(() => _saving = true);
    final ok = _isSaved
        ? await HomeApiService.unsavePost(postId)
        : await HomeApiService.savePost(postId);
    if (!mounted) return;
    if (ok) {
      setState(() => _isSaved = !_isSaved);
      HomeApiService.updateCachedPostState(postId, isSaved: _isSaved);
    }
    setState(() => _saving = false);
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final postId = _resolvedPostId;
    if (postId == null) return;
    final wasLiked = _liked;
    final response = wasLiked
        ? await HomeApiService.unlikePost(postId)
        : await HomeApiService.reactToPost(postId, type: 'like');
    if (!mounted) return;
    if (response != null) {
      final counts = (response['counts'] as Map?) ?? const {};
      setState(() {
        _selectedReaction = _reactionFromState(
          response['user_reaction']?.toString(),
          response['is_liked'] == true,
        );
        _reactionCount = _asInt(counts['reactions']) ?? _reactionCount;
      });
      HomeApiService.updateCachedPostState(
        postId,
        isLiked: response['is_liked'] == true,
        reactionType: response['user_reaction']?.toString(),
        reactionCount: _reactionCount,
      );
    }
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final commentId = _asInt(comment['id']);
    if (commentId == null) return;
    final wasLiked = comment['is_liked'] == true;
    final response = wasLiked
        ? await HomeApiService.unlikePostComment(commentId)
        : await HomeApiService.likePostComment(commentId);
    if (!mounted || response == null) return;
    setState(() {
      _comments = _comments.map((row) {
        if (_asInt(row['id']) == commentId) {
          final updated = Map<String, dynamic>.from(row)..addAll(response);
          return updated;
        }
        return row;
      }).toList();
    });
  }

  bool get _liked => _selectedReaction != _DetailReaction.none;

  _DetailReaction _reactionFromState(String? type, bool isLiked) {
    final parsed = _reactionFromType(type);
    if (parsed != _DetailReaction.none) return parsed;
    return isLiked ? _DetailReaction.like : _DetailReaction.none;
  }

  _DetailReaction _reactionFromType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'heart':
        return _DetailReaction.heart;
      case 'clap':
        return _DetailReaction.clap;
      case 'fire':
        return _DetailReaction.fire;
      case 'idea':
        return _DetailReaction.idea;
      case 'like':
        return _DetailReaction.like;
      default:
        return _DetailReaction.none;
    }
  }

  Future<void> _sharePost() async {
    final postId = _resolvedPostId ?? widget.postId;
    final url = '${ApiConfig.baseUrl}/posts/$postId';
    await Clipboard.setData(ClipboardData(text: url));
    await HomeApiService.sharePost(postId, channel: 'copy_link');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  void _reportPost() {
    if (_reporting) return;
    final postId = _resolvedPostId;
    if (postId == null) return;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report post'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Tell us why (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _reporting = true);
              final ok = await HomeApiService.reportPost(
                postId,
                reason: controller.text.trim().isEmpty
                    ? null
                    : controller.text.trim(),
              );
              if (!mounted) return;
              setState(() => _reporting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Report submitted' : 'Report failed'),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHide() async {
    if (_hiding) return;
    final postId = _resolvedPostId;
    if (postId == null) return;
    setState(() => _hiding = true);
    final ok = await HomeApiService.hidePost(postId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post hidden'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              HomeApiService.unhidePost(widget.postId);
            },
          ),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to hide post')));
    }
    setState(() => _hiding = false);
  }

  Future<void> _toggleMute() async {
    if (_muting) return;
    final user = (_post?['user'] as Map<String, dynamic>?) ?? {};
    final userId = _asInt(user['id']);
    if (userId == null) return;
    setState(() => _muting = true);
    final ok = await HomeApiService.muteUser(userId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User muted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              HomeApiService.unmuteUser(userId);
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to mute')));
    }
    setState(() => _muting = false);
  }

  String _timeAgo(String? iso) {
    if (iso == null) return 'now';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.of(context).viewInsets.bottom,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadPost,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPost,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _post == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('Post not found')),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        if (_refreshing)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Refreshing…',
                                  style: TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _PostHeader(post: _post!),
                        const SizedBox(height: 10),
                        Text(
                          (_post?['content'] ?? 'Shared a post').toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PostMediaGallery(media: _asMapList(_post?['media'])),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '$_reactionCount likes',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$_commentCount comments',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _saving ? null : _toggleSave,
                              child: Text(_isSaved ? 'Unsave' : 'Save'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: _toggleLike,
                              icon: Icon(
                                _liked
                                    ? Icons.thumb_up_alt_rounded
                                    : Icons.thumb_up_alt_outlined,
                                size: 18,
                              ),
                              label: Text(_liked ? 'Liked' : 'Like'),
                            ),
                            TextButton.icon(
                              onPressed: () => _commentCtrl.text.isNotEmpty
                                  ? _sendComment()
                                  : null,
                              icon: const Icon(
                                Icons.mode_comment_outlined,
                                size: 18,
                              ),
                              label: const Text('Comment'),
                            ),
                            TextButton.icon(
                              onPressed: _sharePost,
                              icon: const Icon(Icons.share_outlined, size: 18),
                              label: const Text('Share'),
                            ),
                            TextButton.icon(
                              onPressed: _reporting ? null : _reportPost,
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: const Text('Report'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: _hiding ? null : _toggleHide,
                              icon: const Icon(
                                Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              label: const Text('Hide'),
                            ),
                            TextButton.icon(
                              onPressed: _muting ? null : _toggleMute,
                              icon: const Icon(
                                Icons.volume_off_outlined,
                                size: 18,
                              ),
                              label: const Text('Mute user'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Comments', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_comments.isEmpty)
                          Text(
                            'No comments yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ..._comments.map((c) {
                          final user =
                              (c['user'] as Map<String, dynamic>?) ?? {};
                          final name = (user['name'] ?? 'User').toString();
                          final avatarUrl = HomeApiService.normalizeMediaUrl(
                            user['avatar_url']?.toString(),
                          );
                          final createdAt = c['created_at']?.toString();
                          final parentId = _asInt(c['parent_id']);
                          final parentComment = parentId == null
                              ? null
                              : _comments
                                    .cast<Map<String, dynamic>?>()
                                    .firstWhere(
                                      (row) => _asInt(row?['id']) == parentId,
                                      orElse: () => null,
                                    );
                          final replyName =
                              ((parentComment?['user']
                                          as Map<String, dynamic>?)?['name'] ??
                                      '')
                                  .toString();
                          return Dismissible(
                            key: ValueKey(
                              'detail_comment_${widget.postId}_${c['id']}',
                            ),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (_) async {
                              setState(() => _replyingToComment = c);
                              _commentCtrl.text = '@$name ';
                              _commentCtrl
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: _commentCtrl.text.length),
                              );
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 12),
                              child: const Icon(
                                Icons.reply_rounded,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: parentId == null ? 0 : 18,
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  backgroundImage:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                      ? null
                                      : const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF4B5563),
                                        ),
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name),
                                    if (replyName.isNotEmpty)
                                      Text(
                                        'Replying to $replyName',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF2563EB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(c['content']?.toString() ?? ''),
                                trailing: Builder(
                                  builder: (_) {
                                    final counts =
                                        (c['counts'] as Map?) ?? const {};
                                    final likeCount =
                                        _asInt(counts['likes']) ?? 0;
                                    final isLiked = c['is_liked'] == true;
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _timeAgo(createdAt),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          onTap: () => _toggleCommentLike(c),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isLiked
                                                      ? Icons.favorite_rounded
                                                      : Icons
                                                            .favorite_border_rounded,
                                                  size: 16,
                                                  color: isLiked
                                                      ? const Color(0xFFEF4444)
                                                      : theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                                if (likeCount > 0) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$likeCount',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16 + keyboardInset,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_replyingToComment != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Replying to ${(((_replyingToComment!['user'] as Map<String, dynamic>?)?['name']) ?? 'comment').toString()}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: const Color(
                                                    0xFF1D4ED8,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            setState(
                                              () => _replyingToComment = null,
                                            );
                                            _commentCtrl.clear();
                                          },
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_commentMentionSuggestions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: MentionSuggestionBox(
                                      users: _commentMentionSuggestions,
                                      onSelected: _insertCommentMention,
                                    ),
                                  ),
                                TextField(
                                  controller: _commentCtrl,
                                  scrollPadding: EdgeInsets.only(
                                    bottom: keyboardInset + 24,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _replyingToComment == null
                                        ? 'Add a comment…'
                                        : 'Write a reply…',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sending ? null : _sendComment,
                            icon: _sending
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )
                                : const Icon(Icons.send_rounded),
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

enum _DetailReaction { none, like, clap, fire, heart, idea }

class _PostHeader extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostHeader({required this.post});

  static int? _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = (post['user'] as Map<String, dynamic>?) ?? {};
    final name = (user['name'] ?? 'User').toString();
    final avatarUrl = HomeApiService.normalizeMediaUrl(
      user['avatar_url']?.toString(),
    );
    final createdAt = post['created_at']?.toString();
    String timeAgo(String? iso) {
      if (iso == null) return 'now';
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return 'now';
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      return '${diff.inDays}d';
    }

    final userId = _parseInt(user['id']);
    return InkWell(
      onTap: userId == null
          ? null
          : () => Navigator.of(
              context,
            ).pushNamed('/user-profile', arguments: {'id': userId}),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? null
                : const Icon(Icons.person_rounded, color: Color(0xFF4B5563)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                timeAgo(createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostMediaGallery extends StatelessWidget {
  final List<Map<String, dynamic>> media;

  const _PostMediaGallery({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final items = media
        .map(
          (m) => {
            'type': (m['type'] ?? 'image').toString(),
            'thumbnail':
                HomeApiService.normalizeMediaUrl(
                  (m['thumbnail_url'] ?? '').toString(),
                ) ??
                '',
            'url':
                HomeApiService.normalizeMediaUrl((m['url'] ?? '').toString()) ??
                '',
          },
        )
        .where((m) => (m['url'] ?? '').toString().isNotEmpty)
        .toList()
        .cast<Map<String, String>>();

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          final url = item['url'] ?? '';
          final thumbnail = item['thumbnail'] ?? '';
          final type = (item['type'] ?? 'image').toString().toLowerCase();
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatMediaViewer(
                    media: items
                        .map(
                          (entry) => {
                            'type': entry['type'] ?? 'image',
                            'url': entry['url'] ?? '',
                          },
                        )
                        .toList(),
                    initialIndex: i,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: type.startsWith('video')
                  ? SizedBox(
                      width: 280,
                      child: ColoredBox(
                        color: Colors.black,
                        child: thumbnail.isNotEmpty
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    thumbnail,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        VideoPreview.network(
                                          url: url,
                                          fit: BoxFit.contain,
                                          autoplay: false,
                                          tapToToggle: false,
                                        ),
                                  ),
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
                              )
                            : VideoPreview.network(
                                url: url,
                                fit: BoxFit.contain,
                                autoplay: false,
                                tapToToggle: false,
                              ),
                      ),
                    )
                  : Image.network(
                      url,
                      width: 280,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 280,
                        height: 200,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
