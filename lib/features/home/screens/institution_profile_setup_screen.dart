import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class InstitutionProfileSetupScreen extends StatefulWidget {
  const InstitutionProfileSetupScreen({super.key});

  @override
  State<InstitutionProfileSetupScreen> createState() =>
      _InstitutionProfileSetupScreenState();
}

class _InstitutionProfileSetupScreenState
    extends State<InstitutionProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mottoCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;
  String? _error;
  String? _logoUrl;
  String? _bannerUrl;

  @override
  void initState() {
    super.initState();
    _loadInstitution();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _mottoCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInstitution() async {
    final institution = await HomeApiService.fetchMyInstitution();
    if (!mounted) return;
    if (institution == null) {
      setState(() {
        _loading = false;
        _error = 'Unable to load school profile.';
      });
      return;
    }
    _nameCtrl.text = institution['name']?.toString() ?? '';
    _websiteCtrl.text = institution['website']?.toString() ?? '';
    _emailCtrl.text = institution['email']?.toString() ?? '';
    _phoneCtrl.text = institution['phone']?.toString() ?? '';
    _locationCtrl.text = institution['location']?.toString() ?? '';
    _addressCtrl.text = institution['address']?.toString() ?? '';
    _mottoCtrl.text = institution['motto']?.toString() ?? '';
    _descriptionCtrl.text = institution['description']?.toString() ?? '';
    setState(() {
      _logoUrl = HomeApiService.normalizeMediaUrl(
        institution['logo_url']?.toString(),
      );
      _bannerUrl = HomeApiService.normalizeMediaUrl(
        institution['banner_url']?.toString(),
      );
      _loading = false;
      _error = null;
    });
  }

  Future<void> _pickImage({required bool banner}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (file == null) return;
    setState(() {
      if (banner) {
        _uploadingBanner = true;
      } else {
        _uploadingLogo = true;
      }
    });
    final upload = await HomeApiService.uploadMedia(
      filePath: file.path,
      fileName: file.name,
    );
    if (!mounted) return;
    final url = upload?['url']?.toString();
    setState(() {
      if (banner) {
        _uploadingBanner = false;
        if (url != null && url.isNotEmpty) _bannerUrl = url;
      } else {
        _uploadingLogo = false;
        if (url != null && url.isNotEmpty) _logoUrl = url;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final institution = await HomeApiService.updateMyInstitution({
      'name': _nameCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'motto': _mottoCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'logo_url': _logoUrl,
      'banner_url': _bannerUrl,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (institution == null) {
      setState(() => _error = 'Unable to save school profile.');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('School profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('School profile'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Shape your school presence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Keep your school profile polished so alumni know who you are, what you stand for, and how to reach you.',
                        style: TextStyle(color: Colors.white70, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _mediaCard(
                  title: 'Branding',
                  subtitle: 'Upload your school logo and banner.',
                  child: Column(
                    children: [
                      _imageTile(
                        title: 'School logo',
                        url: _logoUrl,
                        busy: _uploadingLogo,
                        icon: Icons.school_rounded,
                        onTap: () => _pickImage(banner: false),
                      ),
                      const SizedBox(height: 12),
                      _imageTile(
                        title: 'School banner',
                        url: _bannerUrl,
                        busy: _uploadingBanner,
                        icon: Icons.landscape_rounded,
                        onTap: () => _pickImage(banner: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _mediaCard(
                  title: 'Identity',
                  subtitle:
                      'The essentials alumni should recognize immediately.',
                  child: Column(
                    children: [
                      _field('School name', _nameCtrl),
                      _field('Location', _locationCtrl),
                      _field('Motto', _mottoCtrl),
                      _field('Website', _websiteCtrl),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _mediaCard(
                  title: 'Contact',
                  subtitle: 'Make it easy for alumni to reach the right team.',
                  child: Column(
                    children: [
                      _field('Email', _emailCtrl),
                      _field('Phone', _phoneCtrl),
                      _field('Address', _addressCtrl, maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _mediaCard(
                  title: 'About your school',
                  subtitle:
                      'A short profile that gives your institution more presence.',
                  child: _field('Description', _descriptionCtrl, maxLines: 5),
                ),
              ],
            ),
    );
  }

  Widget _mediaCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageTile({
    required String title,
    required String? url,
    required bool busy,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFFE2E8F0),
                child: url != null && url.isNotEmpty
                    ? Image.network(url, fit: BoxFit.cover)
                    : Icon(icon, color: const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    busy ? 'Uploading…' : 'Tap to choose an image',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
