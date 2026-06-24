import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/providers.dart';
import '../../../shared/models/notification.dart' as app_notification;
import 'package:mixvy/core/analytics/analytics_service.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(screenName: 'screen_notifications');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return StreamBuilder<List<app_notification.Notification>>(
            stream: Stream.value([]), // TODO: Fix notifications stream
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No notifications yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_getNotificationIcon(notification.type)),
                      ),
                      title: Text(notification.title),
                      subtitle: Text(notification.message),
                      trailing: Text(
                        _formatTimestamp(notification.timestamp),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () =>
                          _handleNotificationTap(context, notification),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  IconData _getNotificationIcon(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.message:
        return Icons.message;
      case app_notification.NotificationType.newFollower:
        return Icons.person_add;
      case app_notification.NotificationType.roomInvite:
        return Icons.room;
      case app_notification.NotificationType.reaction:
        return Icons.thumb_up;
      case app_notification.NotificationType.tip:
        return Icons.attach_money;
      case app_notification.NotificationType.system:
        return Icons.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(
      BuildContext context, app_notification.Notification notification) {
    // Handle different notification types
    switch (notification.type) {
      case app_notification.NotificationType.message:
        if (notification.roomId != null) {
          Navigator.pushNamed(context, '/room',
              arguments: {'roomId': notification.roomId});
        }
        break;
      case app_notification.NotificationType.roomInvite:
        if (notification.roomId != null) {
          Navigator.pushNamed(context, '/room',
              arguments: {'roomId': notification.roomId});
        }
        break;
      default:
        // Handle other types
        break;
    }
  }
}

