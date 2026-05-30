import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme.dart';
import '../../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../../core/logger.dart';
import '../../features/feed/widgets/feed_empty_state.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/async_state_view.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all'; // all | mentions | gifts | system

  static const _mentionTypes = {
    'follow',
    'friend_request',
    'friend_accept',
    'friend_favorite',
    'like',
    'comment',
    'speed_dating_match',
  };
  static const _giftTypes = {'gift'};
  static const _systemTypes = {'live_room_invite'};

  bool _matchesFilter(String type) {
    switch (_filter) {
      case 'mentions':
        return _mentionTypes.contains(type);
      case 'gifts':
        return _giftTypes.contains(type);
      case 'system':
        return _systemTypes.contains(type) ||
            (!_mentionTypes.contains(type) && !_giftTypes.contains(type));
      default:
        return true;
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _handleNotificationTap(
    BuildContext context,
    String userId,
    NotificationModel notification,
    NotificationService service,
  ) async {
    if (!notification.isRead) {
      try {
        await service.markRead(userId, notification.id);
      } catch (error) {
        Logger.log('Failed to mark notification read on tap: $error');
      }
    }

    if (!context.mounted) return;

    final actorId = notification.actorId?.trim() ?? '';
    final roomId = notification.roomId?.trim() ?? '';

    switch (notification.type) {
      case 'live_room_invite':
        if (roomId.isNotEmpty) context.go('/room/$roomId');
      case 'follow':
      case 'friend_accept':
      case 'friend_favorite':
        if (actorId.isNotEmpty) context.go('/profile/$actorId');
      case 'friend_request':
        context.go('/friends');
      case 'speed_dating_match':
        context.go('/speed-dating');
      default:
        if (actorId.isNotEmpty) context.go('/profile/$actorId');
    }
  }

  // ── Icon + Color helpers ──────────────────────────────────────────────────

  IconData _iconForType(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add_rounded;
      case 'friend_request':
        return Icons.people_rounded;
      case 'friend_accept':
        return Icons.handshake_rounded;
      case 'friend_favorite':
        return Icons.star_rounded;
      case 'live_room_invite':
        return Icons.meeting_room_rounded;
      case 'speed_dating_match':
        return Icons.favorite_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'like':
        return Icons.thumb_up_rounded;
      case 'comment':
        return Icons.comment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'follow':
        return const Color(0xFF4FC3F7);
      case 'friend_request':
        return VelvetNoir.secondary;
      case 'friend_favorite':
        return const Color(0xFFFFD54F);
      case 'friend_accept':
        return const Color(0xFF81C784);
      case 'live_room_invite':
        return const Color(0xFF4DB6AC);
      case 'speed_dating_match':
        return const Color(0xFFFF6EB4);
      case 'gift':
        return const Color(0xFFFFB74D);
      case 'like':
        return VelvetNoir.error;
      case 'comment':
        return const Color(0xFF9FA8DA);
      default:
        return VelvetNoir.primary;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'follow':
        return 'New follower';
      case 'friend_request':
        return 'Friend request';
      case 'friend_accept':
        return 'Friend accepted';
      case 'friend_favorite':
        return 'Favorited you';
      case 'live_room_invite':
        return 'Room invite';
      case 'speed_dating_match':
        return 'Speed date match';
      case 'gift':
        return 'Gift received';
      case 'like':
        return 'New like';
      case 'comment':
        return 'New comment';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentNotificationUserIdProvider);
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final service = ref.read(notificationServiceProvider);

    return AppPageScaffold(
      appBar: AppBar(
        backgroundColor: VelvetNoir.surfaceHigh,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: VelvetNoir.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          if (userId != null)
            IconButton(
              icon: const Icon(
                Icons.done_all_rounded,
                color: VelvetNoir.onSurfaceVariant,
              ),
              tooltip: 'Mark all as read',
              onPressed: () => service.markAllRead(userId),
            ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: VelvetNoir.onSurfaceVariant,
            ),
            tooltip: 'Notification settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: userId == null
          ? const AppEmptyView(
              icon: Icons.notifications_off_outlined,
              title: 'Please sign in to view notifications.',
            )
          : Column(
              children: [
                if (!notificationsEnabled)
                  Container(
                    width: double.infinity,
                    color: VelvetNoir.surfaceBright,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.pageHorizontalPadding,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_off_outlined,
                          size: 16,
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Push notifications are disabled.',
                            style: TextStyle(
                              color: VelvetNoir.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/settings'),
                          style: TextButton.styleFrom(
                            foregroundColor: VelvetNoir.primary,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Enable',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                            horizontal: context.pageHorizontalPadding,
                            vertical: 6,
                          ),
                          children: [
                            _FilterChip(
                              label: 'All',
                              value: 'all',
                              selected: _filter == 'all',
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Mentions',
                              value: 'mentions',
                              selected: _filter == 'mentions',
                              onTap: () => setState(() => _filter = 'mentions'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Gifts',
                              value: 'gifts',
                              selected: _filter == 'gifts',
                              onTap: () => setState(() => _filter = 'gifts'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'System',
                              value: 'system',
                              selected: _filter == 'system',
                              onTap: () => setState(() => _filter = 'system'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: AppAsyncValueView<List<NotificationModel>>(
                          value: notificationsAsync,
                          fallbackContext: 'notifications',
                          isEmpty: (notifications) => notifications
                              .where((n) => _matchesFilter(n.type))
                              .isEmpty,
                          empty: const FeedEmptyState(
                            emoji: '🔔',
                            heading: 'All caught up!',
                            message:
                                'You have no notifications yet.\nRoom invites, friend requests and gift alerts will appear here.',
                          ),
                          data: (notifications) {
                            final filtered = notifications
                                .where((n) => _matchesFilter(n.type))
                                .toList();
                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filtered.length,
                              separatorBuilder: (__, _) => const Divider(
                                height: 1,
                                color: VelvetNoir.outlineVariant,
                                indent: 72,
                              ),
                              itemBuilder: (context, index) {
                                final n = filtered[index];
                                return _NotificationTile(
                                  notification: n,
                                  icon: _iconForType(n.type),
                                  color: _colorForType(n.type),
                                  label: _labelForType(n.type),
                                  timeAgo: _relativeTime(n.createdAt),
                                  onTap: () => _handleNotificationTap(
                                    context,
                                    userId,
                                    n,
                                    service,
                                  ),
                                  onMarkRead: n.isRead
                                      ? null
                                      : () async {
                                          try {
                                            await service.markRead(
                                              userId,
                                              n.id,
                                            );
                                          } catch (e) {
                                            Logger.log('Mark read failed: $e');
                                          }
                                        },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Notification Tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.label,
    required this.timeAgo,
    required this.onTap,
    this.onMarkRead,
  });

  final NotificationModel notification;
  final IconData icon;
  final Color color;
  final String label;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? VelvetNoir.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: unread
                                ? VelvetNoir.onSurface
                                : VelvetNoir.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: VelvetNoir.onSurfaceVariant,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: VelvetNoir.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: VelvetNoir.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Friend request inline actions
                  if (notification.type == 'friend_request') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ActionChip(
                          label: 'View Request',
                          color: VelvetNoir.primary,
                          onTap: onTap,
                        ),
                      ],
                    ),
                  ],
                  // Room invite inline action
                  if (notification.type == 'live_room_invite') ...[
                    const SizedBox(height: 10),
                    _ActionChip(
                      label: 'Join Room',
                      color: const Color(0xFF4DB6AC),
                      onTap: onTap,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? VelvetNoir.primary : VelvetNoir.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? VelvetNoir.primary
                : VelvetNoir.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? VelvetNoir.surface : VelvetNoir.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}



