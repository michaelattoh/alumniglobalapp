import 'package:flutter/material.dart';

import 'job_apply_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  Widget _logoBubble(String name) {
    final display = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          display,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Color(0xFF0369A1),
          ),
        ),
      ),
    );
  }

  String _formatPostedDate(String raw) {
    if (raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
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
    final month = months[parsed.month - 1];
    return '$month ${parsed.day}, ${parsed.year}';
  }

  Widget _tagChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, {IconData? icon}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    dynamic content,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (content == null || (content is List && content.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<String> bullets = [];
    if (content is List) {
      bullets.addAll(
        content.map((e) => e.toString()).where((e) => e.trim().isNotEmpty),
      );
    } else if (content is String) {
      final raw = content.replaceAll('•', '\n');
      bullets.addAll(
        raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bullets.length <= 1)
            Text(
              bullets.isEmpty ? content.toString() : bullets.first,
              style: TextStyle(color: scheme.onSurface, height: 1.45),
            )
          else
            ...bullets.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: TextStyle(height: 1.4, color: scheme.onSurface),
                    ),
                    Expanded(
                      child: Text(
                        e,
                        style: TextStyle(height: 1.4, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
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
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 380;
    final title = (job['title'] ?? 'Job').toString();
    final company = (job['company_name'] ?? job['companyName'] ?? '')
        .toString();
    final location = (job['location'] ?? '').toString();
    final category = (job['category'] ?? '').toString();
    final type = (job['job_type'] ?? job['type'] ?? '').toString();
    final salary = (job['salary'] ?? '').toString();
    final workMode = (job['work_mode'] ?? '').toString();
    final experience = (job['experience_level'] ?? '').toString();
    final postedAtRaw = (job['published_at'] ?? job['created_at'] ?? '')
        .toString();
    final postedAt = _formatPostedDate(postedAtRaw);
    final overview = job['overview'] ?? job['job_overview'] ?? job['summary'];
    final description =
        job['description'] ?? job['job_description'] ?? job['details'];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Job details'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, isCompact ? 12 : 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 14 : 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                        color: Colors.black.withOpacity(isDark ? 0.24 : 0.12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _logoBubble(company.isEmpty ? title : company),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: isCompact ? 18 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  company.isEmpty ? 'Company' : company,
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                if (postedAt.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Posted $postedAt',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFCBD5F5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (location.isNotEmpty)
                            _chip(context, location, icon: Icons.place_rounded),
                          if (type.isNotEmpty)
                            _chip(
                              context,
                              type,
                              icon: Icons.work_outline_rounded,
                            ),
                          if (category.isNotEmpty)
                            _chip(
                              context,
                              category,
                              icon: Icons.category_rounded,
                            ),
                          if (workMode.isNotEmpty)
                            _tagChip(
                              workMode,
                              const Color(0xFFD1FAE5),
                              const Color(0xFF047857),
                            ),
                          if (experience.isNotEmpty)
                            _tagChip(
                              experience,
                              const Color(0xFFE0E7FF),
                              const Color(0xFF4338CA),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (salary.isNotEmpty)
                      _infoTile(
                        context,
                        'Salary',
                        salary,
                        Icons.payments_rounded,
                      ),
                    if (type.isNotEmpty)
                      _infoTile(context, 'Job type', type, Icons.badge_rounded),
                    if (location.isNotEmpty)
                      _infoTile(
                        context,
                        'Location',
                        location,
                        Icons.place_rounded,
                      ),
                    if (category.isNotEmpty)
                      _infoTile(
                        context,
                        'Category',
                        category,
                        Icons.layers_rounded,
                      ),
                    if (workMode.isNotEmpty)
                      _infoTile(
                        context,
                        'Work mode',
                        workMode,
                        Icons.apartment_rounded,
                      ),
                    if (experience.isNotEmpty)
                      _infoTile(
                        context,
                        'Experience',
                        experience,
                        Icons.timeline_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _section(
                  context,
                  'Overview',
                  overview,
                  Icons.info_outline_rounded,
                ),
                _section(
                  context,
                  'Job Description',
                  description,
                  Icons.description_outlined,
                ),
                _section(
                  context,
                  'Responsibilities',
                  job['expectations'],
                  Icons.check_circle_outline,
                ),
                _section(
                  context,
                  'Requirements',
                  job['requirements'],
                  Icons.verified_outlined,
                ),
                _section(
                  context,
                  'Company Overview',
                  job['company_overview'] ?? job['companyOverview'],
                  Icons.apartment_outlined,
                ),
              ],
            ),
          ),

          // APPLY
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: theme.cardColor,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobApplyScreen(
                          jobId: job['id'].toString(),
                          jobTitle: job['title'],
                          companyName:
                              job['company_name'] ?? job['companyName'] ?? '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Apply Now'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
