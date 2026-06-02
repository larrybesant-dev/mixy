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
                SizedBox(height: 8),
                Text(
                  'By using MixVy, you agree to follow community standards, avoid abusive behavior, and use payments features lawfully. '
                  'Accounts may be restricted for fraud, harassment, or repeated policy violations.',
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
                  'Fraudulent activity can result in account suspension and payment restrictions.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Content and Conduct'),
                SizedBox(height: 8),
                Text(
                  'You must not share illegal, exploitative, hateful, or spam content. '
                  'We may remove content and limit features to protect users and platform integrity.',
                ),
                SizedBox(height: 16),
                _SectionTitle('Termination'),
                SizedBox(height: 8),
                Text(
                  'You can delete your account from Account Center. MixVy may suspend or terminate access for significant violations or abuse attempts.',
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
