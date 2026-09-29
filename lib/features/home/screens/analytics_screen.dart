import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _metrics;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    final metrics = await HomeApiService.fetchUserAnalytics();
    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _loading = false;
    });
  }

  int _asInt(String key) {
    final value = _metrics?[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final views = _asInt('profile_views_7d');
    final posts = _asInt('posts_total');
    final events = _asInt('events_going');
    final saved = _asInt('saved_posts_total');
    final hidden = _asInt('hidden_posts_total');
    final muted = _asInt('muted_users_total');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Your momentum',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track profile visibility, content activity, and the signals that show how your alumni presence is growing.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AnalyticsMetricCard(
                        width: (MediaQuery.sizeOf(context).width - 44) / 2,
                        title: 'Profile views',
                        value: '$views',
                        subtitle: 'Last 7 days',
                        accent: const Color(0xFF2563EB),
                        icon: Icons.visibility_rounded,
                      ),
                      _AnalyticsMetricCard(
                        width: (MediaQuery.sizeOf(context).width - 44) / 2,
                        title: 'Posts',
                        value: '$posts',
                        subtitle: 'Published so far',
                        accent: const Color(0xFF16A34A),
                        icon: Icons.post_add_rounded,
                      ),
                      _AnalyticsMetricCard(
                        width: (MediaQuery.sizeOf(context).width - 44) / 2,
                        title: 'Events going',
                        value: '$events',
                        subtitle: 'RSVP commitments',
                        accent: const Color(0xFFF97316),
                        icon: Icons.event_available_rounded,
                      ),
                      _AnalyticsMetricCard(
                        width: (MediaQuery.sizeOf(context).width - 44) / 2,
                        title: 'Saved posts',
                        value: '$saved',
                        subtitle: 'Content you kept close',
                        accent: const Color(0xFF7C3AED),
                        icon: Icons.bookmark_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                          'Community health',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A quick read on how tidy and visible your account feels right now.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InsightRow(
                          label: 'Muted users',
                          value: '$muted',
                          tone: muted > 0 ? 'focus' : 'calm',
                        ),
                        const SizedBox(height: 12),
                        _InsightRow(
                          label: 'Hidden posts',
                          value: '$hidden',
                          tone: hidden > 0 ? 'focus' : 'calm',
                        ),
                        const SizedBox(height: 12),
                        _InsightRow(
                          label: 'Visibility score',
                          value: views > 0 ? 'Active' : 'Quiet',
                          tone: views > 0 ? 'active' : 'calm',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _AnalyticsMetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final String tone;

  const _InsightRow({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    Color toneColor;
    switch (tone) {
      case 'active':
        toneColor = const Color(0xFF16A34A);
        break;
      case 'focus':
        toneColor = const Color(0xFFF97316);
        break;
      default:
        toneColor = const Color(0xFF64748B);
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: toneColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: TextStyle(color: toneColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
