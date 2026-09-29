import 'package:flutter/material.dart';
import 'package:alumni_global_app/core/services/home_api_service.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _settings;
  bool _savingStripe = false;
  bool _savingPaystack = false;
  bool _savingPaypal = false;
  bool _savingFlutterwave = false;

  final stripePublicCtrl = TextEditingController();
  final stripeSecretCtrl = TextEditingController();
  final paystackPublicCtrl = TextEditingController();
  final paystackSecretCtrl = TextEditingController();
  final paypalClientIdCtrl = TextEditingController();
  final paypalClientSecretCtrl = TextEditingController();
  final flutterwavePublicCtrl = TextEditingController();
  final flutterwaveSecretCtrl = TextEditingController();

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
      final data = await HomeApiService.fetchInstitutionPaymentSettings();
      if (!mounted) return;
      setState(() {
        _settings = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load payment settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProvider(String provider) async {
    setState(() => _error = null);

    final payload = <String, dynamic>{};
    if (provider == 'stripe') {
      if (stripePublicCtrl.text.trim().isNotEmpty) {
        payload['stripe_public_key'] = stripePublicCtrl.text.trim();
      }
      if (stripeSecretCtrl.text.trim().isNotEmpty) {
        payload['stripe_secret_key'] = stripeSecretCtrl.text.trim();
      }
      setState(() => _savingStripe = true);
    } else if (provider == 'paystack') {
      if (paystackPublicCtrl.text.trim().isNotEmpty) {
        payload['paystack_public_key'] = paystackPublicCtrl.text.trim();
      }
      if (paystackSecretCtrl.text.trim().isNotEmpty) {
        payload['paystack_secret_key'] = paystackSecretCtrl.text.trim();
      }
      setState(() => _savingPaystack = true);
    } else if (provider == 'paypal') {
      if (paypalClientIdCtrl.text.trim().isNotEmpty) {
        payload['paypal_client_id'] = paypalClientIdCtrl.text.trim();
      }
      if (paypalClientSecretCtrl.text.trim().isNotEmpty) {
        payload['paypal_client_secret'] = paypalClientSecretCtrl.text.trim();
      }
      setState(() => _savingPaypal = true);
    } else if (provider == 'flutterwave') {
      if (flutterwavePublicCtrl.text.trim().isNotEmpty) {
        payload['flutterwave_public_key'] = flutterwavePublicCtrl.text.trim();
      }
      if (flutterwaveSecretCtrl.text.trim().isNotEmpty) {
        payload['flutterwave_secret_key'] = flutterwaveSecretCtrl.text.trim();
      }
      setState(() => _savingFlutterwave = true);
    }

    if (payload.isEmpty) {
      setState(() {
        _error = 'Enter at least one key to update.';
        _savingStripe = false;
        _savingPaystack = false;
        _savingPaypal = false;
        _savingFlutterwave = false;
      });
      return;
    }

    final ok = await HomeApiService.updateInstitutionPaymentSettings(payload);
    if (!mounted) return;
    setState(() {
      _savingStripe = false;
      _savingPaystack = false;
      _savingPaypal = false;
      _savingFlutterwave = false;
    });

    if (!ok) {
      setState(() => _error = 'Failed to save payment settings.');
      return;
    }

    if (provider == 'stripe') {
      stripePublicCtrl.clear();
      stripeSecretCtrl.clear();
    } else if (provider == 'paystack') {
      paystackPublicCtrl.clear();
      paystackSecretCtrl.clear();
    } else if (provider == 'paypal') {
      paypalClientIdCtrl.clear();
      paypalClientSecretCtrl.clear();
    } else if (provider == 'flutterwave') {
      flutterwavePublicCtrl.clear();
      flutterwaveSecretCtrl.clear();
    }

    await _loadSettings();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${provider[0].toUpperCase()}${provider.substring(1)} settings saved')),
    );
  }

  @override
  void dispose() {
    stripePublicCtrl.dispose();
    stripeSecretCtrl.dispose();
    paystackPublicCtrl.dispose();
    paystackSecretCtrl.dispose();
    paypalClientIdCtrl.dispose();
    paypalClientSecretCtrl.dispose();
    flutterwavePublicCtrl.dispose();
    flutterwaveSecretCtrl.dispose();
    super.dispose();
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _keyField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter new value',
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
    final stripe = _settings?['stripe'] as Map<String, dynamic>? ?? {};
    final paystack = _settings?['paystack'] as Map<String, dynamic>? ?? {};
    final paypal = _settings?['paypal'] as Map<String, dynamic>? ?? {};
    final flutterwave = _settings?['flutterwave'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Payment Settings'),
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
                _section(
                  title: 'Stripe',
                  subtitle: stripe['secret_key_set'] == true
                      ? 'Connected (Secret: ${stripe['secret_key_hint'] ?? '••••'})'
                      : 'Not connected',
                  children: [
                    _keyField('Stripe public key', stripePublicCtrl),
                    _keyField('Stripe secret key', stripeSecretCtrl),
                    ElevatedButton(
                      onPressed: _savingStripe ? null : () => _saveProvider('stripe'),
                      child: _savingStripe
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Stripe'),
                    ),
                  ],
                ),
                _section(
                  title: 'Paystack',
                  subtitle: paystack['secret_key_set'] == true
                      ? 'Connected (Secret: ${paystack['secret_key_hint'] ?? '••••'})'
                      : 'Not connected',
                  children: [
                    _keyField('Paystack public key', paystackPublicCtrl),
                    _keyField('Paystack secret key', paystackSecretCtrl),
                    ElevatedButton(
                      onPressed: _savingPaystack ? null : () => _saveProvider('paystack'),
                      child: _savingPaystack
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Paystack'),
                    ),
                  ],
                ),
                _section(
                  title: 'PayPal',
                  subtitle: paypal['client_secret_set'] == true
                      ? 'Connected (Secret: ${paypal['client_secret_hint'] ?? '••••'})'
                      : 'Not connected',
                  children: [
                    _keyField('PayPal client ID', paypalClientIdCtrl),
                    _keyField('PayPal client secret', paypalClientSecretCtrl),
                    ElevatedButton(
                      onPressed: _savingPaypal ? null : () => _saveProvider('paypal'),
                      child: _savingPaypal
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save PayPal'),
                    ),
                  ],
                ),
                _section(
                  title: 'Flutterwave',
                  subtitle: flutterwave['secret_key_set'] == true
                      ? 'Connected (Secret: ${flutterwave['secret_key_hint'] ?? '••••'})'
                      : 'Not connected',
                  children: [
                    _keyField('Flutterwave public key', flutterwavePublicCtrl),
                    _keyField('Flutterwave secret key', flutterwaveSecretCtrl),
                    ElevatedButton(
                      onPressed: _savingFlutterwave ? null : () => _saveProvider('flutterwave'),
                      child: _savingFlutterwave
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Flutterwave'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
