import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class MutedUsersScreen extends StatefulWidget {
  const MutedUsersScreen({super.key});

  @override
  State<MutedUsersScreen> createState() => _MutedUsersScreenState();
}

class _MutedUsersScreenState extends State<MutedUsersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMuted();
  }

  Future<void> _loadMuted() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await HomeApiService.fetchMutedUsers();
      if (!mounted) return;
      setState(() {
        _rows = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load muted users');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _heroCard(),
                  const SizedBox(height: 28),
                  Center(child: Text(_error!)),
                ],
              )
            : _rows.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _heroCard(),
                  const SizedBox(height: 28),
                  const Center(child: Text('No muted users')),
                ],
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _rows.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (i == 0) return _heroCard();
                  final mutedIndex = i - 1;
                  final row = _rows[mutedIndex];
                  final user =
                      (row['muted_user'] as Map<String, dynamic>?) ?? {};
                  final id = (user['id'] as num?)?.toInt();
                  final name = (user['name'] ?? 'User').toString();
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE5E7EB),
                          child: Icon(
                            Icons.person_rounded,
                            color: Color(0xFF4B5563),
                          ),
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
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Muted from your feed and updates',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (id != null)
                          TextButton(
                            onPressed: () async {
                              final ok = await HomeApiService.unmuteUser(id);
                              if (!mounted) return;
                              if (ok) {
                                setState(() => _rows.removeAt(mutedIndex));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unable to unmute'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Unmute'),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.volume_off_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Muted users',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage people you have muted and restore them when you want them back in your network flow.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
