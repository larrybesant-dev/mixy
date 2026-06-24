import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/core/pagination/pagination_controller.dart';
import 'package:mixvy/shared/models/notification.dart';
import 'package:mixvy/shared/widgets/paginated_list_view.dart';
import 'package:mixvy/shared/providers/providers.dart';

/// Paginated notifications page with real-time updates
class NotificationsPaginatedPage extends ConsumerStatefulWidget {
  const NotificationsPaginatedPage({super.key});

  @override
  ConsumerState<NotificationsPaginatedPage> createState() =>
      _NotificationsPaginatedPageState();
}

class _NotificationsPaginatedPageState
    extends ConsumerState<NotificationsPaginatedPage> {
  late PaginationController<Notification> _controller;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    _currentUserId = user.id;

    // Initialize pagination controller
    _controller = PaginationController<Notification>(
      pageSize: 20,
      queryBuilder: () {
        return FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: _currentUserId)
            .orderBy('timestamp', descending: true);
      },
      fromDocument: (doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Notification.fromMap(data..['id'] = doc.id);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await ref.read(markNotificationAsReadProvider(notificationId).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as read')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              // TODO: Implement mark all as read
            },
          ),
        ],
      ),
      body: PaginatedListView<Notification>(
        controller: _controller,
        itemBuilder: (context, notification, index) {
          return _NotificationTile(
            notification: notification,
            onTap: () => _markAsRead(notification.id),
            onDismiss: () {
              // TODO: Delete notification
            },
          );
        },
        emptyWidget: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No notifications',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'You\'re all caught up!',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Notification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: _buildIcon(),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: const TextStyle(color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.timestamp),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color color;

    switch (notification.type) {
      case NotificationType.roomInvite:
        iconData = Icons.group_add;
        color = Colors.purple;
        break;
      case NotificationType.reaction:
        iconData = Icons.favorite;
        color = Colors.red;
        break;
      case NotificationType.newFollower:
        iconData = Icons.person_add;
        color = Colors.blue;
        break;
      case NotificationType.tip:
        iconData = Icons.attach_money;
        color = Colors.amber;
        break;
      case NotificationType.message:
        iconData = Icons.message;
        color = Colors.cyan;
        break;
      case NotificationType.system:
        iconData = Icons.info;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(iconData, color: color),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}

