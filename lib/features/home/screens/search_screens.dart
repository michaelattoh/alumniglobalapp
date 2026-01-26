import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        title: Text(
          'Search',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search alumni, schools, jobs…',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Text(
                  'Search results will appear here',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
