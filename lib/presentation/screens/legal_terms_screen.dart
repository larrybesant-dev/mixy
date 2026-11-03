import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';

import '../../core/layout/app_layout.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../widgets/friends_panel_button.dart';

import '../providers/app_settings_provider.dart';

class LegalTermsScreen extends ConsumerStatefulWidget {
  const LegalTermsScreen({super.key});

  @override
  ConsumerState<LegalTermsScreen> createState() => _LegalTermsScreenState();
}

class _LegalTermsScreenState extends ConsumerState<LegalTermsScreen> {
  bool _accepting = false;

  Future<void> _acceptAndContinue() async {
    setState(() => _accepting = true);
    try {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .acceptCurrentLegal();
      if (!mounted) return;

      final isLoggedIn = ref.read(authControllerProvider).uid != null;
      context.go(isLoggedIn ? '/home' : '/auth');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save acceptance: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider).valueOrNull;
    final accepted = settings?.hasAcceptedCurrentLegal ?? false;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        actions: [
          IconButton(
            tooltip: 'Go to Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/'),
          ),
          const FriendsPanelButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(context.pageHorizontalPadding),
              children: const [
                _SectionTitle('MixVy Terms of Service'),
                SizedBox(height: 4),
                Text('Effective October 3, 2026'),
                SizedBox(height: 8),
                Text(
                  'These Terms are an agreement between you and Southern Supply Services, the operator of MixVy. By creating an account or using MixVy, you agree to these Terms and the Privacy Policy. You must be at least 18 years old and legally able to enter this agreement.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Accounts and Safety'),
                SizedBox(height: 8),
                Text(
                  'You are responsible for your account security and activity under your login. '
                  'Do not impersonate others, evade enforcement, or attempt unauthorized access to systems or user data.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Payments and Virtual Value'),
                SizedBox(height: 8),
                Text(
                  'Payments and coin transfers are subject to anti-abuse monitoring, transaction review, and applicable regional rules. '
                  'Coins, gifts, badges, and other virtual items are licensed digital features, have no cash value unless MixVy expressly provides a withdrawal program, and may not be sold or transferred outside supported features. Fraudulent activity can result in account suspension and payment restrictions.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Content and Conduct'),
                SizedBox(height: 8),
                Text(
                  'You must not share illegal, exploitative, hateful, or spam content. '
                  'You keep ownership of content you submit and grant MixVy a worldwide, non-exclusive license to host, display, transmit, and moderate it only as needed to operate and promote the service. We may remove content and limit features to protect users and platform integrity.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Service Availability'),
                SizedBox(height: 8),
                Text(
                  'MixVy may change, suspend, or discontinue features and cannot guarantee uninterrupted or error-free service. To the extent allowed by law, the service is provided as available without implied warranties, and Southern Supply Services is not liable for indirect or consequential losses.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Termination'),
                SizedBox(height: 8),
                Text(
                  'You can delete your account from Account Center. MixVy may suspend or terminate access for significant violations or abuse attempts.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Changes and Contact'),
                SizedBox(height: 8),
                Text(
                  'We may update these Terms as MixVy changes. Material updates will be identified by a new effective date and, when appropriate, an in-app notice. Questions can be sent to larrybesant@gmail.com.',
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.pageHorizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/legal/privacy'),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Read Privacy Policy'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _accepting || accepted ? null : _acceptAndContinue,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(accepted ? 'Accepted' : 'Accept and Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}
