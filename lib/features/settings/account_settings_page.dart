import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/providers/all_providers.dart';
import '../../shared/widgets/async_value_view_enhanced.dart';
import '../../app/app_routes.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional imports for web-only functionality
import 'account_settings_web_stub.dart'
    if (dart.library.html) 'account_settings_web.dart';

class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  bool _isDeleting = false;
  bool _isLinking = false;
  bool _isExporting = false;

  Future<void> _deleteAccount() async {
    // First, get validation warnings
    try {
      final warnings =
          await ref.read(authServiceProvider).validateAccountDeletion();

      if (!mounted) return;

      // Show confirmation dialog with warnings
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete your account?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('This action will permanently delete:'),
                const SizedBox(height: 8),
                const Text('â€¢ Your profile and personal information'),
                const Text('â€¢ All your created events'),
                const Text('â€¢ Your messages and conversations'),
                const Text('â€¢ Your photos and media'),
                const Text('â€¢ Your subscription data'),
                const Text('â€¢ All other account data'),
                const SizedBox(height: 16),
                const Text(
                  'âš ï¸ This action cannot be undone!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Important notices:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...warnings.map((warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('âš ï¸ $warning'),
                      )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.shade50,
              ),
              child: const Text('Delete My Account'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isDeleting = true);

      try {
        await ref.read(authServiceProvider).deleteAccount();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deleted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      } on Exception catch (e) {
        if (mounted) {
          // Check if reauthentication is needed
          if (e.toString().contains('sign in again')) {
            _showReauthenticationDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete account: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showReauthenticationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reauthentication Required'),
        content: const Text(
          'For security reasons, you need to sign in again before deleting your account. '
          'Please log out and log back in, then try deleting your account again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _linkGoogleAccount() async {
    setState(() => _isLinking = true);

    try {
      await ref.read(authServiceProvider).linkWithGoogle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google account linked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link Google account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  Future<void> _unlinkProvider(String providerId, String providerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Account'),
        content: Text(
          'Are you sure you want to unlink your $providerName account? '
          'You will need to use another sign-in method to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLinking = true);

    try {
      await ref.read(authServiceProvider).unlinkProvider(providerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$providerName account unlinked successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlink account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  Future<void> _exportData() async {
    // Show summary dialog first
    setState(() => _isExporting = true);

    try {
      final summary = await ref.read(authServiceProvider).getExportSummary();

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Your Data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your data export will include:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildExportSummaryRow('Profile Information', '1 record'),
                if (summary['events_created'] != null &&
                    summary['events_created']! > 0)
                  _buildExportSummaryRow(
                      'Events Created', '${summary['events_created']} events'),
                if (summary['messages_sent'] != null &&
                    summary['messages_sent']! > 0)
                  _buildExportSummaryRow(
                      'Messages Sent', '${summary['messages_sent']} messages'),
                if (summary['following'] != null && summary['following']! > 0)
                  _buildExportSummaryRow(
                      'Following', '${summary['following']} users'),
                if (summary['followers'] != null && summary['followers']! > 0)
                  _buildExportSummaryRow(
                      'Followers', '${summary['followers']} users'),
                _buildExportSummaryRow('Reports & Blocks', 'All records'),
                _buildExportSummaryRow('Subscription Data', 'If applicable'),
                const SizedBox(height: 16),
                const Text(
                  'The data will be exported as a JSON file that you can download.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Export Data'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) {
        setState(() => _isExporting = false);
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Exporting your data...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final jsonData = await ref.read(authServiceProvider).exportUserData();

      if (!mounted) return;

      // Download the file
      _downloadJsonFile(jsonData,
          'mixmingle_data_export_${DateTime.now().millisecondsSinceEpoch}.json');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildExportSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('â€¢ $label'),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _downloadJsonFile(String jsonData, String filename) {
    if (kIsWeb) {
      // Web download using conditional import
      final bytes = utf8.encode(jsonData);
      downloadJsonOnWeb(Uint8List.fromList(bytes), filename);
    } else {
      // Mobile - would need path_provider and file writing
      // For now, just show the user they need to implement this
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Mobile download not yet implemented. Use web version.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: AsyncValueViewEnhanced(
        value: currentUserAsync,
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Information Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Email', user?.email ?? 'Not set'),
                    _buildInfoRow('User ID', user?.id ?? 'Unknown'),
                    _buildInfoRow(
                      'Member Since',
                      user != null
                          ? DateFormat.yMMMM().format(user.createdAt)
                          : 'Unknown',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email & Password Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Change Email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Navigate to change email page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feature coming soon')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Navigate to change password page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feature coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Subscription Section
            Card(
              child: ListTile(
                leading: const Icon(Icons.card_membership),
                title: const Text('Manage Subscription'),
                subtitle: const Text('View and manage your subscription'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushNamed('/subscription');
                },
              ),
            ),
            const SizedBox(height: 16),

            // Linked Accounts Section
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Linked Accounts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.facebook),
                    title: const Text('Facebook'),
                    subtitle: const Text('Not connected'),
                    trailing: TextButton(
                      onPressed: () {
                        // TODO: Implement Facebook linking
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.g_mobiledata),
                    title: const Text('Google'),
                    subtitle: const Text('Not connected'),
                    trailing: TextButton(
                      onPressed: () {
                        // TODO: Implement Google linking
                      },
                      child: const Text('Connect'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Linked Accounts Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Accounts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Link multiple sign-in methods to your account for easier access',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    _buildLinkedAccountsList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Data & Privacy Section
            Text(
              'Data & Privacy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Export Your Data'),
                    subtitle: const Text('Download a copy of your data (GDPR)'),
                    trailing: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isExporting ? null : _exportData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Privacy Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Privacy settings coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Danger Zone Section
            Card(
              color: Colors.red.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.red.shade900,
                          ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        Icon(Icons.delete_forever, color: Colors.red.shade700),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    subtitle:
                        const Text('Permanently delete your account and data'),
                    onTap: _isDeleting ? null : _deleteAccount,
                    trailing: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.chevron_right, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountsList() {
    final authService = ref.read(authServiceProvider);
    final linkedProviders = authService.getLinkedProviders();

    return Column(
      children: [
        // Email/Password
        _buildProviderTile(
          'password',
          'Email/Password',
          Icons.email,
          linkedProviders.contains('password'),
        ),
        const Divider(height: 1),

        // Google
        _buildProviderTile(
          'google.com',
          'Google',
          Icons.g_mobiledata,
          linkedProviders.contains('google.com'),
        ),

        // Future providers can be added here
        // const Divider(height: 1),
        // _buildProviderTile('facebook.com', 'Facebook', Icons.facebook, false),
      ],
    );
  }

  Widget _buildProviderTile(
    String providerId,
    String providerName,
    IconData icon,
    bool isLinked,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(providerName),
      subtitle: Text(isLinked ? 'Connected' : 'Not connected'),
      trailing: isLinked
          ? TextButton(
              onPressed: _isLinking
                  ? null
                  : () => _unlinkProvider(providerId, providerName),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Unlink'),
            )
          : ElevatedButton(
              onPressed: _isLinking
                  ? null
                  : () async {
                      if (providerId == 'google.com') {
                        await _linkGoogleAccount();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$providerName linking coming soon'),
                          ),
                        );
                      }
                    },
              child: const Text('Link'),
            ),
    );
  }
}
