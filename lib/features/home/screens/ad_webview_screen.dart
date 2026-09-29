import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AdWebviewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const AdWebviewScreen({super.key, required this.url, this.title});

  @override
  State<AdWebviewScreen> createState() => _AdWebviewScreenState();
}

class _AdWebviewScreenState extends State<AdWebviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Sponsored'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
