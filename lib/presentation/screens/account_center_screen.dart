import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_layout.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../shared/widgets/app_page_scaffold.dart';

class AccountCenterScreen extends ConsumerStatefulWidget {
  const AccountCenterScreen({super.key});

  @override
  ConsumerState<AccountCenterScreen> createState() =>
      _AccountCenterScreenState();
}

class _AccountCenterScreenState extends ConsumerState<AccountCenterScreen> {
  bool _busy = false;

  String _providerLabel(String providerId) {
    switch (providerId) {
      case 'password':
        return 'Email and Password';
      case 'google.com':
        return 'Google';
      case 'apple.com':
        return 'Apple';
      case 'phone':
        return 'Phone Number';
      default:
        return providerId;
    }
  }

  Future<void> _unlinkProvider(String providerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final linkedProviders = user.providerData
        .where((provider) => provider.providerId.isNotEmpty)
        .map((provider) => provider.providerId)
        .toSet();

    if (linkedProviders.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must keep at least one sign-in method linked.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await user.unlink(providerId);
      await user.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_providerLabel(providerId)} has been unlinked.'),
        ),
      );
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not unlink provider: ${e.message ?? e.code}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send verification email: ${e.message ?? e.code}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email is associated with this account.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Password reset sent to $email')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send password reset: ${e.message ?? e.code}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmController = TextEditingController();
        return AlertDialog(
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This action is permanent. Type DELETE to continue.'),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Type DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(confirmController.text.trim().toUpperCase() == 'DELETE'),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      final uid = user.uid;
      await user.delete();
      await ref
          .read(authControllerProvider.notifier)
          .finalizeSessionCleanup(uidOverride: uid);
      if (!mounted) return;
      context.go('/auth');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'For security, log in again and retry account deletion.'
          : 'Could not delete account: ${e.message ?? e.code}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete account: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim();
    final emailText = email == null || email.isEmpty
        ? 'No email linked'
        : email;
    final linkedProviders =
        user?.providerData
            .where((provider) => provider.providerId.isNotEmpty)
            .toList(growable: false) ??
        const <UserInfo>[];

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Account Center')),
      body: ListView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Signed in as'),
              subtitle: Text(emailText),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: const Text('Verify email'),
                  subtitle: Text(
                    user?.emailVerified == true
                        ? 'Your email is verified.'
                        : 'Send verification email.',
                  ),
                  trailing: IconButton(
                    onPressed: _busy || user == null || user.emailVerified
                        ? null
                        : _sendVerificationEmail,
                    icon: const Icon(Icons.send_outlined),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  subtitle: const Text(
                    'We will email you a secure reset link.',
                  ),
                  trailing: IconButton(
                    onPressed: _busy || user == null
                        ? null
                        : _sendPasswordReset,
                    icon: const Icon(Icons.send_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  leading: Icon(Icons.link_outlined),
                  title: Text('Connected Sign-In Methods'),
                  subtitle: Text('Manage linked authentication providers.'),
                ),
                const Divider(height: 1),
                if (linkedProviders.isEmpty)
                  const ListTile(title: Text('No linked providers found.'))
                else
                  ...linkedProviders.map(
                    (provider) => ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(_providerLabel(provider.providerId)),
                      subtitle: Text(
                        provider.email?.trim().isNotEmpty == true
                            ? provider.email!.trim()
                            : 'Linked',
                      ),
                      trailing: TextButton(
                        onPressed: _busy || user == null
                            ? null
                            : () => _unlinkProvider(provider.providerId),
                        child: const Text('Unlink'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              title: const Text('Delete account'),
              subtitle: const Text(
                'Permanently remove your account and profile data.',
              ),
              trailing: FilledButton.tonal(
                onPressed: _busy || user == null ? null : _deleteAccount,
                child: const Text('Delete'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
