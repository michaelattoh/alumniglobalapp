import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showPinSetupDialog(BuildContext context) async {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  String? error;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          Future<void> submit() async {
            final pin = pinController.text.trim();
            final confirm = confirmController.text.trim();
            if (pin.length != 4 || confirm.length != 4) {
              setState(() => error = 'Enter a 4-digit PIN.');
              return;
            }
            if (pin != confirm) {
              setState(() => error = 'PINs do not match.');
              return;
            }
            Navigator.of(dialogCtx).pop(pin);
          }

          return AlertDialog(
            title: const Text('Set a PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Confirm PIN'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submit,
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showPinVerifyDialog(BuildContext context, {required Future<bool> Function(String) verify}) async {
  final pinController = TextEditingController();
  String? error;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setState) {
          Future<void> submit() async {
            final pin = pinController.text.trim();
            if (pin.length != 4) {
              setState(() => error = 'Enter your 4-digit PIN.');
              return;
            }
            final ok = await verify(pin);
            if (!ok) {
              setState(() => error = 'Incorrect PIN.');
              return;
            }
            Navigator.of(dialogCtx).pop(true);
          }

          return AlertDialog(
            title: const Text('Enter PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '4-digit PIN'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: submit,
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );

  return result == true;
}
