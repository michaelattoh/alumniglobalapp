import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'story_create_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  bool _isSchoolAdmin = false;
  int? _currentUserId;
  bool _myOnly = false;
  String _filterType = 'All';
  List<String> _types = const ['All'];
  List<Map<String, dynamic>> _recommended = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadUserRole();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recs = await HomeApiService.fetchRecommendations(
        type: 'event',
        perPage: 6,
      );
      final data = await HomeApiService.fetchEventsPage(page: 1, perPage: 15);
      if (!mounted) return;
      final recRows = (recs['data'] as List<Map<String, dynamic>>?) ?? [];
      final meta = data['meta'] as Map<String, dynamic>?;
      final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
      final typeSet = <String>{};
      final rows = (data['data'] as List<Map<String, dynamic>>?) ?? [];
      for (final row in rows) {
        final type = row['event_type']?.toString();
        if (type != null && type.isNotEmpty) {
          typeSet.add(_formatType(type));
        }
      }
      setState(() {
        _events = rows;
        _recommended = recRows
            .map((r) {
              final entity = (r['entity'] as Map<String, dynamic>?) ?? {};
              if (entity.isEmpty) return null;
              return {
                'recommendation_id': r['id'],
                'reason': r['reason'],
                'event': entity,
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();
        _page = 1;
        _hasMore = _page < lastPage;
        _types = ['All', ...typeSet.toList()..sort()];
        if (!_types.contains(_filterType)) {
          _filterType = 'All';
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load events');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUserRole() async {
    final user = await HomeApiService.fetchMe();
    if (!mounted) return;
    setState(() {
      _isSchoolAdmin = user?['role']?.toString() == 'institution_admin';
      _currentUserId = (user?['id'] as num?)?.toInt();
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await HomeApiService.fetchEventsPage(
      page: nextPage,
      perPage: 15,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    setState(() {
      _events.addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _page = nextPage;
      _hasMore = _page < lastPage;
      _loadingMore = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'TBD';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'TBD';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _isUpcomingEvent(Map<String, dynamic> event) {
    final endsAt = DateTime.tryParse(
      event['ends_at']?.toString() ?? '',
    )?.toLocal();
    if (endsAt != null) return endsAt.isAfter(DateTime.now());
    final startsAt = DateTime.tryParse(
      event['starts_at']?.toString() ?? '',
    )?.toLocal();
    if (startsAt == null) return false;
    return startsAt.isAfter(DateTime.now());
  }

  String _formatType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Event';
    final value = raw.replaceAll('_', ' ');
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleEvents = _events.where((event) {
      if (!_isUpcomingEvent(event)) return false;
      final rawType = event['event_type']?.toString();
      final formattedType = _formatType(rawType);
      final matchesType = _filterType == 'All' || formattedType == _filterType;
      if (!matchesType) return false;
      if (_myOnly && _currentUserId != null) {
        final creator = event['creator'] as Map<String, dynamic>?;
        final creatorId = (creator?['id'] as num?)?.toInt();
        return creatorId == _currentUserId;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _isSchoolAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1D4ED8),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                );
                if (created == true) {
                  _loadEvents();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: RefreshIndicator(
          onRefresh: _loadEvents,
          child: SafeArea(
            bottom: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [Center(child: Text(_error!))],
                  )
                : ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _buildHeader(visibleEvents.length),
                      const SizedBox(height: 18),
                      _buildFilterRail(),
                      if (_recommended.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _buildRecommendedSection(context),
                      ],
                      if (visibleEvents.isEmpty) ...[
                        const SizedBox(height: 32),
                        _buildEmptyState(),
                      ] else ...[
                        const SizedBox(height: 22),
                        ...visibleEvents.map(
                          (event) => _buildEventCard(context, event),
                        ),
                      ],
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int visibleCount) {
    final upcoming = _events.where(_isUpcomingEvent).length;
    final accent = const Color(0xFF1D4ED8);
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221D4ED8),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isCompact ? 42 : 46,
                height: isCompact ? 42 : 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isSchoolAdmin
                      ? 'School reunion calendar'
                      : 'Alumni calendar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 14 : 18),
          Text(
            _isSchoolAdmin
                ? 'Bring your alumni community together'
                : 'Gatherings worth coming back for',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 22 : 26,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSchoolAdmin
                ? 'Run reunions, school meetups, alumni webinars, and the community moments that keep your graduates connected.'
                : 'Discover reunions, class-year meetups, alumni mixers, and the moments your network is gathering around.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          SizedBox(height: isCompact ? 14 : 18),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(
                  label: 'Visible now',
                  value: '$visibleCount',
                  accent: accent,
                  compact: isCompact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderStat(
                  label: 'Upcoming',
                  value: '$upcoming',
                  accent: accent,
                  compact: isCompact,
                ),
              ),
              if (_recommended.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeaderStat(
                    label: 'Recommended',
                    value: '${_recommended.length}',
                    accent: accent,
                    compact: isCompact,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required String label,
    required String value,
    required Color accent,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRail() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSchoolAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentPill(
                    label: 'All events',
                    active: !_myOnly,
                    onTap: () => setState(() => _myOnly = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSegmentPill(
                    label: 'My events',
                    active: _myOnly,
                    onTap: () => setState(() => _myOnly = true),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final type = _types[index];
              final active = type == _filterType;
              return FilterChip(
                label: Text(type),
                selected: active,
                onSelected: (_) => setState(() => _filterType = type),
                selectedColor: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFDBEAFE),
                checkmarkColor: const Color(0xFF1D4ED8),
                side: BorderSide(
                  color: active
                      ? const Color(0xFF93C5FD)
                      : scheme.outlineVariant,
                ),
                backgroundColor: theme.cardColor,
                labelStyle: TextStyle(
                  color: active ? const Color(0xFF1D4ED8) : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentPill({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1D4ED8) : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? const Color(0xFF1D4ED8) : scheme.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended alumni gatherings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A few reunions, mixers, and alumni moments that match your community.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommended.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, idx) {
              final rec = _recommended[idx];
              final event = (rec['event'] as Map<String, dynamic>?) ?? {};
              final title = (event['title'] ?? 'Event').toString();
              final date = _formatDate(event['starts_at']?.toString());
              final location =
                  (event['location'] ?? event['meeting_url'] ?? 'Online')
                      .toString();
              final reason = (rec['reason'] ?? '').toString();
              return InkWell(
                onTap: () async {
                  final recId = (rec['recommendation_id'] as num?)?.toInt();
                  if (recId != null) {
                    HomeApiService.sendRecommendationFeedback(
                      recommendationId: recId,
                      action: 'clicked',
                    );
                  }
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  );
                  if (changed == true) _loadEvents();
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 266,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF6B7280),
                            ),
                            onPressed: () {
                              final recId = (rec['recommendation_id'] as num?)
                                  ?.toInt();
                              if (recId != null) {
                                HomeApiService.sendRecommendationFeedback(
                                  recommendationId: recId,
                                  action: 'dismissed',
                                );
                                setState(() => _recommended.removeAt(idx));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        date,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      if (reason.isNotEmpty)
                        Text(
                          'Why this fits: $reason',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formattedType = _formatType(event['event_type']?.toString());
    final title = (event['title'] ?? 'Event').toString();
    final date = _formatDate(event['starts_at']?.toString());
    final location = (event['location'] ?? event['meeting_url'] ?? 'Online')
        .toString();
    final count = (event['going_count'] ?? 0).toString();
    final creator = (event['creator'] as Map<String, dynamic>?) ?? {};
    final host = (creator['name'] ?? 'Alumni Global').toString();
    final attendanceLabel = int.tryParse(count) == 1
        ? '1 alum going'
        : '$count alumni going';

    return InkWell(
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        );
        if (changed == true) _loadEvents();
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    date.split('•').first.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formattedType,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    host,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? scheme.surfaceContainerHighest
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          attendanceLabel,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Open event',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Color(0xFF1D4ED8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Color(0xFF1D4ED8),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isSchoolAdmin
                ? 'No alumni gatherings match this view yet'
                : 'No alumni gatherings match this view yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSchoolAdmin
                ? 'Try another event type, or create the next reunion, mixer, or class gathering for your alumni community.'
                : 'Try another event type, or come back when your school publishes the next reunion, mixer, or alumni gathering.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 14),
          Text(
            _isSchoolAdmin
                ? 'A lively alumni calendar helps classmates reconnect, show up, and stay involved.'
                : 'The best alumni moments usually start with one school deciding it is time to gather again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _meetingCtrl = TextEditingController();
  String _eventType = 'physical';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _meetingCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _startDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndDate() async {
    final base = _startDate ?? DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _endTime = picked);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _startDate == null ||
        _startTime == null)
      return;
    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    DateTime? end;
    if (_endDate != null && _endTime != null) {
      end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );
      if (!end.isAfter(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date must be later than the start time'),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final event = await HomeApiService.createEvent(
      title: _titleCtrl.text.trim(),
      eventType: _eventType,
      startsAt: start,
      endsAt: end,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      location:
          (_eventType == 'physical' ||
              _eventType == 'fair' ||
              _eventType == 'workshop')
          ? _locationCtrl.text.trim()
          : null,
      meetingUrl:
          (_eventType == 'virtual' ||
              _eventType == 'fair' ||
              _eventType == 'workshop')
          ? _meetingCtrl.text.trim()
          : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (event == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create event')));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateLabel = _startDate == null
        ? 'Pick date'
        : '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}';
    final timeLabel = _startTime == null
        ? 'Pick time'
        : _startTime!.format(context);
    final endDateLabel = _endDate == null
        ? 'Set expiry date'
        : '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}';
    final endTimeLabel = _endTime == null
        ? 'Set expiry time'
        : _endTime!.format(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Event basics',
              subtitle:
                  'Set the event type, title, and timing clearly from the start.',
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('Event title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _eventType,
                    decoration: _inputDecoration('Event type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'physical',
                        child: Text('Physical'),
                      ),
                      DropdownMenuItem(
                        value: 'virtual',
                        child: Text('Virtual'),
                      ),
                      DropdownMenuItem(value: 'fair', child: Text('Fair')),
                      DropdownMenuItem(
                        value: 'workshop',
                        child: Text('Workshop'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _eventType = value ?? 'physical'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: _pickerButtonStyle(),
                          onPressed: _pickDate,
                          child: Text(dateLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: _pickerButtonStyle(),
                          onPressed: _pickTime,
                          child: Text(timeLabel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: _pickerButtonStyle(),
                          onPressed: _pickEndDate,
                          child: Text(endDateLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: _pickerButtonStyle(),
                          onPressed: _pickEndTime,
                          child: Text(endTimeLabel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'This controls when the event stops showing as upcoming.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_eventType == 'physical' ||
                      _eventType == 'fair' ||
                      _eventType == 'workshop')
                    TextField(
                      controller: _locationCtrl,
                      decoration: _inputDecoration('Location'),
                    ),
                  if (_eventType == 'virtual' ||
                      _eventType == 'fair' ||
                      _eventType == 'workshop') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _meetingCtrl,
                      decoration: _inputDecoration('Meeting URL'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'What attendees should know',
              subtitle: 'Describe the purpose, agenda, or value of the event.',
              child: TextField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: _inputDecoration(
                  'Description',
                ).copyWith(hintText: 'Give alumni a reason to show up.'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create event',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.4),
      ),
    );
  }

  ButtonStyle _pickerButtonStyle() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return OutlinedButton.styleFrom(
      backgroundColor: theme.cardColor,
      foregroundColor: scheme.onSurface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: scheme.outlineVariant),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            offset: Offset(0, 14),
            color: Color(0x1F0F172A),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.14),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Create an event',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build a polished invite for alumni, whether it is physical, virtual, or a hybrid moment worth attending.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _submitting = false;
  bool _refreshing = false;
  bool? _isGoing;
  int? _goingCount;
  Map<String, dynamic>? _event;

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
    _refreshEvent();
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'TBD';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'TBD';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[dt.weekday - 1];
    return '$weekday, ${months[dt.month]} ${dt.day}, ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Event';
    final value = raw.replaceAll('_', ' ');
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> _refreshEvent() async {
    final id = ((_event ?? widget.event)['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() => _refreshing = true);
    final fresh = await HomeApiService.fetchEvent(id);
    if (!mounted) return;
    if (fresh != null) {
      setState(() {
        _event = fresh;
        _isGoing = fresh['rsvp_status'] == 'going';
        _goingCount = (fresh['going_count'] as num?)?.toInt();
      });
    }
    setState(() => _refreshing = false);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link right now')),
      );
    }
  }

  Future<void> _shareToStory() async {
    final event = _event ?? widget.event;
    final title = (event['title'] ?? 'Event').toString();
    final date = _formatDate(event['starts_at']?.toString());
    final location = (event['location'] ?? event['meeting_url'] ?? 'Online')
        .toString();
    final creator = (event['creator'] as Map<String, dynamic>?) ?? {};
    final creatorName = (creator['name'] ?? 'Alumni Global').toString();
    final eventType = (event['event_type'] ?? 'event').toString();
    final created = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryCreateScreen(
          initialTemplate: StoryTemplateConfig.event(
            title: title,
            date: date,
            location: location,
            host: 'Hosted by $creatorName',
            type: eventType,
          ),
        ),
      ),
    );
    if (!mounted || created == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event shared to story')));
  }

  Future<void> _rsvp(String status) async {
    final id = (widget.event['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() => _submitting = true);
    final result = await HomeApiService.rsvpEvent(eventId: id, status: status);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result != null) {
        _event = Map<String, dynamic>.from(result);
        final prevGoing = _isGoing ?? (widget.event['rsvp_status'] == 'going');
        final nextGoing = result['rsvp_status'] == 'going';
        final count =
            (result['going_count'] as num?)?.toInt() ??
            (_goingCount ??
                ((widget.event['going_count'] as num?)?.toInt() ?? 0));
        _isGoing = nextGoing;
        _goingCount = count;
        (_event ?? widget.event)['going_count'] = count;
        (_event ?? widget.event)['rsvp_status'] =
            result['rsvp_status']?.toString() ?? status;
        if (prevGoing != nextGoing) {
          widget.event['going_count'] = count;
          widget.event['rsvp_status'] =
              result['rsvp_status']?.toString() ?? status;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result != null ? 'RSVP updated' : 'Unable to update RSVP',
        ),
      ),
    );
    // Keep the user on the detail screen; list refresh happens on back.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final event = _event ?? widget.event;
    final title = (event['title'] ?? 'Event').toString();
    final description = (event['description'] ?? '').toString();
    final date = _formatDate(event['starts_at']?.toString());
    final location = (event['location'] ?? event['meeting_url'] ?? 'Online')
        .toString();
    final going = (_goingCount ?? (event['going_count'] ?? 0)).toString();
    final type = _formatType(event['event_type']?.toString());
    final creator = (event['creator'] as Map<String, dynamic>?) ?? {};
    final creatorName = (creator['name'] ?? 'Organizer').toString();
    final meetingUrl = (event['meeting_url'] ?? '').toString();
    final rsvpStatus = (_isGoing ?? (event['rsvp_status'] == 'going'))
        ? 'going'
        : (event['rsvp_status']?.toString() ?? 'not_going');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: RefreshIndicator(
          onRefresh: _refreshEvent,
          child: SafeArea(
            top: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_refreshing)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EventMetaLine(
                        icon: Icons.schedule_rounded,
                        label: date,
                        light: true,
                      ),
                      const SizedBox(height: 8),
                      _EventMetaLine(
                        icon: Icons.place_outlined,
                        label: location,
                        light: true,
                      ),
                      const SizedBox(height: 8),
                      _EventMetaLine(
                        icon: Icons.people_alt_outlined,
                        label: '$going going • hosted by $creatorName',
                        light: true,
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _shareToStory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.auto_stories_outlined),
                        label: const Text('Share to story'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description.isNotEmpty
                            ? description
                            : 'No extra description has been added for this event yet.',
                        style: TextStyle(
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (meetingUrl.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => _openLink(meetingUrl),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open meeting link'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your RSVP',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusPill(
                            label: rsvpStatus == 'going'
                                ? 'You are going'
                                : rsvpStatus == 'not_going'
                                ? 'Marked not going'
                                : 'No RSVP yet',
                            color: rsvpStatus == 'going'
                                ? const Color(0xFFDCFCE7)
                                : scheme.surfaceContainerHighest,
                            textColor: rsvpStatus == 'going'
                                ? const Color(0xFF166534)
                                : scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_submitting)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _rsvp('going'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text("I'm going"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rsvp('not_going'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Not going'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventMetaLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool light;

  const _EventMetaLine({
    required this.icon,
    required this.label,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white70 : const Color(0xFF64748B);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(color: color, height: 1.35)),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
