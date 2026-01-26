import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToSignup() {
    Navigator.of(context).pushReplacementNamed('/signup');
  }

  void _submitLogin() {
    // TODO: validate + call backend
    Navigator.of(context).pushNamed(
      '/role-details',
      arguments: _selectedType,
    );
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

                  Text(
                    'I am a',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  _buildUserTypeToggle(),

                  SizedBox(height: media.size.height * 0.03),

                  Text(
                    'Email',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      context,
                      hintText: 'you@email.com',
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Password',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecoration(
                      context,
                      hintText: '••••••••',
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Log in'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'or',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Social login
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        side: BorderSide(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      child: const Text('Continue with Google'),
                    ),
                  ),

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
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1.3,
            ),
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
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.4,
        ),
      ),
    );
  }
}
