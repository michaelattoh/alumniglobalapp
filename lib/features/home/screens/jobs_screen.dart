import 'package:flutter/material.dart';
import 'job_detail_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String activeFilter = 'All';

  final filters = ['All', 'Tech', 'Design', 'Marketing', 'Remote'];

  final List<Map<String, dynamic>> jobs = [
    {
      "id": 1,
      "title": "Flutter Developer",
      "category": "Tech",
      "companyName": "Verix Teams",
      "location": "Remote",
      "salary": "₵8,000 – ₵12,000",
      "overview":
          "Join a fast-growing product team building scalable platforms.",
      "description":
          "You will work closely with designers and backend engineers.",
      "expectations": [
        "Build Flutter apps",
        "Integrate APIs",
        "Write clean code",
      ],
      "requirements": [
        "Flutter & Dart",
        "REST APIs",
        "Git",
      ],
      "companyOverview":
          "Verix Teams builds modern digital solutions across Africa.",
    },
    {
      "id": 2,
      "title": "UI/UX Designer",
      "category": "Design",
      "companyName": "Alpha Beta College",
      "location": "Accra",
      "salary": "₵5,000 – ₵7,000",
      "overview":
          "Design intuitive user experiences for education platforms.",
      "description":
          "You will lead UI design across web and mobile products.",
      "expectations": [
        "Create wireframes",
        "User research",
        "Collaborate with devs",
      ],
      "requirements": [
        "Figma",
        "UX research",
        "Design systems",
      ],
      "companyOverview":
          "Alpha Beta College is a leading private institution.",
    },
  ];

  List<Map<String, dynamic>> get filteredJobs {
    return jobs.where((job) {
      final matchesFilter =
          activeFilter == 'All' || job['category'] == activeFilter;
      final matchesSearch = job['title']
          .toLowerCase()
          .contains(_searchCtrl.text.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            // SEARCH
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search jobs',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // FILTERS
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = filters[i];
                  final active = f == activeFilter;
                  return ChoiceChip(
                    label: Text(f),
                    selected: active,
                    onSelected: (_) => setState(() => activeFilter = f),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // JOB LIST
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    await Future.delayed(const Duration(milliseconds: 600)),
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filteredJobs.length,
                  itemBuilder: (_, i) {
                    final job = filteredJobs[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(job: job),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(job['companyName'],
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(job['location'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
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
