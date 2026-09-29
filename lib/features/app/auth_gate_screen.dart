import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';
import 'package:alumni_global_app/core/services/push_token_service.dart';
import 'package:alumni_global_app/features/home/screens/home_screen.dart';
import 'package:alumni_global_app/features/onboarding/screens/onboarding_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  late final Future<bool> _hasTokenFuture;

  @override
  void initState() {
    super.initState();
    _hasTokenFuture = _boot();
  }

  Future<bool> _boot() async {
    final token = await AuthSession.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      unawaited(PushTokenService.register());
    } catch (_) {
      // Push registration should never block app startup.
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: FutureBuilder<bool>(
        future: _hasTokenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final hasToken = snapshot.data ?? false;
          return hasToken ? const HomeScreen() : const OnboardingScreen();
        },
      ),
    );
  }
}
