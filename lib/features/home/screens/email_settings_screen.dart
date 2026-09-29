import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _settings;

  bool _enabled = false;
  bool _showSmtpPassword = false;
  final senderNameCtrl = TextEditingController();
  final senderEmailCtrl = TextEditingController();
  final smtpHostCtrl = TextEditingController();
  final smtpPortCtrl = TextEditingController();
  final smtpUserCtrl = TextEditingController();
  final smtpPassCtrl = TextEditingController();
  String _smtpEncryption = 'tls';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await HomeApiService.fetchInstitutionEmailSettings();
      if (!mounted) return;
      setState(() {
        _settings = data;
        _enabled = data?['is_enabled'] == true;
        senderNameCtrl.text = data?['sender_name']?.toString() ?? '';
        senderEmailCtrl.text = data?['sender_email']?.toString() ?? '';
        smtpHostCtrl.text = data?['smtp_host']?.toString() ?? '';
        smtpPortCtrl.text = data?['smtp_port']?.toString() ?? '';
        smtpUserCtrl.text = '';
        smtpPassCtrl.text = '';
        _smtpEncryption = data?['smtp_encryption']?.toString() ?? 'tls';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load email settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'is_enabled': _enabled,
    };

    if (senderNameCtrl.text.trim().isNotEmpty) {
      payload['sender_name'] = senderNameCtrl.text.trim();
    }
    if (senderEmailCtrl.text.trim().isNotEmpty) {
      payload['sender_email'] = senderEmailCtrl.text.trim();
    }
    if (smtpHostCtrl.text.trim().isNotEmpty) {
      payload['smtp_host'] = smtpHostCtrl.text.trim();
    }
    if (smtpPortCtrl.text.trim().isNotEmpty) {
      payload['smtp_port'] = int.tryParse(smtpPortCtrl.text.trim());
    }
    if (smtpUserCtrl.text.trim().isNotEmpty) {
      payload['smtp_username'] = smtpUserCtrl.text.trim();
    }
    if (smtpPassCtrl.text.trim().isNotEmpty) {
      payload['smtp_password'] = smtpPassCtrl.text.trim();
    }
    if (_smtpEncryption.isNotEmpty) {
      payload['smtp_encryption'] = _smtpEncryption;
    }

    final ok = await HomeApiService.updateInstitutionEmailSettings(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = 'Failed to save email settings.');
      return;
    }

    smtpUserCtrl.clear();
    smtpPassCtrl.clear();
    await _loadSettings();
  }

  @override
  void dispose() {
    senderNameCtrl.dispose();
    senderEmailCtrl.dispose();
    smtpHostCtrl.dispose();
    smtpPortCtrl.dispose();
    smtpUserCtrl.dispose();
    smtpPassCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
      {TextInputType? keyboardType, bool obscure = false, String? hint, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usernameHint = _settings?['smtp_username_hint']?.toString();
    final passwordHint = _settings?['smtp_password_hint']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Email Settings'),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Alumni Global will still send platform emails. '
                    'This setup lets your school send emails with your sender details.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Enable custom sender'),
                  subtitle: const Text('Use your school sender name and email.'),
                ),
                const SizedBox(height: 12),
                _field(senderNameCtrl, 'Sender name'),
                _field(senderEmailCtrl, 'Sender email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 6),
                const Text('SMTP settings (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _field(smtpHostCtrl, 'SMTP host'),
                _field(smtpPortCtrl, 'SMTP port', keyboardType: TextInputType.number),
                _field(
                  smtpUserCtrl,
                  'SMTP username',
                  hint: usernameHint != null ? 'Saved: $usernameHint' : null,
                ),
                _field(
                  smtpPassCtrl,
                  'SMTP password',
                  obscure: !_showSmtpPassword,
                  hint: passwordHint != null ? 'Saved: $passwordHint' : null,
                  suffix: IconButton(
                    onPressed: () => setState(() => _showSmtpPassword = !_showSmtpPassword),
                    icon: Icon(
                      _showSmtpPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('SMTP encryption', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                RadioListTile<String>(
                  value: 'tls',
                  groupValue: _smtpEncryption,
                  onChanged: (v) => setState(() => _smtpEncryption = v ?? 'tls'),
                  title: const Text('TLS'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  value: 'ssl',
                  groupValue: _smtpEncryption,
                  onChanged: (v) => setState(() => _smtpEncryption = v ?? 'ssl'),
                  title: const Text('SSL'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: const Text('Save email settings'),
                      ),
              ],
            ),
    );
  }
}
