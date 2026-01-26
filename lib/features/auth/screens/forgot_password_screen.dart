import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _emailError = null;
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = 'Please enter your email.';
      } else if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$')
          .hasMatch(email)) {
        _emailError = 'Please enter a valid email.';
      }
    });

    if (_emailError != null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('If this email exists, a reset link has been sent.'),
        ),
      );
      Navigator.of(context).pop(); // go back to login
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        title: Text(
          'Forgot password',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
                    'Reset your password',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the email you use for your alumni account and we\'ll send you a reset link.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Email',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      setState(() => _emailError = null);
                    },
                    decoration: InputDecoration(
                      hintText: 'you@email.com',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Send reset link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
