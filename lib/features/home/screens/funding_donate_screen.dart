import 'package:flutter/material.dart';

class FundingDonateScreen extends StatefulWidget {
  final Map<String, dynamic> fund;

  const FundingDonateScreen({super.key, required this.fund});

  @override
  State<FundingDonateScreen> createState() => _FundingDonateScreenState();
}

class _FundingDonateScreenState extends State<FundingDonateScreen> {
  final amountCtrl = TextEditingController();
  String method = 'Card';
  bool loading = false;

  void _pay() async {
    if (amountCtrl.text.isEmpty) return;

    setState(() => loading = true);

    await Future.delayed(const Duration(seconds: 2));
    setState(() => loading = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle,
                size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text(
              "Payment successful!\nThank you for supporting this project.",
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
    return Scaffold(
      appBar: AppBar(title: const Text("Donate")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount (₵)",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // PAYMENT METHOD
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text("Card"),
                    selected: method == 'Card',
                    onSelected: (_) => setState(() => method = 'Card'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text("Mobile Money"),
                    selected: method == 'Momo',
                    onSelected: (_) => setState(() => method = 'Momo'),
                  ),
                ),
              ],
            ),

            const Spacer(),

            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _pay,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: const Text("Proceed to Pay"),
                  ),
          ],
        ),
      ),
    );
  }
}
