import 'package:flutter/material.dart';

class DesktopMessengerShell extends StatelessWidget {
  const DesktopMessengerShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
    );
  }
}
