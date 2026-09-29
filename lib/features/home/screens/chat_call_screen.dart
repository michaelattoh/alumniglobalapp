import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatCallScreen extends StatefulWidget {
  final String title;
  final String url;

  const ChatCallScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<ChatCallScreen> createState() => _ChatCallScreenState();
}

class _ChatCallScreenState extends State<ChatCallScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
