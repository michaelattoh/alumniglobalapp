import 'package:flutter/material.dart';
import 'funding_detail_screen.dart';

class FundingScreen extends StatefulWidget {
  const FundingScreen({super.key});

  @override
  State<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends State<FundingScreen> {
  final TextEditingController searchCtrl = TextEditingController();

  String filterVisibility = 'All';
  String filterCategory = 'All';

  final List<String> categories = [
    'All',
    'Infrastructure',
    'ICT',
    'Library',
    'Sports'
  ];

  final List<String> visibilityOptions = ['All', 'Public', 'Private'];

  final List<Map<String, dynamic>> fundings = [
    {
      "id": 1,
      "title": "New Science Laboratory",
      "school": "Alpha Beta College",
      "goal": 50000,
      "raised": 18500,
      "visibility": "Public",
      "category": "Infrastructure",
      "image":
          "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=800&q=60",
      "description":
          "This project will provide a fully equipped science laboratory for SHS students."
    },
    {
      "id": 2,
      "title": "Library Digital Upgrade",
      "school": "St. Peter’s SHS",
      "goal": 30000,
      "raised": 21000,
      "visibility": "Private",
      "category": "ICT",
      "image":
          "https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=800&q=60",
      "description":
          "Upgrading the school library into a modern digital learning space."
    },
  ];

  /// FILTER
  List<Map<String, dynamic>> get filteredFundings {
    return fundings.where((f) {
      final title = (f['title'] as String).toLowerCase();

      final matchesSearch =
          title.contains(searchCtrl.text.toLowerCase());

      final matchesVisibility =
          filterVisibility == 'All' || f['visibility'] == filterVisibility;

      final matchesCategory =
          filterCategory == 'All' || f['category'] == filterCategory;

      return matchesSearch && matchesVisibility && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            // SEARCH BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search fundraisers…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // FILTERS
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ModernFilterChip(
                    label: filterCategory,
                    icon: Icons.category_rounded,
                    options: categories,
                    onSelected: (v) =>
                        setState(() => filterCategory = v),
                  ),
                  const SizedBox(width: 12),
                  _ModernFilterChip(
                    label: filterVisibility,
                    icon: Icons.visibility_rounded,
                    options: visibilityOptions,
                    onSelected: (v) =>
                        setState(() => filterVisibility = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // FUNDING LIST
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 800));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: filteredFundings.length,
                  itemBuilder: (_, i) {
                    final fund = filteredFundings[i];
                    final percent =
                        (fund['raised'] / fund['goal']).clamp(0.0, 1.0);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FundingDetailScreen(fund: fund),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              color: Colors.black.withOpacity(0.05),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // IMAGE
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                              child: Image.network(
                                fund['image'],
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fund['title'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _VisibilityBadge(
                                          visibility: fund['visibility']),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    fund['school'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: percent,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.grey.shade200,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "₵${fund['raised']} raised of ₵${fund['goal']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _ModernFilterChip({
    required this.label,
    required this.icon,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => options
          .map(
            (e) => PopupMenuItem(
              value: e,
              child: Text(e),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}


class _VisibilityBadge extends StatelessWidget {
  final String visibility;

  const _VisibilityBadge({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final isPrivate = visibility == 'Private';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPrivate
              ? [Colors.orange, Colors.deepOrangeAccent]
              : [Colors.green, Colors.teal],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        visibility,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
