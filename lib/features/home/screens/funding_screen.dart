import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:alumni_global_app/core/config/api_config.dart';
import 'funding_detail_screen.dart';

class FundingScreen extends StatefulWidget {
  const FundingScreen({super.key});

  @override
  State<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends State<FundingScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  bool _loading = true;
  bool _isSchoolAdmin = false;
  String _statusFilter = 'All';

  String filterCategory = 'All';

  List<String> categories = ['All'];

  List<Map<String, dynamic>> fundings = [];

  @override
  void initState() {
    super.initState();
    final cached = HomeApiService.getCachedFundings();
    if (cached.isNotEmpty) {
      _applyCampaigns(cached, setLoading: false);
    }
    _loadCampaigns(showLoader: cached.isEmpty);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = await HomeApiService.fetchMe();
    if (!mounted) return;
    setState(() {
      _isSchoolAdmin = user?['role']?.toString() == 'institution_admin';
    });
  }

  Future<void> _loadCampaigns({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }
    final rows = await HomeApiService.fetchDonationCampaigns();
    if (!mounted) return;
    _applyCampaigns(rows, setLoading: true);
  }

  void _applyCampaigns(
    List<Map<String, dynamic>> rows, {
    required bool setLoading,
  }) {
    final categorySet = <String>{};
    final mapped = rows.map((row) {
      final institution = row['institution'] as Map<String, dynamic>?;
      final category = (row['category'] ?? 'General').toString();
      if (category.trim().isNotEmpty) {
        categorySet.add(category);
      }
      final isActive = row['is_active'] == true;
      String status = isActive ? 'Active' : 'Closed';
      final endsAt = row['ends_at']?.toString();
      if (endsAt != null) {
        final dt = DateTime.tryParse(endsAt)?.toLocal();
        if (dt != null && dt.isBefore(DateTime.now())) {
          status = 'Closed';
        }
      }
      return {
        'id': row['id'],
        'title': row['title'] ?? '',
        'school': institution?['name'] ?? '',
        'goal': double.tryParse((row['target_amount'] ?? '0').toString()) ?? 0,
        'raised':
            double.tryParse((row['raised_amount'] ?? '0').toString()) ?? 0,
        'currency': (row['currency'] ?? 'GHS').toString(),
        'status': status,
        'is_active': isActive,
        'category': category,
        'image': resolveMediaUrl(row['image_url']?.toString()),
        'description': row['description'] ?? '',
        'providers':
            (row['enabled_providers'] as List?)?.cast<String>() ??
            const <String>[],
      };
    }).toList();
    final nextCategories = ['All', ...categorySet.toList()..sort()];
    setState(() {
      fundings = mapped;
      categories = nextCategories;
      if (!categories.contains(filterCategory)) {
        filterCategory = 'All';
      }
      _loading = false;
    });
  }

  /// FILTER
  List<Map<String, dynamic>> get filteredFundings {
    return fundings.where((f) {
      final title = (f['title'] as String).toLowerCase();

      final matchesSearch = title.contains(searchCtrl.text.toLowerCase());

      final matchesCategory =
          filterCategory == 'All' || f['category'] == filterCategory;

      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Active' && f['is_active'] == true) ||
          (_statusFilter == 'Drafts' && f['is_active'] != true);

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _isSchoolAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateCampaignScreen(),
                  ),
                );
                if (created == true) {
                  _loadCampaigns();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadCampaigns,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      isCompact ? 20 : 22,
                      16,
                      12,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isCompact ? 16 : 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF16A34A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isCompact ? 42 : 48,
                            height: isCompact ? 42 : 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: isCompact ? 14 : 18),
                          Text(
                            'Funding',
                            style: TextStyle(
                              fontSize: isCompact ? 24 : 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Support causes, school projects, and alumni-led campaigns from one polished space.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search fundraisers…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: theme.cardColor,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                if (categories.length > 1 || _isSchoolAdmin)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (categories.length > 1)
                            _ModernFilterChip(
                              label: filterCategory,
                              icon: Icons.category_rounded,
                              options: categories,
                              onSelected: (v) =>
                                  setState(() => filterCategory = v),
                            ),
                          if (_isSchoolAdmin) ...[
                            const SizedBox(width: 10),
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _statusFilter == 'All',
                              onSelected: (_) =>
                                  setState(() => _statusFilter = 'All'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Active'),
                              selected: _statusFilter == 'Active',
                              onSelected: (_) =>
                                  setState(() => _statusFilter = 'Active'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Drafts'),
                              selected: _statusFilter == 'Drafts',
                              onSelected: (_) =>
                                  setState(() => _statusFilter = 'Drafts'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: _loading && fundings.isEmpty
                        ? 3
                        : filteredFundings.length,
                    itemBuilder: (_, i) {
                      if (_loading && fundings.isEmpty) {
                        return const _FundingSkeletonCard();
                      }
                      final fund = filteredFundings[i];
                      final percent = (fund['raised'] / fund['goal']).clamp(
                        0.0,
                        1.0,
                      );

                      return GestureDetector(
                        onTap: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FundingDetailScreen(fund: fund),
                            ),
                          );
                          if (changed == true) {
                            _loadCampaigns();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // IMAGE
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                                child:
                                    fund['image'] != null &&
                                        (fund['image'] as String).isNotEmpty
                                    ? Image.network(
                                        fund['image'],
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          height: 160,
                                          color: scheme.surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 42,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 160,
                                        color: scheme.surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.volunteer_activism,
                                          size: 42,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            fund['title'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        _StatusBadge(status: fund['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      fund['school'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      fund['description']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? fund['description'].toString()
                                          : 'Support this campaign and help move the community forward.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                    if ((fund['providers'] as List)
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: (fund['providers'] as List)
                                            .map(
                                              (p) => _ProviderChip(
                                                provider: p.toString(),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 6,
                                      backgroundColor:
                                          scheme.surfaceContainerHighest,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${_formatCurrency(fund['currency'], fund['raised'])} raised of ${_formatCurrency(fund['currency'], fund['goal'])}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _currency = 'GHS';
  bool _saving = false;
  bool _publishNow = true;
  String? _imageUrl;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim());
    if (title.isEmpty || target == null || target <= 0) return;
    setState(() => _saving = true);
    final campaign = await HomeApiService.createDonationCampaign(
      title: title,
      targetAmount: target,
      currency: _currency,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      imageUrl: _imageUrl,
      isActive: _publishNow,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (campaign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create campaign')),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Campaign basics',
              subtitle:
                  'Frame the cause, target amount, and visual identity clearly.',
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('Campaign title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Target amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: _inputDecoration('Currency'),
                    items: const [
                      DropdownMenuItem(value: 'GHS', child: Text('GHS')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    ],
                    onChanged: (value) =>
                        setState(() => _currency = value ?? 'GHS'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            resolveMediaUrl(_imageUrl!) ?? _imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image,
                                size: 20,
                                color: Colors.black38,
                              ),
                            ),
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
                          child: const Icon(
                            Icons.image_outlined,
                            size: 28,
                            color: Colors.black38,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(color: Color(0xFFCCFBF1)),
                          ),
                          onPressed: _saving
                              ? null
                              : () async {
                                  final image = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (image == null) return;
                                  final upload =
                                      await HomeApiService.uploadMedia(
                                        filePath: image.path,
                                        fileName: image.name,
                                      );
                                  if (upload == null || upload['url'] == null) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Image upload failed'),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  setState(
                                    () => _imageUrl = upload['url'].toString(),
                                  );
                                },
                          icon: const Icon(Icons.upload_rounded),
                          label: const Text('Upload cover'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Campaign story',
              subtitle:
                  'Help donors understand what the funds are for and the impact they make.',
              child: TextField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: _inputDecoration('About donation project').copyWith(
                  hintText:
                      'Explain the need, expected impact, and where support goes.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Publish settings',
              subtitle:
                  'Choose whether alumni should see the campaign immediately.',
              child: _toggleTile(
                value: _publishNow,
                onChanged: (value) => setState(() => _publishNow = value),
                icon: Icons.public_rounded,
                title: 'Publish now',
                subtitle: _publishNow
                    ? 'Visible to alumni immediately'
                    : 'Save as draft for internal review',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
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
                        'Create campaign',
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
        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.4),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF0F172A)],
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
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Create a campaign',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Launch a fundraising page that feels credible, mission-driven, and easy for alumni to support.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
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
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
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

class _FundingSkeletonCard extends StatelessWidget {
  const _FundingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            width: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _ModernFilterChip({
    required this.label,
    required this.icon,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) =>
          options.map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
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

String? resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final base = Uri.parse(ApiConfig.baseUrl);
  if (url.startsWith('http://') || url.startsWith('https://')) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host;
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return uri
          .replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          )
          .toString();
    }
    return url;
  }
  if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
  return '${ApiConfig.baseUrl}/$url';
}

String _formatCurrency(dynamic code, dynamic amount) {
  final currency = (code ?? 'GHS').toString().toUpperCase();
  final symbol = _currencySymbol(currency);
  return '$symbol ${amount ?? 0}';
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'Closed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClosed
              ? [Colors.orange, Colors.deepOrangeAccent]
              : [Colors.green, Colors.teal],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
