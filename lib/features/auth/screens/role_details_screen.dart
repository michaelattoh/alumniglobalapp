import 'dart:math';
import 'package:flutter/material.dart';
import './models/user_type.dart';

class RoleDetailsScreen extends StatefulWidget {
  const RoleDetailsScreen({super.key});

  @override
  State<RoleDetailsScreen> createState() => _RoleDetailsScreenState();
}

class _RoleDetailsScreenState extends State<RoleDetailsScreen> {
  // Alumni controllers
  final TextEditingController _alumniSchoolController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();

  // School controllers
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolIdController = TextEditingController();

  // Registered schools for demo
  final List<String> _registeredSchools = [
    'Alpha Beta College',
  ];
  List<String> _suggestions = [];

  // Validation errors
  String? _alumniSchoolError;
  String? _alumniStudentIdError;
  String? _schoolNameError;
  String? _schoolIdError;

  @override
  void dispose() {
    _alumniSchoolController.dispose();
    _studentIdController.dispose();
    _schoolNameController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  String _generateSchoolId(String name) {
    if (name.trim().isEmpty) return '';
    final words = name.trim().split(RegExp(r'\s+'));
    final prefix = words.map((w) => w[0].toUpperCase()).join();
    final randomNum = Random().nextInt(90000) + 10000;
    return '$prefix-$randomNum';
  }

  void _onContinuePressed(bool isAlumni) {
    setState(() {
      _alumniSchoolError = null;
      _alumniStudentIdError = null;
      _schoolNameError = null;
      _schoolIdError = null;

      if (isAlumni) {
        if (_alumniSchoolController.text.trim().isEmpty) {
          _alumniSchoolError = 'Please enter or select your school.';
        }
        if (_studentIdController.text.trim().isEmpty) {
          _alumniStudentIdError = 'Please enter your student ID.';
        }
        if (_alumniSchoolError == null && _alumniStudentIdError == null) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        if (_schoolNameController.text.trim().isEmpty) {
          _schoolNameError = 'Please enter your school name.';
        }
        if (_schoolIdController.text.trim().isEmpty) {
          _schoolIdError = 'Please generate a school ID.';
        }
        if (_schoolNameError == null && _schoolIdError == null) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final args = ModalRoute.of(context)?.settings.arguments;
    final userType = args is UserType ? args : UserType.alumni;
    final isAlumni = userType == UserType.alumni;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAlumni ? 'Verify as Alumni' : 'Verify Your School',
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAlumni)
                    _buildAlumniSection(theme)
                  else
                    _buildSchoolSection(theme),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _onContinuePressed(isAlumni),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Continue'),
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

  Widget _buildAlumniSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('School', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _alumniSchoolController,
          onChanged: (value) {
            setState(() {
              if (value.trim().isEmpty) {
                _suggestions = [];
              } else {
                _suggestions = _registeredSchools
                    .where((school) =>
                        school.toLowerCase().contains(value.toLowerCase()))
                    .toList();
              }
              _alumniSchoolError = null;
            });
          },
          decoration: _inputDecoration(
            hintText: 'Search or enter your school name',
            suffixIcon:
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _suggestions.isNotEmpty
              ? Container(
                  key: const ValueKey('suggestions'),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion,
                          style: theme.textTheme.bodyMedium,
                        ),
                        onTap: () {
                          setState(() {
                            _alumniSchoolController.text = suggestion;
                            _suggestions.clear();
                            _alumniSchoolError = null;
                          });
                        },
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (_alumniSchoolError != null) ...[
          const SizedBox(height: 4),
          Text(
            _alumniSchoolError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 16),
        Text('Student ID', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _studentIdController,
          onChanged: (_) {
            setState(() => _alumniStudentIdError = null);
          },
          decoration: _inputDecoration(
            hintText: 'Enter your student ID',
          ),
        ),
        if (_alumniStudentIdError != null) ...[
          const SizedBox(height: 4),
          Text(
            _alumniStudentIdError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showRequestIdPopup(context),
            child: Text(
              'Request ID from school',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestIdPopup(BuildContext context) {
    final outerTheme = Theme.of(context);
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final schoolCtrl =
        TextEditingController(text: _alumniSchoolController.text);

    String? nameError;
    String? emailError;
    String? schoolError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Theme(
          data: outerTheme.copyWith(
            textTheme: outerTheme.textTheme.apply(fontSizeFactor: 0.9),
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              Future<void> submit() async {
                setLocalState(() {
                  nameError = null;
                  emailError = null;
                  schoolError = null;

                  if (nameCtrl.text.trim().isEmpty) {
                    nameError = 'Please enter your name.';
                  }
                  if (emailCtrl.text.trim().isEmpty) {
                    emailError = 'Please enter your email.';
                  } else if (!RegExp(
                          r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$')
                      .hasMatch(emailCtrl.text.trim())) {
                    emailError = 'Please enter a valid email.';
                  }
                  if (schoolCtrl.text.trim().isEmpty) {
                    schoolError = 'Please enter your school.';
                  }
                });

                if (nameError != null ||
                    emailError != null ||
                    schoolError != null) {
                  return;
                }

                // loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                await Future.delayed(const Duration(seconds: 2));

                Navigator.of(context).pop();
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Request sent. Your school will email you an ID.',
                    ),
                  ),
                );
              }

              return AlertDialog(
                contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                content: SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Request Student ID',
                          style: outerTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: nameCtrl,
                          decoration: _dialogInputDecoration(
                            ctx,
                            hintText: 'Your full name',
                            errorText: nameError,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dialogInputDecoration(
                            ctx,
                            hintText: 'Your email',
                            errorText: emailError,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: schoolCtrl,
                          decoration: _dialogInputDecoration(
                            ctx,
                            hintText: 'School name',
                            errorText: schoolError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actionsPadding:
                    const EdgeInsets.only(right: 14, bottom: 8, top: 4),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: submit,
                    child: const Text('Submit'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


  Widget _buildSchoolSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('School name', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _schoolNameController,
          onChanged: (_) {
            setState(() => _schoolNameError = null);
          },
          decoration: _inputDecoration(
            hintText: 'Enter your school name',
          ),
        ),
        if (_schoolNameError != null) ...[
          const SizedBox(height: 4),
          Text(
            _schoolNameError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 16),
        Text('School ID', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _schoolIdController,
          readOnly: true,
          decoration: _inputDecoration(
            hintText: 'School ID will appear here',
          ),
        ),
        if (_schoolIdError != null) ...[
          const SizedBox(height: 4),
          Text(
            _schoolIdError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _schoolNameError = null;
              });
              final name = _schoolNameController.text.trim();
              if (name.isEmpty) {
                setState(() {
                  _schoolNameError =
                      'Please enter the school name first.';
                });
                return;
              }
              final id = _generateSchoolId(name);
              setState(() {
                _schoolIdController.text = id;
                _schoolIdError = null;
              });
            },
            child: Text(
              'Generate school ID',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
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

  InputDecoration _dialogInputDecoration(
    BuildContext context, {
    required String hintText,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hintText,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.2,
        ),
      ),
    );
  }
}
