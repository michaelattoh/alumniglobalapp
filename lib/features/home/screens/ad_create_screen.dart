import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class AdCreateScreen extends StatefulWidget {
  const AdCreateScreen({super.key});

  @override
  State<AdCreateScreen> createState() => _AdCreateScreenState();
}

class _AdCreateScreenState extends State<AdCreateScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  final _budgetController = TextEditingController();
  final _dailyBudgetController = TextEditingController();
  final _targetUrlController = TextEditingController();
  final _targetLocationController = TextEditingController();
  final _targetInterestsController = TextEditingController();

  String _placement = 'feed';
  String _objective = 'traffic';
  String _pricingModel = 'cpc';
  String _currency = 'GHS';
  bool _dailyCapEnabled = false;
  bool _loading = false;
  String? _error;

  XFile? _mediaFile;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    _budgetController.dispose();
    _dailyBudgetController.dispose();
    _targetUrlController.dispose();
    _targetLocationController.dispose();
    _targetInterestsController.dispose();
    super.dispose();
  }

  void _setObjective(String value) {
    setState(() {
      _objective = value;
      _pricingModel = value == 'awareness'
          ? 'cpm'
          : value == 'conversion'
          ? 'flat'
          : 'cpc';
    });
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _mediaFile = file);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final budget = double.tryParse(_budgetController.text.trim());
    final dailyBudget = double.tryParse(_dailyBudgetController.text.trim());

    if (title.isEmpty || price == null || budget == null) {
      setState(() => _error = 'Title, price, and budget are required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    String? mediaUrl;
    if (_mediaFile != null) {
      final upload = await HomeApiService.uploadMedia(
        filePath: _mediaFile!.path,
        fileName: _mediaFile!.name,
      );
      mediaUrl = upload?['url']?.toString();
    }

    final ad = await HomeApiService.createAd(
      title: title,
      placement: _placement,
      objective: _objective,
      pricingModel: _pricingModel,
      price: price,
      budget: budget,
      currency: _currency,
      content: content.isEmpty ? null : content,
      mediaUrl: mediaUrl,
      targetUrl: _targetUrlController.text.trim().isEmpty
          ? null
          : _targetUrlController.text.trim(),
      targetLocation: _targetLocationController.text.trim().isEmpty
          ? null
          : _targetLocationController.text.trim(),
      targetInterests: _targetInterestsController.text.trim().isEmpty
          ? []
          : _targetInterestsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
      dailyCapEnabled: _dailyCapEnabled,
      dailyBudget: _dailyCapEnabled ? dailyBudget : null,
    );

    if (!mounted) return;

    if (ad == null) {
      setState(() {
        _loading = false;
        _error = 'Failed to create ad.';
      });
      return;
    }

    setState(() => _loading = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(28),
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
                    child: const Icon(
                      Icons.ads_click_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Create an ad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Build a campaign that looks current, targeted, and easy to publish.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            _sectionCard(
              title: 'Creative',
              subtitle:
                  'Start with the message and image that alumni will notice first.',
              child: Column(
                children: [
                  _textField(_titleController, 'Ad title'),
                  _textField(
                    _contentController,
                    'Ad copy (optional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickMedia,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Upload image'),
                        ),
                      ),
                    ],
                  ),
                  if (_mediaFile != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        image: DecorationImage(
                          image: FileImage(File(_mediaFile!.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionCard(
              title: 'Placement & pricing',
              subtitle:
                  'Choose where the ad appears and how the campaign is budgeted.',
              child: Column(
                children: [
                  _dropdown(
                    value: _placement,
                    items: const [
                      DropdownMenuItem(value: 'feed', child: Text('Feed')),
                      DropdownMenuItem(value: 'story', child: Text('Story')),
                      DropdownMenuItem(value: 'banner', child: Text('Banner')),
                    ],
                    onChanged: (v) => setState(() => _placement = v ?? 'feed'),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    value: _objective,
                    items: const [
                      DropdownMenuItem(
                        value: 'traffic',
                        child: Text('Traffic (CPC)'),
                      ),
                      DropdownMenuItem(
                        value: 'awareness',
                        child: Text('Awareness (CPM)'),
                      ),
                      DropdownMenuItem(
                        value: 'conversion',
                        child: Text('Conversion (Flat)'),
                      ),
                    ],
                    onChanged: (v) => _setObjective(v ?? 'traffic'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          _priceController,
                          'Price',
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(
                          _budgetController,
                          'Total budget',
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _dropdown(
                    value: _currency,
                    items: const [
                      DropdownMenuItem(value: 'GHS', child: Text('GHS')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'GHS'),
                  ),
                  SwitchListTile(
                    value: _dailyCapEnabled,
                    onChanged: (v) => setState(() => _dailyCapEnabled = v),
                    title: const Text('Enable daily spend cap'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_dailyCapEnabled)
                    _textField(
                      _dailyBudgetController,
                      'Daily budget',
                      keyboard: TextInputType.number,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Targeting',
              subtitle:
                  'Guide the campaign to the right audience and destination.',
              child: Column(
                children: [
                  _textField(
                    _targetLocationController,
                    'Target location (optional)',
                  ),
                  _textField(
                    _targetInterestsController,
                    'Target interests (comma separated)',
                  ),
                  _textField(
                    _targetUrlController,
                    'Destination URL (optional)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create ad'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
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
}
