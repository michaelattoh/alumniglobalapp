import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'cv_preview_screen.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class JobApplyScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String companyName;

  const JobApplyScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.companyName,
  });

  @override
  State<JobApplyScreen> createState() => _JobApplyScreenState();
}

class _JobApplyScreenState extends State<JobApplyScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final linkedinCtrl = TextEditingController();

  File? cvFile;
  bool submitting = false;
  bool _prefilling = true;

  @override
  void initState() {
    super.initState();
    _prefillUser();
  }

  Future<void> _prefillUser() async {
    try {
      final me = await HomeApiService.fetchMe();
      if (!mounted) return;
      nameCtrl.text = (me?['name'] ?? '').toString();
      emailCtrl.text = (me?['email'] ?? '').toString();
      phoneCtrl.text = (me?['phone'] ?? '').toString();
    } catch (_) {
      // ignore prefill errors
    } finally {
      if (mounted) setState(() => _prefilling = false);
    }
  }

  Future<void> _pickCV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        cvFile = File(result.files.single.path!);
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (cvFile == null) {
      _showMessage('Please upload your CV', isError: true);
      return;
    }

    setState(() => submitting = true);
    final upload = await HomeApiService.uploadMedia(
      filePath: cvFile!.path,
      fileName: cvFile!.path.split('/').last,
    );
    if (upload == null || upload['url'] == null) {
      setState(() => submitting = false);
      _showMessage('Resume upload failed', isError: true);
      return;
    }

    final ok = await HomeApiService.applyToJob(
      jobId: int.tryParse(widget.jobId) ?? 0,
      name: nameCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      linkedinUrl: linkedinCtrl.text.trim(),
      resumeUrl: upload['url'].toString(),
    );

    setState(() => submitting = false);

    if (!ok) {
      _showMessage('Application failed. Please try again.', isError: true);
      return;
    }

    _showMessage('Application submitted successfully');
    Navigator.pop(context);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply – ${widget.jobTitle}'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_prefilling)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              _input(nameCtrl, 'Full name'),
              _input(emailCtrl, 'Email',
                  keyboard: TextInputType.emailAddress),
              _input(
                phoneCtrl,
                'Phone number',
                keyboard: TextInputType.phone,
                hint: '+233 20 000 0000',
              ),
              _input(
                linkedinCtrl,
                'LinkedIn profile (optional)',
                required: false,
              ),

              const SizedBox(height: 16),

              // CV UPLOAD
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cvFile == null
                          ? 'No CV uploaded'
                          : 'Uploaded: ${cvFile!.path.split('/').last}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _pickCV,
                          child: const Text('Upload CV'),
                        ),
                        const SizedBox(width: 8),
                        if (cvFile != null)
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CVPreviewScreen(file: cvFile!),
                                ),
                              );
                            },
                            child: const Text('Preview CV'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              submitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: const Text('Submit Application'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboard,
    bool required = true,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
