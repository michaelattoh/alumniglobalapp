import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  String? invitationStatusMessage;

  final List<_NetworkUser> connectionRequests = [
    _NetworkUser(
      name: 'Akosua Mensah',
      subtitle: 'UX Designer • University of Ghana',
      mutuals: 12,
    ),
    _NetworkUser(
      name: 'Kwame Boateng',
      subtitle: 'Software Engineer • Ashesi University',
      mutuals: 8,
    ),
  ];

  final List<_NetworkUser> suggestions = [
    _NetworkUser(
      name: 'Ama Serwaa',
      subtitle: 'Marketing Lead • KNUST',
      mutuals: 5,
    ),
    _NetworkUser(
      name: 'Yaw Osei',
      subtitle: 'Data Analyst • Alpha Beta College',
      mutuals: 3,
    ),
    _NetworkUser(
      name: 'Rixrod Alumni Group',
      subtitle: 'Group • Technology & Innovation',
      mutuals: 120,
      isGroup: true,
    ),
  ];

  Future<void> _refreshNetwork() async {
    await Future.delayed(const Duration(milliseconds: 800));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshNetwork,
          displacement: 60,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Invitations'),

              if (invitationStatusMessage != null) ...[
                const SizedBox(height: 8),
                _inlineStatus(invitationStatusMessage!),
              ],

              const SizedBox(height: 12),

              if (connectionRequests.isEmpty)
                _emptyState('No new invitations'),

              ...connectionRequests.map(
                (user) => _buildInvitationCard(user),
              ),

              const SizedBox(height: 28),
              _sectionTitle('People & groups you may know'),
              const SizedBox(height: 12),

              ...suggestions.map(
                (user) => _buildSuggestionCard(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
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
          const Icon(Icons.check_circle,
              color: Color(0xFF2563EB), size: 18),
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

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  // ---------------- INVITATIONS ----------------

  Widget _buildInvitationCard(_NetworkUser user) {
    return _NetworkCard(
      user: user,
      actions: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  connectionRequests.remove(user);
                });
                _setInvitationMessage(
                    'You are now connected with ${user.name}');
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
                setState(() {
                  connectionRequests.remove(user);
                });
                _setInvitationMessage(
                    'You ignored the request from ${user.name}');
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
      actions: SizedBox(
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
                  setState(() {
                    user.isPending = true;
                  });
                  _setInvitationMessage(
                    user.isGroup
                        ? 'You joined ${user.name}'
                        : 'Connection request sent to ${user.name}',
                  );
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
    );
  }
}

// ---------------- CARD WIDGET ----------------

class _NetworkCard extends StatelessWidget {
  final _NetworkUser user;
  final Widget actions;

  const _NetworkCard({
    required this.user,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Icon(
              user.isGroup ? Icons.groups_rounded : Icons.person_rounded,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${user.mutuals} mutual connections',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 10),
                actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- MODEL ----------------

class _NetworkUser {
  final String name;
  final String subtitle;
  final int mutuals;
  final bool isGroup;
  bool isPending = false;

  _NetworkUser({
    required this.name,
    required this.subtitle,
    required this.mutuals,
    this.isGroup = false,
  });
}
