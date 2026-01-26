import 'dart:io';
import 'package:flutter/material.dart';

class CVPreviewScreen extends StatelessWidget {
  final File file;

  const CVPreviewScreen({required this.file, super.key});

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split('/').last;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('CV Preview',
            style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('View'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Looks good'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
