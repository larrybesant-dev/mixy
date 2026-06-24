import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/design_constants.dart';
import '../../shared/widgets/club_background.dart';

/// Provider for notifications stream
final notificationsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList());
});

/// Provider for unread notification count
final unreadCountProvider = StreamProvider<int>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(0);
  }

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

/// In-app notification center
class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unreadCount = ref.watch(unreadCountProvider).asData?.value ?? 0;

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
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
              if (unreadCount > 0) ...
                [
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D8B),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFF4D8B)
                                .withValues(alpha: 0.5),
                            blurRadius: 8)
                      ],
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                ],
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _showUnreadOnly
                    ? Icons.mark_email_read
                    : Icons.mark_email_unread,
                color: _showUnreadOnly
                    ? const Color(0xFF00E5CC)
                    : DesignColors.textGray,
              ),
              tooltip:
                  _showUnreadOnly ? 'Show All' : 'Show Unread',
              onPressed: () =>
                  setState(() => _showUnreadOnly = !_showUnreadOnly),
            ),
            IconButton(
              icon: const Icon(Icons.done_all,
                  color: DesignColors.textGray),
              tooltip: 'Mark All Read',
              onPressed: _markAllAsRead,
            ),
            PopupMenuButton<String>(
              color: DesignColors.surfaceLight,
              icon: const Icon(Icons.more_vert,
                  color: DesignColors.textGray),
              onSelected: (value) async {
                switch (value) {
                  case 'clear':
                    await _clearAllNotifications();
                    break;
                  case 'settings':
                    if (context.mounted) {
                      Navigator.pushNamed(
                          context, '/settings/notifications');
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings,
                        color: DesignColors.textGray),
                    SizedBox(width: 8),
                    Text('Settings',
                        style:
                            TextStyle(color: DesignColors.white)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(children: [
                    Icon(Icons.clear_all,
                        color: DesignColors.textGray),
                    SizedBox(width: 8),
                    Text('Clear All',
                        style:
                            TextStyle(color: DesignColors.white)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        body: notificationsAsync.when(
          data: (notifications) {
            final filtered = _showUnreadOnly
                ? notifications
                    .where((n) => n['isRead'] != true)
                    .toList()
                : notifications;

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 72,
                      color: DesignColors.textGray
                          .withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _showUnreadOnly
                          ? 'All caught up! ✨'
                          : 'No notifications yet',
                      style: const TextStyle(
                          color: DesignColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showUnreadOnly
                          ? 'Nothing unread right now'
                          : 'Room invites, likes, matches—enjoy the ride',
                      style: const TextStyle(
                          color: DesignColors.textGray, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: DesignColors.accent,
              backgroundColor: DesignColors.surfaceLight,
              onRefresh: () async {
                ref.invalidate(notificationsStreamProvider);
              },
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    _buildNotificationCard(context, filtered[index]),
              ),
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: DesignColors.accent)),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: DesignColors.error),
                const SizedBox(height: 12),
                const Text('Error loading notifications',
                    style: TextStyle(color: DesignColors.white)),
                const SizedBox(height: 8),
                Text(error.toString(),
                    style: const TextStyle(
                        color: DesignColors.textGray),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final type = notification['type'] as String?;
    final createdAt =
        (notification['createdAt'] as Timestamp?)?.toDate();
    final notificationId = notification['id'] as String;
    final neonColor = _getNotificationColor(type);

    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? DesignColors.surfaceLight.withValues(alpha: 0.5)
              : neonColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? DesignColors.divider.withValues(alpha: 0.3)
                : neonColor.withValues(alpha: 0.35),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: isRead
              ? null
              : [
                  BoxShadow(
                      color: neonColor.withValues(alpha: 0.1),
                      blurRadius: 10)
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: neonColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: neonColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: neonColor.withValues(alpha: 0.2),
                      blurRadius: 8)
                ],
              ),
              child:
                  Icon(_getNotificationIcon(type), color: neonColor, size: 22),
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
                          title,
                          style: TextStyle(
                            color: DesignColors.white,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: neonColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: neonColor.withValues(alpha: 0.7),
                                  blurRadius: 6)
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...
                    [
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                            color: DesignColors.textLightGray,
                            fontSize: 13,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  if (createdAt != null) ...
                    [
                      const SizedBox(height: 6),
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(
                            color: DesignColors.textGray
                                .withValues(alpha: 0.6),
                            fontSize: 11),
                      ),
                    ],
                ],
              ),
            ),
            // Actions popup
            PopupMenuButton<String>(
              color: DesignColors.surfaceLight,
              icon: const Icon(Icons.more_vert,
                  color: DesignColors.textGray, size: 18),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                switch (value) {
                  case 'read':
                    await _markAsRead(notificationId, !isRead);
                    break;
                  case 'delete':
                    await _deleteNotification(notificationId);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'read',
                  child: Row(children: [
                    Icon(
                        isRead
                            ? Icons.mark_email_unread
                            : Icons.mark_email_read,
                        color: DesignColors.textGray),
                    const SizedBox(width: 8),
                    Text(isRead ? 'Mark Unread' : 'Mark Read',
                        style:
                            const TextStyle(color: DesignColors.white)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, color: DesignColors.error),
                    SizedBox(width: 8),
                    Text('Delete',
                        style: TextStyle(color: DesignColors.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'message':
        return Icons.message;
      case 'event':
      case 'eventInvite':
        return Icons.event;
      case 'match':
        return Icons.favorite;
      case 'follow':
        return Icons.person_add;
      case 'like':
        return Icons.thumb_up;
      case 'eventReminder':
        return Icons.alarm;
      case 'systemAlert':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'message':
        return const Color(0xFF4A90FF);   // neon blue
      case 'event':
      case 'eventInvite':
        return const Color(0xFF00E5CC);   // neon cyan
      case 'match':
        return const Color(0xFFFF4D8B);   // neon pink
      case 'follow':
        return const Color(0xFF00E5CC);   // neon cyan
      case 'like':
        return const Color(0xFFFF4D8B);   // neon pink
      case 'roomInvite':
        return const Color(0xFF4A90FF);   // neon blue
      case 'speedDatingMatch':
        return const Color(0xFFFF4D8B);   // neon pink
      case 'friendRequest':
        return const Color(0xFF8B5CF6);   // neon purple
      case 'friendOnline':
        return const Color(0xFF00E5CC);   // neon cyan
      case 'eventReminder':
        return const Color(0xFFFFAB00);   // neon amber
      case 'systemAlert':
        return DesignColors.error;
      default:
        return DesignColors.textGray;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final notificationId = notification['id'] as String;
    final type = notification['type'] as String?;
    final data = notification['data'] as Map<String, dynamic>?;

    // Mark as read
    await _markAsRead(notificationId, true);

    // Check if context is still mounted after async operation
    if (!mounted) return;

    // Navigate based on type
    switch (type) {
      case 'message':
        final conversationId = data?['conversationId'] as String?;
        if (conversationId != null && mounted) {
          Navigator.pushNamed(context, '/chat',
              arguments: {'conversationId': conversationId});
        }
        break;
      case 'event':
      case 'eventInvite':
        final eventId = data?['eventId'] as String?;
        if (eventId != null && mounted) {
          Navigator.pushNamed(context, '/events/details',
              arguments: {'eventId': eventId});
        }
        break;
      case 'match':
        if (mounted) {
          Navigator.pushNamed(context, '/matches');
        }
        break;
      case 'follow':
        final userId = data?['userId'] as String?;
        if (userId != null && mounted) {
          Navigator.pushNamed(context, '/profile/user',
              arguments: {'userId': userId});
        }
        break;
      default:
        break;
    }
  }

  Future<void> _markAsRead(String notificationId, bool isRead) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': isRead,
        'readAt': isRead ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final unreadDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final allDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in allDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
