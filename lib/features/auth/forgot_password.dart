import 'package:flutter/material.dart';

import 'package:mixvy/shared/widgets/app_page_scaffold.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: Semantics(
          label: 'Forgot Password Screen',
          child: Text(
            'Forgot Password Screen',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 400 ? 20 : 18,
            ),
          ),
        ),
      ),
    );
  }
}
