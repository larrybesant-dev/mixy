import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StitchFileViewer extends StatefulWidget {
  const StitchFileViewer({super.key, required this.path});

  final String path;

  @override
  State<StitchFileViewer> createState() => _StitchFileViewerState();
}

class _StitchFileViewerState extends State<StitchFileViewer> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFile(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: WebViewWidget(controller: controller));
  }
}
