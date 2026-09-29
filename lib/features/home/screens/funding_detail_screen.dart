import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/config/api_config.dart';
import 'funding_donate_screen.dart';

class FundingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> fund;

  const FundingDetailScreen({super.key, required this.fund});

  @override
  State<FundingDetailScreen> createState() => _FundingDetailScreenState();
}

class _FundingDetailScreenState extends State<FundingDetailScreen> {
  bool _isSchoolAdmin = false;

  String? _resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final base = Uri.parse(ApiConfig.baseUrl);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;
      final host = uri.host;
      if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
        return uri.replace(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
        ).toString();
      }
      return url;
    }
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return '${ApiConfig.baseUrl}/$url';
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = await HomeApiService.fetchMe();
    if (!mounted) return;
    setState(() {
      _isSchoolAdmin = user?['role']?.toString() == 'institution_admin';
    });
  }

  @override
  Widget build(BuildContext context) {
    final fund = widget.fund;
    final progress = (fund['raised'] / fund['goal']).clamp(0.0, 1.0);
    final imageUrl = _resolveMediaUrl(fund['image']?.toString());
    final providers = (fund['providers'] as List?)?.cast<String>() ?? const <String>[];
    final hasProviders = providers.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(fund['title']),
        actions: [
          if (_isSchoolAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditCampaignScreen(fund: fund),
                  ),
                );
                if (updated is Map<String, dynamic>) {
                  setState(() {
                    widget.fund.addAll(updated);
                  });
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 220,
                            color: const Color(0xFFE2E8F0),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 52, color: Color(0xFF64748B)),
                          ),
                        )
                      : Container(
                          height: 220,
                          color: const Color(0xFFE2E8F0),
                          alignment: Alignment.center,
                          child: const Icon(Icons.volunteer_activism, size: 52, color: Color(0xFF64748B)),
                        ),
                ),

                const SizedBox(height: 20),
                Text(
                  fund['school'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (hasProviders) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: providers.map((p) => _ProviderChip(provider: p)).toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No payment methods available yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                ),

                const SizedBox(height: 8),
                Text(
                  "${_formatCurrency(fund['currency'], fund['raised'])} raised of ${_formatCurrency(fund['currency'], fund['goal'])}",
                  style: const TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 24),
                const Text(
                  "About donation project",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  fund['description'],
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),

          // DONATE BUTTON
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: hasProviders ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FundingDonateScreen(fund: fund),
                    ),
                  );
                } : null,
                child: const Text("Donate"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditCampaignScreen extends StatefulWidget {
  final Map<String, dynamic> fund;

  const EditCampaignScreen({super.key, required this.fund});

  @override
  State<EditCampaignScreen> createState() => _EditCampaignScreenState();
}

class _ProviderChip extends StatelessWidget {
  final String provider;

  const _ProviderChip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final normalized = provider.toLowerCase();
    String label = provider;
    if (normalized == 'stripe') label = 'Stripe';
    if (normalized == 'paystack') label = 'Paystack';
    if (normalized == 'paypal') label = 'PayPal';
    if (normalized == 'momo') label = 'Mobile Money';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

String _currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'GHS':
      return '₵';
    case 'USD':
      return '\$';
    case 'GBP':
      return '£';
    case 'EUR':
      return '€';
    default:
      return code.toUpperCase();
  }
}

String _formatCurrency(dynamic code, dynamic amount) {
  final currency = (code ?? 'GHS').toString().toUpperCase();
  final symbol = _currencySymbol(currency);
  return '$symbol ${amount ?? 0}';
}

class _EditCampaignScreenState extends State<EditCampaignScreen> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _currency = 'GHS';
  bool _publishNow = true;
  String? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.fund['title']?.toString() ?? '';
    _targetCtrl.text = widget.fund['goal']?.toString() ?? '';
    _descCtrl.text = widget.fund['description']?.toString() ?? '';
    _currency = widget.fund['currency']?.toString() ?? 'GHS';
    _imageUrl = widget.fund['image']?.toString();
    _publishNow = widget.fund['is_active'] == true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = widget.fund['id'] as int?;
    final target = double.tryParse(_targetCtrl.text.trim());
    if (id == null || _titleCtrl.text.trim().isEmpty || target == null || target <= 0) return;
    setState(() => _saving = true);
    final updated = await HomeApiService.updateDonationCampaign(
      campaignId: id,
      title: _titleCtrl.text.trim(),
      targetAmount: target,
      currency: _currency,
      description: _descCtrl.text.trim(),
      imageUrl: _imageUrl,
      isActive: _publishNow,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update campaign')),
      );
      return;
    }
    Navigator.pop(context, {
      'title': updated['title'] ?? _titleCtrl.text.trim(),
      'goal': updated['target_amount'] ?? target,
      'currency': updated['currency'] ?? _currency,
      'description': updated['description'] ?? _descCtrl.text.trim(),
      'image': updated['image_url'] ?? _imageUrl,
      'is_active': updated['is_active'] ?? _publishNow,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Edit campaign'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _card(
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Campaign title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'GHS', child: Text('GHS')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  ],
                  onChanged: (value) => setState(() => _currency = value ?? 'GHS'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_imageUrl != null && _imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.image_outlined, size: 28, color: Colors.black38),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
                                if (image == null) return;
                                final upload = await HomeApiService.uploadMedia(
                                  filePath: image.path,
                                  fileName: image.name,
                                );
                                if (upload == null || upload['url'] == null) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Image upload failed')),
                                    );
                                  }
                                  return;
                                }
                                setState(() => _imageUrl = upload['url'].toString());
                              },
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Change cover'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'About donation project', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _publishNow,
            onChanged: (value) => setState(() => _publishNow = value),
            title: const Text('Publish now'),
            subtitle: Text(_publishNow ? 'Visible to alumni immediately' : 'Save as draft'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving ? const CircularProgressIndicator() : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }
}
