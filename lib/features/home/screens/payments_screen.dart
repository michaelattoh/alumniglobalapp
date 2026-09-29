import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final ScrollController _controller = ScrollController();
  final List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  bool _showPayerDetails = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadPayments() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    final data = await HomeApiService.fetchPaymentHistory(page: 1, perPage: 20);
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
    final rows = (data['data'] as List<Map<String, dynamic>>?) ?? [];
    setState(() {
      _rows
        ..clear()
        ..addAll(rows);
      _showPayerDetails = rows.any((row) => row['user'] is Map);
      _loading = false;
      _page = 1;
      _hasMore = _page < lastPage;
    });
  }

  Future<void> _openReceipt(String receiptUrl) async {
    final uri = Uri.tryParse(receiptUrl);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open receipt right now')),
      );
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    final data = await HomeApiService.fetchPaymentHistory(
      page: nextPage,
      perPage: 20,
    );
    if (!mounted) return;
    final meta = data['meta'] as Map<String, dynamic>?;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? nextPage;
    setState(() {
      _rows.addAll((data['data'] as List<Map<String, dynamic>>?) ?? []);
      _loadingMore = false;
      _page = nextPage;
      _hasMore = _page < lastPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completedCount = _rows.where((row) {
      final status = row['status']?.toString().toLowerCase() ?? '';
      return status == 'success' || status == 'completed';
    }).length;
    final receiptCount = _rows.where((row) {
      return (row['receipt_url']?.toString() ?? '').isNotEmpty;
    }).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: RefreshIndicator(
          onRefresh: _loadPayments,
          child: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      _heroCard(completedCount, receiptCount),
                      const SizedBox(height: 28),
                      Center(child: Text(_error!)),
                    ],
                  )
                : ListView.builder(
                    controller: _controller,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _rows.length + (_loadingMore ? 1 : 0) + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _heroCard(completedCount, receiptCount),
                        );
                      }
                      final index = i - 1;
                      if (index >= _rows.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final row = _rows[index];
                      final amount = row['amount']?.toString() ?? '0';
                      final currency = row['currency']?.toString() ?? 'GHS';
                      final status = row['status']?.toString() ?? 'unknown';
                      final type = row['type']?.toString() ?? 'payment';
                      final reference = row['reference']?.toString() ?? '';
                      final receiptUrl = row['receipt_url']?.toString();
                      final paidAt = row['paid_at']?.toString();
                      final user = (row['user'] as Map<String, dynamic>?) ?? {};
                      final payerName = (user['name'] ?? '').toString();
                      final lowerStatus = status.toLowerCase();
                      final statusColor =
                          lowerStatus == 'success' || lowerStatus == 'completed'
                          ? const Color(0xFF059669)
                          : lowerStatus == 'pending'
                          ? const Color(0xFFD97706)
                          : const Color(0xFF64748B);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 16,
                              offset: Offset(0, 10),
                              color: Color(0x12000000),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatCurrency(currency, amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (_showPayerDetails &&
                                          payerName.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Paid by $payerName',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (reference.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Reference',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reference,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                            if (paidAt != null && paidAt.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                paidAt,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (receiptUrl != null &&
                                receiptUrl.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openReceipt(receiptUrl),
                                    icon: const Icon(
                                      Icons.receipt_long_rounded,
                                    ),
                                    label: const Text('View receipt'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: receiptUrl),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Receipt link copied'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.link_rounded),
                                    label: const Text('Copy link'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(int completedCount, int receiptCount) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Payment history',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showPayerDetails
                ? 'Track alumni payments, donations, subscriptions, and receipts in one place.'
                : 'Track donations, subscriptions, and receipts in one place.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _heroStat('Records', '${_rows.length}'),
              const SizedBox(width: 12),
              _heroStat('Completed', '$completedCount'),
              const SizedBox(width: 12),
              _heroStat('Receipts', '$receiptCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 12,
              ),
            ),
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

String _formatCurrency(dynamic code, dynamic amount) {
  final currency = (code ?? 'GHS').toString().toUpperCase();
  final symbol = _currencySymbol(currency);
  return '$symbol ${amount ?? 0}';
}
