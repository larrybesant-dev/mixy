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
          const SizedBox(height: 4),
          const Text('Effective October 3, 2026'),
          const SizedBox(height: 16),
          const _PolicySection('Who operates MixVy'),
          const SizedBox(height: 8),
          const Text(
            'MixVy is operated by Southern Supply Services. Questions and privacy requests can be sent to larrybesant@gmail.com.',
          ),
          const SizedBox(height: 16),
          const _PolicySection('Data we collect'),
          const SizedBox(height: 8),
          const Text(
            'We process account and profile details, sign-in identifiers, user-generated content, messages, room and call activity, safety reports, device and diagnostic data, notification tokens, approximate location when provided, and transaction records. '
            'Live audio or video is transmitted to provide room and call features; recordings are collected only when a feature clearly says that recording is active.',
          ),
          const SizedBox(height: 16),
          const _PolicySection('How we use data'),
          const SizedBox(height: 8),
          const Text(
            'We use data to provide and secure MixVy, personalize social features, deliver notifications, process transactions, prevent fraud and abuse, investigate reports, maintain service reliability, and meet legal obligations. '
            'We do not sell personal information.',
          ),
          const SizedBox(height: 16),
          const _PolicySection('Service providers and disclosure'),
          const SizedBox(height: 8),
          const Text(
            'We share only the data needed with providers that support authentication, hosting, databases, analytics, crash reporting, notifications, live communications, and payments, including Google Firebase, Agora, and Stripe when those features are enabled. '
            'We may also disclose data when required by law or necessary to protect users, the public, or the service.',
          ),
          const SizedBox(height: 16),
          const _PolicySection('Retention and deletion'),
          const SizedBox(height: 8),
          const Text(
            'We retain account data while the account is active. Account deletion removes account and user-facing profile data, subject to backup processing and records we must preserve. '
            'Operational logs associated with a deleted account are retained for up to 30 days unless an active safety or legal investigation requires longer. Financial records required for tax, fraud prevention, or legal compliance may be retained for up to 7 years.',
          ),
          const SizedBox(height: 16),
          const _PolicySection('Your choices and rights'),
          const SizedBox(height: 8),
          const Text(
            'You can manage profile visibility and preferences in the app and delete your account from Account Center. You may ask to access, correct, or export your data, or object to certain processing, by contacting larrybesant@gmail.com. '
            'We may verify your identity before completing a request, and local law may limit some requests.',
          ),
          const SizedBox(height: 16),
          const _PolicySection('Age, security, and changes'),
          const SizedBox(height: 8),
          const Text(
            'MixVy is for adults age 18 or older. We use administrative, technical, and organizational safeguards, but no online service can guarantee absolute security. '
            'We may update this policy as the service or law changes. Material updates will be identified by a new effective date and, when appropriate, an in-app notice.',
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

class _PolicySection extends StatelessWidget {
  const _PolicySection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}
