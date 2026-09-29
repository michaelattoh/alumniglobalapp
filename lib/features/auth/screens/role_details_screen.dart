import 'package:flutter/material.dart';
import './models/user_type.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:alumni_global_app/core/config/api_config.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';

class RoleDetailsScreen extends StatefulWidget {
  const RoleDetailsScreen({super.key});

  @override
  State<RoleDetailsScreen> createState() => _RoleDetailsScreenState();
}

class _RoleDetailsScreenState extends State<RoleDetailsScreen> {
  String? _token;
  bool _didInitArgs = false;
  UserType _userType = UserType.alumni;
  Map<String, dynamic>? _user;

  // institutions from backend
  List<Map<String, dynamic>> _institutions = [];
  String? _codeError;
  String? _selectedInstitutionName;
  int? _selectedInstitutionId;

  // Alumni controllers
  final TextEditingController _alumniSchoolController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();

  // School controllers
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolIdController = TextEditingController();

  // Registered schools for demo

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

  Future<void> _searchInstitutions(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _institutions = [];
        _suggestions = [];
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/institutions?search=${Uri.encodeComponent(q)}',
        ),
        headers: const {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List data = body['data'] ?? [];

        final names = data.map((e) => e['name'].toString()).toList();

        setState(() {
          _institutions = data.cast<Map<String, dynamic>>();
          _suggestions = names;
          _alumniSchoolError = null;
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (_) {
      setState(() => _suggestions = []);
    }
  }

  Future<bool> _validateInviteCode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return false;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/invitations/validate'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': c}),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final inst = body['institution'];

        setState(() {
          _codeError = null;
          _selectedInstitutionName = inst?['name']?.toString();
        });

        // Optional: if user typed a school name, ensure it matches
        final typedSchool = _alumniSchoolController.text.trim();
        if (typedSchool.isNotEmpty &&
            _selectedInstitutionName != null &&
            typedSchool.toLowerCase() !=
                _selectedInstitutionName!.toLowerCase()) {
          setState(() {
            _codeError =
                'Code is for $_selectedInstitutionName, not "$typedSchool".';
          });
          return false;
        }

        return true;
      }

      final body = jsonDecode(res.body);
      setState(() {
        _selectedInstitutionName = null;
        _codeError = body['message']?.toString() ?? 'Invalid code';
      });

      return false;
    } catch (_) {
      setState(() {
        _selectedInstitutionName = null;
        _codeError = 'Network error';
      });
      return false;
    }
  }

  Map<String, dynamic>? _findInstitutionByName(String name) {
    final lower = name.trim().toLowerCase();
    for (final inst in _institutions) {
      if ((inst['name']?.toString().toLowerCase() ?? '') == lower) {
        return inst;
      }
    }
    return null;
  }

  Future<void> _generateStudentId() async {
    if (_token == null || _token!.isEmpty || _selectedInstitutionId == null)
      return;
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/student-ids/generate'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'institution_id': _selectedInstitutionId}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final code = body['code']?.toString() ?? '';
        setState(() {
          _studentIdController.text = code;
          _alumniStudentIdError = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _requestStudentId({
    required String fullName,
    required String email,
  }) async {
    if (_token == null || _token!.isEmpty || _selectedInstitutionId == null)
      return;
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/student-ids/request'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'institution_id': _selectedInstitutionId,
        'full_name': fullName,
        'email': email,
      }),
    );
  }

  Future<void> _registerSchool({required bool navigateAfter}) async {
    if (_token == null || _token!.isEmpty) return;
    final name = _schoolNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _schoolNameError = 'Please enter your school name.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/institutions/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({'school_name': name}),
      );
      Navigator.of(context).pop();
      if (res.statusCode == 201 || res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _schoolIdController.text = body['school_id']?.toString() ?? '';
          _schoolIdError = null;
        });
        if (navigateAfter) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
        return;
      }
      final body = jsonDecode(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message']?.toString() ?? 'Failed')),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _onContinuePressed(bool isAlumni) async {
    // reset errors
    setState(() {
      _alumniSchoolError = null;
      _alumniStudentIdError = null;
      _schoolNameError = null;
      _schoolIdError = null;
      _codeError = null;
      _selectedInstitutionName = null;
    });

    if (isAlumni) {
      if (_alumniSchoolController.text.trim().isEmpty) {
        setState(
          () => _alumniSchoolError = 'Please enter or select your school.',
        );
        return;
      }
      if (_selectedInstitutionId == null) {
        final inst = _findInstitutionByName(_alumniSchoolController.text);
        _selectedInstitutionId = (inst?['id'] as num?)?.toInt();
        if (_selectedInstitutionId == null) {
          setState(
            () => _alumniSchoolError =
                'Please select a valid school from the list.',
          );
          return;
        }
      }
      if (_studentIdController.text.trim().isEmpty) {
        setState(
          () => _alumniStudentIdError = 'Please enter the verification code.',
        );
        return;
      }

      if (_token == null || _token!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing token. Please login again.')),
        );
        return;
      }

      // 1) validate code
      final isValid = await _validateInviteCode(_studentIdController.text);
      if (!isValid) return;

      // 2) attach institution
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/me/attach-institution'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({'code': _studentIdController.text.trim()}),
        );

        Navigator.of(context).pop(); // close loader

        if (res.statusCode == 200) {
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        }

        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message']?.toString() ?? 'Failed')),
        );
      } catch (e) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: $e')));
      }

      return;
    }

    // School verification
    if (_schoolNameController.text.trim().isEmpty) {
      setState(() => _schoolNameError = 'Please enter your school name.');
      return;
    }
    if (_schoolIdController.text.trim().isEmpty) {
      await _registerSchool(navigateAfter: true);
      return;
    }

    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final args = ModalRoute.of(context)?.settings.arguments;
    print('ROLE DETAILS args: $args');

    if (!_didInitArgs) {
      _didInitArgs = true;

      if (args is Map) {
        _userType = args['type'] is UserType ? args['type'] : UserType.alumni;
        _token = args['token']?.toString();
        final rawUser = args['user'];
        if (rawUser is Map<String, dynamic>) {
          _user = rawUser;
        }
      } else if (args is UserType) {
        _userType = args;
      }

      print('ROLE DETAILS token: $_token');
      if (_token == null || _token!.isEmpty) {
        AuthSession.getToken().then((savedToken) {
          if (!mounted) return;
          if (savedToken != null && savedToken.isNotEmpty) {
            setState(() => _token = savedToken);
          }
        });
      }
    }

    final isAlumni = _userType == UserType.alumni;

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
                      onPressed: () async => await _onContinuePressed(isAlumni),
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
              _alumniSchoolError = null;
              _selectedInstitutionId = null;
            });
            _searchInstitutions(value);
          },
          decoration: _inputDecoration(
            hintText: 'Search or enter your school name',
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
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
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey[200]),
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
                            final inst = _findInstitutionByName(suggestion);
                            _selectedInstitutionId = (inst?['id'] as num?)
                                ?.toInt();
                            _suggestions.clear();
                            _alumniSchoolError = null;
                          });
                          _generateStudentId();
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
            hintText: 'Enter the code from your school',
          ),
        ),
        if (_alumniStudentIdError != null) ...[
          const SizedBox(height: 4),
          Text(
            _alumniStudentIdError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
        if (_codeError != null) ...[
          const SizedBox(height: 4),
          Text(
            _codeError!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],

        if (_selectedInstitutionName != null) ...[
          const SizedBox(height: 6),
          Text(
            'Code valid for: $_selectedInstitutionName',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
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
    final nameCtrl = TextEditingController(
      text: _user?['name']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: _user?['email']?.toString() ?? '',
    );
    final schoolCtrl = TextEditingController(
      text: _alumniSchoolController.text,
    );

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
                    r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$',
                  ).hasMatch(emailCtrl.text.trim())) {
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

                if (_selectedInstitutionId == null) {
                  setLocalState(
                    () => schoolError = 'Please select a valid school.',
                  );
                  return;
                }

                // loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                await _requestStudentId(
                  fullName: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                );

                Navigator.of(context).pop();
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Request sent. Your school will send your ID to you.',
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
                actionsPadding: const EdgeInsets.only(
                  right: 14,
                  bottom: 8,
                  top: 4,
                ),
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
          decoration: _inputDecoration(hintText: 'Enter your school name'),
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
          decoration: _inputDecoration(hintText: 'School ID will appear here'),
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
                  _schoolNameError = 'Please enter the school name first.';
                });
                return;
              }
              _registerSchool(navigateAfter: false);
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: BorderSide(color: Colors.blue, width: 1.4),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.2),
      ),
    );
  }
}
