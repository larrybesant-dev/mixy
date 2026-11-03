import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../core/providers/firebase_providers.dart';
import '../../core/streams/stream_lifecycle_manager.dart';
import '../../features/friends/providers/friends_providers.dart';
import 'app_settings_provider.dart';
import 'user_provider.dart';

// Route through canonical provider so test overrides work.
final notificationFirestoreProvider = firestoreProvider;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    firestore: ref.watch(notificationFirestoreProvider),
  );
});

final currentNotificationUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider)?.id;
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(appSettingsControllerProvider)
          .valueOrNull
          ?.notificationsEnabled ??
      true;
});

final notificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final userId = ref.watch(currentNotificationUserIdProvider);
  final lifecycle = ref.watch(streamLifecycleManagerProvider);
  if (userId == null) {
    return const Stream<List<NotificationModel>>.empty();
  }

  return lifecycle.bind(
    key: 'notifications:$userId',
    create: () =>
        ref.watch(notificationServiceProvider).notificationsForUser(userId),
  );
});

final activeFriendRequestActorIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
  final userId = ref.watch(currentNotificationUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream.value(const <String>{});
  }

  return ref.watch(rawAllFriendshipsStreamProvider(userId)).map(
        (friendships) => friendships
            .where(
              (friendship) =>
                  friendship.status == 'pending' &&
                  friendship.requestedBy != userId,
            )
            .map((friendship) => friendship.requestedBy ?? '')
            .where((actorId) => actorId.isNotEmpty)
            .toSet(),
      );
});

final visibleNotificationsProvider =
    Provider.autoDispose<AsyncValue<List<NotificationModel>>>((ref) {
  final notifications = ref.watch(notificationsStreamProvider);
  final activeFriendRequestActorIds =
      ref.watch(activeFriendRequestActorIdsProvider).valueOrNull;

  return notifications.whenData((items) {
    if (activeFriendRequestActorIds == null) {
      return items;
    }

    return items.where((notification) {
      if (notification.type != 'friend_request') {
        return true;
      }
      final actorId = notification.actorId?.trim() ?? '';
      return actorId.isEmpty || activeFriendRequestActorIds.contains(actorId);
    }).toList(growable: false);
  });
});

/// Count of unread notifications for the current user. Derived from the
/// notifications stream so it stays live without an extra Firestore query.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  return ref
          .watch(visibleNotificationsProvider)
          .whenData((list) => list.where((n) => !n.isRead).length)
          .valueOrNull ??
      0;
});
