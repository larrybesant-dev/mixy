// Riverpod provider for Notifications
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification.dart';

// Notifications state notifier
class NotificationsNotifier extends Notifier<List<NotificationItem>> {
  @override
  List<NotificationItem> build() => [];

  void addNotification(NotificationItem notification) {
    state = [...state, notification];
  }

  void removeNotification(String notificationId) {
    state = state.where((n) => n.id != notificationId).toList();
  }

  void clear() {
    state = [];
  }
}

final notificationProvider = NotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  () => NotificationsNotifier(),
);
