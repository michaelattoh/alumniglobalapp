import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MentorshipScreen extends StatefulWidget {
  const MentorshipScreen({super.key});

  @override
  State<MentorshipScreen> createState() => _MentorshipScreenState();
}

class _MentorshipScreenState extends State<MentorshipScreen> {
  bool _loading = true;
  final Set<int> _sendingMentorshipIds = <int>{};
  bool _processingRequest = false;
  bool _processingYearGroupRequest = false;
  bool _assigningYearGroupMember = false;
  bool _creatingYearGroup = false;
  bool _isSchoolAdmin = false;
  int? _institutionId;
  int? _viewerGradYear;
  String _viewerName = 'Member';
  String _scopeLabel = '';
  List<Map<String, dynamic>> _connected = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _yearGroups = [];
  List<Map<String, dynamic>> _pendingYearGroupRequests = [];
  List<Map<String, dynamic>> _institutionAlumni = [];
  int? _selectedYearGroupId;
  int? _selectedAlumniId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isSchoolAdminRole(String? role) =>
      role == 'institution_admin' || role == 'admin';

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = await HomeApiService.fetchMe();
    final connections = await HomeApiService.fetchConnections(perPage: 100);
    final suggestions = await HomeApiService.fetchDirectorySuggestions();
    final institution =
        (me?['institution'] as Map<String, dynamic>?) ?? const {};
    final institutionId = int.tryParse(
      '${institution['id'] ?? me?['institution_id'] ?? ''}',
    );
    final isSchoolAdmin = _isSchoolAdminRole(me?['role']?.toString());
    final yearGroups = institutionId == null
        ? const <Map<String, dynamic>>[]
        : await HomeApiService.fetchInstitutionYearGroups(institutionId);
    final yearGroupRequests = _isInstitutionManagerRole(me?['role']?.toString())
        ? await HomeApiService.fetchInstitutionYearGroupRequests(
            institutionId: institutionId ?? 0,
            perPage: 50,
          )
        : const {'data': <Map<String, dynamic>>[]};
    final institutionAlumni = isSchoolAdmin && institutionId != null
        ? await HomeApiService.searchDirectoryUsersPage(
            '',
            institutionId: institutionId,
            perPage: 60,
          )
        : const {'data': <Map<String, dynamic>>[]};
    if (!mounted) return;

    final sent =
        (connections['sent'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final received =
        (connections['received'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];

    Map<String, dynamic> enrichConnection(
      Map<String, dynamic> row, {
      required bool incoming,
    }) {
      final user = Map<String, dynamic>.from(
        ((incoming ? row['from_user'] : row['to_user']) as Map?) ??
            const <String, dynamic>{},
      );
      return {
        'connection_id': row['id'],
        'status': row['status'],
        'incoming': incoming,
        'message': row['message'],
        'created_at': row['created_at'],
        ...user,
      };
    }

    final accepted = <Map<String, dynamic>>[
      ...sent
          .where((row) => row['status']?.toString() == 'accepted')
          .map((row) => enrichConnection(row, incoming: false)),
      ...received
          .where((row) => row['status']?.toString() == 'accepted')
          .map((row) => enrichConnection(row, incoming: true)),
    ];

    final incoming = received
        .where((row) => row['status']?.toString() == 'pending')
        .map((row) => enrichConnection(row, incoming: true))
        .toList();
    final outgoing = sent
        .where((row) => row['status']?.toString() == 'pending')
        .map((row) => enrichConnection(row, incoming: false))
        .toList();

    final unavailableIds = {
      ...accepted.map((row) => int.tryParse('${row['id'] ?? ''}')),
      ...incoming.map((row) => int.tryParse('${row['id'] ?? ''}')),
      ...outgoing.map((row) => int.tryParse('${row['id'] ?? ''}')),
    }.whereType<int>().toSet();

    final cleanedSuggestions = suggestions
        .where((row) {
          final id = int.tryParse('${row['id'] ?? ''}');
          final viewerId = int.tryParse('${me?['id'] ?? ''}');
          return id != null && id != viewerId && !unavailableIds.contains(id);
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final profile = (me?['profile'] as Map<String, dynamic>?) ?? const {};
    setState(() {
      _isSchoolAdmin = _isSchoolAdminRole(me?['role']?.toString());
      _institutionId = institutionId;
      _viewerGradYear = int.tryParse('${profile['graduation_year'] ?? ''}');
      _viewerName = (me?['name'] ?? 'Member').toString();
      _scopeLabel = (institution['name'] ?? '').toString();
      _connected = accepted;
      _incomingRequests = incoming;
      _outgoingRequests = outgoing;
      _suggestions = cleanedSuggestions;
      _yearGroups = yearGroups;
      _pendingYearGroupRequests =
          (yearGroupRequests['data'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      _institutionAlumni =
          (institutionAlumni['data'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      if (_selectedYearGroupId == null && yearGroups.isNotEmpty) {
        _selectedYearGroupId = int.tryParse('${yearGroups.first['id'] ?? ''}');
      }
      final availableIds = ((institutionAlumni['data'] as List?) ?? const [])
          .map((row) => int.tryParse('${row['id'] ?? ''}'))
          .whereType<int>()
          .toSet();
      if (_selectedAlumniId != null &&
          !availableIds.contains(_selectedAlumniId)) {
        _selectedAlumniId = null;
      }
      _loading = false;
    });
  }

  bool _isInstitutionManagerRole(String? role) =>
      role == 'institution_admin' || role == 'admin' || role == 'super_admin';

  Future<void> _requestMentorship(Map<String, dynamic> user) async {
    final userId = int.tryParse('${user['id'] ?? ''}');
    if (userId == null || _sendingMentorshipIds.contains(userId)) return;
    setState(() => _sendingMentorshipIds.add(userId));
    final ok = await HomeApiService.sendConnection(
      userId,
      message: _isSchoolAdmin
          ? 'Our school would like to open a mentorship connection.'
          : 'I would love to connect for mentorship and guidance.',
      source: 'mentorship',
    );
    if (!mounted) return;
    setState(() {
      _sendingMentorshipIds.remove(userId);
      if (ok) {
        _suggestions.removeWhere((row) => '${row['id']}' == '$userId');
        _outgoingRequests = [
          {...user, 'status': 'pending', 'incoming': false},
          ..._outgoingRequests,
        ];
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Alumni mentorship request sent' : 'Unable to send request',
        ),
      ),
    );
  }

  Future<void> _respondToRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    final connectionId = int.tryParse('${request['connection_id'] ?? ''}');
    if (connectionId == null || _processingRequest) return;
    setState(() => _processingRequest = true);
    final ok = await HomeApiService.respondConnection(
      connectionId: connectionId,
      status: status,
    );
    if (!mounted) return;
    setState(() {
      _processingRequest = false;
      if (ok) {
        _incomingRequests.removeWhere(
          (row) => '${row['connection_id']}' == '$connectionId',
        );
        if (status == 'accepted') {
          _connected = [request, ..._connected];
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? status == 'accepted'
                    ? 'Mentorship request accepted'
                    : 'Request declined'
              : 'Unable to update request',
        ),
      ),
    );
  }

  Future<void> _requestYearGroupJoin(Map<String, dynamic> group) async {
    final institutionId = _institutionId;
    final groupId = int.tryParse('${group['id'] ?? ''}');
    if (institutionId == null ||
        groupId == null ||
        _processingYearGroupRequest) {
      return;
    }
    setState(() => _processingYearGroupRequest = true);
    final result = await HomeApiService.requestInstitutionYearGroupJoin(
      institutionId: institutionId,
      groupId: groupId,
    );
    if (!mounted) return;
    setState(() {
      _processingYearGroupRequest = false;
      if (result['ok'] == true) {
        _yearGroups = _yearGroups.map((row) {
          if ('${row['id']}' != '$groupId') return row;
          return {
            ...row,
            'viewer_membership': result['membership'],
            'counts': {
              ...((row['counts'] as Map?)?.cast<String, dynamic>() ?? const {}),
              'pending_members':
                  (((row['counts'] as Map?)?['pending_members'] as num?) ?? 0) +
                  1,
            },
          };
        }).toList();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['ok'] == true
              ? (result['message']?.toString().isNotEmpty == true
                    ? result['message'].toString()
                    : 'Year-group request sent')
              : (result['message']?.toString().isNotEmpty == true
                    ? result['message'].toString()
                    : 'Unable to join this year group'),
        ),
      ),
    );
  }

  Future<void> _respondToYearGroupRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    final institutionId = _institutionId;
    final membershipId = int.tryParse('${request['id'] ?? ''}');
    if (institutionId == null ||
        membershipId == null ||
        _processingYearGroupRequest) {
      return;
    }

    setState(() => _processingYearGroupRequest = true);
    final ok = await HomeApiService.respondInstitutionYearGroupRequest(
      institutionId: institutionId,
      membershipId: membershipId,
      status: status,
    );
    if (!mounted) return;
    setState(() {
      _processingYearGroupRequest = false;
      if (ok) {
        _pendingYearGroupRequests.removeWhere(
          (row) => '${row['id']}' == '$membershipId',
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? status == 'accepted'
                    ? 'Year-group request approved'
                    : 'Year-group request rejected'
              : 'Unable to update year-group request',
        ),
      ),
    );
  }

  Future<void> _openCreateYearGroup() async {
    final institutionId = _institutionId;
    if (institutionId == null || _creatingYearGroup) return;
    final nameController = TextEditingController();
    final yearController = TextEditingController(
      text: _viewerGradYear?.toString() ?? '',
    );
    final descriptionController = TextEditingController();
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create year group',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Graduation year'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Tell alumni what this year group is for.',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'name': nameController.text.trim(),
                          'graduation_year': int.tryParse(
                            yearController.text.trim(),
                          ),
                          'description': descriptionController.text.trim(),
                        });
                      },
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    nameController.dispose();
    yearController.dispose();
    descriptionController.dispose();

    if (created == null || (created['name'] as String?)?.isEmpty != false) {
      return;
    }
    setState(() => _creatingYearGroup = true);
    final result = await HomeApiService.createInstitutionYearGroup(
      institutionId: institutionId,
      name: created['name'].toString(),
      graduationYear: created['graduation_year'] as int?,
      description: created['description']?.toString(),
    );
    if (!mounted) return;
    setState(() {
      _creatingYearGroup = false;
      if (result['ok'] == true && result['group'] is Map<String, dynamic>) {
        _yearGroups = [
          Map<String, dynamic>.from(result['group'] as Map<String, dynamic>),
          ..._yearGroups,
        ];
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['ok'] == true
              ? 'Year group created'
              : 'Unable to create year group',
        ),
      ),
    );
  }

  Future<void> _addAlumniToYearGroup() async {
    final institutionId = _institutionId;
    final groupId = _selectedYearGroupId;
    final userId = _selectedAlumniId;
    if (institutionId == null ||
        groupId == null ||
        userId == null ||
        _assigningYearGroupMember) {
      return;
    }
    setState(() => _assigningYearGroupMember = true);
    final result = await HomeApiService.addInstitutionYearGroupMember(
      institutionId: institutionId,
      groupId: groupId,
      userId: userId,
    );
    if (!mounted) return;
    setState(() => _assigningYearGroupMember = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString().isNotEmpty == true
              ? result['message'].toString()
              : (result['ok'] == true
                    ? 'Alumni added to year group'
                    : 'Unable to add alumni to year group'),
        ),
      ),
    );
    if (result['ok'] == true) {
      await _load();
    }
  }

  String _headline(Map<String, dynamic> user) {
    final profile = (user['profile'] as Map<String, dynamic>?) ?? const {};
    final headline = (profile['headline'] ?? '').toString().trim();
    if (headline.isNotEmpty) return headline;
    final role = (user['role'] ?? '').toString().replaceAll('_', ' ').trim();
    final institution =
        (user['institution'] as Map<String, dynamic>?) ?? const {};
    final school = (institution['name'] ?? '').toString().trim();
    return [role, school].where((e) => e.isNotEmpty).join(' • ');
  }

  String _heroBody() {
    if (_isSchoolAdmin) {
      final scope = _scopeLabel.isNotEmpty ? ' at $_scopeLabel' : '';
      return 'Coordinate alumni mentors, class-year circles, and school support routes$scope.';
    }
    return 'Reconnect with alumni who can guide your career, open doors, and keep your class network close.';
  }

  List<Map<String, dynamic>> _approvedYearGroups() =>
      _yearGroups.where((group) {
        final membership =
            (group['viewer_membership'] as Map<String, dynamic>?) ?? const {};
        return membership['status']?.toString() == 'approved';
      }).toList();

  List<Map<String, dynamic>> _pendingYearGroups() => _yearGroups.where((group) {
    final membership =
        (group['viewer_membership'] as Map<String, dynamic>?) ?? const {};
    return membership['status']?.toString() == 'pending';
  }).toList();

  List<Map<String, dynamic>> _recommendedYearGroups() =>
      _yearGroups.where((group) {
        if (_isSchoolAdmin) return false;
        final membership = group['viewer_membership'];
        if (membership != null) return false;
        final groupYear = int.tryParse('${group['graduation_year'] ?? ''}');
        if (_viewerGradYear != null && groupYear != null) {
          return _viewerGradYear == groupYear;
        }
        return true;
      }).toList();

  String _alumniOptionLabel(Map<String, dynamic> user) {
    final profile = (user['profile'] as Map<String, dynamic>?) ?? const {};
    final year = profile['graduation_year']?.toString() ?? '';
    return [
      user['name']?.toString() ?? 'Alumni',
      if (year.isNotEmpty) '• $year',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: RefreshIndicator(
          onRefresh: _load,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, isCompact ? 20 : 22, 16, 32),
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isSchoolAdmin
                          ? const [Color(0xFF0F172A), Color(0xFF0F766E)]
                          : const [Color(0xFF0F172A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isCompact ? 44 : 52,
                        height: isCompact ? 44 : 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isSchoolAdmin
                              ? Icons.groups_2_outlined
                              : Icons.handshake_outlined,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isCompact ? 14 : 18),
                      Text(
                        _isSchoolAdmin ? 'Mentorship hub' : 'Mentorship',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 24 : 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _heroBody(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final statWidth = constraints.maxWidth < 360
                              ? (constraints.maxWidth - 8) / 2
                              : (constraints.maxWidth - 16) / 3;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeroStat(
                                width: statWidth,
                                label: 'Active circle',
                                value: '${_connected.length}',
                              ),
                              _HeroStat(
                                width: statWidth,
                                label: 'Incoming',
                                value: '${_incomingRequests.length}',
                              ),
                              _HeroStat(
                                width: statWidth,
                                label: 'Outgoing',
                                value: '${_outgoingRequests.length}',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (_isSchoolAdmin) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'School alumni leadership',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Keep your school presence sharp so alumni know who is leading mentorship, year groups, and class support.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: () => Navigator.of(
                            context,
                          ).pushNamed('/institution-profile-setup'),
                          child: const Text('Manage school'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_isSchoolAdmin) ...[
                    _MentorshipSection(
                      title: 'Year-group join approvals',
                      subtitle:
                          'Only school admins approve year-group requests so the right alumni land in the right circle.',
                      children: _pendingYearGroupRequests.isEmpty
                          ? [
                              _EmptyMentorshipCard(
                                title: 'No pending year-group requests',
                                body:
                                    'When alumni request to join a year group, approvals will show up here.',
                              ),
                            ]
                          : _pendingYearGroupRequests.map((row) {
                              final yearGroup = Map<String, dynamic>.from(
                                (row['year_group'] as Map?) ??
                                    const <String, dynamic>{},
                              );
                              final yearLabel =
                                  yearGroup['graduation_year']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? ' • ${yearGroup['graduation_year']}'
                                  : '';
                              return _MentorCard(
                                user: Map<String, dynamic>.from(
                                  (row['user'] as Map?) ??
                                      const <String, dynamic>{},
                                ),
                                subtitle:
                                    '${yearGroup['name'] ?? 'Year group'}$yearLabel',
                                body: row['intro']?.toString(),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: _processingYearGroupRequest
                                          ? null
                                          : () => _respondToYearGroupRequest(
                                              row,
                                              'rejected',
                                            ),
                                      child: const Text('Reject'),
                                    ),
                                    FilledButton(
                                      onPressed: _processingYearGroupRequest
                                          ? null
                                          : () => _respondToYearGroupRequest(
                                              row,
                                              'accepted',
                                            ),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create alumni year groups',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create class-year circles alumni can request to join. Super admins and school admins can create them, but only school admins approve.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: _creatingYearGroup
                                ? null
                                : _openCreateYearGroup,
                            child: Text(
                              _creatingYearGroup ? 'Creating...' : 'New group',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Place alumni into year groups',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'School admins can place verified alumni into the right alumni class circle directly.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            value: _selectedYearGroupId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Year group',
                            ),
                            items: _yearGroups
                                .map(
                                  (group) => DropdownMenuItem<int>(
                                    value: int.tryParse('${group['id'] ?? ''}'),
                                    child: Text(
                                      [
                                        group['name']?.toString() ??
                                            'Year group',
                                        if ('${group['graduation_year'] ?? ''}'
                                            .isNotEmpty)
                                          '• ${group['graduation_year']}',
                                      ].join(' '),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedYearGroupId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _selectedAlumniId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Alumni',
                            ),
                            items: _institutionAlumni
                                .map(
                                  (user) => DropdownMenuItem<int>(
                                    value: int.tryParse('${user['id'] ?? ''}'),
                                    child: Text(
                                      _alumniOptionLabel(user),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedAlumniId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed:
                                  _institutionAlumni.isEmpty ||
                                      _yearGroups.isEmpty ||
                                      _assigningYearGroupMember
                                  ? null
                                  : _addAlumniToYearGroup,
                              child: Text(
                                _assigningYearGroupMember
                                    ? 'Adding...'
                                    : 'Add alumni',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _MentorshipSection(
                    title: 'Your class circles',
                    subtitle:
                        'Stay close to alumni in your class year and keep the right introductions flowing.',
                    children: _approvedYearGroups().isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No approved year groups yet',
                              body:
                                  'Once you are approved into a year group, it will show up here.',
                            ),
                          ]
                        : _approvedYearGroups()
                              .map(
                                (group) => _YearGroupCard(
                                  group: group,
                                  statusLabel: 'Member',
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 18),
                  _MentorshipSection(
                    title: 'Pending class-circle requests',
                    subtitle:
                        'Track the graduation circles you have asked to join.',
                    children: _pendingYearGroups().isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No pending year-group requests',
                              body:
                                  'Join a matching year group to keep your alumni cohort close.',
                            ),
                          ]
                        : _pendingYearGroups()
                              .map(
                                (group) => _YearGroupCard(
                                  group: group,
                                  statusLabel: 'Pending',
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 18),
                  _MentorshipSection(
                    title: 'Recommended class circles',
                    subtitle:
                        'Join the class circles that match your school and graduation year.',
                    children: _recommendedYearGroups().isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No recommended year groups',
                              body:
                                  'We will surface matching year groups here once they are available.',
                            ),
                          ]
                        : _recommendedYearGroups()
                              .take(6)
                              .map(
                                (group) => _YearGroupCard(
                                  group: group,
                                  action: FilledButton(
                                    onPressed: _processingYearGroupRequest
                                        ? null
                                        : () => _requestYearGroupJoin(group),
                                    child: const Text('Join'),
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 18),
                  _MentorshipSection(
                    title: 'Alumni requests awaiting you',
                    subtitle:
                        'People asking to connect for guidance, mentoring, or school support.',
                    children: _incomingRequests.isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No incoming mentorship requests',
                              body:
                                  'When someone reaches out for guidance, you will be able to accept or decline here.',
                            ),
                          ]
                        : _incomingRequests
                              .map(
                                (user) => _MentorCard(
                                  user: user,
                                  subtitle: _headline(user),
                                  body: user['message']?.toString(),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _processingRequest
                                            ? null
                                            : () => _respondToRequest(
                                                user,
                                                'rejected',
                                              ),
                                        child: const Text('Decline'),
                                      ),
                                      FilledButton(
                                        onPressed: _processingRequest
                                            ? null
                                            : () => _respondToRequest(
                                                user,
                                                'accepted',
                                              ),
                                        child: const Text('Accept'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 18),
                  _MentorshipSection(
                    title: 'Your alumni circle',
                    subtitle:
                        'People already in your circle who can guide, introduce, and support.',
                    children: _connected.isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No active mentorship circle yet',
                              body:
                                  'Once mentorship requests are accepted, your active circle will show up here.',
                            ),
                          ]
                        : _connected
                              .map(
                                (user) => _MentorCard(
                                  user: user,
                                  subtitle: _headline(user),
                                  trailing: const _StatusChip(label: 'Active'),
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 18),
                  _MentorshipSection(
                    title: 'Alumni requests you sent',
                    subtitle:
                        'Outgoing mentorship requests waiting for the other side to respond.',
                    children: _outgoingRequests.isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No pending outgoing requests',
                              body:
                                  'Reach out to alumni, school leads, and peers you want guidance from.',
                            ),
                          ]
                        : _outgoingRequests
                              .map(
                                (user) => _MentorCard(
                                  user: user,
                                  subtitle: _headline(user),
                                  body: user['message']?.toString(),
                                  trailing: const _StatusChip(label: 'Pending'),
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 18),
                  _MentorshipSection(
                    title: 'Suggested alumni mentors',
                    subtitle:
                        'People from your wider community you can reach out to next.',
                    children: _suggestions.isEmpty
                        ? [
                            _EmptyMentorshipCard(
                              title: 'No suggestions right now',
                              body:
                                  'We will surface more relevant mentors as your network grows.',
                            ),
                          ]
                        : _suggestions
                              .take(8)
                              .map(
                                (user) => _MentorCard(
                                  user: user,
                                  subtitle: _headline(user),
                                  trailing: FilledButton(
                                    onPressed:
                                        _sendingMentorshipIds.contains(
                                          int.tryParse('${user['id'] ?? ''}') ??
                                              -1,
                                        )
                                        ? null
                                        : () => _requestMentorship(user),
                                    child: const Text('Request'),
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Signed in as $_viewerName',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

class _YearGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String? statusLabel;
  final Widget? action;

  const _YearGroupCard({required this.group, this.statusLabel, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts =
        (group['counts'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final gradYear = group['graduation_year']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group['name']?.toString() ?? 'Year group',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (statusLabel != null) _StatusChip(label: statusLabel!),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (gradYear != null && gradYear.isNotEmpty)
                      'Class of $gradYear',
                    '${counts['approved_members'] ?? 0} members',
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if ((group['description'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    group['description'].toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

class _MentorshipSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _MentorshipSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ...children.expand((child) => [child, const SizedBox(height: 12)]),
      ],
    );
  }
}

class _MentorCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String subtitle;
  final Widget? trailing;
  final String? body;

  const _MentorCard({
    required this.user,
    required this.subtitle,
    this.trailing,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatarUrl = user['avatar_url']?.toString();
    final name = (user['name'] ?? 'Member').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (body != null && body!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                body!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyMentorshipCard extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyMentorshipCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final double? width;

  const _HeroStat({required this.label, required this.value, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
