import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Stay Connected',
      subtitle: 'All your JHS, SHS and tertiary alumni in one simple app.',
      icon: Icons.hub_rounded,
    ),
    _OnboardingPageData(
      title: 'Join Your Alumni',
      subtitle: 'Find your school, year group and official alumni communities.',
      icon: Icons.school_rounded,
    ),
    _OnboardingPageData(
      title: 'Grow & Support',
      subtitle: 'Fund projects, attend events and unlock opportunities.',
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  void _goNext() {
    if (_currentPage == _pages.length - 1) {
      _goToLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Alumni Global',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _goToLogin,
                    child: Text(
                      'Skip',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: media.size.height * 0.02),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            page.icon,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: isActive ? 18 : 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
