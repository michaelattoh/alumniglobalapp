import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/config/api_config.dart';
import 'story_create_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _uploadingAvatar = false;
  Map<String, String?> _fieldErrors = {};
  int? _gradYearValue;
  int? _quickGradYear;
  bool _editing = false;

  final _nameCtrl = TextEditingController();
  final _headlineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _gradYearCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _careerFocusCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  Map<String, dynamic>? _user;

  String _roleLabel(String? role) {
    if (role == 'institution_admin' || role == 'admin') return 'School admin';
    return 'Alumni member';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _headlineCtrl.dispose();
    _locationCtrl.dispose();
    _gradYearCtrl.dispose();
    _departmentCtrl.dispose();
    _programCtrl.dispose();
    _companyCtrl.dispose();
    _roleCtrl.dispose();
    _industryCtrl.dispose();
    _careerFocusCtrl.dispose();
    _skillsCtrl.dispose();
    _interestsCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = await HomeApiService.fetchMe();
    if (!mounted) return;
    final profile = (user?['profile'] as Map<String, dynamic>?) ?? {};

    setState(() {
      _user = user;
      _nameCtrl.text = (user?['name'] ?? '').toString();
      _headlineCtrl.text = (profile['headline'] ?? '').toString();
      _locationCtrl.text = (profile['location'] ?? '').toString();
      final grad = profile['graduation_year'];
      _gradYearValue = grad is int
          ? grad
          : int.tryParse(grad?.toString() ?? '');
      _gradYearCtrl.text = _gradYearValue?.toString() ?? '';
      _quickGradYear = _gradYearValue;
      _departmentCtrl.text = (profile['department'] ?? '').toString();
      _programCtrl.text = (profile['program'] ?? '').toString();
      _companyCtrl.text = (profile['current_company'] ?? '').toString();
      _roleCtrl.text = (profile['current_role'] ?? '').toString();
      _industryCtrl.text = (profile['industry'] ?? '').toString();
      _careerFocusCtrl.text = (profile['career_focus'] ?? '').toString();
      final skills =
          (profile['skills'] as List?)?.map((e) => e.toString()).join(', ') ??
          '';
      _skillsCtrl.text = skills;
      final interests =
          (profile['interests'] as List?)
              ?.map((e) => e.toString())
              .join(', ') ??
          '';
      _interestsCtrl.text = interests;
      _bioCtrl.text = (profile['bio'] ?? '').toString();
      _loading = false;
      _fieldErrors = {};
    });
  }

  bool _validateProfile() {
    final nextErrors = <String, String?>{};
    final role = _user?['role']?.toString();
    final isSchoolAdmin = role == 'institution_admin';
    if (_nameCtrl.text.trim().isEmpty) {
      nextErrors['name'] = 'Name is required';
    }
    if (_locationCtrl.text.trim().isEmpty) {
      nextErrors['location'] = 'Country is required';
    }
    if (!isSchoolAdmin) {
      final gradText = _gradYearCtrl.text.trim();
      if (gradText.isNotEmpty) {
        final year = int.tryParse(gradText);
        final currentYear = DateTime.now().year;
        if (year == null || year < 1950 || year > currentYear) {
          nextErrors['graduation_year'] =
              'Use a valid year (1950 - $currentYear)';
        }
      }
    }
    setState(() {
      _fieldErrors = nextErrors;
    });
    return nextErrors.isEmpty;
  }

  Future<void> _saveProfile() async {
    if (!_validateProfile()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fix the highlighted fields.')),
        );
      }
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final role = _user?['role']?.toString();
    final isSchoolAdmin = role == 'institution_admin';
    final gradYear = int.tryParse(_gradYearCtrl.text.trim());
    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final interests = _interestsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final payload = {
      'name': _nameCtrl.text.trim(),
      'headline': _headlineCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      if (!isSchoolAdmin) 'graduation_year': gradYear,
      if (!isSchoolAdmin) 'department': _departmentCtrl.text.trim(),
      if (!isSchoolAdmin) 'program': _programCtrl.text.trim(),
      if (!isSchoolAdmin) 'current_company': _companyCtrl.text.trim(),
      if (!isSchoolAdmin) 'current_role': _roleCtrl.text.trim(),
      if (!isSchoolAdmin) 'industry': _industryCtrl.text.trim(),
      if (!isSchoolAdmin) 'career_focus': _careerFocusCtrl.text.trim(),
      if (!isSchoolAdmin) 'skills': skills,
      if (!isSchoolAdmin) 'interests': interests,
      'bio': _bioCtrl.text.trim(),
    };

    final user = await HomeApiService.updateMe(payload);
    if (!mounted) return;
    setState(() {
      _user = user ?? _user;
      _saving = false;
      _error = user == null ? 'Failed to save profile' : null;
    });
    if (user != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      _loadProfile();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile update failed')));
    }
  }

  Future<void> _updateAvatar() async {
    if (_uploadingAvatar) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    final upload = await HomeApiService.uploadMedia(
      filePath: file.path,
      fileName: file.name,
    );
    if (upload == null || upload['url'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Avatar upload failed')));
      }
      setState(() => _uploadingAvatar = false);
      return;
    }

    final normalizedUrl =
        _resolveMediaUrl(upload['url']?.toString()) ?? upload['url'].toString();
    final user = await HomeApiService.updateMe({'avatar_url': normalizedUrl});
    if (!mounted) return;
    setState(() {
      _user = user ?? _user;
      _uploadingAvatar = false;
    });
    if (user == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar update failed')));
    }
  }

  Future<void> _removeAvatar() async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    final user = await HomeApiService.updateMe({'avatar_url': null});
    if (!mounted) return;
    setState(() {
      _user = user ?? _user;
      _uploadingAvatar = false;
    });
  }

  Future<void> _shareAchievementToStory() async {
    final user = _user;
    if (user == null) return;
    final role = user['role']?.toString();
    final isSchool = role == 'institution_admin';
    final profile = (user['profile'] as Map<String, dynamic>?) ?? {};
    final name = (user['name'] ?? 'Alumni').toString();
    final headline = (profile['headline'] ?? '').toString();
    final company = (profile['current_company'] ?? '').toString();
    final currentRole = (profile['current_role'] ?? '').toString();
    final gradYear = profile['graduation_year']?.toString() ?? '';
    final program = (profile['program'] ?? '').toString();
    final institution = (user['institution'] as Map<String, dynamic>?) ?? {};
    final schoolName = (institution['name'] ?? '').toString();
    final badgeImageUrl = isSchool
        ? _resolveMediaUrl(
            institution['logo_url']?.toString() ??
                institution['avatar_url']?.toString(),
          )
        : _resolveMediaUrl(
            profile['avatar_url']?.toString() ?? user['avatar_url']?.toString(),
          );
    final title = isSchool ? name : (headline.isNotEmpty ? headline : name);
    final subtitle = isSchool
        ? (schoolName.isNotEmpty ? schoolName : 'Community milestone')
        : [
            currentRole,
            company,
          ].where((item) => item.trim().isNotEmpty).join(' @ ').isNotEmpty
        ? [
            currentRole,
            company,
          ].where((item) => item.trim().isNotEmpty).join(' @ ')
        : 'Celebrating growth in the network';
    final meta = <String>[
      if (!isSchool && gradYear.isNotEmpty) 'Class of $gradYear',
      if (!isSchool && program.isNotEmpty) program,
      if (isSchool && schoolName.isNotEmpty) schoolName,
    ];

    final created = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryCreateScreen(
          initialTemplate: StoryTemplateConfig.achievement(
            title: title,
            subtitle: subtitle,
            meta: meta,
            isSchool: isSchool,
            badgeImageUrl: badgeImageUrl,
            badgeText: isSchool ? schoolName : name,
          ),
        ),
      ),
    );

    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Achievement shared to story')),
    );
  }

  void _showAvatarOptions(String? avatarUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 6,
                width: 56,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        size: 54,
                        color: Colors.black54,
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        contentPadding: const EdgeInsets.all(12),
                        content: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Preview photo'),
                ),
              ElevatedButton(
                onPressed: _uploadingAvatar
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _updateAvatar();
                      },
                child: const Text('Change photo'),
              ),
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                TextButton(
                  onPressed: _uploadingAvatar
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _removeAvatar();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('Remove photo'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _quickUpdateGradYear() async {
    if (_quickGradYear == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = await HomeApiService.updateMe({
      'graduation_year': _quickGradYear,
    });
    if (!mounted) return;
    setState(() {
      _user = user ?? _user;
      _gradYearValue = _quickGradYear;
      _gradYearCtrl.text = _quickGradYear?.toString() ?? '';
      _saving = false;
      _error = user == null ? 'Failed to update graduation year' : null;
    });
  }

  String? _resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final base = Uri.parse(ApiConfig.baseUrl);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;
      final host = uri.host;
      if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
        return uri
            .replace(
              scheme: base.scheme,
              host: base.host,
              port: base.hasPort ? base.port : null,
            )
            .toString();
      }
      return url;
    }
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return '${ApiConfig.baseUrl}/$url';
  }

  Widget _buildProfileView(
    ThemeData theme,
    Map<String, dynamic> institution,
    Map<String, dynamic> profile,
    String? avatarUrl,
    bool isSchoolAdmin,
  ) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final name = _nameCtrl.text.trim().isEmpty
        ? 'Your profile'
        : _nameCtrl.text.trim();
    final headline = _headlineCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    final gradYear = _gradYearCtrl.text.trim();
    final department = _departmentCtrl.text.trim();
    final program = _programCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final role = _roleCtrl.text.trim();
    final industry = _industryCtrl.text.trim();
    final careerFocus = _careerFocusCtrl.text.trim();
    final skills = _skillsCtrl.text.trim();
    final interests = _interestsCtrl.text.trim();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 88),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    size: 46,
                    color: Colors.black54,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _roleLabel(role),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  headline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  institution['name']?.toString() ?? 'No school',
                  if (!isSchoolAdmin && gradYear.isNotEmpty)
                    'Class of $gradYear',
                  if (location.isNotEmpty) location,
                ].join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _shareAchievementToStory,
                icon: const Icon(Icons.auto_stories_outlined),
                label: Text(
                  isSchoolAdmin
                      ? 'Share school highlight'
                      : 'Share achievement',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!isSchoolAdmin)
          _infoCard('Class year', gradYear.isEmpty ? 'Not set' : gradYear),
        if (!isSchoolAdmin)
          _infoCard('Department', department.isEmpty ? 'Not set' : department),
        if (!isSchoolAdmin)
          _infoCard('Program', program.isEmpty ? 'Not set' : program),
        if (!isSchoolAdmin)
          _infoCard('Current company', company.isEmpty ? 'Not set' : company),
        if (!isSchoolAdmin)
          _infoCard('Current role', role.isEmpty ? 'Not set' : role),
        if (!isSchoolAdmin)
          _infoCard('Industry', industry.isEmpty ? 'Not set' : industry),
        if (!isSchoolAdmin)
          _infoCard(
            'Career focus',
            careerFocus.isEmpty ? 'Not set' : careerFocus,
          ),
        if (!isSchoolAdmin)
          _infoCard('Skills', skills.isEmpty ? 'Not set' : skills),
        if (!isSchoolAdmin)
          _infoCard('Interests', interests.isEmpty ? 'Not set' : interests),
        _infoCard('Bio', bio.isEmpty ? 'No bio yet' : bio),
        SizedBox(height: bottomInset + 16),
      ],
    );
  }

  Widget _infoCard(String label, String value) {
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final institution = (_user?['institution'] as Map<String, dynamic>?) ?? {};
    final profile = (_user?['profile'] as Map<String, dynamic>?) ?? {};
    final avatarUrl = _resolveMediaUrl(
      profile['avatar_url']?.toString() ?? _user?['avatar_url']?.toString(),
    );
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(
      currentYear - 1949,
      (index) => currentYear - index,
    );
    final role = _user?['role']?.toString();
    final isSchoolAdmin = role == 'institution_admin';

    if (!_editing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: const Color(0xFFF5F5F7),
          elevation: 0,
          actions: [
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildProfileView(
                theme,
                institution,
                profile,
                avatarUrl,
                isSchoolAdmin,
              ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Cancel'),
                ),
                TextButton(onPressed: _saveProfile, child: const Text('Save')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 104,
              ),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: () => _showAvatarOptions(avatarUrl),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 42,
                                  color: Colors.black54,
                                )
                              : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _updateAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _uploadingAvatar
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameCtrl.text.trim().isEmpty
                            ? 'Your profile'
                            : _nameCtrl.text.trim(),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${institution['name']?.toString() ?? 'No school'} • ${_locationCtrl.text.trim().isEmpty ? 'Country not set' : _locationCtrl.text.trim()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isSchoolAdmin)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int?>(
                                value: _quickGradYear,
                                decoration: const InputDecoration(
                                  labelText: 'Graduation year',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Select year'),
                                  ),
                                  ...years.map(
                                    (year) => DropdownMenuItem<int?>(
                                      value: year,
                                      child: Text(year.toString()),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _quickGradYear = value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _saving ? null : _quickUpdateGradYear,
                              child: const Text('Update'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Text(
                  isSchoolAdmin ? 'School' : 'Alumni home',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                _readonlyField(institution['name']?.toString() ?? ''),
                if (institution['id'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/institution-profile',
                              arguments: {
                                'id': institution['id'],
                                'name': institution['name'],
                              },
                            );
                          },
                          icon: const Icon(Icons.school_outlined),
                          label: const Text('View alma mater'),
                        ),
                        if (isSchoolAdmin)
                          FilledButton.icon(
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed('/institution-profile-setup'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Manage school profile'),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed('/home', arguments: {'tab': 2}),
                          icon: const Icon(Icons.handshake_outlined),
                          label: Text(
                            isSchoolAdmin
                                ? 'Open alumni mentorship hub'
                                : 'Find alumni mentors',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _inputField(
                  'Full name',
                  _nameCtrl,
                  errorText: _fieldErrors['name'],
                ),
                _inputField(
                  isSchoolAdmin ? 'Leadership headline' : 'Alumni headline',
                  _headlineCtrl,
                ),
                _inputField(
                  'Location / Country',
                  _locationCtrl,
                  errorText: _fieldErrors['location'],
                ),
                if (!isSchoolAdmin) ...[
                  DropdownButtonFormField<int?>(
                    value: _gradYearValue,
                    decoration: InputDecoration(
                      labelText: 'Class year',
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _fieldErrors['graduation_year'],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Select year'),
                      ),
                      ...years.map(
                        (year) => DropdownMenuItem<int?>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _gradYearValue = value;
                        _gradYearCtrl.text = value?.toString() ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _inputField('Department', _departmentCtrl),
                  _inputField('Program', _programCtrl),
                  _inputField('Current company', _companyCtrl),
                  _inputField('Current role', _roleCtrl),
                  _inputField('Industry', _industryCtrl),
                  _inputField('Career focus', _careerFocusCtrl),
                  _inputField('Skills (comma separated)', _skillsCtrl),
                  _inputField('Interests (comma separated)', _interestsCtrl),
                ],
                _inputField('Bio', _bioCtrl, maxLines: 6),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 18),
              ],
            ),
    );
  }

  Widget _readonlyField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(value),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        minLines: maxLines > 1 ? maxLines : 1,
        maxLines: maxLines,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          errorText: errorText,
          alignLabelWithHint: maxLines > 1,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 18 : 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }
}
