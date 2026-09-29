import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class AnnouncementCreateScreen extends StatefulWidget {
  const AnnouncementCreateScreen({super.key});

  @override
  State<AnnouncementCreateScreen> createState() =>
      _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sendEmail = false;
  bool _publishNow = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final announcement = await HomeApiService.createAnnouncement(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      sendEmail: _sendEmail,
      isActive: _publishNow,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (announcement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to publish announcement')),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(
              icon: Icons.campaign_rounded,
              title: 'Create an announcement',
              subtitle:
                  'Share updates with alumni clearly, choose whether to send email, and decide if it should go live immediately.',
              accent: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Message details',
              subtitle: 'Keep the title sharp and the message easy to scan.',
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('Announcement title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 6,
                    decoration: _inputDecoration('Message').copyWith(
                      hintText:
                          'Share the update, next step, or important context.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Delivery options',
              subtitle: 'Choose how widely the message goes out.',
              child: Column(
                children: [
                  _toggleTile(
                    value: _sendEmail,
                    onChanged: (v) => setState(() => _sendEmail = v),
                    icon: Icons.mark_email_unread_rounded,
                    title: 'Send email blast',
                    subtitle: 'Deliver this announcement to inboxes as well.',
                  ),
                  const SizedBox(height: 12),
                  _toggleTile(
                    value: _publishNow,
                    onChanged: (v) => setState(() => _publishNow = v),
                    icon: Icons.public_rounded,
                    title: 'Publish now',
                    subtitle: _publishNow
                        ? 'Visible to alumni immediately'
                        : 'Save as draft for later review',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Publish announcement',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.4),
      ),
    );
  }

  Widget _heroCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.95), const Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            offset: Offset(0, 14),
            color: Color(0x1F0F172A),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.14),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _toggleTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
