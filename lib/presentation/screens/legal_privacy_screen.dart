import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_layout.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../widgets/friends_panel_button.dart';

class LegalPrivacyScreen extends StatelessWidget {
  const LegalPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            tooltip: 'Go to Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/'),
          ),
          const FriendsPanelButton(),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        children: [
          Text(
            'MixVy Privacy Policy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'We collect only the data needed to run social features, safety tools, and payment workflows. '
            'This includes profile metadata, room activity metadata, and transaction records required for fraud prevention and compliance.',
          ),
          const SizedBox(height: 16),
          const Text(
            'You can control profile visibility and account preferences in Settings and profile privacy tools. '
            'You can request account deletion from Account Center, which removes user-facing profile data and disables account access.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Operational logs and payment records may be retained for a limited period to satisfy abuse investigations, legal obligations, and financial auditing.',
          ),
          const SizedBox(height: 16),
          const Text(
            'By continuing to use MixVy, you acknowledge this policy and consent to data processing required to provide core app functionality and enforce platform safety.',
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/legal/terms'),
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Back to Terms of Service'),
          ),
        ],
      ),
    );
  }
}



