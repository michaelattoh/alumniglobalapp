import 'package:flutter/material.dart';

class MentionSuggestionBox extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const MentionSuggestionBox({
    super.key,
    required this.users,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (users.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
        itemBuilder: (_, index) {
          final user = users[index];
          final avatarUrl = user['avatar_url']?.toString();
          final name = (user['name'] ?? 'Member').toString();
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? null
                  : Text(
                      name.isEmpty ? '@' : name[0].toUpperCase(),
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            title: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '@${name.toLowerCase().replaceAll(' ', '')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            onTap: () => onSelected(user),
          );
        },
      ),
    );
  }
}
