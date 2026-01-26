import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'cv_preview_screen.dart';

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
    await Future.delayed(const Duration(seconds: 2));
    setState(() => submitting = false);

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
              _input(nameCtrl, 'Full name'),
              _input(emailCtrl, 'Email',
                  keyboard: TextInputType.emailAddress),
              _input(phoneCtrl, 'Phone number',
                  keyboard: TextInputType.phone),
              _input(linkedinCtrl, 'LinkedIn profile (optional)'),

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

  Widget _input(TextEditingController ctrl, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: (v) =>
            v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
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
