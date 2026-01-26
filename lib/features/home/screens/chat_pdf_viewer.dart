import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatPdfViewer extends StatefulWidget {
  final String title;
  final String url;

  const ChatPdfViewer({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<ChatPdfViewer> createState() => _ChatPdfViewerState();
}

class _ChatPdfViewerState extends State<ChatPdfViewer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(
          'https://docs.google.com/gview?embedded=true&url=${widget.url}',
        ),
      );
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