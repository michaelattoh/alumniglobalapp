import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  String? invitationStatusMessage;
  bool _loading = true;
  bool _loadingSuggestions = true;

  final List<_NetworkUser> connectionRequests = [];
  final List<_NetworkUser> suggestions = [];

  @override
  void initState() {
    super.initState();
    _refreshNetwork();
  }

  Future<void> _refreshNetwork() async {
    setState(() {
      _loading = true;
      _loadingSuggestions = true;
    });

    final me = await HomeApiService.fetchMe();
    final currentUserId =
        (me?['id'] as num?)?.toInt() ?? await AuthSession.getUserId();
    final connections = await HomeApiService.fetchConnections();
    if (!mounted) return;

    final received =
        (connections['received'] as List<Map<String, dynamic>>?) ?? [];
    final sent = (connections['sent'] as List<Map<String, dynamic>>?) ?? [];
    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final sentTargetIds = sent
        .map((e) => asInt((e['to_user'] as Map<String, dynamic>?)?['id']))
        .whereType<int>()
        .toSet();
    final connectedUserIds = <int>{
      ...sent
          .where((e) => e['status']?.toString() == 'accepted')
          .map((e) => asInt((e['to_user'] as Map<String, dynamic>?)?['id']))
          .whereType<int>(),
      ...received
          .where((e) => e['status']?.toString() == 'accepted')
          .map((e) => asInt((e['from_user'] as Map<String, dynamic>?)?['id']))
          .whereType<int>(),
    };
    final pendingUserIds = <int>{
      ...sentTargetIds,
      ...received
          .where((e) => e['status']?.toString() == 'pending')
          .map((e) => asInt((e['from_user'] as Map<String, dynamic>?)?['id']))
          .whereType<int>(),
    };

    setState(() {
      connectionRequests
        ..clear()
        ..addAll(
          received.where((e) => e['status'] == 'pending').map((e) {
            final from = (e['from_user'] as Map<String, dynamic>?) ?? {};
            return _NetworkUser(
              connectionId: (e['id'] as num?)?.toInt(),
              userId: (from['id'] as num?)?.toInt(),
              name: (from['name'] ?? '').toString(),
              subtitle: '',
              avatarUrl: HomeApiService.normalizeMediaUrl(
                from['avatar_url']?.toString(),
              ),
              mutuals: 0,
            );
          }),
        );
      _loading = false;
    });

    final recsFuture = HomeApiService.fetchRecommendations(
      type: 'connection',
      perPage: 12,
    );
    final suggestionsFuture = HomeApiService.fetchDirectorySuggestions();
    final results = await Future.wait([recsFuture, suggestionsFuture]);
    if (!mounted) return;
    final recs = results[0] as Map<String, dynamic>;
    final suggestionRows = results[1] as List<Map<String, dynamic>>;

    final recRows = (recs['data'] as List<Map<String, dynamic>>?) ?? [];
    final recommendedUsers = recRows
        .map((r) {
          final entity = (r['entity'] as Map<String, dynamic>?) ?? {};
          if (entity.isEmpty) return null;
          final program = (entity['profile']?['program'] ?? '').toString();
          final location = (entity['profile']?['location'] ?? '').toString();
          final subtitle = [
            program,
            location,
          ].where((v) => v.isNotEmpty).join(' • ');
          final avatarUrl = HomeApiService.normalizeMediaUrl(
            entity['profile']?['avatar_url']?.toString() ??
                entity['avatar_url']?.toString(),
          );
          return _NetworkUser(
            recommendationId: (r['id'] as num?)?.toInt(),
            recommendationReason: _normalizeRecommendationReason(
              (r['reason'] ?? '').toString(),
            ),
            userId: (entity['id'] as num?)?.toInt(),
            name: (entity['name'] ?? '').toString(),
            subtitle: subtitle,
            avatarUrl: avatarUrl,
            mutuals: 0,
          );
        })
        .whereType<_NetworkUser>()
        .toList();

    setState(() {
      suggestions
        ..clear()
        ..addAll(
          (recommendedUsers.isNotEmpty
                  ? recommendedUsers
                  : suggestionRows.map((e) {
                      final program = (e['program'] ?? '').toString();
                      final location = (e['location'] ?? '').toString();
                      final subtitle = [
                        program,
                        location,
                      ].where((v) => v.isNotEmpty).join(' • ');
                      return _NetworkUser(
                        userId: (e['id'] as num?)?.toInt(),
                        name: (e['name'] ?? '').toString(),
                        subtitle: subtitle,
                        avatarUrl: HomeApiService.normalizeMediaUrl(
                          e['avatar_url']?.toString(),
                        ),
                        mutuals: 0,
                      );
                    }).toList())
              .where(
                (u) =>
                    u.userId != null &&
                    !pendingUserIds.contains(u.userId) &&
                    !connectedUserIds.contains(u.userId) &&
                    u.userId != currentUserId,
              )
              .take(12),
        );
      _loadingSuggestions = false;
    });
  }

  String _normalizeRecommendationReason(String reason) {
    final normalized = reason.trim().toLowerCase();
    if (normalized == 'same institution') {
      return 'Shared alumni context';
    }
    return reason;
  }

  void _setInvitationMessage(String message) {
    setState(() {
      invitationStatusMessage = message;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => invitationStatusMessage = null);
      }
    });
  }

  Future<void> _respondInvitation(_NetworkUser user, String status) async {
    if (user.connectionId == null) return;
    final ok = await HomeApiService.respondConnection(
      connectionId: user.connectionId!,
      status: status,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => connectionRequests.remove(user));
      _setInvitationMessage(
        status == 'accepted'
            ? 'You are now connected with ${user.name}'
            : 'You ignored the request from ${user.name}',
      );
    } else {
      _setInvitationMessage('Could not update request. Please try again.');
    }
  }

  Future<void> _connectSuggestion(_NetworkUser user) async {
    if (user.userId == null || user.isPending) return;
    final ok = await HomeApiService.sendConnection(user.userId!);
    if (!mounted) return;
    if (ok) {
      if (user.recommendationId != null) {
        HomeApiService.sendRecommendationFeedback(
          recommendationId: user.recommendationId!,
          action: 'clicked',
        );
      }
      setState(() => user.isPending = true);
      _setInvitationMessage('Connection request sent to ${user.name}');
    } else {
      _setInvitationMessage('Could not send connection request.');
    }
  }

  void _dismissSuggestion(_NetworkUser user) {
    if (user.recommendationId != null) {
      HomeApiService.sendRecommendationFeedback(
        recommendationId: user.recommendationId!,
        action: 'dismissed',
      );
    }
    setState(() => suggestions.remove(user));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshNetwork,
          displacement: 60,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16, isCompact ? 20 : 16, 16, 16),
            children: [
              _heroCard(),
              const SizedBox(height: 22),
              _sectionTitle('Invitations'),

              if (invitationStatusMessage != null) ...[
                const SizedBox(height: 8),
                _inlineStatus(invitationStatusMessage!),
              ],

              const SizedBox(height: 12),

              if (connectionRequests.isEmpty)
                _loading
                    ? _loadingCard()
                    : _emptyState(
                        'No new invitations',
                        subtitle:
                            'When alumni or schools connect with you, the requests will show here.',
                      ),

              ...connectionRequests.map((user) => _buildInvitationCard(user)),

              const SizedBox(height: 28),
              _sectionTitle('People & groups you may know'),
              const SizedBox(height: 12),

              if (_loadingSuggestions) _loadingCard(),
              if (!_loadingSuggestions)
                ...suggestions.map((user) => _buildSuggestionCard(user)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    );
  }

  Widget _heroCard() {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
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
            width: isCompact ? 42 : 48,
            height: isCompact ? 42 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white),
          ),
          SizedBox(height: isCompact ? 14 : 18),
          Text(
            'Grow your network',
            style: TextStyle(
              fontSize: isCompact ? 24 : 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay on top of invitations and discover alumni worth connecting with.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineStatus(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Text(text, style: TextStyle(color: Colors.grey[600])),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- INVITATIONS ----------------

  Widget _buildInvitationCard(_NetworkUser user) {
    return _NetworkCard(
      user: user,
      onTap: () {
        if (user.userId == null) return;
        Navigator.of(
          context,
        ).pushNamed('/user-profile', arguments: {'id': user.userId});
      },
      actions: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _respondInvitation(user, 'accepted');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Accept'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _respondInvitation(user, 'rejected');
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Ignore'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SUGGESTIONS ----------------

  Widget _buildSuggestionCard(_NetworkUser user) {
    return _NetworkCard(
      user: user,
      onTap: () {
        if (user.userId == null) return;
        Navigator.of(
          context,
        ).pushNamed('/user-profile', arguments: {'id': user.userId});
      },
      actions: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: user.isPending
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Pending'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (user.isGroup) return;
                      _connectSuggestion(user);
                    },
                    icon: Icon(
                      user.isGroup
                          ? Icons.group_add_rounded
                          : Icons.person_add_alt_1_rounded,
                    ),
                    label: Text(user.isGroup ? 'Join group' : 'Connect'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
          ),
          if (user.recommendationId != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _dismissSuggestion(user),
              child: const Text('Not interested'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------- CARD WIDGET ----------------

class _NetworkCard extends StatelessWidget {
  final _NetworkUser user;
  final Widget actions;
  final VoidCallback? onTap;

  const _NetworkCard({required this.user, required this.actions, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage:
                  user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? null
                  : Icon(
                      user.isGroup
                          ? Icons.groups_rounded
                          : Icons.person_rounded,
                      color: const Color(0xFF4B5563),
                      size: 28,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (user.recommendationReason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${user.recommendationReason}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${user.mutuals} mutual connections',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  actions,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- MODEL ----------------

class _NetworkUser {
  final int? userId;
  final int? connectionId;
  final int? recommendationId;
  final String recommendationReason;
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final int mutuals;
  final bool isGroup;
  bool isPending = false;

  _NetworkUser({
    this.userId,
    this.connectionId,
    this.recommendationId,
    this.recommendationReason = '',
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    required this.mutuals,
    this.isGroup = false,
  });
}
