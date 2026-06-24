// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/app/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixmingle/core/analytics/analytics_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(screenName: 'screen_settings');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(userSubscriptionProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: AsyncValueViewEnhanced(
          value: currentUserAsync,
          data: (currentUser) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Card
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: currentUser?.photoUrl != null &&
                            currentUser?.photoUrl?.isNotEmpty == true
                        ? NetworkImage(currentUser!.photoUrl!) as ImageProvider
                        : null,
                    child: (currentUser?.photoUrl == null ||
                            currentUser?.photoUrl?.isEmpty == true)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(currentUser?.displayName ?? 'User'),
                  subtitle: Text(currentUser?.email ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.accountSettings);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Subscription Status
              subscriptionAsync.when(
                data: (subscription) {
                  if (subscription != null && subscription.isActive) {
                    return Card(
                      color: Colors.purple.shade50,
                      child: ListTile(
                        leading:
                            Icon(Icons.star, color: Colors.purple.shade700),
                        title: Text(
                          '${subscription.tier.name.toUpperCase()} Member',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                        subtitle: Text(
                            '${subscription.daysRemaining} days remaining'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pushNamed('/subscription');
                        },
                      ),
                    );
                  }
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.card_membership),
                      title: const Text('Free Plan'),
                      subtitle:
                          const Text('Upgrade to unlock premium features'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed('/subscription');
                      },
                    ),
                  );
                },
                loading: () => const Card(
                  child: ListTile(
                    leading: Icon(Icons.card_membership),
                    title: Text('Loading subscription...'),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Account Section
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.editProfile);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: const Text('Account Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.accountSettings);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.card_membership),
                      title: const Text('Subscription'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed('/subscription');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy & Safety Section
              Text(
                'Privacy & Safety',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Privacy Settings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.privacySettings);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: const Text('Blocked Users'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.blockedUsers);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notifications Section
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notification Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(AppRoutes.notificationSettings);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Appearance Section
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Theme'),
                  subtitle: const Text('Light'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement theme settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Theme settings coming soon')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // About Section
              Text(
                'About',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.help),
                      title: const Text('Help & Support'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Help center coming soon')),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Terms of Service')),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Privacy Policy')),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('Version'),
                      trailing: Text('1.0.0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade700),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (_) => false,
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
