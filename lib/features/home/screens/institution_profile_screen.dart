import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:flutter/material.dart';

class InstitutionProfileScreen extends StatefulWidget {
  final int institutionId;
  final String? institutionName;

  const InstitutionProfileScreen({
    super.key,
    required this.institutionId,
    this.institutionName,
  });

  @override
  State<InstitutionProfileScreen> createState() =>
      _InstitutionProfileScreenState();
}

class _InstitutionProfileScreenState extends State<InstitutionProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _institution;

  @override
  void initState() {
    super.initState();
    _loadInstitution();
  }

  Future<void> _loadInstitution() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await HomeApiService.fetchInstitutionPublic(
      widget.institutionId,
    );
    if (!mounted) return;
    setState(() {
      _institution = data;
      _loading = false;
      if (data == null) {
        _error = 'Unable to load school profile.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final institution = _institution ?? <String, dynamic>{};
    final logoUrl = HomeApiService.normalizeMediaUrl(
      institution['logo_url']?.toString(),
    );
    final bannerUrl = HomeApiService.normalizeMediaUrl(
      institution['banner_url']?.toString(),
    );
    final name =
        institution['name']?.toString() ?? widget.institutionName ?? 'School';
    final description = institution['description']?.toString() ?? '';
    final motto = institution['motto']?.toString() ?? '';
    final location = institution['location']?.toString() ?? '';
    final status = institution['status']?.toString() ?? 'active';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _loadInstitution,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 104),
                children: [
                  SafeArea(
                    bottom: false,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              children: [
                                _heroAction(
                                  icon: Icons.arrow_back_rounded,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                                const Spacer(),
                                _heroChip(
                                  icon: Icons.verified_rounded,
                                  label: status == 'active'
                                      ? 'School profile'
                                      : status,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 190,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withOpacity(0.10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.16),
                              ),
                              image: bannerUrl != null && bannerUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(bannerUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: bannerUrl == null || bannerUrl.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.apartment_rounded,
                                          color: Colors.white.withOpacity(0.86),
                                          size: 40,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'School spotlight',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                          Transform.translate(
                            offset: const Offset(0, -26),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 38,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      backgroundImage:
                                          logoUrl != null && logoUrl.isNotEmpty
                                          ? NetworkImage(logoUrl)
                                          : null,
                                      child: logoUrl == null || logoUrl.isEmpty
                                          ? const Icon(
                                              Icons.school_rounded,
                                              size: 34,
                                              color: Color(0xFF475569),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: theme.textTheme.headlineSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.05,
                                                ),
                                          ),
                                          if (location.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              location,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.white70,
                                                  ),
                                            ),
                                          ],
                                          if (motto.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              motto,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (location.isNotEmpty)
                                  _metaChip(
                                    icon: Icons.location_on_outlined,
                                    label: location,
                                  ),
                                if ((institution['website']?.toString() ?? '')
                                    .isNotEmpty)
                                  _metaChip(
                                    icon: Icons.language_rounded,
                                    label: institution['website'].toString(),
                                  ),
                                if ((institution['email']?.toString() ?? '')
                                    .isNotEmpty)
                                  _metaChip(
                                    icon: Icons.alternate_email_rounded,
                                    label: institution['email'].toString(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    title: 'About this school',
                    subtitle:
                        'A polished snapshot of the institution alumni are connecting back to.',
                    child: Text(
                      description.isNotEmpty
                          ? description
                          : 'This school has not added a description yet, but the profile is ready for alumni to explore and reconnect.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        color: scheme.onSurface.withOpacity(0.82),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    title: 'Contact & campus details',
                    subtitle:
                        'Everything alumni need to reach the right office or team.',
                    child: Column(
                      children: [
                        _infoTile(
                          context,
                          icon: Icons.language_rounded,
                          title: 'Website',
                          value: institution['website']?.toString(),
                        ),
                        _infoTile(
                          context,
                          icon: Icons.email_outlined,
                          title: 'Email',
                          value: institution['email']?.toString(),
                        ),
                        _infoTile(
                          context,
                          icon: Icons.call_outlined,
                          title: 'Phone',
                          value: institution['phone']?.toString(),
                        ),
                        _infoTile(
                          context,
                          icon: Icons.pin_drop_outlined,
                          title: 'Address',
                          value: institution['address']?.toString(),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: bottomInset + 28),
                ],
              ),
            ),
    );
  }

  Widget _heroAction({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _heroChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
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
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String? value,
    bool last = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final display = value?.trim() ?? '';
    if (display.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withOpacity(0.12),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  display,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
