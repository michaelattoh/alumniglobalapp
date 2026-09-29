import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class HiddenPostsScreen extends StatefulWidget {
  const HiddenPostsScreen({super.key});

  @override
  State<HiddenPostsScreen> createState() => _HiddenPostsScreenState();
}

class _HiddenPostsScreenState extends State<HiddenPostsScreen> {
  final ScrollController _controller = ScrollController();
  final List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHidden();
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadHidden() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    final data = await HomeApiService.fetchHiddenPosts(page: 1, perPage: 20);
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
    setState(() {
      _rows
        ..clear()
        ..addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _loading = false;
      _page = 1;
      _hasMore = _page < lastPage;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await HomeApiService.fetchHiddenPosts(
      page: nextPage,
      perPage: 20,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    setState(() {
      _rows.addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _loadingMore = false;
      _page = nextPage;
      _hasMore = _page < lastPage;
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: RefreshIndicator(
        onRefresh: _loadHidden,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 28),
                    Center(child: Text(_error!)),
                  ],
                )
              : _rows.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 28),
                    const Center(child: Text('No hidden posts')),
                  ],
                )
              : ListView.builder(
                  controller: _controller,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: _rows.length + (_loadingMore ? 1 : 0) + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _heroCard(),
                      );
                    }
                    final index = i - 1;
                    if (index >= _rows.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final post = _rows[index];
                    final user = (post['user'] as Map<String, dynamic>?) ?? {};
                    final name = (user['name'] ?? 'User').toString();
                    final content = (post['content'] ?? '').toString();
                    final createdAt = post['created_at']?.toString();
                    final postId = (post['id'] as num?)?.toInt();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (postId != null)
                                TextButton(
                                  onPressed: () async {
                                    final ok = await HomeApiService.unhidePost(
                                      postId,
                                    );
                                    if (!mounted) return;
                                    if (ok) {
                                      setState(() => _rows.removeAt(index));
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Unable to unhide'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Unhide'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timeAgo(createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(content.isEmpty ? 'Shared a post' : content),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF64748B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.visibility_off_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hidden posts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review posts you chose to hide and bring them back when they matter again.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
