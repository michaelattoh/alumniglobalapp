import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class ScheduledPostsScreen extends StatefulWidget {
  const ScheduledPostsScreen({super.key});

  @override
  State<ScheduledPostsScreen> createState() => _ScheduledPostsScreenState();
}

class _ScheduledPostsScreenState extends State<ScheduledPostsScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final List<Map<String, dynamic>> _rows = [];
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 150) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page = 1;
      _hasMore = true;
    });
    final res = await HomeApiService.fetchScheduledPosts(page: 1, perPage: 20);
    final meta = res['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
    if (!mounted) return;
    setState(() {
      _rows
        ..clear()
        ..addAll((res['data'] as List<Map<String, dynamic>>?) ?? []);
      _loading = false;
      _page = 1;
      _hasMore = _page < lastPage;
    });
  }

  Future<void> _loadMore() async {
    final nextPage = _page + 1;
    setState(() => _loadingMore = true);
    final res = await HomeApiService.fetchScheduledPosts(
      page: nextPage,
      perPage: 20,
    );
    final meta = res['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    if (!mounted) return;
    setState(() {
      _rows.addAll((res['data'] as List<Map<String, dynamic>>?) ?? []);
      _page = nextPage;
      _hasMore = _page < lastPage;
      _loadingMore = false;
    });
  }

  String _formatDate(String? iso) {
    final dt = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _publishNow(int postId) async {
    final ok = await HomeApiService.publishScheduledPost(postId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to publish post')));
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post published')));
  }

  Future<void> _deletePost(int postId) async {
    final response = await HomeApiService.deletePost(postId);
    if (!mounted) return;
    if (!response) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete post')));
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SafeArea(
                child: ListView(
                  controller: _controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 18),
                    if (_rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('No scheduled posts')),
                      )
                    else
                      ..._rows.map((row) {
                        final content = (row['content'] ?? 'Scheduled post')
                            .toString();
                        final scheduledAt = _formatDate(
                          row['scheduled_at']?.toString(),
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Scheduled: $scheduledAt',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _publishNow((row['id'] as num).toInt()),
                                    child: const Text('Publish now'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _deletePost((row['id'] as num).toInt()),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    if (_loadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
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
          colors: [Color(0xFF0F172A), Color(0xFF4338CA)],
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
            child: const Icon(Icons.schedule_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scheduled posts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review what is queued, publish it now, or delete it before it goes live.',
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
