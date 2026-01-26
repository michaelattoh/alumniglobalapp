import 'package:flutter/material.dart';
import 'funding_donate_screen.dart';

class FundingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> fund;

  const FundingDetailScreen({super.key, required this.fund});

  @override
  Widget build(BuildContext context) {
    final progress = (fund['raised'] / fund['goal']).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(fund['title'])),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    fund['image'],
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  fund['school'],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                ),

                const SizedBox(height: 8),
                Text(
                  "₵${fund['raised']} raised of ₵${fund['goal']}",
                  style: const TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 24),
                const Text(
                  "About this project",
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  fund['description'],
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),

          // DONATE BUTTON
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FundingDonateScreen(fund: fund),
                    ),
                  );
                },
                child: const Text("Donate"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
