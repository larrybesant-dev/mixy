import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/layout/app_layout.dart';
import '../../shared/widgets/app_page_scaffold.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static final Uri _supportEmail = Uri(
    scheme: 'mailto',
    path: 'larrybesant@gmail.com',
    queryParameters: {
      'subject': 'MixVy support request',
    },
  );

  Future<void> _contactSupport(BuildContext context) async {
    try {
      final launched = await launchUrl(
        _supportEmail,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showLaunchError(context);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open your email app: $error')),
      );
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open your email app. Email larrybesant@gmail.com directly.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Support'),
        actions: [
          IconButton(
            tooltip: 'Go to Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.all(context.pageHorizontalPadding),
            children: [
              Text(
                'How can we help?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Contact MixVy support for account access, safety concerns, '
                'privacy requests, or technical problems.',
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email support'),
                  subtitle: const SelectableText('larrybesant@gmail.com'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _contactSupport(context),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Include your MixVy account email, app version, device type, '
                'and a short description of what happened. Do not send your '
                'password or payment credentials.',
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/legal/privacy'),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Read Privacy Policy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
