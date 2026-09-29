import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _loading = true;
  bool _connecting = false;
  bool _requestSent = false;
  String? _error;
  Map<String, dynamic>? _user;
  int? _viewerId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await HomeApiService.fetchMe();
      final user = await HomeApiService.fetchUserProfile(widget.userId);
      final connections = await HomeApiService.fetchConnections(perPage: 100);
      final sent =
          (connections['sent'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      final received =
          (connections['received'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      final hasPendingOrAcceptedConnection =
          sent.any((row) {
            final to = (row['to_user'] as Map<String, dynamic>?) ?? const {};
            final id = (to['id'] as num?)?.toInt();
            final status = (row['status'] ?? '').toString();
            return id == widget.userId &&
                (status == 'pending' || status == 'accepted');
          }) ||
          received.any((row) {
            final from =
                (row['from_user'] as Map<String, dynamic>?) ?? const {};
            final id = (from['id'] as num?)?.toInt();
            final status = (row['status'] ?? '').toString();
            return id == widget.userId &&
                (status == 'pending' || status == 'accepted');
          });
      if (!mounted) return;
      setState(() {
        _user = user;
        _viewerId = (me?['id'] as num?)?.toInt();
        _requestSent = hasPendingOrAcceptedConnection;
      });
      await HomeApiService.trackAnalytics(
        eventType: 'profile_view',
        entityType: 'user',
        entityId: widget.userId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load profile');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    if (_connecting || _requestSent) return;
    setState(() => _connecting = true);
    final ok = await HomeApiService.sendConnection(widget.userId);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _requestSent = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Connection request sent' : 'Could not send connection request',
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _roleLabel(String roleName) {
    if (roleName == 'institution admin') return 'School admin';
    if (roleName == 'admin') return 'School admin';
    if (roleName == 'alumni') return 'Alumni member';
    return roleName.isEmpty ? 'Alumni member' : roleName;
  }

  @override
  Widget build(BuildContext context) {
    final profile = (_user?['profile'] as Map<String, dynamic>?) ?? {};
    final name = (_user?['name'] ?? 'Alumni').toString();
    final email = (_user?['email'] ?? '').toString();
    final status = (_user?['status'] ?? '').toString();
    final roleName = (_user?['role'] ?? '').toString().replaceAll('_', ' ');
    final headline = (profile['headline'] ?? '').toString();
    final location = (profile['location'] ?? '').toString();
    final graduationYear = profile['graduation_year']?.toString() ?? '';
    final department = (profile['department'] ?? '').toString();
    final program = (profile['program'] ?? '').toString();
    final company = (profile['current_company'] ?? '').toString();
    final role = (profile['current_role'] ?? '').toString();
    final industry = (profile['industry'] ?? '').toString();
    final careerFocus = (profile['career_focus'] ?? '').toString();
    final bio = (profile['bio'] ?? '').toString();
    final skills =
        (profile['skills'] as List?)?.map((e) => e.toString()).join(', ') ?? '';
    final interests =
        (profile['interests'] as List?)?.map((e) => e.toString()).join(', ') ??
        '';
    final avatarUrl = HomeApiService.normalizeMediaUrl(
      profile['avatar_url']?.toString(),
    );
    final visibility = (profile['visibility'] ?? '').toString();
    final verificationStatus = (profile['verification_status'] ?? '')
        .toString();
    final institution = (_user?['institution'] as Map<String, dynamic>?) ?? {};
    final institutionId = (institution['id'] as num?)?.toInt();
    final institutionName = (institution['name'] ?? '').toString();
    final isOwnProfile = _viewerId == widget.userId;
    final alumniIdentity = [
      if (institutionName.isNotEmpty) institutionName,
      if (graduationYear.isNotEmpty) 'Class of $graduationYear',
    ].join(' • ');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SafeArea(
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
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 30,
                                  color: Color(0xFF4B5563),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                              if (roleName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _roleLabel(roleName),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (headline.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  headline,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                              if (institutionName.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    institutionName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (institutionId != null) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      '/institution-profile',
                                      arguments: {
                                        'id': institutionId,
                                        'name': institution['name'],
                                      },
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                  icon: const Icon(Icons.school_outlined),
                                  label: const Text('View alma mater'),
                                ),
                              ],
                              if (!isOwnProfile) ...[
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: _requestSent || _connecting
                                      ? null
                                      : _connect,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _requestSent
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : Colors.white,
                                    disabledBackgroundColor: Colors.white
                                        .withValues(alpha: 0.18),
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: _requestSent ? 0.28 : 0.35,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  icon: Icon(
                                    _requestSent
                                        ? Icons.check_circle_outline
                                        : Icons.person_add_alt_rounded,
                                  ),
                                  label: Text(
                                    _requestSent
                                        ? 'Connection sent'
                                        : (_connecting
                                              ? 'Sending...'
                                              : 'Connect'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Wrap(
                      runSpacing: 12,
                      spacing: 12,
                      children: [
                        if (email.isNotEmpty) _pill('Email', email),
                        if (location.isNotEmpty) _pill('Location', location),
                        if (alumniIdentity.isNotEmpty)
                          _pill('Alumni circle', alumniIdentity),
                        if (verificationStatus.isNotEmpty)
                          _pill('Verification', verificationStatus),
                        if (visibility.isNotEmpty)
                          _pill('Visibility', visibility),
                        if (status.isNotEmpty) _pill('Status', status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Class year', graduationYear),
                        _infoRow('Department', department),
                        _infoRow('Program', program),
                        _infoRow('Current company', company),
                        _infoRow('Current role', role),
                        _infoRow('Industry', industry),
                        _infoRow('Career focus', careerFocus),
                        _infoRow('Skills', skills),
                        _infoRow('Interests', interests),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Bio',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(bio),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
