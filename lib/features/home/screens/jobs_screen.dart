import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'job_detail_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String activeFilter = 'All';
  final ScrollController _scrollController = ScrollController();

  final filters = ['All', 'Tech', 'Design', 'Marketing', 'Remote'];

  final List<Map<String, dynamic>> jobs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _isSchoolAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _loadUserRole();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadUserRole() async {
    final user = await HomeApiService.fetchMe();
    if (!mounted) return;
    setState(() {
      _isSchoolAdmin = user?['role']?.toString() == 'institution_admin';
    });
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _page = 1;
      _hasMore = true;
    });
    final data = await HomeApiService.fetchJobs(
      query: _searchCtrl.text.trim(),
      category: activeFilter,
      page: 1,
      perPage: 20,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
    setState(() {
      jobs
        ..clear()
        ..addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _loading = false;
      _hasMore = _page < lastPage;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await HomeApiService.fetchJobs(
      query: _searchCtrl.text.trim(),
      category: activeFilter,
      page: nextPage,
      perPage: 20,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    setState(() {
      jobs.addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _page = nextPage;
      _hasMore = _page < lastPage;
      _loadingMore = false;
    });
  }

  int get _remoteCount {
    return jobs.where((job) {
      final mode = (job['work_mode'] ?? job['type'] ?? '')
          .toString()
          .toLowerCase();
      return mode.contains('remote');
    }).length;
  }

  String _subtitleFor(Map<String, dynamic> job) {
    final workMode = (job['work_mode'] ?? '').toString();
    final type = (job['job_type'] ?? job['type'] ?? '').toString();
    final experience = (job['experience_level'] ?? '').toString();
    return [
      workMode,
      type,
      experience,
    ].where((e) => e.trim().isNotEmpty).join(' · ');
  }

  String _timeAgo(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(
            theme.brightness == Brightness.dark ? 0.92 : 0.88,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tone, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = (job['title'] ?? 'Job opportunity').toString();
    final company =
        (job['company_name'] ?? job['companyName'] ?? 'Organization')
            .toString();
    final location = (job['location'] ?? 'Location flexible').toString();
    final overview = (job['overview'] ?? job['summary'] ?? '').toString();
    final salary = (job['salary'] ?? '').toString();
    final category = (job['category'] ?? '').toString();
    final timeAgo = _timeAgo(
      (job['published_at'] ?? job['created_at'] ?? '').toString(),
    );
    final subtitle = _subtitleFor(job);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0EAFF), Color(0xFFF8FAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      company.trim().isEmpty
                          ? '?'
                          : company.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        company,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _jobMetaChip(Icons.place_rounded, location),
                if (salary.trim().isNotEmpty)
                  _jobMetaChip(Icons.payments_outlined, salary),
                if (category.trim().isNotEmpty)
                  _jobMetaChip(Icons.auto_awesome_mosaic_rounded, category),
              ],
            ),
            if (overview.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                overview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: const [
                Text(
                  'Open role',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _jobMetaChip(IconData icon, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _isSchoolAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1D4ED8),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateJobScreen()),
                );
                if (created == true) {
                  _loadJobs();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadJobs,
            child: ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    gradient: theme.brightness == Brightness.dark
                        ? const LinearGradient(
                            colors: [Color(0xFF111827), Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFE0EAFF), Color(0xFFF8FBFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jobs',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Discover roles from schools, alumni teams, and partners in one polished stream.',
                        style: TextStyle(
                          height: 1.45,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white70
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => _loadJobs(),
                        decoration: InputDecoration(
                          hintText: 'Search jobs, companies, or locations',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: theme.brightness == Brightness.dark
                              ? scheme.surfaceContainerHighest
                              : Colors.white.withOpacity(0.92),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _statCard(
                            icon: Icons.work_outline_rounded,
                            label: 'Open now',
                            value: '${jobs.length}',
                            tone: const Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 12),
                          _statCard(
                            icon: Icons.language_rounded,
                            label: 'Remote friendly',
                            value: '$_remoteCount',
                            tone: const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final f = filters[i];
                      final active = f == activeFilter;
                      return ChoiceChip(
                        label: Text(f),
                        selected: active,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : scheme.onSurface,
                        ),
                        backgroundColor: theme.cardColor,
                        selectedColor: const Color(0xFF1D4ED8),
                        side: BorderSide(
                          color: active
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFE5E7EB),
                        ),
                        onSelected: (_) {
                          setState(() => activeFilter = f);
                          _loadJobs();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (jobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.work_outline_rounded,
                          size: 42,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No jobs match this search yet.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try another filter or search term and we will keep the board fresh for you.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.45,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...jobs.map(_buildJobCard),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _overviewCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _workMode = '';
  String _experienceLevel = '';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _companyCtrl.dispose();
    _locationCtrl.dispose();
    _salaryCtrl.dispose();
    _overviewCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final job = await HomeApiService.createJob(
      title: _titleCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      companyName: _companyCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      workMode: _workMode,
      salary: _salaryCtrl.text.trim(),
      experienceLevel: _experienceLevel,
      overview: _overviewCtrl.text.trim(),
      description: _descCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (job == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create job')));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Role details',
              subtitle:
                  'Define the role clearly so alumni can evaluate it fast.',
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('Job title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryCtrl,
                    decoration: _inputDecoration('Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _companyCtrl,
                    decoration: _inputDecoration('Company or school unit'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationCtrl,
                    decoration: _inputDecoration('Location'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _workMode.isEmpty ? null : _workMode,
                    decoration: _inputDecoration('Work mode'),
                    items: const [
                      DropdownMenuItem(value: 'remote', child: Text('Remote')),
                      DropdownMenuItem(value: 'onsite', child: Text('On-site')),
                      DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                    ],
                    onChanged: (value) =>
                        setState(() => _workMode = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _salaryCtrl,
                    decoration: _inputDecoration('Salary'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _experienceLevel.isEmpty
                        ? null
                        : _experienceLevel,
                    decoration: _inputDecoration('Experience level'),
                    items: const [
                      DropdownMenuItem(value: 'entry', child: Text('Entry')),
                      DropdownMenuItem(value: 'mid', child: Text('Mid')),
                      DropdownMenuItem(value: 'senior', child: Text('Senior')),
                      DropdownMenuItem(value: 'lead', child: Text('Lead')),
                    ],
                    onChanged: (value) =>
                        setState(() => _experienceLevel = value ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'What candidates should know',
              subtitle:
                  'Use overview for the short pitch and description for depth.',
              child: TextField(
                controller: _overviewCtrl,
                maxLines: 3,
                decoration: _inputDecoration(
                  'Overview',
                ).copyWith(hintText: 'A concise summary of the opportunity.'),
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Role description',
              subtitle: 'Outline responsibilities, expectations, and impact.',
              child: TextField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: _inputDecoration('Description').copyWith(
                  hintText:
                      'Responsibilities, requirements, and what success looks like.',
                ),
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
                        'Create job',
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
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.4),
      ),
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
            child: const Icon(Icons.work_outline_rounded, color: Colors.white),
          ),
          const SizedBox(height: 18),
          const Text(
            'Create a job opening',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Post a role that looks current, trustworthy, and easy for alumni to act on.',
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
