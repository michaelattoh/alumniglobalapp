import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _graduationYearCtrl = TextEditingController();
  final TextEditingController _industryCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int? _viewerId;
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _schoolResults = [];
  String _mode = 'alumni';
  final Set<int> _sendingConnectionIds = <int>{};
  final Set<int> _sentConnectionIds = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadViewer();
  }

  Future<void> _loadViewer() async {
    final me = await HomeApiService.fetchMe();
    if (!mounted) return;
    setState(() => _viewerId = (me?['id'] as num?)?.toInt());
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    final hasFilters =
        _graduationYear != null || _industryCtrl.text.trim().isNotEmpty;
    if (trimmed.isEmpty && !hasFilters) {
      setState(() {
        _results = [];
        _schoolResults = [];
        _loading = false;
        _page = 1;
        _hasMore = true;
        _query = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _query = trimmed;
      _page = 1;
      _hasMore = true;
    });

    if (_mode == 'schools') {
      final schools = await HomeApiService.searchInstitutions(trimmed);
      if (!mounted) return;
      setState(() {
        _schoolResults = schools;
        _loading = false;
        _hasMore = false;
      });
    } else {
      final data = await HomeApiService.searchDirectoryUsersPage(
        trimmed,
        page: 1,
        perPage: 20,
        graduationYear: _graduationYear,
        industry: _industryCtrl.text,
      );
      if (!mounted) return;
      final meta = data['meta'] as Map<String, dynamic>?;
      final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
      setState(() {
        _results = (data['data'] as List<Map<String, dynamic>>?) ?? [];
        _loading = false;
        _hasMore = _page < lastPage;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_mode != 'alumni' || _query.isEmpty || !_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await HomeApiService.searchDirectoryUsersPage(
      _query,
      page: nextPage,
      perPage: 20,
      graduationYear: _graduationYear,
      industry: _industryCtrl.text,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    setState(() {
      _results.addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _loadingMore = false;
      _page = nextPage;
      _hasMore = _page < lastPage;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _graduationYearCtrl.dispose();
    _industryCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? get _graduationYear {
    final value = int.tryParse(_graduationYearCtrl.text.trim());
    final currentYear = DateTime.now().year;
    if (value == null || value < 1950 || value > currentYear) return null;
    return value;
  }

  bool get _hasAlumniFilters =>
      _graduationYear != null || _industryCtrl.text.trim().isNotEmpty;

  Future<void> _sendConnection(Map<String, dynamic> user) async {
    final userId = (user['id'] as num?)?.toInt();
    if (userId == null || _sendingConnectionIds.contains(userId)) return;
    setState(() => _sendingConnectionIds.add(userId));
    final ok = await HomeApiService.sendConnection(userId);
    if (!mounted) return;
    setState(() {
      _sendingConnectionIds.remove(userId);
      if (ok) _sentConnectionIds.add(userId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Connection request sent' : 'Could not send connection request',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        title: Text(
          'Search',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                if (value.trim().isEmpty &&
                    _graduationYear == null &&
                    _industryCtrl.text.trim().isEmpty) {
                  setState(() {
                    _results = [];
                    _schoolResults = [];
                  });
                  return;
                }
                _search(value);
              },
              decoration: InputDecoration(
                hintText: 'Search alumni, schools, jobs…',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _filterChip('Alumni', _mode == 'alumni', () {
                  setState(() {
                    _mode = 'alumni';
                    _results = [];
                    _schoolResults = [];
                  });
                  if (_searchCtrl.text.trim().isNotEmpty || _hasAlumniFilters) {
                    _search(_searchCtrl.text);
                  }
                }),
                const SizedBox(width: 8),
                _filterChip('Schools', _mode == 'schools', () {
                  setState(() {
                    _mode = 'schools';
                    _results = [];
                    _schoolResults = [];
                  });
                  if (_searchCtrl.text.trim().isNotEmpty) {
                    _search(_searchCtrl.text);
                  }
                }),
              ],
            ),
            if (_mode == 'alumni') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _graduationYearCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _search(_query),
                      decoration: InputDecoration(
                        hintText: 'Graduation year',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _industryCtrl,
                      onChanged: (_) => _search(_query),
                      decoration: InputDecoration(
                        hintText: 'Industry',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_mode == 'schools'
                ? _schoolResults.isEmpty
                : _results.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Search results will appear here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _mode == 'schools'
                      ? _schoolResults.length
                      : _results.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    if (_mode == 'alumni' && i >= _results.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_mode == 'schools') {
                      final school = _schoolResults[i];
                      final name = (school['name'] ?? '').toString();
                      final slug = (school['slug'] ?? '').toString();
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(
                            Icons.school_rounded,
                            color: Color(0xFF0EA5E9),
                          ),
                        ),
                        title: Text(name),
                        subtitle: slug.isNotEmpty ? Text(slug) : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final id = (school['id'] as num?)?.toInt() ?? 0;
                          Navigator.of(context).pushNamed(
                            '/institution-profile',
                            arguments: {'id': id, 'name': name},
                          );
                        },
                      );
                    }

                    final user = _results[i];
                    final name = (user['name'] ?? '').toString();
                    final program =
                        (user['program'] ?? user['department'] ?? '')
                            .toString();
                    final industry = (user['industry'] ?? '').toString();
                    final location = (user['location'] ?? '').toString();
                    final avatarUrl = HomeApiService.normalizeMediaUrl(
                      user['avatar_url']?.toString(),
                    );
                    final subtitle = [
                      program,
                      industry,
                      location,
                    ].where((e) => e.isNotEmpty).join(' • ');
                    final userId = (user['id'] as num?)?.toInt() ?? 0;
                    final canConnect = userId != 0 && userId != _viewerId;
                    final sent = _sentConnectionIds.contains(userId);
                    final sending = _sendingConnectionIds.contains(userId);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFDBEAFE),
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? null
                            : const Icon(
                                Icons.person,
                                color: Color(0xFF1D4ED8),
                              ),
                      ),
                      title: Text(name),
                      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                      trailing: canConnect
                          ? TextButton(
                              onPressed: sent || sending
                                  ? null
                                  : () => _sendConnection(user),
                              child: Text(sent ? 'Sent' : 'Connect'),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushNamed('/user-profile', arguments: {'id': userId});
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFF2563EB) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
