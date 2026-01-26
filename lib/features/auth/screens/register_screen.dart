import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './models/user_type.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  double _passwordStrength = 0.0;
  String _passwordLabel = 'Enter a password';
  Color _passwordColor = Colors.grey;

  UserType _selectedType = UserType.alumni;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _onTypeSelected(UserType type) {
    if (_selectedType == type) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedType = type;
    });
  }

  void _onPasswordChanged(String value) {
    final result = _calculatePasswordStrength(value);
    setState(() {
      _passwordStrength = result.strength;
      _passwordLabel = result.label;
      _passwordColor = result.color;
    });
  }

  _PasswordStrengthResult _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      return _PasswordStrengthResult(
        strength: 0.0,
        label: 'Enter a password',
        color: Colors.grey,
      );
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password)) score++;

    final strength = (score / 4).clamp(0.0, 1.0);
    String label;
    Color color;

    if (strength <= 0.25) {
      label = 'Very weak';
      color = Colors.red;
    } else if (strength <= 0.5) {
      label = 'Weak';
      color = Colors.orange;
    } else if (strength <= 0.75) {
      label = 'Good';
      color = Colors.blue;
    } else {
      label = 'Strong';
      color = Colors.green;
    }

    return _PasswordStrengthResult(
      strength: strength,
      label: label,
      color: color,
    );
  }

  void _submitCreateAccount() {
    // TODO: validate + send to backend
    Navigator.of(context).pushNamed(
      '/role-details',
      arguments: _selectedType,
    );
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
                    'Create account ✨',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up as an alumni or a school to join the network.',
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

                  Text('Full name', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _fullNameController,
                    hintText: 'Ama Mensah',
                  ),
                  const SizedBox(height: 16),

                  Text('Email', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _emailController,
                    hintText: 'you@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  Text('Phone number', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _phoneController,
                    hintText: '+233 24 000 0000',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  Text('Password', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: _onPasswordChanged,
                    decoration: _inputDecoration(
                      hintText: 'Create a strong password',
                    ),
                  ),

                  const SizedBox(height: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.grey[300],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _passwordStrength,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: _passwordColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _passwordLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _passwordColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text('Confirm password', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _buildInputField(
                    controller: _confirmPasswordController,
                    hintText: 'Re-enter your password',
                    obscureText: true,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitCreateAccount,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Create account'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      TextButton(
                        onPressed: _goToLogin,
                        child: Text(
                          'Log in',
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: _inputDecoration(hintText: hintText),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
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
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(
          color: Colors.blue,
          width: 1.4,
        ),
      ),
    );
  }
}

class _PasswordStrengthResult {
  final double strength;
  final String label;
  final Color color;

  _PasswordStrengthResult({
    required this.strength,
    required this.label,
    required this.color,
  });
}
