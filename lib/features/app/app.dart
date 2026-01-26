import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/role_details_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/search_screens.dart';
import '../../features/home/screens/messages_screen.dart';
import '../../features/home/screens/analytics_screen.dart';

class AlumniGlobalApp extends StatelessWidget {
  const AlumniGlobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Alumni Global Network',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      ),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/role-details': (_) => const RoleDetailsScreen(),
        '/home': (_) => const HomeScreen(),
        '/search': (_) => const SearchScreen(),
        '/messages': (_) => const MessagesScreen(),
        '/analytics': (_) => const AnalyticsScreen(),
      },
    );
  }
}
