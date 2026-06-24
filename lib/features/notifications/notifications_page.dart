// lib/features/notifications/notifications_page.dart
//
// Notifications Page — grouped by category, real-time, with mark-all-read.
//
// Groups: Chats · Feed · Friend Requests · Room Invites · Matches · Tips ·
//         Followers · System
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/models/app_notification.dart';
import '../../core/design_system/design_constants.dart';
import '../../shared/widgets/club_background.dart';
import 'widgets/notification_tile.dart';

// ── Group display order ────────────────────────────────────────────────────────
const _kGroupOrder = [
  'Chats',
  'Friend Requests',
  'Matches',
  'Feed',
  'Room Invites',
  'Tips',
  'Followers',
  'System',
];

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(appNotificationsProvider);
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: DesignColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Text(
                'NOTIFICATIONS',
                style: TextStyle(
                  color: DesignColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D8B), Color(0xFFFF6B35)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF4D8B)
                              .withValues(alpha: 0.5),
                          blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (unreadCount > 0)
              TextButton(
                onPressed: () =>
                    ref.read(markAllNotificationsReadProvider.future),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                      color: DesignColors.accent, fontSize: 12),
                ),
              ),
          ],
        ),
        body: notifAsync.when(
          data: (notifications) =>
              _buildBody(context, ref, notifications),
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: DesignColors.accent),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                const Text('Error loading notifications',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(appNotificationsProvider),
                  child: const Text('Retry',
                      style: TextStyle(color: DesignColors.accent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
  ) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 72,
                color: DesignColors.accent.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'All caught up!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'No notifications yet.\nWe\'ll let you know when something happens.',
              style: TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Partition into groups
    final Map<String, List<AppNotification>> grouped = {};
    for (final n in notifications) {
      grouped.putIfAbsent(n.groupLabel, () => []).add(n);
    }

    // Build ordered section list
    final sections = <Widget>[];
    for (final groupName in _kGroupOrder) {
      final items = grouped[groupName];
      if (items == null || items.isEmpty) continue;
      sections.add(_GroupSection(
          label: groupName,
          notifications: items));
    }
    // Any groups not in the ordered list (future types)
    for (final entry in grouped.entries) {
      if (!_kGroupOrder.contains(entry.key)) {
        sections.add(_GroupSection(
            label: entry.key,
            notifications: entry.value));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: sections,
    );
  }
}

// ── Section with sticky label ─────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  final String label;
  final List<AppNotification> notifications;

  const _GroupSection({required this.label, required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: DesignColors.accent.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),

        // Tiles
        ...notifications.map((n) => NotificationTile(notification: n)),
      ],
    );
  }
}
