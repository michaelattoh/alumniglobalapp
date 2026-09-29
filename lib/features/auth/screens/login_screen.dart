import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:alumni_global_app/core/config/api_config.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';
import 'package:alumni_global_app/core/services/biometric_service.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/services/push_token_service.dart';
import 'package:alumni_global_app/core/widgets/pin_dialog.dart';
import './models/user_type.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  UserType _selectedType = UserType.alumni;
  bool _showPassword = false;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  String? _biometricRole;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final enabled = await AuthSession.getBiometricsEnabled();
    final available = await BiometricService.isAvailable();
    final role = await AuthSession.getBiometricRole();
    if (!mounted) return;
    setState(() {
      _biometricsEnabled = enabled;
      _biometricsAvailable = available;
      _biometricRole = role;
    });
  }

  Future<void> _tryBiometricLogin({bool silent = false}) async {
    if (!_biometricsEnabled || !_biometricsAvailable) return;
    final token = await AuthSession.getToken();
    if (token == null || token.isEmpty) return;
    final expectedRole = _selectedType == UserType.school
        ? 'institution_admin'
        : 'alumni';
    if (_biometricRole != null && _biometricRole != expectedRole) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric login is set up for another account type.',
            ),
          ),
        );
      }
      return;
    }
    if (!silent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Authenticating...')));
    }
    final ok = await BiometricService.authenticate();
    if (!ok) {
      final pinOk = await showPinVerifyDialog(
        context,
        verify: (pin) => AuthSession.verifyPin(pin),
      );
      if (!pinOk) return;
    }
    Map<String, dynamic>? me;
    try {
      me = await HomeApiService.fetchMe();
    } catch (_) {
      me = null;
    }
    if (!mounted) return;
    if (me == null || me.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToSignup() {
    Navigator.of(context).pushReplacementNamed('/signup');
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required')),
      );
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = body['token']?.toString();
        if (token == null || token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login succeeded but token missing')),
          );
          return;
        }

        TextInput.finishAutofillContext(shouldSave: true);
        await _handleAuthSuccess(body);
        return;
      }
      if (response.statusCode == 403 &&
          body['requires_email_verification'] == true) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Verify your email'),
            content: const Text(
              'Please verify your email address to continue. Check your inbox for the verification link.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final emailToUse = _emailController.text.trim();
                  final ok = await HomeApiService.resendVerificationEmail(
                    emailToUse,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Verification email sent.'
                            : 'Unable to send email.',
                      ),
                    ),
                  );
                },
                child: const Text('Resend'),
              ),
            ],
          ),
        );
        return;
      }

      final message = body['message']?.toString() ?? 'Login failed';
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> body) async {
    final token = body['token']?.toString();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login succeeded but token missing')),
      );
      return;
    }

    await AuthSession.saveToken(token);
    final user = body['user'] as Map<String, dynamic>?;
    final userId = (user?['id'] as num?)?.toInt();
    if (userId != null) {
      await AuthSession.saveUserId(userId);
    }
    if (!mounted) return;

    final resolved = user ?? {};
    HomeApiService.cacheMe(resolved);
    final role = resolved['role']?.toString();
    final institution = resolved['institution'] as Map<String, dynamic>?;
    final hasInstitution =
        institution?['id'] != null || resolved['institution_id'] != null;

    if (role == 'institution_admin' && !hasInstitution) {
      Navigator.of(context).pushNamed(
        '/role-details',
        arguments: {'type': UserType.school, 'token': token, 'user': user},
      );
      return;
    }

    if (role == 'alumni' && !hasInstitution) {
      Navigator.of(context).pushNamed(
        '/role-details',
        arguments: {'type': UserType.alumni, 'token': token, 'user': resolved},
      );
      return;
    }
    if (role != null && role.isNotEmpty) {
      await AuthSession.saveRole(role);
    }
    unawaited(PushTokenService.register());

    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _onTypeSelected(UserType type) {
    if (_selectedType == type) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back 👋',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in as an alumni or a school to stay connected.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),

                    SizedBox(height: media.size.height * 0.03),

                    Text('I am a', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 10),
                    _buildUserTypeToggle(),

                    SizedBox(height: media.size.height * 0.03),

                    Text('Email', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        context,
                        hintText: 'you@email.com',
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text('Password', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitLogin(),
                      decoration: _inputDecoration(
                        context,
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/forgot-password');
                        },
                        child: Text(
                          'Forgot password?',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Log in',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (_biometricsEnabled &&
                        _biometricsAvailable &&
                        (_biometricRole == null ||
                            _biometricRole ==
                                (_selectedType == UserType.school
                                    ? 'institution_admin'
                                    : 'alumni'))) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _tryBiometricLogin(),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Use biometrics'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New here?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        TextButton(
                          onPressed: _goToSignup,
                          child: Text(
                            'Create an account',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // big toggle with slide + gradient + icons
  Widget _buildUserTypeToggle() {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final thumbWidth = (totalWidth - 8) / 2;

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!, width: 1.3),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                left: _selectedType == UserType.alumni ? 0 : thumbWidth + 4,
                top: 0,
                bottom: 0,
                width: thumbWidth,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.75),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTypeSelected(UserType.alumni),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: theme.textTheme.labelLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _selectedType == UserType.alumni
                                  ? Colors.white
                                  : Colors.grey[800],
                            ),
                            child: const Text('👨‍🎓  Alumni'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTypeSelected(UserType.school),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: theme.textTheme.labelLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _selectedType == UserType.school
                                  ? Colors.white
                                  : Colors.grey[800],
                            ),
                            child: const Text('🏫  School'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
      ),
    );
  }
}
