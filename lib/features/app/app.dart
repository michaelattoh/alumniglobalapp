import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/app/auth_gate_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/role_details_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/check_email_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/search_screens.dart';
import '../../features/home/screens/messages_screen.dart';
import '../../features/home/screens/analytics_screen.dart';
import '../../features/home/screens/events_screen.dart';
import '../../features/home/screens/settings_screen.dart';
import '../../features/home/screens/payments_screen.dart';
import '../../features/home/screens/profile_screen.dart';
import '../../features/home/screens/jobs_screen.dart';
import '../../features/home/screens/mentorship_screen.dart';
import '../../features/home/screens/saved_posts_screen.dart';
import '../../features/home/screens/hidden_posts_screen.dart';
import '../../features/home/screens/muted_users_screen.dart';
import '../../features/home/screens/post_detail_screen.dart';
import '../../features/home/screens/support_screen.dart';
import '../../features/home/screens/scheduled_posts_screen.dart';
import '../../features/home/screens/institution_profile_screen.dart';
import '../../features/home/screens/announcement_create_screen.dart';
import '../../features/home/screens/payment_settings_screen.dart';
import '../../features/home/screens/email_settings_screen.dart';
import '../../features/home/screens/ad_create_screen.dart';
import '../../features/home/screens/ad_webview_screen.dart';
import '../../features/home/screens/user_profile_screen.dart';
import '../../core/services/app_navigator.dart';
import '../../features/home/screens/institution_profile_setup_screen.dart';

class AlumniGlobalApp extends StatelessWidget {
  const AlumniGlobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightBase = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );

    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      title: 'Alumni Global Network',
      debugShowCheckedModeBanner: false,
      theme: lightBase.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        textTheme: GoogleFonts.poppinsTextTheme(lightBase.textTheme),
      ),
      initialRoute: '/auth-gate',
      routes: {
        '/auth-gate': (_) => const AuthGateScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/role-details': (_) => const RoleDetailsScreen(),
        '/home': (_) => const HomeScreen(),
        '/search': (_) => const SearchScreen(),
        '/messages': (_) => const MessagesScreen(),
        '/analytics': (_) => const AnalyticsScreen(),
        '/events': (_) => const EventsScreen(),
        '/create-event': (_) => const CreateEventScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/payments': (_) => const PaymentsScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/jobs': (_) => const JobsScreen(),
        '/mentorship': (_) => const MentorshipScreen(),
        '/saved-posts': (_) => const SavedPostsScreen(),
        '/hidden-posts': (_) => const HiddenPostsScreen(),
        '/muted-users': (_) => const MutedUsersScreen(),
        '/scheduled-posts': (_) => const ScheduledPostsScreen(),
        '/support': (_) => const SupportScreen(),
        '/create-announcement': (_) => const AnnouncementCreateScreen(),
        '/payment-settings': (_) => const PaymentSettingsScreen(),
        '/email-settings': (_) => const EmailSettingsScreen(),
        '/create-ad': (_) => const AdCreateScreen(),
        '/institution-profile-setup': (_) =>
            const InstitutionProfileSetupScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/check-email') {
          final email = settings.arguments is String
              ? settings.arguments as String
              : '';
          return MaterialPageRoute(
            builder: (_) => CheckEmailScreen(email: email),
            settings: settings,
          );
        }
        if (settings.name == '/user-profile') {
          final args = settings.arguments;
          int userId = 0;
          if (args is Map) {
            final rawId = args['id'];
            if (rawId is int) {
              userId = rawId;
            } else if (rawId is String) {
              userId = int.tryParse(rawId) ?? 0;
            }
          } else if (args is int) {
            userId = args;
          }
          return MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId),
            settings: settings,
          );
        }
        if (settings.name == '/ad-webview') {
          final args = settings.arguments;
          String url = '';
          String? title;
          if (args is Map) {
            url = args['url']?.toString() ?? '';
            title = args['title']?.toString();
          }
          return MaterialPageRoute(
            builder: (_) => AdWebviewScreen(url: url, title: title),
            settings: settings,
          );
        }
        if (settings.name == '/institution-profile') {
          final args = settings.arguments;
          int institutionId = 0;
          String? institutionName;
          if (args is Map) {
            final rawId = args['id'];
            if (rawId is int) {
              institutionId = rawId;
            } else if (rawId is String) {
              institutionId = int.tryParse(rawId) ?? 0;
            }
            institutionName = args['name']?.toString();
          }
          return MaterialPageRoute(
            builder: (_) => InstitutionProfileScreen(
              institutionId: institutionId,
              institutionName: institutionName,
            ),
            settings: settings,
          );
        }
        if (settings.name == '/post-detail') {
          int postId = 0;
          Map<String, dynamic>? post;
          if (settings.arguments is int) {
            postId = settings.arguments as int;
          } else if (settings.arguments is Map) {
            final args = settings.arguments as Map;
            final rawId = args['postId'];
            if (rawId is int) {
              postId = rawId;
            } else if (rawId is String) {
              postId = int.tryParse(rawId) ?? 0;
            }
            post = args['post'] is Map
                ? Map<String, dynamic>.from(args['post'] as Map)
                : null;
          }
          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId, initialPost: post),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
