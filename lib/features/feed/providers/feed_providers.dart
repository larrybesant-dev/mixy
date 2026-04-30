import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/room_service.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

import '../repository/feed_repository.dart';
import '../models/home_feed_snapshot.dart';
import '../models/post_model.dart';
import '../../../models/room_model.dart';
import '../../../models/social_activity_model.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/presence_repository.dart';
import '../../../services/social_activity_service.dart';
import '../services/home_feed_service.dart';
import 'package:mixvy/models/models.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.read(firestoreProvider));
});

final postsFeedProvider = StreamProvider.autoDispose<List<PostModel>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => PostModel.fromDoc(d.id, d.data())).toList(),
      );
});

final postsStreamProvider = FutureProvider.autoDispose<List<PostModel>>((ref) {
  return ref.read(feedRepositoryProvider).getPostsFeed();
});

final userPostsStreamProvider = StreamProvider.autoDispose.family<List<PostModel>, String>((
  ref,
  userId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('posts')
      .where('authorId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => PostModel.fromDoc(d.id, d.data())).toList(),
      );
});

final roomsStreamProvider = StreamProvider.autoDispose<List<RoomModel>>((ref) {
  // ref.watch (not ref.read) so dependency tracking works correctly if
  // roomServiceProvider is overridden in tests or re-initialized.
  return ref.watch(roomServiceProvider).watchLiveRooms(limit: 50);
});

final eventsStreamProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) {
  return ref.read(feedRepositoryProvider).getEventsFeed();
});

/// Dashboard metrics do not need live Firestore listeners on every page load.
/// Fetch them once and refresh when the screen is re-entered or manually pulled.
final onlineUsersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(presenceRepositoryProvider).countOnlineUsers(limit: 501);
});

final liveRoomsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final rooms = await ref.read(roomServiceProvider).getLiveRooms(limit: 501);
  return rooms.length;
});

final newMembersStreamProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(12)
      .get();
  return snapshot.docs
      .map((d) {
        final data = d.data();
        data['id'] = d.id;
        return UserModel.fromJson(data);
      })
      .toList(growable: false);
});

final trendingUsersStreamProvider = FutureProvider.autoDispose<List<UserModel>>(
  (ref) async {
    final snapshot = await ref
        .watch(firestoreProvider)
        .collection('users')
        .orderBy('balance', descending: true)
        .limit(10)
        .get();
    return snapshot.docs
        .map((d) => UserModel.fromJson({'id': d.id, ...d.data()}))
        .toList(growable: false);
  },
);

final socialActivityServiceProvider = Provider<SocialActivityService>((ref) {
  return SocialActivityService(firestore: ref.watch(firestoreProvider));
});

final homeFeedServiceProvider = Provider<HomeFeedService>((ref) {
  return const HomeFeedService();
});

final currentUserActivitiesProvider =
  FutureProvider.autoDispose<List<SocialActivity>>((ref) async {
    final currentUser = ref.watch(userProvider);
    final userId = currentUser?.id ?? '';
    return ref
      .watch(socialActivityServiceProvider)
      .getUserActivities(userId, limit: 12);
  });

final homeFeedSnapshotProvider =
    Provider.autoDispose<AsyncValue<HomeFeedSnapshot>>((ref) {
      final activitiesAsync = ref.watch(currentUserActivitiesProvider);
      final roomsAsync = ref.watch(roomsStreamProvider);
      final usersAsync = ref.watch(trendingUsersStreamProvider);

      if (activitiesAsync.isLoading &&
          roomsAsync.isLoading &&
          usersAsync.isLoading) {
        return const AsyncValue.loading();
      }

      return AsyncValue.data(
        ref
            .watch(homeFeedServiceProvider)
            .buildSnapshot(
              activities:
                  activitiesAsync.valueOrNull ?? const <SocialActivity>[],
              liveRooms: roomsAsync.valueOrNull ?? const <RoomModel>[],
              suggestedUsers: usersAsync.valueOrNull ?? const <UserModel>[],
            ),
      );
    });
