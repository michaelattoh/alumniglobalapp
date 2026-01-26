import 'package:flutter/material.dart';
import 'job_apply_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  Widget section(String title, dynamic content) {
    if (content == null || (content is List && content.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          if (content is List)
            ...content.map<Widget>((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $e'),
                ))
          else
            Text(content.toString()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: Text(job['title'])),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job['companyName'],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(job['location']),
                const SizedBox(height: 16),
                section('Overview', job['overview']),
                section('Job Description', job['description']),
                section('What You’re Expected To Do', job['expectations']),
                section('Requirements', job['requirements']),
                section('Salary', job['salary']),
                section('Company Overview', job['companyOverview']),
              ],
            ),
          ),

          // APPLY
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobApplyScreen(
                        jobId: job['id'].toString(),
                        jobTitle: job['title'],
                        companyName: job['companyName'],
                      ),
                    ),
                  );
                },
                child: const Text('Apply Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
