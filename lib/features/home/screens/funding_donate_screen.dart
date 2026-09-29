import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class FundingDonateScreen extends StatefulWidget {
  final Map<String, dynamic> fund;

  const FundingDonateScreen({super.key, required this.fund});

  @override
  State<FundingDonateScreen> createState() => _FundingDonateScreenState();
}

class _FundingDonateScreenState extends State<FundingDonateScreen> {
  final amountCtrl = TextEditingController();
  String method = 'stripe';
  bool loading = false;
  String? errorMessage;
  final List<Map<String, dynamic>> methods = const [
    {'label': 'Card (Stripe)', 'value': 'stripe', 'icon': Icons.credit_card},
    {'label': 'Paystack', 'value': 'paystack', 'icon': Icons.payments},
    {'label': 'PayPal', 'value': 'paypal', 'icon': Icons.account_balance},
    {'label': 'Flutterwave', 'value': 'flutterwave', 'icon': Icons.flash_on},
    {'label': 'Mobile Money', 'value': 'momo', 'icon': Icons.phone_iphone},
  ];

  void _pay() async {
    if (amountCtrl.text.isEmpty) return;

    setState(() => loading = true);
    setState(() => errorMessage = null);

    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        loading = false;
        errorMessage = 'Enter a valid amount.';
      });
      return;
    }

    final provider = method;
    final currency = (widget.fund['currency'] ?? 'GHS').toString();
    final campaignId = widget.fund['id'] as int?;

    bool ok = false;
    String? checkoutUrl;
    if (campaignId != null) {
      final result = await HomeApiService.donateToCampaign(
        campaignId: campaignId,
        amount: amount,
        provider: provider,
        currency: currency,
      );
      ok = result['ok'] == true;
      checkoutUrl = result['checkout_url']?.toString();
      if (!ok && result['message'] != null) {
        errorMessage = result['message'].toString();
      }
    }

    setState(() => loading = false);

    if (!ok) {
      setState(() => errorMessage = errorMessage ?? 'Payment failed. Please try again.');
      return;
    }

    if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
      final uri = Uri.tryParse(checkoutUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hourglass_bottom,
                size: 64, color: Colors.orange),
            SizedBox(height: 12),
            Text(
              "Payment initiated.\nWe will update your status once confirmed.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Done"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final enabledProviders = (widget.fund['providers'] as List?)?.cast<String>() ?? const <String>[];
    final allowedProviders = <String>{
      ...enabledProviders.map((e) => e.toLowerCase()),
      if (enabledProviders.map((e) => e.toLowerCase()).contains('paystack')) 'momo',
    };
    final visibleMethods = allowedProviders.isEmpty
        ? methods
        : methods.where((m) => allowedProviders.contains(m['value'] as String)).toList();
    if (visibleMethods.isNotEmpty && !allowedProviders.contains(method)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => method = visibleMethods.first['value'] as String);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Donate")),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, media.padding.bottom + 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount (${_currencySymbol((widget.fund['currency'] ?? 'GHS').toString())})",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),

            // PAYMENT METHOD
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: visibleMethods
                  .map(
                    (option) => ChoiceChip(
                      avatar: Icon(
                        option['icon'] as IconData,
                        size: 18,
                        color:
                            method == option['value'] ? Colors.white : null,
                      ),
                      label: Text(option['label'] as String),
                      selected: method == option['value'],
                      onSelected: (_) =>
                          setState(() => method = option['value'] as String),
                    ),
                  )
                  .toList(),
            ),
            if (visibleMethods.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'No payment methods are configured for this school yet.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: visibleMethods.isEmpty ? null : _pay,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: const Text("Proceed to Pay"),
                      ),
              ),
            ],
          ),
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
